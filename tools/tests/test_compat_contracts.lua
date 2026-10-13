-- Run from the addon root with Lua 5.1 or 5.2+.
-- Execute the production adapters and gossip readers with native 3.3.5 tuples.
-- Only the relevant function chunks are loaded for adapters/private readers;
-- unrelated UI bootstrap is excluded. Questgiver and sound modules are loaded whole.
local unpackValues = unpack or table.unpack
local tests = 0
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function pack(...)
    return {n = select("#", ...), ...}
end
local function compile(source, label, env)
    if setfenv then
        return setfenv(assert(loadstring(source, label)), env)
    end
    return assert(load(source, label, "t", env))
end
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end
local function loadFunction(path, declaration, env)
    local pattern = declaration:gsub("(%W)", "%%%1") .. ".-\nend"
    local source = assert(read(path):match(pattern), "missing production function: " .. declaration)
    compile(source, "@" .. path, env)()
end

local env = setmetatable({}, {__index = _G})
env._G = env
env.unpack, env.tinsert = unpackValues, table.insert
env.QuestieCompat = {}
local nativeAvailable, nativeActive, numAvailable, numActive
local availableIds = {Ordinary = 101, Daily = 102, Repeatable = 103}
local activeIds = {Incomplete = 201, Complete = 202, Another = 203}
local npcGuid = "Creature-0-0-0-0-12345-00000001"
env.GetNumGossipAvailableQuests = function() return numAvailable end
env.GetNumGossipActiveQuests = function() return numActive end
env.GetGossipAvailableQuests = function() return unpackValues(nativeAvailable, 1, nativeAvailable.n) end
env.GetGossipActiveQuests = function() return unpackValues(nativeActive, 1, nativeActive.n) end
env.GetQuestID = function(isAvailable, title)
    return assert((isAvailable and availableIds or activeIds)[title], "misaligned gossip title: " .. tostring(title))
end
env.QuestieDB = {
    GetQuestIDFromName = function(title, guid, isAvailable)
        equal(guid, npcGuid, "questgiver passed to title lookup")
        return env.GetQuestID(isAvailable, title)
    end,
    IsComplete = function(id) return id == 202 and 1 or 0 end,
    IsPvPQuest = function() return false end,
    IsActiveEventQuest = function() return false end,
    IsRepeatable = function(id) return id == 103 end,
}
env.QuestieCompat.UnitGUID = function() return npcGuid end
env.Questie = {db = {profile = {enableQuestFrameIcons = true}},
    icons = {available = "available", repeatable = "repeatable", complete = "complete", incomplete = "incomplete"}}
local questgiver = {}
env.QuestieLoader = {
    CreateModule = function(_, name) equal(name, "QuestgiverFrame", "questgiver module"); return questgiver end,
    ImportModule = function(_, name) return name == "QuestieDB" and env.QuestieDB or {} end,
}
loadFunction("Compat/QuestLog.lua", "function QuestieCompat.GetAvailableQuests()", env)
loadFunction("Compat/QuestLog.lua", "function QuestieCompat.GetActiveQuests()", env)
loadFunction("Modules/Auto/QuestieAuto.lua", "_GetStructuredAvailableQuests = function()", env)
loadFunction("Modules/Auto/QuestieAuto.lua", "_GetStructuredActiveQuests = function()", env)
loadFunction("Modules/Quest/AvailableQuests.lua", "_GetStructuredAvailableQuestsInGossip = function(npcGuid)", env)
loadFunction("Modules/Quest/AvailableQuests.lua", "_GetStructuredActiveQuestsInGossip = function(npcGuid)", env)
compile(read("Modules/Quest/QuestgiverFrame.lua"), "@Modules/Quest/QuestgiverFrame.lua", env)()

local function checkGossip(available, active)
    local rawAvailable = pack(env.QuestieCompat.GetAvailableQuests())
    local rawActive = pack(env.QuestieCompat.GetActiveQuests())
    equal(rawAvailable.n, #available * 7, "available tuple width")
    equal(rawActive.n, #active * 6, "active tuple width")
    for index, row in ipairs(available) do
        for field = 1, 7 do equal(rawAvailable[(index - 1) * 7 + field], row[field], "available field " .. field) end
    end
    for index, row in ipairs(active) do
        for field = 1, 6 do equal(rawActive[(index - 1) * 6 + field], row[field], "active field " .. field) end
    end

    local autoAvailable, autoActive = env._GetStructuredAvailableQuests(), env._GetStructuredActiveQuests()
    equal(#autoAvailable, #available, "auto-accept quest count")
    equal(#autoActive, #active, "auto-turn-in quest count")
    local fields = {"title", "questLevel", "isTrivial", "frequency", "repeatable", "isLegendary", "isIgnored"}
    for index, row in ipairs(available) do
        for field, key in ipairs(fields) do equal(autoAvailable[index][key], row[field], "auto-accept " .. key) end
        equal(autoAvailable[index].questID, availableIds[row[1]], "auto-accept ID")
    end
    fields = {"title", "questLevel", "isTrivial", "isComplete", "isLegendary", "isIgnored"}
    for index, row in ipairs(active) do
        for field, key in ipairs(fields) do equal(autoActive[index][key], row[field], "auto-turn-in " .. key) end
        equal(autoActive[index].questID, activeIds[row[1]], "auto-turn-in ID")
    end

    local offered = env._GetStructuredAvailableQuestsInGossip(npcGuid)
    local accepted = env._GetStructuredActiveQuestsInGossip(npcGuid)
    equal(#offered, #available, "available-note quest count")
    equal(#accepted, #active, "active-note quest count")
    for index, row in ipairs(available) do
        equal(offered[index].title, row[1], "available-note title")
        equal(offered[index].questID, availableIds[row[1]], "available-note ID")
    end
    for index, row in ipairs(active) do
        equal(accepted[index].title, row[1], "active-note title")
        equal(accepted[index].questID, activeIds[row[1]], "active-note ID")
    end

    local icons = {}
    for index = 1, #available + #active + 1 do
        local buttonIndex = index
        env["GossipTitleButton" .. index .. "GossipIcon"] = {
            SetTexture = function(_, icon) icons[buttonIndex] = icon end,
        }
    end
    questgiver.GossipMark()
    for index, row in ipairs(available) do
        equal(icons[index], row[5] and "repeatable" or "available", "offered quest icon")
    end
    local offset = #available + ((#available > 0 and #active > 0) and 1 or 0)
    if offset > #available then equal(icons[offset], nil, "gossip section separator") end
    for index, row in ipairs(active) do
        equal(icons[offset + index], row[4] and "complete" or "incomplete", "active quest icon")
    end
    if #available + #active == 0 then equal(next(icons), nil, "empty gossip has no icons") end
    tests = tests + 1
end

nativeAvailable, nativeActive, numAvailable, numActive = {n = 0}, {n = 0}, 0, 0
checkGossip({}, {})

-- Native nil flags include holes and trailing nils. Always return the full native tuple.
nativeAvailable = {n = 5, "Ordinary", 10, nil, nil, nil}
numAvailable = 1
checkGossip({{"Ordinary", 10, false, 1, false, false, false}}, {})
nativeAvailable, numAvailable = {n = 0}, 0
nativeActive, numActive = {n = 4, "Incomplete", 10, nil, nil}, 1
checkGossip({}, {{"Incomplete", 10, false, false, false, false}})

nativeAvailable = {n = 15, "Ordinary", 10, nil, nil, nil, "Daily", 20, 1, 1, nil, "Repeatable", 30, nil, nil, 1}
nativeActive = {n = 12, "Incomplete", 10, nil, nil, "Complete", 20, 1, 1, "Another", 30, nil, nil}
numAvailable, numActive = 3, 3
checkGossip({
    {"Ordinary", 10, false, 1, false, false, false},
    {"Daily", 20, true, 2, false, false, false},
    {"Repeatable", 30, false, 1, true, false, false},
}, {
    {"Incomplete", 10, false, false, false, false},
    {"Complete", 20, true, true, false, false},
    {"Another", 30, false, false, false, false},
})

-- Inventory consumers expect item ID in return position 10, not the native 7-field tuple.
loadFunction("Compat/Compat.lua", "function QuestieCompat.GetContainerItemInfo(bagID, slot)", env)
local itemInfo, itemQueries = {}, 0
env.GetContainerItemInfo = function(bag, slot)
    equal(bag, -2, "keyring bag forwarded")
    equal(slot, 3, "slot forwarded")
    return unpackValues(itemInfo, 1, itemInfo.n)
end
env.GetItemInfo = function(link)
    equal(link, itemInfo[7], "quality lookup uses the original hyperlink")
    itemQueries = itemQueries + 1
    return "Item", link, 4
end
local link = "|cffffffff|Hitem:6948:0:0:0:0:0:0:0|h[Hearthstone]|h|r"
for _, quality in ipairs({1, -1}) do
    itemInfo = {n = 7, "icon", 2, nil, quality, nil, nil, link}
    local result = pack(env.QuestieCompat.GetContainerItemInfo(-2, 3))
    equal(result.n, 11, "normalized inventory return count")
    equal(result[1], "icon", "inventory icon")
    equal(result[2], 2, "inventory count")
    equal(result[3], nil, "inventory lock flag preserved")
    equal(result[4], quality < 0 and 4 or quality, "inventory quality")
    equal(result[5], nil, "inventory readable flag preserved")
    equal(result[6], nil, "inventory loot flag preserved")
    equal(result[7], link, "inventory hyperlink preserved")
    for _, field in ipairs({8, 9, 11}) do equal(result[field], false, "unsupported inventory field") end
    equal(result[10], 6948, "inventory numeric item ID")
    tests = tests + 1
end
equal(itemQueries, 1, "only unknown quality needs an item query")
itemInfo = {n = 0}
equal(pack(env.QuestieCompat.GetContainerItemInfo(-2, 3)).n, 0, "empty slot returns no item")
tests = tests + 1

-- Sound selection must work directly from its owning module, before compatibility startup.
do
    local soundEnv = setmetatable({}, {__index = _G})
    local sounds, timers, played = {}, {}, {}
    local mediaQueries = 0
    local mediaPaths = {
        CustomOgg = "Interface\\AddOns\\MySounds\\quest.ogg",
        CustomMp3 = "Interface/AddOns/MySounds/quest.mp3",
        CustomWav = "Interface\\AddOns\\MySounds\\quest.wav",
        MixedCase = "INTERFACE/ADDONS/MySounds/quest.ogg",
        MixedSlashes = "Interface\\AddOns/MySounds/quest.ogg",
        GameOgg = "Sound/Interface/MapPing.ogg",
        GameWav = "Sound/Interface/MapPing.wav",
        Silent = "",
    }
    soundEnv.QuestieLoader = {CreateModule = function(_, name)
        equal(name, "Sounds", "sound module declaration")
        return sounds
    end}
    soundEnv.LibStub = function(name)
        equal(name, "LibSharedMedia-3.0", "sound media library")
        return {Fetch = function(_, kind, selection)
            equal(kind, "sound", "media lookup category")
            mediaQueries = mediaQueries + 1
            return mediaPaths[selection] or "Sound/Interface/iquestcomplete.ogg"
        end}
    end
    soundEnv.QuestieCompat = {C_Timer = {After = function(delay, callback)
        equal(delay, 0.3, "sound delay preserved")
        timers[#timers + 1] = callback
    end}}
    soundEnv.Questie = {db = {profile = {
        soundOnObjectiveProgress = true, soundOnObjectiveComplete = true, soundOnQuestComplete = true,
        soundDelay = 0.3, objectiveProgressSoundChoiceName = "CustomOgg",
        objectiveCompleteSoundChoiceName = "ObjectiveDefault", questCompleteSoundChoiceName = "GameDefault",
    }}}
    soundEnv.PlaySoundFile = function(path, channel) played[#played + 1] = {path, channel} end
    compile(read("Modules/Sounds.lua"), "@Modules/Sounds.lua", soundEnv)()

    equal(sounds.GetSelectedSoundFile("QuestDefault"), "Sound/Creature/Peon/PeonBuildingComplete1.wav", "built-in quest sound")
    equal(sounds.GetSelectedSoundFile("ObjectiveDefault"), "Sound/Interface/iquestupdate.wav", "built-in objective sound")
    equal(mediaQueries, 0, "built-in choices do not fall back to shared media")
    for _, selection in ipairs({"CustomOgg", "CustomMp3", "CustomWav", "MixedCase", "MixedSlashes", "GameWav", "Silent"}) do
        equal(sounds.GetSelectedSoundFile(selection), mediaPaths[selection], "registered path preserved: " .. selection)
    end
    equal(sounds.GetSelectedSoundFile("GameOgg"), "Sound/Interface/MapPing.wav", "registered game-archive sound")
    equal(sounds.GetSelectedSoundFile("Unknown"), "Sound/Interface/iquestcomplete.wav", "shared-media fallback sound")
    tests = tests + 1

    sounds.PlayObjectiveProgress()
    sounds.PlayObjectiveComplete()
    equal(#played, 0, "objective playback remains delayed")
    equal(#timers, 2, "objective callbacks scheduled")
    for _, callback in ipairs(timers) do callback() end
    sounds.PlayQuestComplete()
    equal(#played, 3, "all sound events play")
    equal(played[1][1], mediaPaths.CustomOgg, "progress event preserves custom extension")
    equal(played[2][1], "Sound/Interface/iquestupdate.wav", "objective event uses native sound path")
    equal(played[3][1], "Sound/Interface/iquestcomplete.wav", "quest event uses native sound path")
    for _, entry in ipairs(played) do equal(entry[2], "Master", "playback channel preserved") end
    tests = tests + 1
end

-- Registered artwork must resolve to packaged files, including the mount TGA.
do
    local iconEnv = setmetatable({Questie = {}, QuestieLib = {AddonPath = ""}}, {__index = _G})
    local declaration = assert(read("Questie.lua"):match("(Questie%.icons = %b{})"), "missing icon registry")
    compile(declaration, "@Questie.lua", iconEnv)()
    equal(iconEnv.Questie.icons.mount_up, "Icons\\mount_up.blp", "mount icon uses its packaged format")
    for name, path in pairs(iconEnv.Questie.icons) do
        if path:match("^Icons\\") then
            local file = assert(io.open(path:gsub("\\", "/"), "rb"), "missing registered icon: " .. name .. " (" .. path .. ")")
            file:close()
        end
    end
    tests = tests + 1
end

print("Compatibility contract regression tests passed (" .. tests .. " groups)")
