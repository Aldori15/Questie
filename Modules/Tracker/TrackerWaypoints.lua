---@class TrackerWaypoints
local TrackerWaypoints = QuestieLoader:CreateModule("TrackerWaypoints")

---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

-- Own the selected waypoint's identity and quest/objective association. TomTom's
-- numeric IDs can change on reload, so resolve identity before removing a target.
function TrackerWaypoints:ForgetTomTomTarget()
    Questie.db.char._tom_waypoint = nil
    Questie.db.char._tom_waypoint_quest = nil
    Questie.db.char._tom_waypoint_source = nil
    Questie.db.char._tom_waypoint_identity = nil
end

function TrackerWaypoints:GetTomTomTarget()
    local waypoint = Questie.db.char._tom_waypoint
    if not waypoint then
        return waypoint
    end

    local identity = Questie.db.char._tom_waypoint_identity
    if not identity or not identity.zone or not identity.coord or not TomTom or not TomTom.waypoints then
        return nil
    end

    local function matches(uid)
        local data = TomTom.waypoints[uid]
        return data and data.zone == identity.zone and data.coord == identity.coord and data.title == identity.title
            and (not TomTom.IsValidWaypoint or TomTom:IsValidWaypoint(uid))
    end

    if matches(waypoint) then
        return waypoint
    end
    for uid in pairs(TomTom.waypoints) do
        if type(uid) == "number" and matches(uid) then
            Questie.db.char._tom_waypoint = uid
            return uid
        end
    end
end

---Removes the currently tracked TomTom waypoint, if any.
function TrackerWaypoints:ClearTomTomTarget()
    local waypoint = TrackerWaypoints:GetTomTomTarget()
    if TomTom and TomTom.RemoveWaypoint and waypoint then
        TomTom:RemoveWaypoint(waypoint)
    end
    TrackerWaypoints:ForgetTomTomTarget()
end

---Removes the tracked TomTom waypoint only if it belongs to the given quest (and, if given, objective).
---@param questId number
---@param objectiveIndex ObjectiveIndex?
function TrackerWaypoints:ClearTomTomTargetForQuest(questId, objectiveIndex)
    local target = Questie.db.char._tom_waypoint_quest
    if (not target) or target.questId ~= questId then
        return
    end
    if objectiveIndex and target.objectiveIndex and target.objectiveIndex ~= objectiveIndex then
        return
    end
    TrackerWaypoints:ClearTomTomTarget()
end

---@param title string The name of the WayPoint
---@param zone number The zone ID number
---@param x number X coordinate
---@param y number Y coordinate
---@param questId number? The quest this waypoint belongs to
---@param objectiveIndex ObjectiveIndex? The objective this waypoint belongs to
---@param source string? "autoRoute" for automatic targets; all other callers are manual
function TrackerWaypoints:SetTomTomTarget(title, zone, x, y, questId, objectiveIndex, source)
    if TomTom and TomTom.AddWaypoint then
        TrackerWaypoints:ClearTomTomTarget()
        local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)

        local persistent
        if source == "autoRoute" then
            persistent = false
        end
        Questie.db.char._tom_waypoint = QuestieCompat.TomTom_AddWaypoint(title, uiMapId, x, y, persistent)

        if Questie.db.char._tom_waypoint and TomTom.waypoints then
            local data = TomTom.waypoints[Questie.db.char._tom_waypoint]
            if data then
                Questie.db.char._tom_waypoint_identity = { zone = data.zone, coord = data.coord, title = data.title }
            end
        end

        if questId and Questie.db.char._tom_waypoint then
            Questie.db.char._tom_waypoint_quest = { questId = questId, objectiveIndex = objectiveIndex }
        else
            Questie.db.char._tom_waypoint_quest = nil
        end
        Questie.db.char._tom_waypoint_source = Questie.db.char._tom_waypoint and (source or "manual") or nil
    end
end

---@param quest Quest
---@return boolean
function TrackerWaypoints:SetTomTomTargetToDungeonEntrance(quest)
    local dungeonLocation = quest and quest.zoneOrSort and ZoneDB:GetDungeonLocation(quest.zoneOrSort)
    local entrance = dungeonLocation and dungeonLocation[1]
    if not entrance then
        return false
    end

    local title = ZoneDB:GetLocalizedDungeonName(quest.zoneOrSort) or quest.name
    TrackerWaypoints:SetTomTomTarget(title, entrance[1], entrance[2], entrance[3], quest.Id)
    return true
end
