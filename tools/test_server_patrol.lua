-- Run from the addon root with Lua 5.2+. Uses production protocol, conversion,
-- complete batches, scope changes and pin movement code; no client or running server is required.
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a"); file:close()
    return source
end
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 0.0001, label .. ": " .. actual .. " ~= " .. expected)
end
local function setup()
    local env = setmetatable({}, {__index = _G})
    local modules, messages, frame, now = {}, {}, {}, 0
    env.unpack = table.unpack
    env.QuestieLoader = {
        CreateModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
        ImportModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
    }
    env.Questie = {db = {profile = {}}, Print = function() end}
    env.QuestieCompat = {Is335 = true}
    assert(loadfile("Compat/UiMapData.lua", "t", env))()
    local npcs = {}
    modules.QuestieDB = {GetNPC = function(_, id) return npcs[id] end}
    modules.ZoneDB = {
        GetUiMapIdByAreaId = function(_, area) return ({[4395] = 125, [4560] = 126, [210] = 118, [3430] = 1941})[area] end,
        GetParentZoneId = function(_, area) return ({[4560] = 4395})[area] end,
    }
    local hbdSource = read("Compat/HBD.lua")
    -- Load the actual conversion functions without the client's UI setup.
    assert(load(hbdSource:sub(1, assert(hbdSource:find("--- Convert world coordinates to local/point zone coordinates on the azeroth")) - 1), "HBD conversion", "t", env))()
    local pins, mini, world = {}, {}, {}
    env.pins, env.minimapPins, env.worldmapPins = pins, mini, world
    env.minimapPinRegistry, env.worldmapPinRegistry = {[env.Questie] = {}}, {[env.Questie] = {}}
    env.activeMinimapPins = {}
    env.lastXY, env.lastYY = 620, 5900
    local miniMoves, mapMoves = 0, 0
    env.drawMinimapPin = function() miniMoves = miniMoves + 1 end
    env.HandleWorldMapPin = function() mapMoves = mapMoves + 1 end
    env.QuestieCompat.HBDPins = pins
    local moveSource = assert(hbdSource:match("(function pins:MoveIconWorld.-)--- Remove a worldmap icon"))
    assert(load(moveSource, "HBD pin movement", "t", env))()
    env.GetTime = function() return now end
    env.UnitName = function() return "Tester" end
    env.IsInInstance = function() return false, "none" end
    env.SlashCmdList = {}
    env.CreateFrame = function() return frame end
    frame.RegisterEvent = function() end
    frame.SetScript = function(_, name, callback) frame[name] = callback end
    env.SendAddonMessage = function(_, payload) messages[#messages + 1] = payload end
    local refreshes = 0
    modules.QuestieServerIntegrations = {Initialize = function() end, Refresh = function() refreshes = refreshes + 1 end}
    assert(loadfile("Modules/Network/QuestieServerPatrol.lua", "t", env))()
    assert(loadfile("Modules/Network/QuestieServer.lua", "t", env))()
    modules.QuestieServer:Initialize()
    local function token() return messages[#messages]:match("^[^~]+~%d+~([^~]+)~") end
    local function receive(payload, sender, channel)
        frame.OnEvent(frame, "CHAT_MSG_ADDON", "QSTSVR", payload, channel or "WHISPER", sender or "Tester")
    end
    local function snapshot(sequence, caps, rows)
        rows = rows or {}
        local header = "~12~" .. token() .. "~" .. sequence
        receive("BEGIN" .. header .. "~" .. (caps or "PATROLS,HEARTBEAT") .. "~" .. #rows .. "~" .. #rows)
        for index, row in ipairs(rows) do receive("PART" .. header .. "~" .. index .. "~" .. row) end
        receive("END" .. header)
    end
    local function motion(sequence, rows, context, anchor, oldToken, dropped)
        rows = rows or {"37780:133649:5915.750:626.745"}
        context = context or {571, 0, 4395}
        local header = "~12~" .. (oldToken or token()) .. "~" .. (anchor or 1) .. "~" .. sequence
        receive("MBEGIN" .. header .. "~" .. table.concat(context, "~") .. "~" .. #rows .. "~" .. #rows .. "~READY")
        for index, row in ipairs(rows) do
            if dropped ~= index then receive("MPART" .. header .. "~" .. index .. "~" .. row) end
        end
        if dropped ~= "END" then receive("MEND" .. header) end
        return header
    end
    local function icon(minimap, manual, loaded, id, spawn, uiMap, area, kind)
        id, uiMap, area = id or 37780, uiMap or 125, area or 4395
        npcs[id] = npcs[id] or {spawns = {[area] = {{51.3, 27.27}}}}
        local data = manual and {id = id, Type = "manual", spawnType = "monster", npcData = npcs[id]}
            or {Type = kind or "available", StarterEntryId = id, FinisherEntryId = id, Id = 24506}
        local pin = {data = data, AreaID = area, UiMapID = uiMap, x = 51.3, y = 27.27, _loaded = loaded,
            miniMapIcon = minimap, isManualIcon = manual}
        local target, registry = minimap and mini or world, minimap and env.minimapPinRegistry or env.worldmapPinRegistry
        local x, y, instance = env.QuestieCompat.HBD:GetWorldCoordinatesFromZone(pin.x / 100, pin.y / 100, uiMap)
        target[pin] = {instanceID = instance, x = x, y = y, uiMapID = uiMap, worldMapShowFlag = 3}
        registry[env.Questie][pin] = true
        if minimap then env.activeMinimapPins[pin] = target[pin] end
        modules.QuestieServerPatrol:Register(pin, spawn and {51.3, 27.27, 0, 0, 571, 0, 0, spawn})
        return pin
    end
    return {env = env, server = modules.QuestieServer, patrol = modules.QuestieServerPatrol,
        token = token, snapshot = snapshot, motion = motion, npcs = npcs, messages = messages, receive = receive, icon = icon,
        step = function(seconds) now = now + seconds; frame.OnUpdate(frame) end,
        elapse = function(seconds) now = now + seconds end,
        update = function() modules.QuestieServerPatrol:Update(now) end,
        event = function(name) frame.OnEvent(frame, name) end,
        counts = function() return miniMoves, mapMoves, refreshes end}
end

local s = setup()
s.motion(1)
equal(s.server:GetPatrolPositions(), nil, "movement cannot create a snapshot")
s.snapshot(1); s.motion(1)
local good = s.server:GetPatrolPositions()
equal(good.positions[133649].worldX, 626.745, "native Y becomes HBD X")
equal(good.positions[133649].worldY, 5915.75, "native X becomes HBD Y")
for _, row in ipairs({
    "37780:133649:nan:626.745", "37780:133649:1e9:626.745", "37780:133649:20001.0:626.745",
    "37780:0:5915.750:626.745", "0:133649:5915.750:626.745", "37780:133649:5915.750:626.745:extra",
}) do
    s.motion(2, {row}); equal(s.server:GetPatrolPositions(), good, "malformed position rejected atomically")
end
s.motion(2, nil, nil, 99); s.motion(2, nil, nil, nil, "oldtoken")
equal(s.server:GetPatrolPositions(), good, "old connection/snapshot rejected")
s.motion(2, {"37780:133649:5915.750:626.745", "37780:133649:5916.750:627.745"})
equal(s.server:GetPatrolPositions(), good, "duplicate spawn rejected")
local unauthorized = "~12~" .. s.token() .. "~1~2"
for _, senderAndChannel in ipairs({{"Other", "WHISPER"}, {"Tester", "PARTY"}}) do
    for _, payload in ipairs({"MBEGIN" .. unauthorized .. "~571~0~4395~0~0~READY", "MEND" .. unauthorized}) do
        s.receive(payload, senderAndChannel[1], senderAndChannel[2])
    end
end
equal(s.server:GetPatrolPositions(), good, "unauthorized sender/channel rejected")
s.receive("MBEGIN" .. unauthorized .. "~571~0~4395~65~1~READY")
s.receive("MEND" .. unauthorized)
equal(s.server:GetPatrolPositions(), good, "oversized catalog rejected")
s.motion(2, nil, nil, nil, nil, 1)
equal(s.server:GetPatrolPositions(), good, "missing part cannot replace sample")
s.motion(3, nil, nil, nil, nil, "END")
equal(s.server:GetPatrolPositions(), good, "missing end cannot replace sample")
s.elapse(3); s.receive("MEND~12~" .. s.token() .. "~1~3")
equal(s.server:GetPatrolPositions(), good, "late batch end rejected")
s.motion(4); local newest = s.server:GetPatrolPositions(); s.motion(1, {})
equal(s.server:GetPatrolPositions(), newest, "reordered catalog rejected")
s.elapse(5); equal(s.server:GetPatrolPositions(), nil, "five-second expiry")
s.motion(5); equal(s.server:GetPatrolPositions() ~= nil, true, "fresh catalog recovers")
s.elapse(22); s.motion(6)
equal(s.server:GetPatrolPositions(), nil, "movement cannot renew base freshness")

s = setup(); s.snapshot(1); s.motion(1)
local map, mini = s.icon(false, false, true, nil, 133649), s.icon(true, false, true, nil, 133649)
s.update()
local hbd = s.env.QuestieCompat.HBD
local x, y = hbd:GetZoneCoordinatesFromWorld(626.745, 5915.75, 125)
near(map.x, x * 100, "Dalaran conversion"); near(mini.y, y * 100, "paired minimap conversion")
s.motion(2, {"37780:133649:5915.750:636.745"}); s.step(0.11)
near(mini.worldX, 636.745, "new sample moves directly without interpolation")
local beforeMini, beforeMap, beforeRefresh = s.counts()
for _ = 1, 1000 do s.step(0.001) end
local afterMini, afterMap, afterRefresh = s.counts()
equal(beforeMini, afterMini, "client FPS does not cause extra minimap redraws")
equal(beforeMap, afterMap, "client FPS does not cause extra map redraws")
equal(beforeRefresh, afterRefresh, "motion cannot rebuild quest availability")
s.snapshot(2)
s.step(0.11); near(mini.worldX, 636.745, "same-scope snapshot replacement keeps fresh position")
s.motion(3, {"37780:133649:5915.750:666.745"}, nil, 1)
s.step(0.11); near(mini.worldX, 636.745, "late previous-anchor data cannot update position")
s.motion(4, {}, nil, 2); s.step(0.11)
near(map.x, 51.3, "missing NPC restores static map position")
near(mini.y, 27.27, "missing NPC restores static minimap position")
s.motion(5, nil, nil, 2); s.step(0.11); s.elapse(5); s.update()
near(map.x, 51.3, "expiry restores static location without reload")
s.receive("MBEGIN~12~" .. s.token() .. "~2~6~571~0~4395~0~0~OVERFLOW")
s.receive("MEND~12~" .. s.token() .. "~2~6")
equal(s.server:GetPatrolPositions().status, "OVERFLOW", "overflow never supplies a partial catalog")
s.step(0.11); near(map.x, 51.3, "overflow retains static fallback")

-- The reported bank/shop bug: area-only transitions outside phase regions must
-- keep the connection and fresh sample. Actual zone transitions invalidate both.
s = setup(); s.snapshot(1, "PATROLS,PHASES,HEARTBEAT", {"P:PHASE_CONTEXT:571:4613:1:4395"}); s.motion(1)
local bank = s.icon(false, false, true, nil, 133649)
s.update(); local bankX, bankToken = bank.x, s.token()
for _, event in ipairs({"ZONE_CHANGED", "ZONE_CHANGED_INDOORS"}) do
    s.event(event); s.step(0.11)
    near(bank.x, bankX, "bank/shop transition keeps live location")
    equal(s.token(), bankToken, "bank/shop transition keeps WATCH token")
end
local drawX, drawY = s.patrol:GetDrawCoordinates(bank.data, 4395, 125, 51.3, 27.27,
    {51.3, 27.27, 0, 0, 571, 0, 0, 133649})
near(drawX, bank.x, "redrawn pin starts at live location"); near(drawY, bank.y, "initial live Y")
s.event("ZONE_CHANGED_NEW_AREA"); s.step(0.11)
equal(s.server:GetPatrolPositions(), nil, "true zone change clears live sample")
near(bank.x, 51.3, "true zone change immediately restores static position")

-- Ship passengers use world coordinates despite a deck-local DB map. Exact
-- identities let two spawns with the same NPC entry follow different positions.
s = setup(); s.snapshot(1)
local ship = s.icon(false, false, true, 29795, 142849, 118, 210)
local other = s.icon(true, true, true, 29795, 222222, 118, 210)
local finisher = s.icon(false, false, true, 29795, 142849, 118, 210, "complete")
s.motion(1, {"29795:142849:8000.000:1000.000", "29795:222222:8050.000:1100.000", "31261:142901:8005.000:1005.000"}, {571, 0, 210})
s.update()
near(ship.worldX, 1000, "gunship world position"); near(other.worldX, 1100, "same entry distinct spawn")
near(finisher.worldY, 8000, "turn-in follows moving questgiver")
equal(s.env.worldmapPins[ship].worldMapShowFlag, 3, "original map scope retained")
local legacy = s.icon(false, true, true, 29795, nil, 118, 210)
s.step(0.11); near(legacy.x, 51.3, "ambiguous old data keeps static location")
s.npcs[29795].spawns[210] = {{51.3, 27.27}, {52, 28}}
s.motion(2, {"29795:142849:8000.000:1000.000"}, {571, 0, 210}); s.step(0.11)
near(legacy.x, 51.3, "multiple static locations cannot use entry-only fallback")

s = setup(); s.snapshot(1)
local queued = s.icon(false, true, nil, nil, 133649)
s.motion(1); s.update(); near(queued.x, 51.3, "queued frame not moved before draw")
queued._loaded = true; s.step(0.11); near(queued.worldX, 626.745, "queued frame catches up")
queued._needsUnload = true; s.motion(2, {"37780:133649:5915.750:636.745"}); s.step(0.11)
near(queued.worldX, 626.745, "pending removal cannot move")
s.patrol:Unregister(queued); queued._needsUnload = nil; queued.data = {Id = 999}
s.step(0.11); near(queued.worldX, 626.745, "recycled frame remains untouched")

-- Native map 530 is translated into the client's Eastern Kingdoms coordinate
-- space for TBC starting zones. Ordinary continent maps need no such remap.
s = setup(); s.snapshot(1)
local elf = s.icon(false, true, true, 123, 456, 1941, 3430)
s.motion(1, {"123:456:10000.000:-5500.000"}, {530, 0, 3430}); s.update()
local elfMap = hbd.mapData[1941]
local expected = (-4487.55 + 5500) / elfMap[1] * 100
near(elf.x, expected, "native map-530 starting-zone transform")
local classic = s.icon(false, true, true, 2198, 1234, 1443, 405)
local wx, wy = s.env.QuestieCompat.HBD:GetWorldCoordinatesFromZone(0.4, 0.6, 1443)
s.motion(2, {string.format("2198:1234:%.3f:%.3f", wy, wx)}, {1, 0, 405}); s.step(0.11)
near(classic.x, 40, "ordinary Classic map transform")

-- Shifty Vickers uses the Underbelly floor rectangle, while AC reports the
-- parent Dalaran zone. Exact spawn matching must work on both map and minimap.
s = setup(); s.snapshot(1, "PATROLS,PHASES,HEARTBEAT", {"P:PHASE_CONTEXT:571:4570:1:4395"})
local sewerMap = s.icon(false, false, true, 30137, 113397, 126, 4560)
local sewerMini = s.icon(true, false, true, 30137, 113397, 126, 4560)
s.motion(1, {"30137:113397:5816.140:649.888"}); s.update()
local sewerX, sewerY = s.env.QuestieCompat.HBD:GetZoneCoordinatesFromWorld(649.888, 5816.140, 126)
near(sewerMap.x, sewerX * 100, "Underbelly map uses its floor rectangle")
near(sewerMini.y, sewerY * 100, "Underbelly minimap follows exact spawn")
s.motion(2, {"30137:113397:5817.140:654.888"}); s.step(0.11)
near(sewerMap.worldX, 654.888, "Underbelly map receives subsequent movement")
near(sewerMini.worldX, 654.888, "Underbelly minimap receives subsequent movement")
local oldSewerMap = s.icon(false, false, true, 30137, nil, 126, 4560)
local oldSewerMini = s.icon(true, false, true, 30137, nil, 126, 4560)
s.step(0.11)
near(oldSewerMap.worldX, 654.888, "legacy Underbelly spawn matches its parent Dalaran zone")
near(oldSewerMini.worldX, 654.888, "legacy Underbelly minimap matches its parent zone")
s.motion(3, {"30137:113397:5817.140:654.888"}, {571, 0, 210}); s.step(0.11)
near(oldSewerMap.x, 51.3, "legacy Underbelly spawn rejects unrelated server zone")
s.motion(4, {"30137:113397:5817.140:654.888", "30137:113398:5818.140:655.888"}); s.step(0.11)
near(oldSewerMap.x, 51.3, "parent-zone fallback still rejects ambiguous live spawns")
local unknownArea = s.icon(false, false, true, 30137, nil, 126, 9999)
s.motion(5, {"30137:113397:5817.140:654.888"}, {571, 0, 9998}); s.step(0.11)
near(unknownArea.x, 51.3, "unknown maps cannot match just because both IDs are nil")

print("Server patrol: batched protocol, zone transitions, identities, transports, turn-ins, fallback and pin reuse passed")
