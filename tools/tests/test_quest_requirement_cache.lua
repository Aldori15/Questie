-- Exercise the production cache without loading the client UI.
local file = assert(io.open("Database/QuestieDB.lua", "rb"))
local source = file:read("*a")
file:close()
local factory = assert(source:match("(local function CreateQuestRequirementQuery.-)\r?\nQuestieDB.itemDataOverrides"))
local compile = loadstring or load
local create = assert(compile(factory .. "\nreturn CreateQuestRequirementQuery"))()
local keys = {requiredRaces = 6, preQuestSingle = 13, requiredSpell = 30, requiredRanks = 35}
local rows = {
    [101] = {requiredRaces = 0, preQuestSingle = {10, 20}, requiredSpell = false},
    [202] = {requiredRaces = 690, preQuestSingle = {30}},
}
local reads, overrides = {}, {}
local function read(id, field)
    local key = id .. ":" .. field
    reads[key] = (reads[key] or 0) + 1
    return rows[id] and rows[id][field]
end
local query = create(read, keys, overrides)
assert(query(101, "requiredRaces") == 0)
assert(query(202, "preQuestSingle")[1] == 30)
local prerequisites = query(101, "preQuestSingle")
assert(prerequisites[1] == 10 and prerequisites[2] == 20)
assert(query(202, "requiredRaces") == 690)
assert(query(101, "requiredSpell") == false)
assert(query(101, "requiredRanks") == nil)
collectgarbage("collect")
assert(query(101, "preQuestSingle") == prerequisites)
assert(query(101, "requiredRaces") == 0)
assert(query(101, "requiredSpell") == false)
assert(query(101, "requiredRanks") == nil)
for key, count in pairs(reads) do assert(count == 1, "cache miss on repeated query: " .. key) end

-- Corrections remain live even after the compiled value or absence was cached.
overrides[101] = {[6] = 1101, [35] = false}
assert(query(101, "requiredRaces") == 1101)
assert(query(101, "requiredRanks") == false)
overrides[101][6] = 0
assert(query(101, "requiredRaces") == 0)
overrides[101][13] = {}
assert(query(101, "preQuestSingle") == overrides[101][13])
overrides[101][13][1] = 99
assert(query(101, "preQuestSingle")[1] == 99)
overrides[101] = nil
assert(query(101, "preQuestSingle") == prerequisites)
assert(query(101, "requiredRaces") == 0)
assert(query(101, "requiredRanks") == nil)
for key, count in pairs(reads) do assert(count == 1, "override queried compiled data: " .. key) end

-- A replacement database gets a fresh cache, regardless of field query order.
rows[101].requiredRanks = {{202, 2}}
assert(query(101, "requiredRanks") == nil)
local fresh = create(read, keys, overrides)
assert(fresh(101, "requiredRanks")[1][1] == 202)
assert(fresh(101, "requiredSpell") == false)
assert(fresh(101, "requiredRaces") == 0)
assert(fresh(202, "preQuestSingle")[1] == 30)
assert(fresh(202, "requiredRaces") == 690)

print("Quest requirement cache: values, misses, live overrides and fresh handles passed")
