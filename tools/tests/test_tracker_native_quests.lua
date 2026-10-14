-- Run from the addon root with Lua 5.1 or 5.2+.
-- Native display fallback, real sorting/manual tracking/menu paths, and snapshot lifetime.
local function equal(a, b, label) assert(a == b, label .. ": " .. tostring(a)) end
local function noop() end
local env = setmetatable({}, {__index = _G})
env._G, env.tinsert, env.strmatch = env, table.insert, string.match
local modules = {}
local function module(name) modules[name] = modules[name] or {private = {}}; return modules[name] end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end, ImportModule = function(_, name) return module(name) end}
local function loadModule(path)
    if setfenv then setfenv(assert(loadfile(path)), env)()
    else assert(loadfile(path, "t", env))() end
end
local clock, selected, shift, useHeaderLogIndex = 100, nil, false, false
local rows = {{title = "Zone A", header = true}, {title = "Known", id = 100, level = 10},
    {title = "Zone B", header = true}, {title = "Custom quest", id = 900001, level = -1, ordinal = 1},
    {title = "Custom action", id = 900002, level = 20, ordinal = 2},
    {title = "Loading quest", id = 900003, level = 30, ordinal = 1}}
local function logTitle(index)
    local row = rows[index]
    if row then return row.title, row.level, nil, row.header, nil, row.complete, 1, row.id end
end
local function logIndex(id) for i, row in ipairs(rows) do if row.id == id then return i end end end
env.GetNumQuestLogEntries = function() return 3, 4 end
env.GetQuestSortIndex = function(index)
    local ordinal = index == 1 and 1 or index == 3 and 2 or rows[index].ordinal
    return useHeaderLogIndex and ordinal == 2 and 3 or ordinal
end
env.GetQuestLogSpecialItemInfo = function(index)
    if rows[index].id == 900001 then return "|Hitem:99999:0|h[Test item]|h", "texture", 1 end
end
env.GetTime = function() return clock end
env.GetNumQuestWatches = function() return 0 end
env.LibStub = function() return {} end
env.GetItemCount = function(id) return id == 99999 and 1 or 0 end
env.GetItemSpell = function(id) if id == 99999 then return "Use item" end end
env.IsEquippableItem = function() return false end
env.IsShiftKeyDown = function() return shift end
env.IsInInstance = function() return false end
env.RemoveQuestWatch, env.GetTrackedAchievements = noop, noop
env.QuestLogFrame = {IsShown = function() return true end}
env.QuestLogListScrollFrame = {ScrollBar = {GetValueStep = function() return 1 end, SetValue = noop}}
env.SelectQuestLogEntry = function(index) selected = index end
env.ExpandQuestHeader = noop
env.QuestLog_UpdateQuestDetails, env.QuestLog_Update = noop, noop
env.UIParent, env.StaticPopupDialogs = {}, {}
local char = {TrackedQuests = {}, AutoUntrackedQuests = {}, collapsedQuests = {}, collapsedZones = {}}
local profile = {trackerEnabled = true, autoTrackQuests = false, trackerSortObjectives = "byZone", trimObjectiveText = true}
env.Questie = {db = {char = char, profile = profile}, Debug = noop, Colorize = function(_, text) return text end}
env.QuestieCompat = {GetQuestLogTitle = logTitle, GetQuestLogIndexByID = logIndex,
    GetQuestLink = function(id) return "|Hquest:" .. id .. ":20|h[Native quest]|h" end,
    C_Map = {GetBestMapForUnit = function() end}, C_Timer = {NewTicker = function() return {Cancel = noop} end},
    LibUIDropDownMenu = {Create_UIDropDownMenu = function() return {} end}}
local known = {Id = 100, name = "Known", level = 10, zoneOrSort = 100,
    Objectives = {{Collected = 0, Needed = 0}}, IsComplete = function() return 0 end}
module("QuestiePlayer").currentQuestlog = {[100] = known}
module("QuestiePlayer").GetPlayerLevel = function() return 80 end
module("QuestieDB").QuestPointers = {[100] = true}
local names = {[100] = "Known"}
module("QuestieDB").QueryQuestSingle = function(id, key) if key == "name" then return names[id] end end
-- Load the real validity helper without initializing the unrelated database adapters.
local dbFile = assert(io.open("Database/QuestieDB.lua", "r"))
local dbSource = dbFile:read("*a"); dbFile:close()
local validity = "local QuestieDB = QuestieLoader:ImportModule('QuestieDB')\n"
    .. assert(dbSource:match("function QuestieDB.HasQuestData%(questId%).-\nend"))
if setfenv then setfenv(assert(loadstring(validity)), env)()
else assert(load(validity, "@database-quest-validity", "t", env))() end
module("QuestieDB").QueryItemSingle = function() error("Native item must not require database metadata") end
local cache = {[900001] = {objectives = {[1] = {text = "Collect crystals", raw_text = "Collect crystals: 0/5",
    type = "item", numFulfilled = 2, numRequired = 5, raw_finished = false}}},
    [900002] = {objectives = {[1] = {text = "Activate device", raw_text = "Activate device: 1/1", type = "object",
        numFulfilled = 1, numRequired = 1, raw_finished = false},
        [3] = {text = "Speak to the engineer", raw_text = "Speak to the engineer", type = "log",
        numFulfilled = 0, numRequired = 1, raw_finished = false}}}}
module("QuestLogCache").questLog_DO_NOT_MODIFY = cache
local lib = module("QuestieLib")
lib.GetFullObjectiveText = function(text) if not profile.trimObjectiveText then return text:gsub(": %d+/%d+$", "") end end
lib.PrintDifficultyColor = function(_, _, text) return text end
lib.GetColoredQuestName = function() return "Known colored title" end
lib.GetQuestTypeSuffixPriority = function() return 0 end
lib.GetRGBForObjective = function(_, obj) return obj.Collected >= obj.Needed and "green" or "red" end
module("QuestieLink").GetQuestInsertStringById = function() return "Known link" end
setmetatable(module("l10n"), {__call = function(_, text) return text end})
module("l10n").zoneLookup = {{[100] = "Zone A"}}
module("QuestieCoords").GetPlayerMapPosition = noop
module("TrackerWaypoints").SetTomTomTargetToDungeonEntrance = function() error("Native quests have no navigation metadata") end
module("QuestieMap").GetNearestQuestSpawn = function(_, quest) assert(not quest.NativeOnly, "Native quests must not enter map sorting") end
module("QuestieCombatQueue").Queue = noop
module("CommsVisibility").ScheduleSnapshot = noop
module("AutoRoute").ScheduleUpdate = noop
loadModule("Modules/Tracker/TrackerData.lua")
loadModule("Modules/Tracker/TrackerUtils.lua")
loadModule("Modules/Tracker/Sorter/Sorter.lua")
for _, name in ipairs({"byZone", "byLevel", "byComplete"}) do loadModule("Modules/Tracker/Sorter/" .. name .. ".lua") end
loadModule("Modules/Tracker/TrackerQuestOrder.lua")
loadModule("Modules/Tracker/TrackerObjectiveText.lua")
local data, order = module("TrackerData"), module("TrackerQuestOrder")
local quests = data.Refresh()
equal(quests[100], known, "Known map object identity retained")
equal(module("QuestiePlayer").currentQuestlog[900001], nil, "Native display cannot enter map object storage")
equal(quests[900001].zoneName, "Zone A", "Hidden quest resolves header ordinal")
equal(quests[900002].zoneName, "Zone B", "Second hidden header is not a log index")
useHeaderLogIndex = true
equal(data.Refresh()[900002].zoneName, "Zone B", "Native header keys also work when the client returns log indices")
useHeaderLogIndex = false
equal(quests[900001].level, 80, "Scaling level resolved")
equal(quests[900003]:IsComplete(), 0, "Loading title is not complete")
equal(#quests[900003].Objectives, 0, "Unloaded objectives are not fabricated")
equal(#quests[900002].Objectives, 2, "Objective holes do not truncate later rows")
equal(quests[900002].Objectives[2].NativeIndex, 3, "Native objective index retained")
equal(quests[900002].Objectives[1].Completed, false, "Unfinished 1/1 does not become complete")
equal(quests[900001].sourceItemId, 99999, "Native quest item ID")
equal(module("TrackerUtils"):GetUsableQuestItemIds(quests[900001])[1], 99999, "Usable native item without database entry")
local format = module("TrackerObjectiveText").GetQuestObjectiveText
profile.trimObjectiveText = false
assert(format(quests[900001].Objectives[1], "Unused"):find("Collect crystals: 2/5", 1, true), "Accepted progress replaces stale native counter")
assert(format(quests[900002].Objectives[1], "Unused"):find("red", 1, true), "Unfinished full-counter action is not green")
profile.trimObjectiveText = true
assert(format(quests[900002].Objectives[1], "Activate device"):find("red", 1, true), "Trimmed action retains native completion")
equal(format(quests[900002].Objectives[2], "Unused"), "red- Speak to the engineer|r", "Log instruction has no invented counter")
local previous = quests[900001].Objectives
cache[900001] = nil
equal(data.Refresh()[900001].Objectives, previous, "Loading gap retains accepted display snapshot")
cache[900001] = {objectives = {[1] = {text = "Crystals", type = "item", numFulfilled = 3, numRequired = 5, raw_finished = false}}}
equal(data.Refresh()[900001].Objectives[1].Collected, 3, "Loading recovery updates progress")
local ids, details = order:GetSortedQuestIds()
equal(#ids, 4, "Native and known quests both sort")
equal(details[900001].zoneName, "Zone A", "Native header reaches renderer details")
for _, mode in ipairs({"byLevel", "byComplete", "byZonePlayerProximity"}) do
    profile.trackerSortObjectives = mode
    equal(#(order:GetSortedQuestIds()), 4, "Native quests survive " .. mode)
end
profile.trackerSortObjectives = "byLevel"
loadModule("Modules/Tracker/QuestieTracker.lua")
local tracker = module("QuestieTracker")
local group = order.GetQuestGroupName(quests[900001])
char.collapsedQuests[900001], char.collapsedZones[group] = true, true
clock = clock + 1
tracker:AQW_Insert(4, 0)
equal(char.TrackedQuests[900001], true, "Manual tracking accepts database-unknown quest")
equal(char.collapsedQuests[900001], nil, "Retracking expands quest")
equal(char.collapsedZones[group], nil, "Retracking expands displayed group")
tracker:UntrackQuestId(900001)
equal(char.TrackedQuests[900001], nil, "Manual untracking")
profile.autoTrackQuests, shift = true, true
clock = clock + 1
tracker:AQW_Insert(4, 0)
equal(char.AutoUntrackedQuests[900001], true, "Automatic mode supports manual untracking")
clock = clock + 1
tracker:AQW_Insert(4, 0)
equal(char.AutoUntrackedQuests[900001], nil, "Automatic mode supports retracking")
loadModule("Modules/Tracker/TrackerMenu.lua")
local menu = module("TrackerMenu"):GetMenuForQuest(quests[900001])
local found = {}
for _, entry in ipairs(menu) do found[entry.text] = true end
assert(found["Show in Quest Log"] and found["Link Quest to chat"] and found["Abandon Quest"] and found["Untrack Quest"], "Native menu retains normal actions")
assert(not found["Focus Quest"] and not found["Show on Map"], "Native menu does not offer unsupported map actions")
equal(data.GetQuestLink(quests[900001]), "|Hquest:900001:20|h[Native quest]|h", "Native chat link")
rows[4].complete = -1
equal(data.Refresh()[900001]:IsComplete(), -1, "Native failure flag")
rows[4].complete = 1
equal(data.Refresh()[900001]:IsComplete(), 1, "Native completion flag")
tracker:RemoveQuest(900001)
cache[900001], rows[4].complete = nil, nil
local fresh = data.Refresh()[900001]
assert(fresh ~= quests[900001] and #fresh.Objectives == 0, "Removed/reaccepted quest cannot inherit previous snapshot")
rows[4].id = 900004
equal(data.GetQuest(900001), nil, "Native quest disappears on removal")
equal(data.ContainsQuest(900001), false, "Removed membership")

-- A temporary preview exercises native display without damaging live database/map state.
local redraw
module("QuestieCombatQueue").Queue = function(_, callback) redraw = callback end
local enabled = data.SetNativeQuestPreview(100)
equal(enabled, true, "Preview accepts an existing mapped quest")
assert(redraw, "Preview refresh waits for the combat queue")
local preview = data.GetQuest(100)
assert(preview.NativeOnly and preview ~= known, "Preview uses a separate native display record")
equal(module("QuestieDB").QuestPointers[100], true, "Preview preserves database membership")
equal(module("QuestiePlayer").currentQuestlog[100], known, "Preview preserves original map object")
equal(data.SetNativeQuestPreview(999999), false, "Invalid preview ID is rejected")
equal(data.GetQuest(100), preview, "Rejected preview leaves current preview intact")
equal(data.SetNativeQuestPreview(nil), true, "Preview can be stopped")
equal(data.GetQuest(100), known, "Stopping restores original mapped display")
equal(data.Refresh()[100], known, "Subsequent renders cannot reuse the preview")

-- Removing quest 5's base row leaves correction-only metadata and a compiled pointer.
local placeholder = {Id = 5, name = "Quest 5", level = 0, Objectives = {}, IsComplete = function() return 1 end}
module("QuestieDB").QuestPointers[5] = true
module("QuestiePlayer").currentQuestlog[5] = placeholder
rows[7] = {title = "Jitters' Growling Gut", id = 5, level = 20, ordinal = 1}
equal(module("QuestieDB").HasQuestData(5), false, "Correction-only pointer is not usable quest data")
local corrected = data.Refresh()[5]
assert(corrected.NativeOnly and corrected ~= placeholder, "Correction-only object cannot suppress native fallback")
equal(corrected.name, "Jitters' Growling Gut", "Correction-only quest uses native title")
equal(corrected.level, 20, "Correction-only quest uses native level")
equal(corrected.zoneName, "Zone A", "Correction-only quest uses native header")
equal(corrected:IsComplete(), 0, "Empty placeholder cannot imply native quest completion")
equal(data.GetQuest(5), corrected, "Direct/manual lookup uses native record rather than the placeholder")
names[5] = "   "
equal(module("QuestieDB").HasQuestData(5), false, "Whitespace-only database name is not usable")
names[5] = "Jitters' Growling Gut"
equal(module("QuestieDB").HasQuestData(5), true, "Restored base name restores database validity")
names[5] = nil

-- Acceptance fills the native cache without a map lifecycle redraw. A forced update
-- must survive a preceding title-only render at the same timestamp.
local queue, delayed, ready, progress = {}, {}, false, 0
local renderedObjectives, renderedProgress, lastRender, forcedRenders = nil, nil, nil, 0
module("QuestieCombatQueue").Queue = function(_, callback) queue[#queue + 1] = callback end
env.QuestieCompat.C_Timer.After = function(_, callback) delayed[#delayed + 1] = callback end
env.Questie.Error = function(...) error("Unexpected native-quest error: " .. tostring(select(1, ...))) end
env.CreateFrame = function() return {} end
module("TrackerUtils").ClearTomTomTargetForQuest = noop
lib.CacheItemNames = noop
module("QuestieJourney").AcceptQuest = noop
module("QuestieAnnounce").AcceptedQuest = noop
module("QuestLifecycle").AcceptQuest = noop
module("IsleOfQuelDanas").MAX_ISLE_OF_QUEL_DANAS_PHASES = 1
module("IsleOfQuelDanas").CheckForActivePhase = function() return false end
module("BreadcrumbQuests").CheckQuestBreadcrumbs = noop
module("QuestiePartyObjectives").ScheduleUpdate = noop
local mappedUpdates, mappedDirty, nameplateUpdates = 0, 0, 0
module("QuestieQuest").SetObjectivesDirty = function(_, id)
    equal(id, 100, "Native updates cannot enter map objective population")
    mappedDirty = mappedDirty + 1
end
module("QuestieQuest").UpdateQuest = function(_, id)
    equal(id, 100, "Native updates cannot enter map quest processing")
    mappedUpdates = mappedUpdates + 1
end
module("QuestieNameplate").UpdateNameplate = function() nameplateUpdates = nameplateUpdates + 1 end
module("QuestieDB").GetQuest = function(id) if id == 100 then return known end end
module("QuestLogCache").HasPendingItemRegression = function() return false end
module("QuestLogCache").CheckForChanges = function()
    if not ready then return true, {} end
    local old = cache[900004]
    if old and old.objectives[1].numFulfilled == progress then return false, {} end
    cache[900004] = {objectives = {{text = "Lynx Collar", raw_text = "Lynx Collar: " .. progress .. "/8",
        type = "item", numFulfilled = progress, numRequired = 8, raw_finished = false}}}
    return false, {[900004] = {1}}
end
tracker.Update = function(_, force)
    if not force and lastRender and clock - lastRender < 0.1 then return end
    lastRender = clock
    if force then forcedRenders = forcedRenders + 1 end
    local display = data.Refresh()[900004]
    renderedObjectives = display and #display.Objectives
    renderedProgress = display and display.Objectives[1] and display.Objectives[1].Collected
end
local function drain()
    while #queue > 0 do table.remove(queue, 1)() end
end
loadModule("Modules/Quest/QuestEventHandler.lua")
local events = module("QuestEventHandler").private
tracker:Update(true)
equal(renderedObjectives, 0, "First native render is title-only while data loads")
events:QuestAccepted(4, 900004)
drain() -- Cache miss defers acceptance to the next quest-log event.
equal(renderedObjectives, 0, "Pending acceptance retains title-only display")
ready = true
events:QuestLogUpdate()
drain() -- Same timestamp: ordinary redraws are throttled, native readiness must force one.
equal(renderedObjectives, 1, "Accepted native objectives appear without manual tracker toggling")
equal(renderedProgress, 0, "New acceptance displays 0/8")
equal(forcedRenders, 2, "Readiness schedules one forced redraw")
progress = 1
events:UpdateAllQuests()
progress = 2
events:UpdateAllQuests()
equal(#queue, 1, "Rapid native progress changes share a single queued redraw")
drain()
equal(renderedProgress, 2, "Queued redraw reads the latest collar count")
equal(mappedUpdates, 0, "Native loot causes no mapped-quest updates")
equal(#delayed, 0, "Native progress does not rely on a delayed map redraw")
progress = 3
events:UpdateAllQuests()
equal(#queue, 1, "Finishing a native redraw allows the next progress update")
drain()
equal(renderedProgress, 3, "Later collar progress still refreshes")
module("QuestLogCache").CheckForChanges = function() return false, {[100] = {1}} end
events:UpdateAllQuests()
drain()
equal(mappedUpdates, 1, "Mapped progress retains quest processing")
equal(mappedDirty, 1, "Mapped progress retains dirty-objective tracking")
equal(nameplateUpdates, 1, "Mapped progress retains nameplate updates")
equal(#delayed, 1, "Mapped progress retains its existing delayed redraw")

-- Exercise the production native-objective adapter without installing unrelated event hooks.
local f = assert(io.open("Compat/QuestLog.lua", "r"))
local source = f:read("*a"); f:close()
local first = assert(source:find("QuestieCompat.C_QuestLog = {", 1, true))
local last = assert(source:find("\n-- Can't find", first, true))
local adapter = [[
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
local math_max = math.max
local function normalizeObjectiveName(text) return text end
local function getObjectiveProgressCache() end
local function parseQuestObjective(text) return text, 0, 1 end
]] .. source:sub(first, last - 1)
env.GetNumQuestLeaderBoards = function() return 3 end
local nativeRows = {{"Open gate", "event"}, {"Listen to instructions", "log"}, {"Collect token: 0/1", "item"}}
env.GetQuestLogLeaderBoard = function(index) return nativeRows[index][1], nativeRows[index][2], false end
if setfenv then setfenv(assert(loadstring(adapter)), env)()
else assert(load(adapter, "@native-objective-adapter", "t", env))() end
local native = env.QuestieCompat.C_QuestLog.GetQuestObjectives(900004, 4)
equal(#native, 3, "Native-only log instructions survive the client adapter")
equal(native[1].type, "event", "Native event retains client ordering")
equal(native[2].type, "log", "Native instruction retains client ordering")
equal(native[3].type, "item", "Native counted objective retains client ordering")
local mapped = env.QuestieCompat.C_QuestLog.GetQuestObjectives(100, 2)
equal(#mapped, 2, "Mapped quest retains existing log-row filtering")
equal(mapped[1].type, "item", "Mapped quest retains existing objective ordering")
local partial = env.QuestieCompat.C_QuestLog.GetQuestObjectives(5, 7)
equal(#partial, 3, "Correction-only quest retains native instruction rows")
equal(partial[1].type, "event", "Correction-only quest retains native objective order")
print("Native quest tracker regressions passed")
