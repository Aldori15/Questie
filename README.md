# Questie-335
This is the actively maintained successor to the [widxwer/Questie:335](https://github.com/widxwer/Questie/tree/335) fork, tracking true 3.3.5a (AzerothCore) compatibility.  This means that Questie's data should be a 1:1 match of what is seen on AzerothCore.  If you play on a server that has custom quest data or a server that is not Acore-driven, you may see anomalies and I cannot guarantee data to be a perfect match there.  Since I play using a local Acore server, my fork is driven by that.

All 16 open issues from the archived widxwer repo have been resolved, and this fork remains ahead with ongoing backports from the upstream Questie master branch, along with additional features, fixes and refactors.

A fork of the WoW Classic Questie addon aiming to provide compatibility with Wrath of the Lich King client version 3.3.5a (12340).

> [!IMPORTANT]
> **Warmane users:** Questie **v9.6.5 or newer** is required for party quest progress sharing. Version 9.6.5 includes a [Warmane addon communication compatibility fix](https://github.com/Aldori15/Questie/commit/1735a56). All members on Warmane using Questie should update, because older versions cannot exchange quest progress data correctly on Warmane.  More info in Issues [#101](https://github.com/Aldori15/Questie/issues/101) and [#103](https://github.com/Aldori15/Questie/issues/103).

# Installation
- [Download](https://github.com/Aldori15/Questie/archive/refs/heads/335.zip) the archive.
- Extract it into `Interface/AddOns/` directory, folder name should be `Questie-335`.

## Optional AzerothCore Server Bridge Module

Server owners can install [mod-questie-bridge](https://github.com/Aldori15/mod-questie-bridge)
to let Questie's quest availability, reset timing, and locations follow live AzerothCore state. It supports:

- Holidays started or stopped by GM commands or server scripts, including simultaneous Darkmoon Faire locations.
- Zalazane's Fall quests appear while the server event is active.
- Stranglethorn and Kalu'ak fishing quests before and after a tournament winner is declared.
- Scourge Invasion activity and Isle of Quel'Danas quest unlocks.
- The server's selected daily and weekly pool quests, before visiting the questgiver.
- ICC weekly quests follow the selected family, raid size, and unlocks in your current raid instance.
- Weekly and monthly quest completion history follows the server's reset schedule.
- Wintergrasp quests and questgiver locations as faction control changes.
- Questgiver markers follow loaded patrols and moving transport passengers in your current zone,
  including Orgrim's Hammer and the Skybreaker.
- NPC and object quest locations match your story phase in supported areas, including
  Icecrown, Storm Peaks, the death knight starting area, and other Wrath story regions.
- **World Progress** in related Journey quest details and hover tooltips, including Sun's Reach construction
  and Scourge Invasion battles and remaining necropolises.

Install the module on the server and this addon on the client; see the
[module installation instructions](https://github.com/Aldori15/mod-questie-bridge#installation).
Run `/qserver` to check the connection and server information. Use `/qserver pool <pool ID>`
or `/qserver wintergrasp` for more detail. Inside Icecrown Citadel, use `/qserver icc` to check its weekly quests.
Use `/qserver resets` to check the server's next weekly and monthly quest resets.
Use `/qserver phases` to check story-phase location filtering. It applies within your
current subarea; locations elsewhere keep their usual behavior.
Use `/qserver patrol` or `/qserver patrol <NPC ID>` to check live questgiver positions.
Patrol pins update once per second without smoothing, using loaded NPCs visible to your character
in the current zone. Opening another zone's map does not request remote NPC positions.
Missing or expired positions restore the usual marker and patrol line.

Your visibility options, character requirements, and manually hidden quests still apply.
Enable **Available Scourge Invasion Quests** or **Available Sun's Reach Quests** to show those quest sets.
Accepted quests remain tracked when server state changes.

The bridge is optional. Without it, or when its information becomes unavailable, Questie keeps its existing
calendar detection, manual settings, and daily quest discovery.
Install matching addon and module builds if `/qserver` reports a protocol mismatch.

## Regression checks

GitHub Actions runs the standalone regression suites on pushes and pull requests. It checks
the addon's Lua 5.1 syntax, then uses Lua 5.2 for the simulated-client tests and Python 3.13
for generator tests. No WoW client, running server, database, or private exports are required.
These checks cover bridge messages and fallback, patrol pins, phase metadata, quest completion,
and correction generation. In-game testing still verifies actual server and UI behavior.

The workflow checks protocol and phase profiles against a pinned compatible revision of
`mod-questie-bridge`. Update that revision in `.github/workflows/regressions.yml` when changing
the shared contracts. A missing configured bridge checkout fails the check rather than skipping it.

To run the same checks locally from the addon directory, with Lua 5.1, Lua 5.2, and Python installed:

```sh
python -B tools/check_lua_syntax.py --luac luac5.1
for test in tools/test_*.lua; do lua5.2 "$test" || exit; done
QUESTIE_TEST_LUA=lua5.2 python -B -m unittest discover -s tools -p 'test_*.py' -v
```

On Windows, run each `tools/test_*.lua` with your Lua 5.2 interpreter and set
`QUESTIE_TEST_LUA` to its executable path before running the Python command.
Set `QUESTIE_BRIDGE_SOURCE` to a compatible module checkout to include the shared-contract check;
without it, local tests look beside the addon and skip that check if no module source is found.

## Questie Information
- [Frequently Asked Questions](https://github.com/Questie/Questie/wiki/FAQ)
- Come chat with us on [our Discord server](https://discord.gg/s33MAYKeZd).
- You can use the [issue tracker](https://github.com/Aldori15/Questie/issues) to report bugs and post feature requests (requires a Github account).
- If you get an error message from the WoW client, please include the **complete** text or a screenshot of it in your report.
    - You need to enter `/console scriptErrors 1` once in the ingame chat for Lua error messages to be shown. You can later disable them again with `/console scriptErrors 0`.

Trust us it's (Good)!

# Features

### Show quests on map
- Show notes for quest start points, turn in points, and objectives.

![Questie Quest Givers](https://i.imgur.com/4abi5yu.png)
![Questie Complete](https://i.imgur.com/DgvBHyh.png)
![Questie Tooltip](https://i.imgur.com/uPykHKC.png)

### Quest Tracker
- Improved quest tracker:
    - Automatically tracks quests on accepting
    - Can show all 20 quests from the log (instead of default 5)
    - Left click quest to open quest log (configurable)
    - Right-click for more options, e.g.:
        - Focus quest (makes other quest icons translucent)
        - Point arrow towards objective (requires TomTom addon)

![QuestieTracker](https://user-images.githubusercontent.com/8838573/67285596-24dbab00-f4d8-11e9-9ae1-7dd6206b5e48.png)

### Quest Communication
- You can see party members quest progress on the tooltip.
- You can announce objective progress, objective complete, quest complete, quest accept, quest abandon to chat.

<img width="483" height="281" alt="image" src="https://github.com/user-attachments/assets/bed0522f-31e8-4ca1-a9fe-0927a12599df" />

### Tooltips
- Show tooltips on map notes and quest NPCs/objects.
- Holding Shift while hovering over a map icon displays more information, like quest XP.
- Show quest names on the tooltip of items that begin a quest.

<img width="707" height="160" alt="image" src="https://github.com/user-attachments/assets/d85698ba-7fdb-428c-a876-02cb8cc698f9" />

<img width="447" height="365" alt="image" src="https://github.com/user-attachments/assets/df379e3b-682c-404d-a966-c5b88d5856bf" />

#### Waypoints

- Waypoint lines for quest givers showing their pathing.
- With the TomTom addon, you can shift+left click an icon on the map to place a waypoint and navigate.

<img width="853" height="495" alt="image" src="https://github.com/user-attachments/assets/380aa249-927b-4132-aa54-3b267bbd0a2f" />

<img width="202" height="166" alt="image" src="https://github.com/user-attachments/assets/a44a1b5e-9bd0-49ae-9e27-b932050bd9f3" />

### Journey Log
- Questie records the steps of your journey in the "My Journey" window. (left-click on minimap button and select the "My Journey" tab or type `/questie journey`)

![Journey](https://user-images.githubusercontent.com/8838573/67285651-3cb32f00-f4d8-11e9-95d8-e8ceb2a8d871.png)

### Quests by Zone
- Questie lists all the quests of a zone divided between completed and available quest. Gotta complete 'em all. (left-click on minimap button (or type `/questie journey`) and select the "Quests by Zone" tab

![QuestsByZone](https://user-images.githubusercontent.com/8838573/67285665-450b6a00-f4d8-11e9-9283-325d26c7c70d.png)

### Quests by Faction
- Similarly to Quests by Zone, Questie lists all the quests of a faction divided between completed and available quest. Gotta complete 'em all. (left-click on minimap button (or type `/questie journey`) and select the "Quests by Faction" tab

### Search
- Questie's database can be searched. (left-click on minimap button (or type `/questie journey`) and select the "Advanced Search" tab

![Search](https://user-images.githubusercontent.com/8838573/67285691-4f2d6880-f4d8-11e9-8656-b3e37dce2f05.png)

### Configuration
- Extensive configuration options. (right-click on minimap button to open or type `/questie`)
