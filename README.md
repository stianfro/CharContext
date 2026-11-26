# CharContext

**CharContext** turns your **WoW Forever** character sheet into Markdown you can copy. Share your build with a guildmate, save your quest progress between sessions, or give an AI chat your current gear, talents, and inventory before asking for advice.

Type `/cc` to open the copy window. The text is already selected, so press **Ctrl+C** and paste it wherever you like. Use **Ctrl+A** to select the text again. Press **Esc** or click **Close** to close the window and clear the snapshot. Opening it again takes a fresh snapshot.

## Commands and example output

The examples are excerpts from a level 57 warlock’s snapshot, with the character name changed.

### `/cc` — Full character snapshot

Shows your level, race, class, faction, realm, XP, rested XP, location, hearthstone, and gold. It also includes combat stats, spell bonuses by school, talents, professions and skills, equipped gear, quest objectives, active buffs, bag space, and carried items. Typing `/cc` while the window is open closes it.

```text
# Mira Ashwick - 2026-11-27
Level 57 Gnome Warlock (Alliance) - Realm: n/a (realm name unavailable on Forever) - Region: US
XP: 157811/195000 (80.93% toward next level, rested 0)
Location: Mount Hyjal / Summit of Eternity - Hearth: Summit of Eternity
Gold: 149g 41s 70c
```

### `/cc bags` — Bag space and carried items

Shows each bag’s name, used slots, and free slots. The total distinguishes space available for general loot from specialty space, such as a warlock’s soul bag. Free slots with an unknown bag type are labeled unclassified. Matching stacks are totaled, and gear variants are listed separately. If an item name is unavailable, the report shows the item ID when the client supplies one.

```text
## Carried inventory
- Total space: 67/92 slots used, 25 free (13 general, 12 specialty)
- Backpack — 20/20 slots used, 0 free
- Bag 4: Red Mageweave Bag (general) — 1/14 slots used, 13 free
- Bag 5: Box of Souls (specialty) — 4/16 slots used, 12 free

### Items
- Hearthstone
- Major Mana Potion ×2
- Runecloth ×39
- Soul Shard ×4
```

### `/cc gear` — Equipped items

Lists equipment by slot, with item levels and enchant descriptions or IDs when available.

```text
## Equipped gear
- Head: Felcloth Hood (ilvl 58)
- Main hand: Soul Harvester (ilvl 52) (enchant: Intellect +5)
- Off hand: empty
```

### `/cc talents` — Talent build

Shows points spent in each tree, followed by the name and rank of each purchased talent.

```text
## Talents
Points: 41/7/0
- Demonology: Demonic Energies 2/2, Unholy Power 5/5
- Destruction: none
```

### `/cc quests` — Quest log and objective progress

Shows your quest count and log limit, each quest’s level and zone header, objective progress, and complete or failed status. Reading the log preserves your selected quest and collapsed headers.

```text
## Quest log (38/40)
- [58] Rubble Rummage (Mount Hyjal)
  - 1/5 Frayed Wire
  - 5/5 Calcified Excrement
  - 4/5 Warped Metal Scrap
- [58] Stolen Life (Mount Hyjal) (Complete)
  - 1/1 Drop of Stolen Life
```

### `/cc help` — Command list

```text
# CharContext

- /cc — open or close the full snapshot
- /cc quests — quest log and objectives
- /cc gear — equipped items
- /cc bags — bag space, bag names, and carried items
- /cc talents — talent points and ranks
- /cc help — show these commands
```

## Privacy

CharContext reads only your own character, on demand. The snapshot stays in the copy window until you close it. You choose what to copy and where to share it. Values the client cannot provide appear as `n/a`.

## Installation

Install the **Forever** release through CurseForge when available, or extract the release ZIP into `_forever_/Interface/AddOns/`. Check that the manifest is at `Interface/AddOns/CharContext/CharContext.toc`. If installing from source, copy the `CharContext` directory from this repository. Restart WoW and enable **CharContext** in the character selection screen’s AddOns list.

## Data and compatibility

The addon has no saved variables, automatic gameplay actions, background collection, chat output, or network integration.

CharContext reads bag names, capacity, free space, and items through `C_Container.GetBagName`, `GetContainerNumSlots`, `GetContainerNumFreeSlots`, and `GetContainerItemInfo`, using the older global functions when needed. If the free-space API is unavailable, it counts empty slots during the item scan. Unreadable totals appear as `n/a`.

This release targets Forever 1.60.1 (interface `16001`). It uses the client’s talent trees, skill lines, quest log, item cache, and helpful auras. The snapshot shows current and maximum health and mana independently. Each value appears as `n/a` if the client cannot supply it as readable text. If Forever withholds the realm name, the snapshot includes the region when available. Other missing data appears as `n/a`. If a collapsed skill header hides entries, open it in the Skills panel and take another snapshot. Quest selection and header state are preserved.

## Building the release ZIP

Run `python tools/package.py` with Python 3 from the repository root. The archive in `dist/` contains the addon's Lua file and manifest inside one `CharContext/` directory.
