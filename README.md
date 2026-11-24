# CharContext

Type `/cc` in World of Warcraft: Forever to copy a Markdown snapshot of your character. Use it for play notes or paste it into an AI chat when you want advice about your current build, equipment, or quests.

## Using the copy window

1. Type `/cc`. The text is already selected.
2. Press **Ctrl+C**, then paste wherever you want to share it. Use **Ctrl+A** to select everything again.
3. Press **Esc**, click **Close**, or type `/cc` again to close the window and clear the snapshot. Open it again for fresh values.

| Command | Contents |
| --- | --- |
| `/cc` | Character, XP and rested XP, location and hearth, money, combat stats, talents, skills, equipment, quests, and active buff names |
| `/cc quests` | Quest levels, zones, completion flags, and objective progress |
| `/cc gear` | Equipped slots, cached item levels, and enchant descriptions or IDs |
| `/cc talents` | Points per tree and the rank of each purchased talent |
| `/cc help` | Command list |

## Installation

Install the **Forever** release through CurseForge when available, or extract the release ZIP into `_forever_/Interface/AddOns/`. Check that the manifest is at `Interface/AddOns/CharContext/CharContext.toc`. If installing from source, copy the `CharContext` directory from this repository. Restart WoW and enable **CharContext** in the character selection screen’s AddOns list.

## Data and compatibility

CharContext reads your own character through the in-game addon API when you run a command. The text stays in the window until you choose to copy it. The addon has no saved variables, automatic gameplay actions, background collection, chat output, or network integration.

This release targets Forever 1.60.1 (interface `16001`). It uses the client’s talent trees, skill lines, quest log, item cache, and helpful auras. Current health and mana can read `n/a (client-restricted)` while their maxima remain visible. If Forever withholds the realm name, the snapshot includes the region when available. Other missing data appears as `n/a`. If a collapsed skill header hides entries, open it in the Skills panel and take another snapshot. Quest selection and header state are preserved.

## Building the release ZIP

Run `python tools/package.py` with Python 3 from the repository root. The archive in `dist/` contains the addon's Lua file and manifest inside one `CharContext/` directory.
