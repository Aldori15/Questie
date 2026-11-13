-- Run from the addon root with Lua 5.1 or 5.2. Exercise real frame recycling and draw queues.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function noop() end
local function harness()
    local env = setmetatable({}, {__index = _G})
    env._G, env.unpack = env, unpack or table.unpack
    local modules, visible = {}, {}
    local function module(name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    local pins = {
        AddWorldMapIconMap = function(_, _, frame) visible[frame] = true end,
        AddMinimapIconMap = function(_, _, frame) visible[frame] = true end,
        RemoveWorldMapIcon = function(_, _, frame) visible[frame] = nil end,
        RemoveMinimapIcon = function(_, _, frame) visible[frame] = nil end,
    }
    env.QuestieCompat = {HBD = {}, HBDPins = pins}
    env.CreateFrame, env.StaticPopupDialogs = function() return {} end, {}
    env.tremove, env.tinsert = table.remove, table.insert
    env.Questie = {db = {profile = {}}, Debug = noop}
    setmetatable(module("l10n"), {__call = function(_, text) return text end})
    module("QuestieDBMIntegration").UnregisterHudQuestIcon = noop
    local function loadModule(path)
        if setfenv then setfenv(assert(loadfile(path)), env)()
        else assert(loadfile(path, "t", env))() end
    end
    loadModule("Modules/FramePool/QuestieFrame.lua")
    module("QuestieFrame").CreateIconFrame = function(id)
        return {frameId = id, texture = {SetVertexColor = noop, SetTexCoord = noop},
            glowTexture = {Hide = noop}, SetAlpha = noop, SetScript = noop, SetSize = noop, Hide = noop,
            GetName = function() return "QuestieFrame" .. id end,
            Unload = module("QuestieFrame").private.Unload}
    end
    loadModule("Modules/FramePool/QuestieFramePool.lua")
    loadModule("Modules/Map/QuestieMap.lua")
    local pool, map = modules.QuestieFramePool, modules.QuestieMap
    map.utils.SetDrawOrder = noop
    return {pool = pool, map = map, visible = visible, draw = function(frame, id, surface)
        frame.data = {Id = id}
        map:QueueDraw(surface, env.Questie, frame)
    end}
end

for _, surface in ipairs({"MAP", "MINIMAP"}) do
    local h = harness()
    local frame = h.pool:GetFrame()
    h.draw(frame, 844, surface)
    h.map.ProcessQueue()
    equal(h.visible[frame], true, surface .. " original icon draws")
    frame._hidden_by_flash = true
    h.pool:UnloadFrame(frame)
    equal(frame._hidden_by_flash, nil, surface .. " unloading clears the flash visibility marker")
    equal(h.visible[frame], nil, surface .. " original icon unloads")
    h.pool:UnloadFrame(frame)
    equal(frame._needsUnload, nil, surface .. " duplicate unload cannot flag a pooled frame")
    local reused = h.pool:GetFrame()
    equal(reused, frame, surface .. " released frame is reused")
    equal(reused._hidden_by_flash, nil, surface .. " reused frame cannot inherit temporary flash visibility")
    assert(h.pool:GetFrame() ~= reused, surface .. " duplicate unload cannot return a frame twice")
    h.draw(reused, 868, surface)
    h.map.ProcessQueue()
    equal(h.visible[reused], true, surface .. " replacement icon survives queue processing")
    equal(reused.data.Id, 868, surface .. " replacement data stays intact")
end

do
    local h = harness()
    local frame = h.pool:GetFrame()
    h.draw(frame, 844, "MAP")
    h.map.ProcessQueue()
    h.pool:UnloadFrame(frame)
    frame._needsUnload, frame._loaded = true, true
    local reused = h.pool:GetFrame()
    equal(reused, frame, "reinitialization uses the released frame")
    equal(reused._needsUnload, nil, "reinitialization clears stale unload state")
    equal(reused._loaded, nil, "reinitialization clears stale loaded state")
end

-- A queued draw still owns its frame until ProcessQueue consumes that draw.
for _, surface in ipairs({"MAP", "MINIMAP"}) do
    local h = harness()
    local frame = h.pool:GetFrame()
    h.draw(frame, 844, surface)
    frame._hidden_by_flash = true
    h.pool:UnloadFrame(frame)
    equal(frame._hidden_by_flash, nil, surface .. " pending unload also clears flash visibility")
    h.pool:UnloadFrame(frame)
    equal(frame._needsUnload, true, surface .. " queued unload stays pending")
    equal(frame.data.Id, 844, surface .. " pending draw retains its data")
    assert(h.pool:GetFrame() ~= frame, surface .. " pending frame is not reused early")
    h.map.ProcessQueue()
    equal(h.visible[frame], nil, surface .. " queue removes the cancelled icon")
    equal(frame.data, nil, surface .. " cancelled draw releases its data")
    local reused = h.pool:GetFrame()
    equal(reused, frame, surface .. " cancelled frame is reusable after queue completion")
    assert(h.pool:GetFrame() ~= reused, surface .. " cancelled frame returns to pool once")
    h.draw(reused, 868, surface)
    h.map.ProcessQueue()
    equal(h.visible[reused], true, surface .. " cancelled frame can draw another icon")
end

print("Frame pool regressions passed (duplicate unloads, reuse/flash flags and deferred map/minimap draws)")
