-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise production tooltip hooks with the original Wrath spell/aura return values.
local env = setmetatable({}, {__index = _G})
env._G = env
local modules = {}
local function module(name)
    if not modules[name] then modules[name] = {private = {}} end
    return modules[name]
end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end}
local function loadModule(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    if setfenv then setfenv(assert(loadstring(source, "@" .. path)), env)()
    else assert(load(source, "@" .. path, "t", env))() end
end
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
setmetatable(module("l10n"), {__call = function(_, text) return text end})
module("QuestiePlayer").numberOfGroupMembers = 1
env.QuestieCompat = {}
env.Questie = {db = {profile = {enabled = true, enableTooltips = true}}}
loadModule("Modules/Options/QuestieOptionsDefaults.lua")
local profile = env.Questie.db.profile
profile.enableTooltipsSpellID = module("QuestieOptionsDefaults"):Load().profile.enableTooltipsSpellID
equal(profile.enableTooltipsSpellID, false, "new and existing profiles default off")

local auraCalls, auraIds = {}, {UnitAura = 139, UnitBuff = 21562, UnitDebuff = 589}
for api, id in pairs(auraIds) do
    local spellId = id
    env[api] = function(unit, index, filter)
        auraCalls[#auraCalls + 1] = {api, unit, index, filter}
        if index == 0 then return nil end
        -- spellId is eleventh; rank is deliberately a nonnumeric string.
        return "Aura", "Rank 7", "icon", 1, "Magic", 10, 20, "player", false, false, spellId
    end
end
local methodHookCounts = {}
env.hooksecurefunc = function(object, method, hook)
    local original = assert(object[method])
    methodHookCounts[object] = methodHookCounts[object] or {}
    local counts = methodHookCounts[object]
    counts[method] = (counts[method] or 0) + 1
    object[method] = function(...)
        original(...)
        hook(...)
    end
end
local function tooltip(name)
    local tip = {scripts = {}, lines = {}, shows = 0}
    function tip:HookScript(script, fn)
        self.scripts[script] = self.scripts[script] or {}
        table.insert(self.scripts[script], fn)
    end
    function tip:Fire(script)
        for _, fn in ipairs(self.scripts[script] or {}) do fn(self) end
    end
    function tip:Clear()
        self.lines, self.spellId = {}, nil
        self:Fire("OnTooltipCleared")
    end
    function tip:GetSpell() return self.spellId and "Spell", "Rank 7", self.spellId end
    function tip:GetName() return name end
    function tip:AddDoubleLine(label, value, ...) table.insert(self.lines, {label, value, ...}) end
    function tip:Show()
        self.shows = self.shows + 1
        self:Fire("OnShow")
    end
    function tip:SetSpell(id)
        self:Clear()
        self.spellId = id
        self:Fire("OnTooltipSetSpell")
    end
    function tip:SetUnitAura() self:Clear() end
    function tip:SetUnitBuff() self:Clear() end
    function tip:SetUnitDebuff() self:Clear() end
    return tip
end
env.GameTooltip, env.ItemRefTooltip = tooltip("GameTooltip"), tooltip("ItemRefTooltip")
loadModule("Modules/Tooltips/Tooltip.lua")
loadModule("Modules/Tooltips/TooltipHandler.lua")
local tooltips = module("QuestieTooltips")
tooltips:Initialize()
local game, ref = env.GameTooltip, env.ItemRefTooltip
game:SetSpell(133)
equal(#game.lines, 0, "disabled option")
profile.enableTooltipsSpellID = true
game:SetSpell(133)
equal(game.lines[1][1], "Spell ID", "localized label")
equal(game.lines[1][2], "133", "third GetSpell value, not rank")
game:Fire("OnTooltipSetSpell")
equal(#game.lines, 1, "repeated hooks do not duplicate lines")
game:SetSpell(133)
equal(#game.lines, 1, "rebuilding the same spell restores its line")
ref:SetSpell(116)
equal(ref.lines[1][2], "116", "clicked spell link uses receiving tooltip")
equal(game.lines[1][2], "133", "clicked link leaves hover tooltip alone")
for _, id in ipairs({false, 0, -1, "Rank 7"}) do
    game:SetSpell(id)
    equal(#game.lines, 0, "invalid spell ID")
end

for _, tip in ipairs({game, ref}) do
    for _, aura in ipairs({{"SetUnitAura", "UnitAura"}, {"SetUnitBuff", "UnitBuff"}, {"SetUnitDebuff", "UnitDebuff"}}) do
        tip[aura[1]](tip, "target", 3, "PLAYER")
        equal(tip.lines[1][2], tostring(auraIds[aura[2]]), aura[1] .. " eleventh value")
        local call = auraCalls[#auraCalls]
        equal(call[1], aura[2], "matching aura API")
        equal(call[2], "target", "unit forwarded")
        equal(call[3], 3, "index forwarded")
        equal(call[4], "PLAYER", "filter forwarded")
        -- Some tooltip paths also fire the spell script after setting an aura.
        tip.spellId = auraIds[aura[2]]
        tip:Fire("OnTooltipSetSpell")
        equal(#tip.lines, 1, "spell/aura hooks share duplicate protection")
        tip[aura[1]](tip, "target", 0)
        equal(#tip.lines, 0, "missing aura ignored")
    end
end
for _, setting in ipairs({"enableTooltipsSpellID", "enableTooltips", "enabled"}) do
    profile[setting] = false
    local before = #auraCalls
    game:SetSpell(133)
    game:SetUnitDebuff("target", 1)
    equal(#game.lines, 0, setting .. " hides spell/aura IDs")
    equal(#auraCalls, before, setting .. " avoids unused aura queries")
    profile[setting] = true
end
tooltips:Initialize()
for _, tip in ipairs({game, ref}) do
    equal(#tip.scripts.OnTooltipSetSpell, 1, "spell hooks installed once")
    equal(#tip.scripts.OnTooltipCleared, 1, "clear hooks installed once")
    for _, count in pairs(methodHookCounts[tip]) do equal(count, 1, "aura hooks installed once") end
end
print("PASS: Wrath spell/aura IDs, receiving tooltip, duplicate prevention, reuse, invalid IDs, settings and hook lifecycle")
