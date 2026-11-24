-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise trainer classification independently of NPC titles and client locale.
local modules = {l10n = {translations = {}}}
local env = setmetatable({}, {__index = _G})
env._G, env.tinsert = env, table.insert
env.bit = {band = function(flags, mask)
    -- These NPC service flags are individual bits.
    return math.floor(flags / mask) % 2 == 1 and mask or 0
end}
env.hooksecurefunc = function() end
env.Questie = {Debug = function() end, db = {global = {}, profile = {}}}
env.QuestieLoader = {ImportModule = function(_, name)
    modules[name] = modules[name] or {}
    return modules[name]
end}
env.QuestieLoader.CreateModule = env.QuestieLoader.ImportModule
local function loadModule(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    local chunk
    if setfenv then chunk = setfenv(assert(loadstring(source, "@" .. path)), env)
    else chunk = assert(load(source, "@" .. path, "t", env)) end
    chunk()
end
loadModule("Localization/Translations/Professions.lua")
env.ExpandSkillHeader = function() end
env.GetNumSkillLines = function() return 1 end
env.GetSkillLineInfo = function() return "Couture", false, nil, 75 end
loadModule("Modules/QuestieProfessions.lua")
modules.QuestieProfessions:Init()
modules.QuestieQuest.ResetAutoblacklistCategory = function() end
modules.QuestieProfessions:Update()
assert(modules.QuestieProfessions:GetPlayerProfessionNames()[1] == "Couture", "preserve localized native profession lookup")
loadModule("Modules/QuestieMenu/Townsfolk.lua")
loadModule("Modules/QuestieMenu/ProfessionTrainers.lua")
local town, keys = modules.Townsfolk, modules.QuestieProfessions.professionKeys
local categories = town.GetProfessionTrainers()
local db = modules.QuestieDB
db.npcKeys = {name = 1, subName = 2, spawns = 3, npcFlags = 4}
db.npcFlags = {BANKER = 131072, BATTLEMASTER = 1048576}
db.npcData, db.itemData, db.itemKeys = {}, {}, {foodType = 1}
local function contains(ids, id)
    for _, value in ipairs(ids or {}) do if value == id then return true end end
    return false
end
for category, ids in pairs(categories) do
    local previous = 0
    for _, id in ipairs(ids) do
        assert(id > previous, category .. ": IDs must be sorted and unique")
        previous = id
        -- Deliberately give every NPC an unrelated translated title.
        db.npcData[id] = {"Trainer " .. id, "Sans titre", {[12] = {{50, 50}}}, 0}
    end
end
assert(contains(categories.FIRST_AID, 18990), "Burko must teach First Aid")
assert(contains(categories.TAILORING, 11557), "Meilosh must teach Tailoring without a subtitle")
assert(contains(categories.MINING, 18804), "Prospector Nachlan must teach Mining")
assert(contains(categories.HERBALISM, 33996), "William Saldean must teach Herbalism")
assert(contains(categories.COOKING, 19186), "Kylene must remain a Cooking trainer")
assert(contains(categories.FIRST_AID, 18991), "Aresella must remain a First Aid trainer")
assert(contains(categories.FISHING, 10216), "Gubber Blump must remain a Fishing trainer")
assert(contains(categories.RIDING, 7954), "Binjy must belong to Riding by ID")
for _, id in ipairs({3690,4732,4752,4753,4772,4773,7953,7954,16280,20500,20511,20914,28746,31238,31247,35093,35100,35133,35135}) do
    assert(contains(categories.RIDING, id), "preserve verified Riding trainer " .. id)
end
assert(contains(categories.WEAPON_MASTER, 2704), "Hanashi must remain a Weapon Master")
-- Neither empty subtitles nor an NPC missing from the database may break initialization.
db.npcData[11557][2] = nil
db.npcData[7954][2] = "Mechanostrider Pilot"
db.npcData[514] = nil
db.npcData[999999] = {"Barber", "Barber", {[12] = {{50, 50}}}, 0}
-- Service flags, not subtitles, identify bankers and battlemasters.
for index, subtitle in ipairs({false, "", "Translated title"}) do
    db.npcData[900000 + index] = {"Banker " .. index, subtitle or nil, nil, 131073}
    db.npcData[900010 + index] = {"Battlemaster " .. index, subtitle or nil, nil, 1048577}
end
db.npcData[900020] = {"[DND] Banker", nil, nil, 131072}
db.npcData[900021] = {"[DND] Battlemaster", nil, nil, 1048576}
db.npcData[900022] = {"Ordinary NPC", "Banker", nil, 0}
db.npcData[900023] = {"Ordinary NPC", "Battlemaster", nil, 0}
town.GetClassTrainers = function() return {HUNTER = {}, MAGE = {}} end
town.GetMeetingStones = function() return {} end
town.GetFactionSpecificMailboxes = function() return {}, {} end
local function runStartupTask(task, ...)
    local thread = coroutine.create(task)
    local ok, err = coroutine.resume(thread, ...)
    assert(ok, err)
    while coroutine.status(thread) ~= "dead" do
        ok, err = coroutine.resume(thread)
        assert(ok, err)
    end
end
local function initialize()
    runStartupTask(town.Initialize)
end
initialize()
local global = env.Questie.db.global
do
    global.petFoodVendorTypes = {Meat = {90}}
    initialize()
    assert(global.petFoodVendorTypes == nil, "recompile invalidates the previous pet-food index")

    local queries = 0
    db.ItemPointers = {[101] = true, [102] = true, [103] = true, [104] = true}
    local foodTypes = {[101] = 1, [102] = 8, [103] = 0}
    db.QueryItemSingle = function(id, field)
        assert(field == "foodType")
        queries = queries + 1
        return foodTypes[id]
    end
    runStartupTask(town.InitializePetFoodIndex, "MAGE")
    assert(queries == 0 and global.petFoodVendorTypes == nil, "non-hunter skips the scan and leaves no empty cache")
    runStartupTask(town.InitializePetFoodIndex, "HUNTER")
    assert(queries == 4 and global.petFoodVendorTypes.Meat[1] == 101, "first hunter on cached DB builds the index")
    assert(global.petFoodVendorTypes["Raw Fish"][1] == 102, "compiled food types select the correct category")
    assert(#global.petFoodVendorTypes.Bread == 0 and #global.petFoodVendorTypes.Meat == 1, "non-food entries are ignored")
    runStartupTask(town.InitializePetFoodIndex, "HUNTER")
    assert(queries == 4, "hunter with a warm index skips the scan")
end
for index = 1, 3 do
    assert(contains(global.townsfolk.Banker, 900000 + index), "bankers do not require subtitles")
    assert(contains(global.townsfolk.Battlemaster, 900010 + index), "battlemasters do not require subtitles")
end
assert(#global.townsfolk.Banker == 3, "bankers still exclude DND and unflagged NPCs")
assert(#global.townsfolk.Battlemaster == 3, "battlemasters still exclude DND and unflagged NPCs")
for category, ids in pairs(categories) do
    local target = category == "RIDING" and global.townsfolk["Riding Trainer"]
        or category == "WEAPON_MASTER" and global.townsfolk["Weapon Master"]
        or global.professionTrainers[keys[category]]
    assert(target, "missing category " .. category)
    local seen, expected = {}, 0
    for _, id in ipairs(ids) do
        if db.npcData[id] then
            expected = expected + 1
            assert(contains(target, id), category .. ": translated or missing subtitle lost NPC " .. id)
        end
    end
    assert(#target == expected, category .. ": unexpected entries")
    for _, id in ipairs(target) do
        assert(not seen[id], category .. ": duplicate NPC " .. id)
        seen[id] = true
    end
end
assert(not contains(global.professionTrainers[keys.BLACKSMITHING], 514), "skip missing NPCs")
assert(not global.professionTrainers[keys.RIDING], "Riding must stay under Townsfolk")
assert(contains(global.townsfolk.Barber, 999999), "preserve Barber discovery")
-- Book vendors can already be trainers. Their post-boot merge must stay unique.
env.Questie.db.char = {vendorList = {}}
local vendorGroups = {
    [22012] = {[18990] = true, [18991] = true, [26947] = true},
    [27532] = {[18911] = true, [26947] = true},
    [27736] = {[18987] = true, [18988] = true, [18993] = true},
}
town.PopulateVendors = function(_, items) return vendorGroups[items[1]] or {} end
town.UpdatePlayerVendors = function() end
town.PostBoot()
assert(contains(global.professionTrainers[keys.FIRST_AID], 26947), "preserve additional profession book vendors")
for category, ids in pairs(global.professionTrainers) do
    local seen = {}
    for _, id in ipairs(ids) do
        assert(not seen[id], "book vendors duplicated trainer " .. id .. " in category " .. category)
        seen[id] = true
    end
end
-- Saved categories must not alias the generated lists or accumulate entries on recompilation.
local ridingCount = #categories.RIDING
table.insert(global.townsfolk["Riding Trainer"], 999998)
initialize()
assert(#categories.RIDING == ridingCount, "do not mutate the generated source lists")
assert(#env.Questie.db.global.townsfolk["Riding Trainer"] == ridingCount, "rebuild fresh category lists")
print("Trainer categories: ID classification, missing/translated titles, unique entries, and rebuild passed")
