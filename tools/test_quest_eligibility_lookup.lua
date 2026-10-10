-- Run with Lua 5.2+. Use real compiled databases and production eligibility checks.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local modules = {}
local env = setmetatable({bit = bit32, unpack = table.unpack, tremove = table.remove}, {__index = _G})
local state = {items = {}, spells = {}, professionSpells = {}, rewarded = {}, bridge = {}, events = {},
    reputation = 1000, profession = true, skill = 300, rank = 5, specialization = true,
    dailyLimit = false, dailyHidden = {}, achievement = true, zone = 210}
env.QuestieLoader = {
    CreateModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
    ImportModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
}
env.GetCVar = function() return "" end
env.UnitFactionGroup = function() return "Alliance" end
env.UnitLevel = function() return 80 end
env.StaticPopupDialogs = {}
env.Questie = {db = {global = {}, profile = {}, char = {complete = {}, hidden = {}}}, Debug = noop, Error = error}
env.QuestieCompat = {Is335 = true, C_QuestLog = {IsOnQuest = function(id) return state.onQuest == id end},
    AzerothCoreQuestAvailabilityConditions = {[23] = {{{4, 210, 0, 0, 0}}}}}
env.IsQuestCompletedOnServer = function(id) return state.rewarded[id] == true end
env.QuestieCompat.IsQuestCompletedOnServer = env.IsQuestCompletedOnServer
env.IsSpellKnownOrOverridesKnown = function(id) return state.spells[id] == true end
env.IsPlayerSpell = function(id) return state.professionSpells[id] == true end
env.QuestieCompat.IsSpellKnownOrOverridesKnown = env.IsSpellKnownOrOverridesKnown
env.QuestieCompat.IsPlayerSpell = env.IsPlayerSpell
env.GetItemCount = function(id) return state.items[id] or 0 end
env.GetAchievementInfo = function() return nil, nil, nil, state.achievement end
env.GetRealZoneText = function() return "Test zone" end
env.GetZoneText = env.GetRealZoneText
env.GetSubZoneText = function() return "" end
env.GetZoneID = function() return state.zone end
modules.ZoneDB = {zoneIDs = {ICECROWN = 210}}
modules.l10n = setmetatable({}, {__call = function(_, text) return text end})
modules.QuestieCorrections = {hiddenQuests = {}}
modules.QuestiePlayer = {currentQuestlog = {}, GetPlayerLevel = function() return 80 end,
    GetCurrentZoneId = function() return state.zone end,
    HasRequiredRace = function(mask) return mask == 0 or bit32.band(mask, 1) ~= 0 end,
    HasRequiredClass = function(mask) return mask == 0 or bit32.band(mask, 1) ~= 0 end}
modules.QuestieLib = {TableMemoizeFunction = function(_, fn)
    return setmetatable({}, {__index = function(tbl, key) local value = fn(key); tbl[key] = value; return value end})
end}
modules.QuestieServer = {GetQuestAvailabilityState = function(_, id) return state.bridge[id] end,
    IsICCQuestActive = function(_, id) return state.bridge[id] end,
    IsWintergraspQuestActive = function() end, IsPooledQuestActive = function() end}
modules.QuestieEvent = {IsEventQuestInCurrentExpansion = function(_, id) return id == 24 end,
    IsEventActiveForQuest = function(_, id) return state.events[id] end, IsServerQuestActive = function() end}
modules.QuestieQuestBlacklist = {AQWarEffortQuests = {}, ScourgeInvasionQuests = {}}
modules.DailyQuests = {ShouldBeHidden = function(id) return state.dailyHidden[id] end,
    IsAtDailyQuestLimit = function() return state.dailyLimit end}
modules.QuestieProfessions = {
    HasProfessionAndSkillLevel = function(_, requirement) return state.profession, state.skill >= requirement[2] end,
    HasProfessionAndRankLevel = function(_, requirements) return state.profession, state.rank >= requirements[1][2] end,
    HasSpecialization = function() return state.specialization end,
}
modules.QuestieReputation = {HasFactionAndReputationLevel = function(_, minimum, maximum)
    return not minimum or state.reputation >= minimum[2], true, not maximum or state.reputation < maximum[2], true
end}
assert(loadfile("Database/QuestieDB.lua", "t", env))()
for _, name in ipairs({"questDB", "npcDB", "objectDB", "itemDB"}) do
    assert(loadfile("Database/" .. name .. ".lua", "t", env))()
end
assert(loadfile("Modules/QuestieStream.lua", "t", env))()
assert(loadfile("Database/compiler.lua", "t", env))()
local db, compiler = modules.QuestieDB, modules.DBCompiler
local keys, data = db.questKeys, {}
local function add(id, fields)
    local entry = {[keys.name] = "Test quest " .. id, [keys.requiredLevel] = 1, [keys.questLevel] = 80}
    for field, value in pairs(fields or {}) do entry[keys[field]] = value end
    data[id] = entry
end
add(1)
add(2, {preQuestSingle = {200}})
add(3, {preQuestGroup = {201, -202}})
add(201, {exclusiveTo = {203}})
add(4, {parentQuest = 300})
add(5, {nextQuestInChain = 301})
add(6, {exclusiveTo = {302}})
add(7, {requiredMinRep = {72, 500}, requiredMaxRep = {72, 2000}})
add(8, {requiredSkill = {164, 200}})
add(9, {requiredRanks = {{164, 4}}})
add(10, {requiredSpecialization = 9787})
add(11, {requiredSpell = 401})
add(12, {requiredSpell = -402})
add(13, {requiredItemConditions = {{501, 2}, {-502, 1}}})
add(14, {breadcrumbForQuestId = 303})
add(15, {breadcrumbs = {304}})
add(16, {disabledByQuest = 305})
add(17, {availableUntilCompleted = 306})
add(18, {availableStartingWith = 307})
add(19, {questFlags = 4096})
add(20, {requiredRaces = 2})
add(21, {requiredClasses = 2})
add(23)
add(24)
add(14107)
local function compile()
    local global = env.Questie.db.global
    global.questBin, global.questPtrs = compiler:CompileTable(data, db.questCompilerTypes, db.questCompilerOrder, keys)
    for _, name in ipairs({"npc", "object", "item"}) do
        local prefix = name == "object" and "obj" or name
        global[prefix .. "Bin"], global[prefix .. "Ptrs"] = compiler:CompileTable({}, db[name .. "CompilerTypes"], db[name .. "CompilerOrder"], db[name .. "Keys"])
    end
end
local function initialize()
    local thread = coroutine.create(function() db:Initialize() end)
    while coroutine.status(thread) ~= "dead" do
        local ok, message = coroutine.resume(thread)
        assert(ok, message)
    end
end
compile()
initialize()
local source = db.QueryQuestSingle
local function uncached(id, field) return source(id, field) end
local comparisons = 0
local function verify(id, expected, label, ignoreLocation, snapshot)
    db.QueryQuestSingle = source
    db.autoBlacklist[id] = nil
    local actual = db.IsDoable(id, false, ignoreLocation, snapshot)
    equal(actual, expected, label)
    local blacklist = db.autoBlacklist[id]
    local text, hidden, reason = db.IsDoableVerbose(id, false, true, true)
    db.autoBlacklist[id] = nil
    db.QueryQuestSingle = uncached -- Changing the source bypasses the compiled-field cache.
    equal(db.IsDoable(id, false, ignoreLocation, snapshot), actual, label .. " uncached eligibility")
    equal(db.autoBlacklist[id], blacklist, label .. " uncached blacklist")
    local rawText, rawHidden, rawReason = db.IsDoableVerbose(id, false, true, true)
    equal(text, rawText, label .. " verbose text")
    equal(hidden, rawHidden, label .. " verbose visibility")
    equal(reason, rawReason, label .. " verbose reason")
    db.QueryQuestSingle = source
    comparisons = comparisons + 1
end

-- Warm each branch, then change live state without clearing the requirement cache.
verify(1, true, "ordinary quest")
verify(2, false, "missing prerequisite")
state.rewarded[200] = true
verify(2, true, "rewarded repeatable prerequisite")
state.rewarded[200] = nil
env.Questie.db.char.complete[200] = true
verify(2, true, "completed prerequisite")
env.Questie.db.char.complete[200] = nil
verify(2, false, "removed prerequisite completion")
verify(3, false, "missing grouped prerequisites")
state.rewarded[203], state.rewarded[202] = true, true
verify(3, true, "exclusive alternative and negative group entry")
state.rewarded[202] = nil
verify(3, false, "group member completion remains live")
verify(4, false, "inactive parent")
modules.QuestiePlayer.currentQuestlog[300] = {}
verify(4, true, "accepted parent")
modules.QuestiePlayer.currentQuestlog[300] = nil
verify(4, false, "abandoned parent")
for id, related in pairs({[5] = 301, [6] = 302, [14] = 303, [15] = 304, [16] = 305}) do
    verify(id, true, "inactive related quest " .. id)
    modules.QuestiePlayer.currentQuestlog[related] = {}
    verify(id, false, "accepted related quest " .. id)
    modules.QuestiePlayer.currentQuestlog[related] = nil
    verify(id, true, "abandoned related quest " .. id)
end
for _, reputation in ipairs({1000, 100, 2500, 1000}) do
    state.reputation = reputation
    verify(7, reputation == 1000, "live reputation " .. reputation)
end
for _, skill in ipairs({300, 100, 300}) do
    state.skill = skill
    verify(8, skill >= 200, "live skill " .. skill)
end
for _, rank in ipairs({5, 1, 5}) do
    state.rank = rank
    verify(9, rank >= 4, "live profession rank " .. rank)
end
for _, present in ipairs({true, false, true}) do
    state.specialization = present
    verify(10, present, "live specialization " .. tostring(present))
    state.spells[401] = present
    verify(11, present, "live learned spell " .. tostring(present))
    state.spells[402] = present
    verify(12, not present, "live forbidden spell " .. tostring(present))
end
state.spells[401], state.professionSpells[401] = nil, true
verify(11, true, "profession spell satisfies requirement")
for _, count in ipairs({0, 2, 1, 2}) do
    state.items[501] = count
    verify(13, count >= 2, "live required inventory " .. count)
end
state.items[502] = 1
verify(13, false, "live forbidden inventory")
state.items[502] = nil
verify(13, true, "removed forbidden inventory")
verify(17, true, "completion cutoff not reached")
env.Questie.db.char.complete[306] = true
verify(17, false, "completion cutoff reached")
verify(18, false, "enabling quest missing")
modules.QuestiePlayer.currentQuestlog[307] = {}
verify(18, true, "enabling quest accepted")
modules.QuestiePlayer.currentQuestlog[307] = nil
env.Questie.db.char.complete[307] = true
verify(18, true, "enabling quest turned in")
verify(19, true, "daily limit open")
state.dailyLimit = true
verify(19, false, "daily limit reached")
state.dailyLimit = false
state.dailyHidden[19] = true
verify(19, false, "daily pool hidden")
verify(20, false, "wrong race")
verify(21, false, "wrong class")
verify(23, true, "location allowed")
state.zone = 999
verify(23, false, "location changed")
verify(23, true, "per-spawn location bypass", true)
state.events[24] = true
verify(24, true, "event active")
state.events[24] = false
verify(24, false, "event ended")
verify(14107, true, "achievement earned")
state.achievement = false
verify(14107, false, "achievement missing")
state.bridge[1] = false
verify(1, false, "bridge disabled quest")
state.bridge[1] = nil
verify(1, true, "bridge expired or unsupported")
state.onQuest = 1
state.bridge[1] = false
verify(1, true, "in-log shortcut precedes bridge gate")
state.onQuest, state.bridge[1] = nil, nil
verify(1, true, "caller membership snapshot", false, {[1] = true})
env.Questie.db.char.complete[1] = true
verify(1, false, "completed quest precedes membership shortcut", false, {[1] = true})
env.Questie.db.char.complete[1] = nil
env.Questie.db.char.hidden[1] = true
verify(1, false, "manual hiding remains live")
env.Questie.db.char.hidden[1] = nil
modules.QuestieCorrections.hiddenQuests[1] = true
verify(1, false, "automatic hiding remains live")
modules.QuestieCorrections.hiddenQuests[1] = nil
db.activeChildQuests[2] = true
verify(2, true, "active child bypasses prerequisites")
state.bridge[2] = false
verify(2, false, "bridge gate precedes child shortcut")
state.bridge[2], db.activeChildQuests[2] = nil, nil

-- Live corrections take precedence over cached compiled fields. Removing a
-- correction restores compiled data, never an old correction's value.
db.questDataOverrides[2] = {[keys.preQuestSingle] = {999}}
verify(2, false, "new prerequisite correction")
state.rewarded[999] = true
verify(2, true, "corrected prerequisite completed")
db.questDataOverrides[2][keys.preQuestSingle][1] = 998
verify(2, false, "in-place correction list edit")
db.questDataOverrides[2][keys.preQuestSingle] = false
verify(2, true, "false correction overrides populated list")
db.questDataOverrides[2][keys.preQuestSingle] = nil
verify(2, false, "removed correction restores compiled prerequisite")
db.questDataOverrides[4] = {[keys.parentQuest] = 0}
verify(4, true, "zero correction disables parent requirement")
db.questDataOverrides[4] = nil
verify(4, false, "removed correction restores compiled parent")
db.questDataOverrides[1] = {[keys.requiredItemConditions] = {{503, 1}}}
verify(1, false, "correction replaces cached absent field")
state.items[503] = 1
verify(1, true, "corrected inventory condition remains live")
db.questDataOverrides[1] = nil
verify(1, true, "removed correction restores cached absence")
db.questDataOverrides[90000] = {[keys.preQuestSingle] = {999}}
verify(90000, true, "override-only quest without compiled pointer")
state.rewarded[999] = nil
verify(90000, false, "override-only prerequisite remains live")

-- Public database reads still return fresh lists, so consumers cannot edit the
-- privately cached requirements by mutating their own decoded result.
local publicList = db.QueryQuestSingle(2, "preQuestSingle")
publicList[1] = 999
state.rewarded[999] = true
verify(2, false, "ordinary query result does not alias requirement cache")

-- Quantify avoided binary work without relying on machine-specific timings.
local reads, skips = 0, 0
for kind, reader in pairs(compiler.readers) do
    compiler.readers[kind] = function(...) reads = reads + 1; return reader(...) end
end
for kind, skipper in pairs(compiler.skippers) do
    compiler.skippers[kind] = function(...) skips = skips + 1; return skipper(...) end
end
verify(1, true, "warm benchmark fixture")
reads, skips = 0, 0
for _ = 1, 100 do equal(db.IsDoable(1), true, "warm eligibility") end
equal(reads, 100, "warm eligibility only decodes uncached daily flags")
equal(skips, 0, "warm eligibility does not skip variable-length fields")
local warmReads = reads
reads, skips = 0, 0
db.QueryQuestSingle = uncached
for _ = 1, 100 do equal(db.IsDoable(1), true, "uncached eligibility") end
assert(reads > warmReads * 10, "requirement cache removes most repeated binary decoding")
assert(skips > 0, "uncached requirement queries skip variable-length fields repeatedly")
print("Eligibility binary reads over 100 warm checks: " .. warmReads .. " cached vs " .. reads .. " uncached; " .. skips .. " uncached skips")
db.QueryQuestSingle = source

-- Reinitializing a database replaces the cache, including previously cached nil.
data[1][keys.preQuestSingle] = {777}
compile()
initialize()
source = db.QueryQuestSingle
verify(1, false, "database reinitialization replaces absent prerequisite")
state.rewarded[777] = true
verify(1, true, "new database prerequisite remains live")
print("Quest eligibility: " .. comparisons .. " cached/uncached comparisons passed, including live state, correction edits and database replacement")
