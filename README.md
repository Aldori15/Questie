# Questie-335
This is the actively maintained successor to the [widxwer/Questie:335](https://github.com/widxwer/Questie/tree/335) fork, tracking true 3.3.5a (AzerothCore) compatibility.  This means that Questie's data should be a 1:1 match of what is seen on AzerothCore.  If you play on a server that has custom quest data or a server that is not Acore-driven, you may see anomalies and I cannot guarantee data to be a perfect match there.  Since I play using a local Acore server, my fork is driven by that.

All 16 open issues from the archived widxwer repo have been resolved, and this fork remains ahead with ongoing backports from the upstream Questie master branch, along with additional features, fixes and refactors.

A fork of the WoW Classic Questie addon aiming to provide compatibility with Wrath of the Lich King client version 3.3.5a (12340).
# Installation
- [Download](https://github.com/balintx/Questie/archive/refs/tags/335.zip) the archive.
- Extract it into `Interface/AddOns/` directory, folder name should be `Questie-335`.

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
