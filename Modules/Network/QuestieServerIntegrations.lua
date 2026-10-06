---@class QuestieServerIntegrations
local Integrations = QuestieLoader:CreateModule("QuestieServerIntegrations")
local Server = QuestieLoader:ImportModule("QuestieServer")
local Event = QuestieLoader:ImportModule("QuestieEvent")
local Blacklist = QuestieLoader:ImportModule("QuestieQuestBlacklist")

-- Stable HolidayIds; server descriptions and localized calendar names are not protocol identifiers.
local holidays = {
    ["Midsummer"] = 341, ["Winter Veil"] = 141, ["Lunar Festival"] = 327,
    ["Love is in the Air"] = 423, ["Noblegarden"] = 181, ["Children's Week"] = 201,
    ["Harvest Festival"] = 321, ["Hallow's End"] = 324, ["Brewfest"] = 372,
    ["Pilgrim's Bounty"] = 404, ["Pirates' Day"] = 398, ["Day of the Dead"] = 409,
    ["Fireworks Spectacular"] = 62,
}

-- AC game_event_creature_quest: permanent unlocks and construction projects are
-- separate events, not nine mutually exclusive linear phases.
Integrations.quelDanasQuestEvents = {
    [11496] = 101, [11524] = 101, [11523] = 103, [11525] = 103,
    [11513] = 104, [11517] = 104, [11514] = 105, [11534] = 105, [11547] = 105,
    [11532] = 102, [11538] = 102, [11533] = 107, [11537] = 107,
    [11535] = 108, [11536] = 109, [11544] = 109,
    [11539] = 106, [11542] = 106, [11540] = 110, [11541] = 110,
    [11543] = 110, [11549] = 110, [11545] = 111, [11548] = 112,
    [11520] = 113, [11521] = 114, [11546] = 114,
}

function Integrations:GetQuelDanasQuestState(questId)
    local eventId = self.quelDanasQuestEvents[questId]
    if eventId then return Server:IsEventActive(eventId) end
end

local function FishingState(states)
    local crew, turnIns = Server:IsEventActive(62), Server:IsEventActive(90)
    if crew ~= nil and turnIns ~= nil then
        local offered = crew and turnIns
        for _, id in ipairs({8221, 8224, 8225}) do states[id] = offered end
        local winner = Server:GetWorldState(198)
        if not offered then
            states[8193], states[8194] = false, false
        elseif winner ~= nil then
            states[8193], states[8194] = winner == 0, winner == 1
        end
    end
    local announce = Server:IsEventActive(14)
    if announce ~= nil then states[8228], states[8229] = announce, announce end
    local kaluak = Server:IsEventActive(63)
    if kaluak == false then
        states[24803], states[24806] = false, false
    elseif kaluak == true then
        local finished = Server:IsKaluakDerbyFinished()
        if finished ~= nil then states[24803], states[24806] = not finished, finished end
    end
end

local function DarkmoonState(states, registrations)
    local locations = {{375, 1}, {374, 2}, {376, 3}}
    local activeLocations = {}
    for _, pair in ipairs(locations) do
        local active = Server:IsHolidayActive(pair[1])
        if active == nil then return nil end
        if active then activeLocations[#activeLocations + 1] = pair[2] end
    end
    for id, registration in pairs(registrations) do
        if registration.name == "Darkmoon Faire" and Event.IsQuestVisibleForExpansion(registration.expansion) then
            states[id] = #activeLocations > 0
        end
    end
    states[7905], states[7926] = Server:IsHolidayActive(374), Server:IsHolidayActive(375)
    return activeLocations
end

function Integrations:Refresh()
    local states = {}
    local registrations = Event.GetServerQuestRegistrations()
    -- Respect the user's content visibility choices; live state changes availability only.
    local profile = Questie.db.profile
    local locations
    if profile.showEventQuests then
        for id, registration in pairs(registrations) do
            local holiday = holidays[registration.name]
            if holiday and Event.IsQuestVisibleForExpansion(registration.expansion) then
                states[id] = Server:IsHolidayActive(holiday)
            end
        end
        FishingState(states)
        locations = DarkmoonState(states, registrations)
    end
    local scourge = Server:IsScourgeInvasionActive()
    if profile.showScourgeInvasionQuests and scourge ~= nil then
        for id in pairs(Blacklist.ScourgeInvasionQuests) do states[id] = scourge end
    end
    if profile.showSunsReachQuests then
        for id in pairs(self.quelDanasQuestEvents) do states[id] = self:GetQuelDanasQuestState(id) end
    end
    local available = QuestieLoader:ImportModule("AvailableQuests")
    for id, active in pairs(states) do
        if active and Event.IsServerQuestActive(id) == false then
            available.ClearUnavailableQuestForLiveTransition(id)
        end
    end
    local changed = Event.SetServerQuestStates(states)
    changed = Event.SetServerDarkmoonLocations(locations) or changed
    if changed then Event.RefreshAvailableQuests() end
end

function Integrations:Initialize()
    Server:WatchWorldState(198)
end
