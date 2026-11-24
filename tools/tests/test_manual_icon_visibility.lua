-- Run from the addon root with Lua 5.1 or 5.2+.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function noop() end
local env = setmetatable({}, {__index = _G})
env._G = env
local modules = {}
local function module(name)
    modules[name] = modules[name] or {private = {}}
    return modules[name]
end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end}
local profile = {enabled = true, enableMapIcons = true, enableMiniMapIcons = true}
env.Questie = {db = {profile = profile, char = {hidden = {}}}, Debug = noop}
env.QuestieCompat = {HBD = {}, HBDPins = {}, C_Timer = {}}
module("ThreadLib").ThreadInstant = function(callback) coroutine.wrap(callback)() end
module("AvailableQuests").CalculateAndDrawAll = noop
local map = module("QuestieMap")
local function loadModule(path)
    if setfenv then setfenv(assert(loadfile(path)), env)()
    else assert(loadfile(path, "t", env))() end
end
loadModule("Modules/Map/QuestieMap.lua")
loadModule("Modules/Map/QuestieMapUtils.lua")
loadModule("Modules/Quest/QuestieQuest.lua")
local quest = module("QuestieQuest")
quest.GetAllQuestIds = noop
local function icon(minimap)
    local frame = {miniMapIcon = minimap, hidden = false, hides = 0, shows = 0}
    function frame:FakeHide() self.hidden = true; self.hides = self.hides + 1 end
    function frame:FakeShow() self.hidden = false; self.shows = self.shows + 1 end
    function frame:ShouldBeHidden() error("manual markers must not use quest-specific filters") end
    return frame
end

for _, category in ipairs({{group = "any", id = -31}, {group = "Repair", id = 2994},
    {group = "Riding Trainer", id = 7954}}) do
    local world, mini = icon(false), icon(true)
    env.ManualWorld, env.ManualMini = world, mini
    map.manualFrames = {[category.group] = {[category.id] = {"ManualWorld", "ManualMini", "MissingFrame"}}}
    profile.enabled, profile.enableMapIcons, profile.enableMiniMapIcons = true, true, true
    profile.enableMiniMapIcons = false
    quest:ToggleNotes(false)
    equal(world.hidden, false, "minimap off preserves world marker: " .. category.group)
    equal(mini.hidden, true, "minimap off hides minimap marker")
    quest:ToggleNotes(false)
    equal(mini.hides, 1, "unchanged visibility does not repeat hide")
    profile.enableMapIcons = false
    quest:ToggleNotes(false)
    profile.enableMapIcons = true
    quest:ToggleNotes(true)
    equal(world.hidden, false, "world map can be restored independently")
    equal(mini.hidden, true, "world map restoration does not restore disabled minimap")
    profile.enableMapIcons = false
    quest:ToggleNotes(false)
    profile.enableMiniMapIcons = true
    quest:ToggleNotes(true)
    equal(world.hidden, true, "minimap restoration does not restore disabled world map")
    equal(mini.hidden, false, "minimap restored independently")
    local shows = mini.shows
    quest:ToggleNotes(true)
    equal(mini.shows, shows, "unchanged visibility does not repeat show")
    profile.enabled = false
    quest:ToggleNotes(false)
    quest:ToggleNotes(true)
    equal(world.hidden, true, "global off keeps world marker hidden")
    equal(mini.hidden, true, "global off keeps minimap marker hidden")
    profile.enabled = true
    quest:ToggleNotes(true)
    equal(world.hidden, true, "global restoration preserves disabled world map")
    equal(mini.hidden, false, "global restoration restores enabled minimap")
    profile.enableMapIcons = true
    quest:ToggleNotes(true)
    profile.enableObjectives, profile.showAvailableQuests = false, false
    quest:ToggleNotes(false)
    equal(world.hidden, false, "quest filters leave manual world markers visible")
    equal(mini.hidden, false, "quest filters leave manual minimap markers visible")
end

local explored = false
local now, explorationChecks = 0, 0
local refresh
env.debugprofilestop = function() return now end
module("ThreadLib").ThreadCallbackInstant = function(callback, onComplete)
    local thread = coroutine.create(callback)
    local timer = {}
    function timer:Cancel()
        equal(refresh, self, "only the pending refresh is cancelled")
        refresh = nil
    end
    function timer:Tick()
        local ok, message = coroutine.resume(thread)
        assert(ok, message)
        if coroutine.status(thread) == "dead" then
            refresh = nil
            onComplete()
        end
    end
    refresh = timer
    return timer
end
local function finishRefresh()
    while refresh do refresh:Tick() end
end
map.utils.IsExplored = function(uiMapId, x, y)
    equal(uiMapId, 1433, "manual pin exploration map")
    equal(x, 27, "manual pin exploration x")
    equal(y, 45, "manual pin exploration y")
    explorationChecks = explorationChecks + 1
    now = now + 10
    return explored
end
module("ZoneDB").GetUiMapIdByAreaId = function() return 1433 end
map.QueueDraw, map.utils.RescaleIcon = noop, noop
map.manualFrames = {}

local function draw(category, id)
    local index = 0
    module("QuestieFramePool").GetFrame = function()
        index = index + 1
        local frame = icon()
        local name = "Manual" .. id .. "_" .. index
        frame.GetName = function() return name end
        frame.SetWidth, frame.SetHeight = noop, noop
        frame.texture = {SetTexture = noop, SetTexCoord = noop, SetVertexColor = noop}
        env[name] = frame
        return frame
    end
    return map:DrawManualIcon({id = id, Name = category, GetIconScale = function() return 1 end}, 44, 27, 45, category)
end

profile.hideUnexploredMapIcons = true
local world, mini = draw("Inn", 6727)
equal(world.hidden, true, "world pin is hidden when drawn under fog")
equal(mini.hidden, true, "minimap pin is hidden when drawn under fog")
local exempt = {}
for index, category in ipairs({"any", "instanceDungeon", "instanceRaid"}) do
    local exemptWorld, exemptMini = draw(category, index)
    exempt[#exempt + 1] = exemptWorld
    exempt[#exempt + 1] = exemptMini
end

profile.hideUnexploredMapIcons = false
quest:RefreshManualIconVisibility()
equal(world.hidden, false, "turning filter off shows world pin")
equal(mini.hidden, false, "turning filter off shows minimap pin")
profile.hideUnexploredMapIcons = true
quest:RefreshManualIconVisibility()
equal(world.hidden, false, "enabling schedules the expensive scan")
local beforeTick = explorationChecks
refresh:Tick()
equal(explorationChecks, beforeTick + 1, "expensive lookups yield between frames")
equal(world.hidden, true, "first batch hides the world pin")
equal(mini.hidden, false, "next batch has not run yet")

profile.hideUnexploredMapIcons = false
quest:RefreshManualIconVisibility()
equal(refresh, nil, "disabling cancels the partial refresh")
equal(world.hidden, false, "disabling immediately restores the first batch")
profile.hideUnexploredMapIcons = true
quest:RefreshManualIconVisibility()
finishRefresh()
equal(world.hidden, true, "turning filter on hides existing world pin")
equal(mini.hidden, true, "turning filter on hides existing minimap pin")
for _, frame in ipairs(exempt) do
    equal(frame.hidden, false, "search and instance pins stay visible through fog")
end

explored = true
profile.enableMiniMapIcons = false
quest:RefreshManualIconVisibility()
map.utils.MapExplorationUpdate()
finishRefresh()
equal(world.hidden, false, "discovery makes the world pin visible")
equal(mini.hidden, true, "discovery respects disabled minimap")
profile.enableMiniMapIcons = true
map.utils.MapExplorationUpdate()
finishRefresh()
equal(mini.hidden, false, "explored minimap pin can be shown")

explored = false
quest:RefreshManualIconVisibility()
map.manualFrames.Inn[6727] = nil
local beforeRemoval = explorationChecks
finishRefresh()
equal(explorationChecks, beforeRemoval, "removed pins are skipped during a pending refresh")
print("Manual icon visibility: map toggles, quest-filter isolation, exploration and exemptions passed")
