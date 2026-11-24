-- Only the slash handler reads the character. Keep nils in multi-return Classic APIs.
local function readable(value)
    return (not issecretvalue or not issecretvalue(value))
        and (not canaccessvalue or canaccessvalue(value))
        and (not canaccesstable or type(value) ~= "table" or canaccesstable(value))
end

local function publicResults(ok, ...)
    local count = select("#", ...)
    if not ok or count == 0 then return nil end
    if not issecretvalue and not canaccessvalue and not canaccesstable then return ... end
    local values = { ... }
    for i = 1, count do
        if not readable(values[i]) then values[i] = nil end
    end
    return unpack(values, 1, count)
end

local function call(fn, ...)
    if type(fn) == "function" then return publicResults(pcall(fn, ...)) end
    return nil
end

local function val(value)
    if not readable(value) or value == nil or value == "" then return "n/a" end
    return tostring(value)
end

local function pct(n)
    return type(n) == "number" and string.format("%.2f%%", n) or "n/a"
end

local function collectHeader(lines)
    local name, surname = call(UnitNameUnmodified or UnitName, "player")
    -- Forever's regional names can include a surname in the second return.
    local realm = call(GetRealmName)
    local _, _, _, interface = call(GetBuildInfo)
    local forever = (WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
        or (type(interface) == "number" and interface >= 16000 and interface < 17000)
    if realm == nil or realm == "" then
        if forever and GetRealmName then
            realm = "n/a (realm name unavailable on Forever)"
            local region = call(GetCurrentRegionName)
            if type(region) == "string" and region ~= "" then realm = realm .. " - Region: " .. region end
        elseif not forever then
            realm = call(GetNormalizedRealmName)
        end
    end
    if (forever or call(RegionalUniqueNamesEnabled)) and name and surname and surname ~= "" then
        name = name .. " " .. surname
    end
    local xp, maxXP = call(UnitXP, "player"), call(UnitXPMax, "player")
    local progress = type(xp) == "number" and type(maxXP) == "number" and maxXP > 0
        and pct(100 * xp / maxXP) or "n/a"
    local rested = call(function() return GetXPExhaustion() or 0 end)
    local copper = call(GetMoney)
    local gold = type(copper) == "number" and string.format("%dg %ds %dc",
        math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100) or "n/a"
    lines[#lines+1] = "# " .. val(name) .. " - " .. val(call(date, "%Y-%m-%d"))
    lines[#lines+1] = "Level " .. val(call(UnitLevel, "player")) .. " " .. val(call(UnitRace, "player"))
        .. " " .. val(call(UnitClass, "player")) .. " (" .. val(call(UnitFactionGroup, "player")) .. ") - Realm: " .. val(realm)
    lines[#lines+1] = "XP: " .. val(xp) .. "/" .. val(maxXP) .. " (" .. progress .. " toward next level, rested " .. val(rested) .. ")"
    local zone, subzone = call(GetZoneText), call(GetSubZoneText)
    if subzone == nil or subzone == "" then subzone = call(GetMinimapZoneText) end
    local location = val(zone)
    if type(subzone) == "string" and subzone ~= "" and subzone ~= zone then
        location = (zone and zone ~= "") and (location .. " / " .. subzone) or subzone
    elseif not GetSubZoneText and not GetMinimapZoneText and zone then
        location = location .. " / n/a"
    end
    lines[#lines+1] = "Location: " .. location .. " - Hearth: " .. val(call(GetBindLocation))
    lines[#lines+1] = "Gold: " .. gold
end

-- Preserve the difference between a missing getter and a value WoW forbids exporting.
local function resourceValue(getter, ...)
    if type(getter) ~= "function" then return nil end
    local ok, value = pcall(getter, ...)
    if not ok then return nil end
    if not readable(value) then return "n/a (client-restricted)" end
    if type(value) == "number" then return value end
end

local function collectStats(lines)
    local function stat(label, value)
        lines[#lines+1] = "- " .. label .. ": " .. val(value)
    end
    lines[#lines+1] = "## Stats"
    stat("Health", val(resourceValue(UnitHealth, "player")) .. " / " .. val(resourceValue(UnitHealthMax, "player")))
    local mana, maxMana = resourceValue(UnitPower, "player", 0), resourceValue(UnitPowerMax, "player", 0)
    if call(UnitPowerType, "player") == 0 then
        mana = mana or resourceValue(UnitPower, "player") or resourceValue(UnitMana, "player")
        maxMana = maxMana or resourceValue(UnitPowerMax, "player") or resourceValue(UnitManaMax, "player")
    end
    stat("Mana", val(mana) .. " / " .. val(maxMana))
    for i, label in ipairs({"Stamina", "Intellect", "Spirit"}) do
        local _, effective = call(UnitStat, "player", i + 2)
        stat(label, effective)
    end
    local _, armor = call(UnitArmor, "player")
    stat("Armor", armor)

    -- The paper doll numbers magic schools from Holy (2) to Arcane (7).
    local crit = call(GetSpellCritChance) -- Forever reports one spell crit percentage.
    local bySchool = type(crit) ~= "number" and type(GetSpellCritChance) == "function"
    lines[#lines+1] = ""
    lines[#lines+1] = "| School | Bonus spell damage |" .. (bySchool and " Spell crit |" or "")
    lines[#lines+1] = "|---|---:|" .. (bySchool and "---:|" or "")
    for i, school in ipairs({"Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane"}) do
        lines[#lines+1] = "| " .. school .. " | " .. val(call(GetSpellBonusDamage, i + 1))
            .. " |" .. (bySchool and (" " .. pct(call(GetSpellCritChance, i + 1)) .. " |") or "")
    end
    lines[#lines+1] = ""
    if not bySchool then stat("Spell crit", pct(crit)) end
    stat("Bonus spell healing", call(GetSpellBonusHealing))
    stat("Spell hit modifier", pct(call(GetSpellHitModifier)))
    if CR_HIT_SPELL then
        stat("Spell hit bonus from rating", pct(call(GetCombatRatingBonus, CR_HIT_SPELL)))
    end
    local haste = call(UnitSpellHaste, "player")
    if haste == nil then stat("Haste", pct(call(GetHaste)))
    else stat("Spell haste", pct(haste)) end
end

-- Use only the permanent-enchant line or the client's explicit localized label.
local function tooltipText(text)
    if not readable(text) or type(text) ~= "string" then return nil end
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[%w_]+:", "")
        :gsub("|r", ""):gsub("|H[^|]*|h(.-)|h", "%1"))
end

local function inventoryEnchantName(slot)
    local tip = call(C_TooltipInfo and C_TooltipInfo.GetInventoryItem, "player", slot)
    if not tip or not readable(tip.lines) or type(tip.lines) ~= "table" then return nil end
    local kinds = Enum and Enum.TooltipDataLineType or {}
    local format = tooltipText(ENCHANTED_TOOLTIP_LINE) or ""
    local prefix, suffix = format:match("^(.-)%%s(.-)$")
    local labeled
    for _, line in ipairs(tip.lines) do
        if readable(line) and type(line) == "table" and readable(line.type) then
            local text = tooltipText(line.leftText)
            if text and text ~= "" then
                local name
                if prefix and #prefix + #suffix > 0 and #text > #prefix + #suffix
                    and text:sub(1, #prefix) == prefix
                    and (#suffix == 0 or text:sub(-#suffix) == suffix) then
                    name = text:sub(#prefix + 1, #text - #suffix)
                end
                if kinds.ItemEnchantmentPermanent and line.type == kinds.ItemEnchantmentPermanent then
                    return name or text
                end
                if line.type == nil or line.type == kinds.None then labeled = labeled or name end
            end
        end
    end
    return labeled
end

local function unlinkedSlot(slot)
    -- A successful nil/zero ID means empty. A failed or restricted read stays unknown.
    if GetInventoryItemID then
        local ok, id = pcall(GetInventoryItemID, "player", slot)
        if not ok or not readable(id) then return "n/a" end
        if id == nil or id == 0 then return "empty" end
        if type(id) == "number" and id > 0 then return "item " .. id .. " (details n/a)" end
    elseif C_Item and C_Item.DoesItemExist then
        local loc = call(ItemLocation and ItemLocation.CreateFromEquipmentSlot, ItemLocation, slot)
        if loc and call(C_Item.DoesItemExist, loc) == false then return "empty" end
    end
    return "n/a"
end

local function collectGear(lines)
    lines[#lines+1] = "## Equipped gear"
    local slots = {"Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs",
        "Feet", "Wrists", "Hands", "Finger 1", "Finger 2", "Trinket 1", "Trinket 2",
        "Back", "Main hand", "Off hand", "Ranged / relic", "Tabard", [0] = "Ammo"}
    for slot = 0, #slots do
        local linkOK, link = pcall(GetInventoryItemLink, "player", slot)
        local result
        if linkOK and not readable(link) then
            result = "n/a"
        elseif linkOK and type(link) == "string" and link ~= "" then
            local name = link:match("|h%[(.-)%]|h")
            local enchant = tonumber(link:match("item:%d+:([%-]?%d+)"))
            local level, enchantName
            -- Only read metadata after the client confirms the item is already cached.
            if call(C_Item and C_Item.IsItemDataCachedByID or IsItemDataCachedByID, link) then
                local location = call(ItemLocation and ItemLocation.CreateFromEquipmentSlot, ItemLocation, slot)
                if location then level = call(C_Item and C_Item.GetCurrentItemLevel, location) end
                level = level or call(C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo, link)
                if not name or level == nil then
                    local cachedName, _, _, base = call(C_Item and C_Item.GetItemInfo or GetItemInfo, link)
                    name = name or cachedName
                    level = level or (base and (val(base) .. " base"))
                end
                if enchant and enchant > 0 then enchantName = call(inventoryEnchantName, slot) end
            end
            result = val(name) .. " (ilvl " .. val(level) .. ")"
            if enchantName then
                result = result .. " (enchant: " .. enchantName .. ")"
            elseif enchant and enchant > 0 then
                result = result .. " (enchant ID " .. enchant .. ")"
            end
        else
            result = unlinkedSlot(slot)
        end
        lines[#lines+1] = "- " .. slots[slot] .. ": " .. result
    end
end

local function collectBuffs(lines)
    lines[#lines+1] = "## Active buffs"
    local modern = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    local getter = modern or UnitBuff or UnitAura
    for index = 1, 256 do
        -- Distinguish an unreadable buff name from the end of the list.
        local present, name = call(function()
            local aura = getter("player", index, "HELPFUL")
            if not readable(aura) then return true end
            if not aura then return false end
            if modern then return true, aura.name end
            return true, aura
        end)
        if present == nil then
            lines[#lines+1] = "- n/a"
            return
        elseif not present then
            if index == 1 then lines[#lines+1] = "- None" end
            return
        end
        if type(name) ~= "string" or name:lower():match("^interface[\\/]") then
            name = nil
        end
        lines[#lines+1] = "- " .. val(name)
    end
    lines[#lines+1] = "- n/a (aura list limit)"
end

local function ranked(name, rank, maximum)
    return val(name) .. " " .. val(rank) .. "/" .. val(maximum)
end

local function classicTalentTrees(count)
    local trees = {}
    for tab = 1, count do
        local first, second, third, _, fifth = call(GetTalentTabInfo, tab)
        local name, points = first, third
        if type(first) == "number" then name, points = second, fifth end
        local tree = {name = name, points = points}
        local talents = call(GetNumTalents, tab)
        tree.incomplete = talents == nil
        for i = 1, talents or 0 do
            local talent, _, _, _, rank, maximum = call(GetTalentInfo, tab, i)
            if type(rank) ~= "number" then
                tree.incomplete = true
            elseif rank > 0 then
                tree[#tree + 1] = ranked(talent, rank, maximum)
            end
        end
        trees[#trees + 1] = tree
    end
    return trees
end

local function foreverTalentTrees()
    local traits = C_Traits or {}
    local id = call(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
    if not id then
        local spec = C_SpecializationInfo or {}
        local group = call(spec.GetActiveSpecGroup)
        if group then id = call(spec.GetCombatConfigIDForSpecGroup, group) end
    end
    local config = id and call(traits.GetConfigInfo, id)
    if not config or not config.treeIDs then return {} end
    -- The node API includes edits in the talent window before the player applies them.
    if call(traits.ConfigHasStagedChanges, id) then return {}, "n/a (unapplied talent changes)" end
    local trees = {}
    for _, treeID in ipairs(config.treeIDs) do
        -- Forever's three tabs share one tree. A node can belong to several other groups.
        local groups, ordered, groupIDs = {}, {}, {}
        for i, info in ipairs(call(traits.GetGroupDisplayInfoByTreeID, treeID) or {}) do
            local tab = {name = info.displayName, order = info.orderIndex or i, points = 0}
            ordered[#ordered + 1], groups[info.groupID] = tab, tab
            groupIDs[#groupIDs + 1] = info.groupID
        end
        table.sort(ordered, function(a, b) return a.order < b.order end)
        local nodes = call(traits.GetTreeNodes, treeID)
        local other, incomplete
        for _, nodeID in ipairs(nodes or {}) do
            local node = call(traits.GetNodeInfo, id, nodeID)
            local rank = node and node.ranksPurchased
            if type(rank) ~= "number" then
                incomplete = true
            elseif rank > 0 then
                local tab
                for _, groupID in ipairs(node.groupIDs or {}) do
                    if groups[groupID] then tab = groups[groupID] break end
                end
                if not tab then
                    other = other or {name = "Unspecified tree", points = 0}
                    tab = other
                end
                local entryID = node.activeEntry and node.activeEntry.entryID
                local entry = entryID and call(traits.GetEntryInfo, id, entryID)
                local def = entry and call(traits.GetDefinitionInfo, entry.definitionID)
                local name = def and def.overrideName
                if def and (not name or name == "") then
                    name = call(C_Spell and C_Spell.GetSpellName, def.spellID)
                end
                tab.points = tab.points + rank
                tab[#tab + 1] = ranked(name, rank, node.maxRanks)
            end
        end
        if other then ordered[#ordered + 1] = other end
        for _, tab in ipairs(ordered) do
            if incomplete or not nodes then tab.incomplete, tab.points = true, nil end
            trees[#trees + 1] = tab
        end
        -- The talent window shows currency spent, which can differ from a rank count.
        local totals = call(traits.GetGroupCurrencyInfo, id, groupIDs)
        if totals then
            for _, tab in pairs(groups) do tab.points = 0 end
            for _, total in ipairs(totals) do
                local tab = groups[total.traitNodeGroupID]
                local currency = total.currencyInfos and total.currencyInfos[1]
                if tab then tab.points = currency and currency.spent end
            end
        end
    end
    return trees
end

local function collectTalents(lines)
    lines[#lines + 1] = "## Talents"
    local count = call(GetNumTalentTabs)
    local trees, reason
    if count and count > 0 then trees = classicTalentTrees(count) else trees, reason = foreverTalentTrees() end
    if #trees == 0 then
        lines[#lines + 1] = reason or "n/a"
        return
    end
    local totals = {}
    for i, tree in ipairs(trees) do totals[i] = val(tree.points) end
    lines[#lines + 1] = "Points: " .. table.concat(totals, "/")
    for _, tree in ipairs(trees) do
        if tree.incomplete then tree[#tree + 1] = "n/a" end
        lines[#lines + 1] = "- " .. val(tree.name) .. ": " .. (#tree > 0 and table.concat(tree, ", ") or "none")
    end
end

local function collectSkills(lines)
    lines[#lines + 1] = "## Professions and skills"
    local groups, byName = {}, {}
    local function group(title)
        if not byName[title] then
            local new = { title = title }
            groups[#groups + 1], byName[title] = new, new
        end
        return byName[title]
    end

    local function add(bucket, name, rank, maximum, id, parent)
        local row = { name = name, rank = rank, maximum = maximum, id = id, parent = parent }
        for index, old in ipairs(bucket) do
            if name and old.name == name then
                -- Different IDs can produce identical display rows in the same group.
                if rank == old.rank and maximum == old.maximum then return end
                local child = parent and parent > 0 and parent == old.id
                local related = child or (id and id > 0 and (id == old.id or id == old.parent))
                local cap, oldCap = maximum or 0, old.maximum or 0
                -- Prefer a tracked progression to its 1/1 registration or missing rank.
                -- Keep unrelated, same-name lines when both have independent progress.
                if related or cap <= 1 or oldCap <= 1 then
                    local prefer = cap > oldCap or (cap == oldCap and (rank or -1) > (old.rank or -1))
                    if (rank == nil) ~= (old.rank == nil) then prefer = rank ~= nil
                    elseif related and id ~= old.id and cap > 1 and oldCap > 1 then prefer = child end
                    if prefer then bucket[index] = row end
                    return
                end
            end
        end
        bucket[#bucket + 1] = row
    end

    local api = C_SkillInfo or {}
    if not (api.GetNumSkillLines and api.GetSkillLineInfo) then api = _G end
    local count = call(api.GetNumSkillLines)
    local function row(i)
        if api ~= _G then
            local info = call(api.GetSkillLineInfo, i)
            if info then return info.name, info.isHeader, info.isCollapsed, info.rank, info.maxRank,
                info.skillID, info.parentSkillLineID end
        else
            local name, header, expanded, rank, _, _, maximum = call(api.GetSkillLineInfo, i)
            return name, header and header ~= 0, not expanded or expanded == 0, rank, maximum
        end
    end
    if count and api.GetSkillLineInfo then
        local current
        for i = 1, count do
            local name, header, collapsed, rank, maximum, id, parent = call(row, i)
            if header then
                current = group(val(name))
                current.collapsed = collapsed
            else
                current = current or group("")
                add(current, name, rank, maximum, id, parent)
            end
        end
    elseif GetProfessions and GetProfessionInfo then
        -- Some clients expose professions but have no character skill list.
        local profs = { call(GetProfessions) }
        local primary, secondary = group("Professions"), group("Secondary skills")
        for i = 1, 6 do
            if profs[i] then
                local name, _, rank, maximum, _, _, id = call(GetProfessionInfo, profs[i])
                add(i <= 2 and primary or secondary, name, rank, maximum, id)
            end
        end
    end
    for _, bucket in ipairs(groups) do
        if bucket.title ~= "" then lines[#lines + 1] = "### " .. bucket.title end
        if bucket.collapsed then lines[#lines + 1] = "- n/a (open this skill header and run /cc again)" end
        for _, skill in ipairs(bucket) do
            lines[#lines + 1] = "- " .. ranked(skill.name, skill.rank, skill.maximum)
        end
    end
    if #groups == 0 then lines[#lines + 1] = count == 0 and "none" or "n/a"
    elseif not count or not api.GetSkillLineInfo then lines[#lines + 1] = "Weapon and other skills: n/a" end
end

local function questRow(log, index)
    local info = call(log.GetInfo, index)
    if type(info) == "table" then return info, true end
    local title, level, _, header, _, complete, _, id = call(GetQuestLogTitle, index)
    if title then
        return { title = title, level = level, isHeader = header, isComplete = complete, questID = id }
    end
end

local function questFlag(info, log, modern)
    local complete = info.isComplete
    if complete == -1 or info.isFailed then return " (Failed)" end
    if complete == 1 or complete == true then return " (Complete)" end
    if modern then
        local failed = call(log.IsFailed, info.questID)
        local done = call(log.IsComplete, info.questID)
        if failed then return " (Failed)" end
        if done then return " (Complete)" end
        if failed == nil or done == nil then return " (status n/a)" end
    end
    return ""
end

local function questObjectives(lines, log, id, index)
    local objectives = id and call(log.GetQuestObjectives, id)
    local count = type(objectives) == "table" and #objectives or call(GetNumQuestLeaderBoards, index)
    if type(count) ~= "number" then
        lines[#lines+1] = "  - Objectives: n/a"
        return
    end
    for n = 1, count do
        local obj = type(objectives) == "table" and objectives[n]
        local label, finished, current, needed
        if type(obj) == "table" then
            label, finished, current, needed = obj.text, obj.finished, obj.numFulfilled, obj.numRequired
        else
            local text, _, done = call(GetQuestLogLeaderBoard, n, index)
            label, finished = text, done
        end
        label = val(label)
        -- Many clients already include localized counters in the objective text.
        if not label:match("%d%s*/%s*%d") then
            if current ~= nil and type(needed) == "number" and needed > 0 then
                label = val(current) .. "/" .. val(needed) .. " " .. label
            elseif finished then
                label = label .. " (Complete)"
            elseif finished == false then
                label = label .. " (Incomplete)"
            end
        end
        lines[#lines+1] = "  - " .. label
    end
end

local function collectQuests(lines)
    local log = C_QuestLog or {}
    local shown, total = call(log.GetNumQuestLogEntries)
    if shown == nil then shown, total = call(GetNumQuestLogEntries) end
    local maximum = call(log.GetMaxNumQuestsCanAccept) or MAX_QUESTLOG_QUESTS
    local heading, headers, listed = #lines + 1, {}, 0
    lines[heading] = "## Quest log"
    -- Older logs append quests under collapsed headers after the visible entries.
    -- Query by index or ID so the player's selection and headers stay intact.
    local limit = (shown or 0) + (total or maximum or 256)
    for index = 1, limit do
        local info, modern = questRow(log, index)
        if not info then
            if index > (shown or 0) then break end
        elseif info.isHeader then
            headers[#headers+1] = val(info.title)
        elseif not info.isHidden and not info.isInternalOnly then
            local zone = headers[#headers]
            if not modern and shown and index > shown then
                zone = headers[call(GetQuestSortIndex, index)]
            end
            lines[#lines+1] = "- [" .. val(info.level) .. "] " .. val(info.title) ..
                " (" .. val(zone) .. ")" .. questFlag(info, log, modern)
            questObjectives(lines, log, info.questID, index)
            listed = listed + 1
        end
    end
    if total == nil and (shown == 0 or listed > 0) then total = listed end
    lines[heading] = "## Quest log (" .. val(total) .. "/" .. val(maximum) .. ")"
    if total and listed < total then
        lines[#lines+1] = "- Quest details n/a for " .. (total - listed) .. " entries."
    end
end

local sections = {
    { "Character", collectHeader }, { "Stats", collectStats }, { "Talents", collectTalents },
    { "Skills", collectSkills }, { "Equipped gear", collectGear }, { "Quest log", collectQuests },
    { "Active buffs", collectBuffs },
}
local short = { quests = collectQuests, gear = collectGear, talents = collectTalents }
local help = [[# CharContext

- /cc — open or close the full snapshot
- /cc quests — quest log and objectives
- /cc gear — equipped items
- /cc talents — talent points and ranks
- /cc help — show these commands]]

local function snapshot(command)
    if command ~= "" and not short[command] then return help end
    local output = {}
    for _, section in ipairs(sections) do
        if command == "" or section[2] == short[command] then
            -- A custom or restricted nested result must not discard the rest of the snapshot.
            local lines = {}
            if not pcall(section[2], lines) or #lines == 0 then
                lines = { "## " .. section[1], "- n/a" }
            end
            output[#output + 1] = table.concat(lines, "\n")
        end
    end
    return table.concat(output, "\n\n")
end

-- All frames and scripts belong to the copy window. Create them only on first use.
local panel, scroll, box
local function createWindow()
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(math.min(640, UIParent:GetWidth() - 24), math.min(480, UIParent:GetHeight() - 24))
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.055, 0.065, 0.085, 0.98)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText("CharContext")
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", 16, 10)
    hint:SetText("Ctrl+A selects all    Ctrl+C copies    Esc closes")

    local close = CreateFrame("Button", nil, panel)
    close:SetSize(56, 28)
    close:SetPoint("TOPRIGHT", -6, -4)
    local label = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText("Close")
    close:SetScript("OnClick", function() panel:Hide() end)

    scroll = call(CreateFrame, "ScrollFrame", "CharContextScroll", panel, "UIPanelScrollFrameTemplate")
    if not scroll then
        scroll = CreateFrame("ScrollFrame", nil, panel)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local offset = self:GetVerticalScroll() - delta * 36
            self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
        end)
    end
    scroll:SetPoint("TOPLEFT", 16, -42)
    scroll:SetPoint("BOTTOMRIGHT", -36, 32)
    box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal or GameFontHighlight)
    box:SetMaxLetters(0)
    box:SetWidth(panel:GetWidth() - 52)
    box:SetHeight(1) -- Multiline EditBoxes grow with their wrapped text.
    box:SetPoint("TOPLEFT")
    scroll:SetScrollChild(box)
    box:SetScript("OnEscapePressed", function() panel:Hide() end)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(self.snapshot or "") end
    end)
    panel:SetScript("OnHide", function()
        box:ClearFocus()
        box.snapshot = nil
        box:SetText("")
    end)
end

if SlashCmdList then
    SLASH_CHARCONTEXT1 = "/cc"
    SlashCmdList.CHARCONTEXT = function(message)
        local command = (message or ""):lower():match("^%s*(.-)%s*$")
        if command == "" and panel and panel:IsShown() then
            panel:Hide()
            return
        end
        if not panel then
            if not CreateFrame or not UIParent then return end
            createWindow()
        end
        panel:Show()
        box.snapshot = snapshot(command)
        box:SetText(box.snapshot)
        call(scroll.UpdateScrollChildRect, scroll)
        box:SetCursorPosition(0)
        box:SetFocus()
        box:HighlightText()
        scroll:SetVerticalScroll(0)
    end
end
