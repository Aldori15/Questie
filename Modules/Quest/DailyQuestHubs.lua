---@type DailyQuests
local DailyQuests = QuestieLoader:ImportModule("DailyQuests")

---@alias HubId string

---@class Hub
---@field quests QuestId[]
---@field limit number
---@field exclusiveHubs table<HubId, boolean>
---@field preQuestHubsSingle table<HubId, boolean>
---@field preQuestHubsGroup table<HubId, boolean>
---@field IsActive? function(completedQuests: table<QuestId, boolean>, questLog: table<QuestId, Quest>): boolean

-- 3.3.5-specific daily hub definitions live here. The logic in DailyQuests.lua
-- is ported from master; this table is the data hook for Wrath-era hubs as they
-- are identified and ported.
---@type table<HubId, Hub>
DailyQuests.hubs = {
}
