---@class DropDB
local DropDB = QuestieLoader:CreateModule("DropDB")

---@type QuestieWotlkAcoreItemDrops
local QuestieWotlkAcoreItemDrops = QuestieLoader:ImportModule("QuestieWotlkAcoreItemDrops")

DropDB.tableAzerothCore = nil

function DropDB:Initialize()
    if not Questie.IsWotlk then
        Questie:Error("ItemDrops: AzerothCore drop data requires WotLK")
        return
    end

    DropDB.tableAzerothCore = loadstring(QuestieWotlkAcoreItemDrops.data)()
    QuestieWotlkAcoreItemDrops.data = nil
    collectgarbage()
end

-- To obtain final drop rate data, query QuestieDB.GetItemDroprate(ItemID,NpcID).
-- DropDB returns the effective AzerothCore drop rate generated from the server SQL.

-- The number provided is a float; it is up to the end user to determine how to display that.
-- 100.0 would be 100%, 47.254 would be 47.254%, etc.

-- Return values are {dropRate, sourceDB} as {float, str}

-- This function will return nil if the DB is not loaded properly or there is no data match.
-- Be sure you can handle successful nil returns!

---@param itemId ItemId
---@param npcId NpcId
---@return table<number, string>
function DropDB.GetItemDroprate(itemId, npcId)

    if DropDB.tableAzerothCore and DropDB.tableAzerothCore[itemId] and DropDB.tableAzerothCore[itemId][npcId]
    then
        return {DropDB.tableAzerothCore[itemId][npcId], "azerothcore"}
    end

    return nil
end