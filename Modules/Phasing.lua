---@class Phasing
local Phasing = QuestieLoader:CreateModule("Phasing")

local bitband = bit.band
local math_max = math.max

-- Minimal Wrath-era phasing support for 3.3.5a.
local phases = {
    HAR_KOA_AT_ALTAR = 1034,
    HAR_KOA_AT_ZIM_TORGA = 1035,
}
Phasing.phases = phases

---@param phase number|nil
---@return boolean
function Phasing.IsSpawnVisible(phase)
    if (not phase) or phase == 0 then
        return true
    end

    if (not Questie) or (not Questie.db) or (not Questie.db.char) or (not Questie.db.char.complete) then
        return true
    end

    local complete = Questie.db.char.complete

    if phase == phases.HAR_KOA_AT_ALTAR then
        return not complete[12685]
    end

    if phase == phases.HAR_KOA_AT_ZIM_TORGA then
        return complete[12685] or false
    end

    return false
end

---Converts the 3.3.5 client difficulty values to AzerothCore's zero-based
---Map::GetSpawnMode value.
---@return number spawnMode
local function GetAzerothCoreSpawnMode()
    local isInInstance, instanceType = IsInInstance()
    if not isInInstance then
        return 0
    end

    local _, _, difficulty, _, _, playerDifficulty, isDynamicInstance = GetInstanceInfo()
    difficulty = difficulty or 1

    if instanceType == "raid" and isDynamicInstance and (difficulty == 1 or difficulty == 2) then
        return difficulty - 1 + ((playerDifficulty or 0) * 2)
    end

    return math_max(difficulty - 1, 0)
end

---A spawn tuple may contain Questie's phase ID at index 3 and generated
---AzerothCore spawnMask/map metadata at indices 4 and 5.
---Spawn masks are evaluated only while inside the matching instance. Outside,
---all difficulty variants remain visible for world-map planning.
---@param spawn number[]|nil
---@return boolean
function Phasing.IsSpawnDataVisible(spawn)
    if not spawn then
        return true
    end

    if not Phasing.IsSpawnVisible(spawn[3]) then
        return false
    end

    local spawnMask = spawn[4]
    if not spawnMask then
        return true
    end

    local isInInstance = IsInInstance()
    if not isInInstance then
        return true
    end

    local _, _, activeMapId = QuestieCompat.GetCurrentPlayerMinimapWorldPosition()
    local spawnMapId = spawn[5]
    if activeMapId and spawnMapId and activeMapId ~= spawnMapId then
        return true
    end

    return bitband(spawnMask, 2 ^ GetAzerothCoreSpawnMode()) ~= 0
end
