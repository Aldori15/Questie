---@class QuestieStatus
local QuestieStatus = QuestieLoader:CreateModule("QuestieStatus")

-- Session-only notices. Producers own stable IDs and explicitly set/clear them.
-- This registry does not intercept Lua errors or decide whether Questie is ready.
QuestieStatus.Severity = {Error = 1, Warning = 2, Info = 3}
local issues, order = {}, {}
local nextOrder = 0
local onChange

local function CopyIssue(issue, id)
    local copy = {id = id, severity = issue.severity, message = issue.message, action = issue.action}
    if issue.args then
        copy.args = {}
        for index, value in ipairs(issue.args) do copy.args[index] = value end
    end
    if issue.icon then copy.icon = {texture = issue.icon.texture} end
    return copy
end

local function NotifyChanged()
    if not onChange then return true end
    -- Display failures must not replace the startup error being recorded. Observers never yield.
    return xpcall(onChange, geterrorhandler())
end

---@param id string
---@param issue table @severity, message (localization key), optional args/action/icon.texture
function QuestieStatus.Set(id, issue)
    assert(type(id) == "string" and id ~= "", "QuestieStatus requires a notice ID")
    assert(issue.severity == 1 or issue.severity == 2 or issue.severity == 3, "Invalid QuestieStatus severity")
    assert(type(issue.message) == "string", "QuestieStatus requires a message")
    local copy = CopyIssue(issue, id)
    if not issues[id] then
        nextOrder = nextOrder + 1
        order[id] = nextOrder
    end
    issues[id] = copy
    NotifyChanged()
end

---@param id string
function QuestieStatus.Clear(id)
    if not issues[id] then return end
    issues[id], order[id] = nil, nil
    NotifyChanged()
end

---Return snapshots ordered by severity, then original activation order.
function QuestieStatus.GetIssues()
    local result = {}
    for id, issue in pairs(issues) do result[#result + 1] = CopyIssue(issue, id) end
    table.sort(result, function(left, right)
        if left.severity ~= right.severity then return left.severity < right.severity end
        return order[left.id] < order[right.id]
    end)
    return result
end

function QuestieStatus.GetBadgeIssue()
    local sorted = QuestieStatus.GetIssues()
    local first = sorted[1]
    if not first then return nil end
    -- A default badge takes precedence over custom icons within the highest severity.
    for _, issue in ipairs(sorted) do
        if issue.severity ~= first.severity then break end
        if not issue.icon then return issue end
    end
    return first
end

---Register one non-yielding display observer and immediately replay current state.
function QuestieStatus.SetOnChange(callback)
    onChange = callback
    return NotifyChanged()
end
