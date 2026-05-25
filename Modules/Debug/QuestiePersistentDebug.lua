---@class QuestiePersistentDebug
local QuestiePersistentDebug = QuestieLoader:CreateModule("QuestiePersistentDebug")

-- Persistent SavedVariables table declared in the TOC: QuestieDebugLogs
-- Structure: QuestieDebugLogs = { entries = { {time=..., tag=..., msg=...}, ... }, maxEntries = N }
QuestieDebugLogs = QuestieDebugLogs or {}
QuestieDebugLogs.entries = QuestieDebugLogs.entries or {}
QuestieDebugLogs.maxEntries = QuestieDebugLogs.maxEntries or 1200

local saved = QuestieDebugLogs
local DEFAULT_MAX = 1200

local function serializeArg(a)
    local t = type(a)
    if t == "table" then
        local s = "{"
        local cnt = 0
        for k, v in pairs(a) do
            cnt = cnt + 1
            if cnt > 10 then
                s = s .. "..."
                break
            end
            s = s .. tostring(k) .. "=" .. tostring(v) .. ","
        end
        s = s .. "}"
        return s
    else
        return tostring(a)
    end
end

local function trimIfNeeded()
    local max = saved.maxEntries or DEFAULT_MAX
    while #saved.entries > max do
        table.remove(saved.entries, 1)
    end
end

function QuestiePersistentDebug.Add(tag, ...)
    if not tag then tag = "unknown" end
    local parts = {}
    for i = 1, select('#', ...) do
        parts[#parts + 1] = serializeArg(select(i, ...))
    end

    local entry = { time = (GetTime and GetTime()) or 0, tag = tag, msg = table.concat(parts, " | ") }
    saved.entries[#saved.entries + 1] = entry
    trimIfNeeded()

    -- If debug logging is enabled, also echo to chat for real-time visibility
    if Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugEnabled then
        print(string.format("[QuestieDebug] %.3f %s: %s", entry.time, entry.tag, entry.msg))
    end
end

function QuestiePersistentDebug.Print(n)
    n = n or 60
    local start = #saved.entries - n + 1
    if start < 1 then start = 1 end
    for i = start, #saved.entries do
        local e = saved.entries[i]
        print(string.format("[QuestieDebug] %.3f %s: %s", e.time or 0, tostring(e.tag), tostring(e.msg)))
    end
end

function QuestiePersistentDebug.Clear()
    saved.entries = {}
end

-- Helper alias for ease-of-use
QuestiePersistentDebug.AddEntry = QuestiePersistentDebug.Add

-- Expose module table
return QuestiePersistentDebug
