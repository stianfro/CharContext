-- Run from the repository root with Lua 5.1. Fixtures never access a live client.
local widgets, methods = {}, {}
local function noop() end
local function widget(kind)
    local w = { scripts = {} }
    widgets[kind] = w
    return setmetatable(w, { __index = methods })
end
for name in ("SetSize SetPoint SetFrameStrata SetClampedToScreen SetMovable EnableMouse RegisterForDrag " ..
             "StartMoving StopMovingOrSizing SetAllPoints SetTexture SetVertexColor SetMultiLine SetAutoFocus " ..
             "SetFontObject SetMaxLetters SetWidth SetHeight SetScrollChild SetCursorPosition SetFocus " ..
             "ClearFocus HighlightText SetVerticalScroll"):gmatch("%S+") do methods[name] = noop end
function methods:GetWidth() return 800 end
function methods:GetHeight() return 600 end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:SetText(value) self.text = value end
function methods:Show() self.shown = true end
function methods:IsShown() return self.shown end
function methods:Hide() self.shown = false; self.scripts.OnHide() end
function methods:CreateTexture() return widget("Texture") end
function methods:CreateFontString() return widget("Label") end
UIParent, CreateFrame, SlashCmdList = widget("Root"), widget, {}
assert(loadfile("CharContext/CharContext.lua"))()
assert(widgets.EditBox == nil)

local function report(command)
    if command == "" and widgets.Frame and widgets.Frame.shown then SlashCmdList.CHARCONTEXT("") end
    SlashCmdList.CHARCONTEXT(command)
    return widgets.EditBox.text
end
local function has(output, text)
    assert(output:find(text, 1, true), "Missing from snapshot: " .. text)
end
local function lacks(output, text)
    assert(not output:find(text, 1, true), "Unexpected in snapshot: " .. text)
end
local function fixed(value) return function() return value end end
local secret = {}
issecretvalue = function(value) return rawequal(value, secret) end
GetBuildInfo = function() return "1.60.1", nil, nil, 16001 end
UnitName = function(unit) assert(unit == "player"); return "Test", "Scribe" end
GetRealmName, GetCurrentRegionName = fixed(""), fixed("EU")
GetZoneText, GetSubZoneText, GetMinimapZoneText = fixed("Wetlands"), fixed(""), fixed("Wetlands")
UnitHealth, UnitHealthMax = fixed(0), fixed(500)
UnitPower, UnitPowerMax, UnitPowerType = fixed(120), fixed(600), fixed(0)
local text = report("")
has(text, "Test Scribe")
has(text, "Region: EU")
has(text, "Location: Wetlands - Hearth:")
has(text, "Health: 0 / 500")
has(text, "Mana: 120 / 600")

UnitHealth, UnitPower = fixed(secret), fixed(secret)
local legacyReads = 0
UnitMana = function() legacyReads = legacyReads + 1; return 777 end
GetMinimapZoneText, GetRealmName = fixed("Menethil Harbor"), fixed("Test Realm")
text = report("")
has(text, "Realm: Test Realm")
has(text, "Wetlands / Menethil Harbor")
has(text, "Health: n/a (client-restricted) / 500")
has(text, "Mana: n/a (client-restricted) / 600")
assert(legacyReads == 0)
UnitPower = function(unit, powerType)
    assert(unit == "player" and powerType == nil, "Legacy signature")
    return 45
end
has(report(""), "Mana: 45 / 600")

C_SkillInfo = {
    GetNumSkillLines = fixed(6),
    GetSkillLineInfo = function(i)
        return ({
            { name="Professions", isHeader=true },
            { name="Weaving", rank=125, maxRank=150, skillID=11 },
            { name="Weaving", rank=125, maxRank=150, skillID=12 },
            { name="Secondary Skills", isHeader=true },
            { name="Cooking", rank=25, maxRank=75, skillID=31 },
            { name="Cooking", rank=25, maxRank=75, skillID=32 },
        })[i]
    end,
}
text = report("")
for _, label in ipairs({"Weaving 125/150", "Cooking 25/75"}) do
    local _, hits = text:gsub(label, "")
    assert(hits == 1, label .. " appeared " .. hits .. " times")
end

local names = { [5]="Test Chest", [8]="Test Boots", [10]="Test Gloves" }
GetInventoryItemID = function(unit, slot) assert(unit == "player"); return names[slot] and 100 + slot or 0 end
GetInventoryItemLink = function(unit, slot)
    assert(unit == "player")
    if names[slot] then return ("|Hitem:%d:%d:0|h[%s]|h"):format(100+slot, 200+slot, names[slot]) end
end
C_Item = { IsItemDataCachedByID = fixed(true) }
Enum = { TooltipDataLineType = { ItemEnchantmentPermanent = 15 } }
C_TooltipInfo = { GetInventoryItem = function(unit, slot)
    assert(unit == "player" and names[slot])
    return { lines = {
        { type=0, leftText="+999 incorrect item bonus" },
        { type=15, leftText="Enchant on " .. names[slot] },
    } }
end }
text = report("gear")
has(text, "Ammo: empty")
lacks(text, "item 0")
lacks(text, "incorrect item bonus")
for _, name in pairs(names) do has(text, "Enchant on " .. name) end
C_TooltipInfo = nil
has(report("gear"), "205")
print("CharContext snapshot regression tests passed")
