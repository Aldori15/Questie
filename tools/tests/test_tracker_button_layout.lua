-- Run from the addon root with Lua 5.1 or 5.2+.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end
local function compile(source, name, env)
    if setfenv then return setfenv(assert(loadstring(source, name)), env or _G) end
    return assert(load(source, name, "t", env or _G))
end
local function noop() end
local function setup()
    local env, modules = setmetatable({}, {__index = _G}), {}
    env._G = env
    local function module(name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    env.QuestieCompat = {C_Timer = {}, WorldMapFrame = {}}
    env.QuestLogListScrollFrame = {}
    env.Questie = {db = {profile = {trackerFontSizeQuest = 10, trackerShowPlayButtons = true}, char = {}}}
    local s = {env = env, modules = modules, voice = false}
    env.IsAddOnLoaded = function() return s.voice end
    env.VoiceOver = {QuestOverlayUI = {questPlayButtons = {}, displayedButtons = {},
            CreatePlayButton = noop, UpdatePlayButtonTexture = noop},
        DataModules = {PrepareSound = noop, GetQuestLogQuestGiverTypeAndID = noop, GetObjectName = noop},
        SoundQueue = {Contains = noop, AddSoundToQueue = noop, RemoveSoundFromQueue = noop},
        Enums = {SoundEvent = {QuestAccept = 1}, GUID = {CanHaveID = noop}}, Utils = {MakeGUID = noop}}
    compile(read("Modules/Tracker/TrackerUtils.lua"), "@Modules/Tracker/TrackerUtils.lua", env)()
    s.utils, s.profile = modules.TrackerUtils, env.Questie.db.profile
    return s
end
local groups = 0
do
    local s = setup()
    for _, addon in ipairs({"VoiceOverRedux", "AI_VoiceOver", "AI_VoiceOver_Continued"}) do
        s.env.IsAddOnLoaded = function(name) return name == addon end
        equal(s.utils:IsVoiceOverLoaded(), true, addon .. " uses the compatible playback API")
    end
    s.env.VoiceOver.SoundQueue.RemoveSoundFromQueue = nil
    equal(s.utils:IsVoiceOverLoaded(), false, "incompatible playback APIs do not enable tracker integration")
    s.env.VoiceOver = nil
    equal(s.utils:IsVoiceOverLoaded(), false, "a loaded addon without its playback namespace is harmless")
    groups = groups + 1
end
do
    local s = setup()
    for _, font in ipairs({8, 10, 12, 20}) do
        s.profile.trackerFontSizeQuest = font
        for _, focus in ipairs({false, true}) do
            s.profile.trackerShowQuestFocusButtons = focus
            for _, voice in ipairs({false, true}) do
                s.voice = voice
                for _, items in ipairs({false, true}) do
                    for _, passive in ipairs({false, true}) do
                        s.utils:SetTrackerColumns(items, passive)
                        local m = s.utils:GetTrackerMargins()
                        equal(m.left, 14, "outer left padding stays unchanged")
                        equal(m.right, 30, "outer right padding stays unchanged")
                        equal(m.buttonSize, font + 3, "expand/focus button size follows the quest font")
                        equal(m.itemButtonSize, font + 12, "quest items retain their native size")
                        equal(m.statusLeft, 0, "status/focus column begins at the left edge")
                        equal(m.objective - m.quest, font, "objectives indent one quest-font unit")
                        local statusWidth = focus and m.buttonSize or (passive and font or 0)
                        local occupiedRight = statusWidth
                        if voice then
                            equal(m.playButtonSize, m.buttonSize + 2, "play texture has its transparent-border allowance")
                            equal(m.playButtonRight - m.playButtonSize, occupiedRight + (statusWidth > 0 and 2 or 0),
                                "play button follows the status column without overlapping it")
                            occupiedRight = m.playButtonRight
                        end
                        equal(m.itemButtonLeft, occupiedRight + ((statusWidth > 0 or voice) and 2 or 0),
                            "item/expand column follows the optional controls")
                        local columnWidth = items and m.itemButtonSize or m.buttonSize
                        equal(m.quest, m.itemButtonLeft + columnWidth + 2, "quest title follows the actual visible column")
                        assert(m.expandQuestRight - m.buttonSize >= m.itemButtonLeft,
                            "expand icon stays inside its item column")
                        assert(m.expandQuestRight <= m.quest - 2, "expand icon clears the quest title")
                        local center = (m.itemButtonLeft + m.quest - 2) / 2
                        assert(math.abs(m.expandQuestRight - m.buttonSize / 2 - center) <= 0.5,
                            "expand icon is centered in its column")
                        s.profile.trackerShowPlayButtons = false
                        local hidden = s.utils:GetTrackerMargins()
                        local removed = voice and (m.playButtonSize + 2) or 0
                        for _, key in ipairs({"quest", "objective", "itemButtonLeft", "expandQuestRight"}) do
                            equal(m[key] - hidden[key], removed, "hidden playback reclaims only its own column: " .. key)
                        end
                        equal(hidden.statusLeft, m.statusLeft, "hiding playback preserves the focus/status anchor")
                        s.profile.trackerShowPlayButtons = true
                    end
                end
            end
        end
    end
    groups = groups + 1
end

do
    local s = setup()
    s.env.GetItemCount = function(id) return id == 99001 and 1 or 0 end
    s.utils.IsQuestItemUsable = function() return true end
    s.modules.QuestieDB.QueryQuestSingle = function() error("native-only quest must not query the addon quest database") end
    s.modules.QuestieDB.QueryItemSingle = function() error("native-only source item must not require addon item data") end
    local quest = {Id = 99000, NativeOnly = true, sourceItemId = 99001, Objectives = {}, isComplete = true}
    for _, state in ipairs({0, 1}) do
        local items, completeUsable = s.utils:GetQuestItemButtonState(quest, state)
        equal(items[1], 99001, "native-only usable source items remain available to the column prepass")
        equal(completeUsable, state == 1, "native-only source items can remain usable at completion")
    end
    s.env.GetItemCount = function() return 0 end
    equal(#s.utils:GetQuestItemButtonState(quest, 0), 0, "absent native-only items do not reserve an item column")
    groups = groups + 1
end

-- Reuse the established full redraw fixture, with the actual tracker and Utils.
-- Inject at its final item assertion so these cases share its native frame setup.
do
    local source = read("tools/tests/test_tracker_objective_text.lua")
    local marker = '    equal(items[2]:GetAlpha(), 0, "fixture exercises transparent item controls")'
    local first, last = source:find(marker, 1, true)
    assert(first, "real renderer fixture retains its final item assertion")
    local cases = [[
    for _, first in ipairs({true, false}) do
        profile.listAchievementsFirst = first
        itemIndex = 0
        tracker:Update(true)
        local margin = utils:GetTrackerMargins()
        local criterion
        for _, row in ipairs(rows) do
            if row.mode == "objective" and row.label.text:find("4/3000", 1, true) then criterion = row end
        end
        assert(criterion, "two-item quest still permits native achievement criteria")
        equal(criterion.label.point[4], margin.objective,
            "achievement indent never inherits a prior quest's secondary item")
        equal(criterion.label:GetWidth(), base:GetWidth() - margin.objective - margin.right,
            "achievement label width matches its actual anchor")
    end
    profile.trackerShowQuestFocusButtons = false
    local function redraw()
        itemIndex = 0
        tracker:Update(true)
        return utils:GetTrackerMargins()
    end
    local expanded = redraw()
    env.Questie.db.char.collapsedQuests[quest.Id] = true
    local collapsed = redraw()
    equal(expanded.quest - collapsed.quest, expanded.itemButtonSize - expanded.buttonSize,
        "collapsed quests reserve only the expand button column")
    env.Questie.db.char.collapsedQuests[quest.Id] = nil
    env.Questie.db.char.collapsedZones["Hellfire Peninsula"] = true
    local hiddenZone = redraw()
    equal(hiddenZone.itemButtonLeft, 0, "collapsed zones reserve neither item nor passive status columns")
    env.Questie.db.char.collapsedZones["Hellfire Peninsula"] = nil
    env.Questie.db.char.AutoUntrackedQuests[quest.Id] = true
    equal(redraw().quest, hiddenZone.quest, "untracked item quests do not reserve columns")
    env.Questie.db.char.AutoUntrackedQuests[quest.Id] = nil
    local oldComplete = quest.IsComplete
    quest.IsComplete = function() return 1 end
    profile.trackerShowCompleteQuests, profile.collapseCompletedQuests = true, true
    equal(redraw().quest, collapsed.quest, "automatically collapsed completed quests do not reserve item width")
    profile.collapseCompletedQuests = false
    env.Questie.db.char.collapsedQuests[quest.Id] = nil
    quest.NativeOnly = true
    env.Questie.Colorize = function(_, text) return text end
    utils.GetQuestItemButtonState = function() return {1001, 1002}, true end
    equal(redraw().quest, expanded.quest, "visible completed native-only quest items retain their column")
    profile.trackerShowCompleteQuests = false
    equal(redraw().quest, hiddenZone.quest, "hidden completed quests do not reserve item/status columns")
    quest.IsComplete = oldComplete
    local before = rows
    local oldCombat = env.InCombatLockdown
    env.InCombatLockdown = function() return true end
    tracker:Update(true)
    equal(rows, before, "secure item layout is not rebuilt during combat")
    env.InCombatLockdown = oldCombat
    ]]
    source = source:sub(1, last) .. "\n" .. cases .. source:sub(last + 1)
    compile(source, "real tracker button layout regressions")()
    groups = groups + 1
end

do
    local s = setup()
    local env, voice = s.env, s.env.VoiceOver
    s.voice = true
    local playing, updated = {}, {}
    voice.SoundQueue.Contains = function(_, sound) return playing[sound] == true end
    voice.SoundQueue.AddSoundToQueue = function(_, sound) playing[sound] = true end
    voice.SoundQueue.RemoveSoundFromQueue = function(_, sound) playing[sound] = nil end
    voice.DataModules.PrepareSound = function(_, sound) return sound.questID ~= 3 end
    voice.DataModules.GetQuestLogQuestGiverTypeAndID = function() return "Creature", 10 end
    voice.DataModules.GetObjectName = function() return "Quest giver" end
    voice.QuestOverlayUI.UpdatePlayButtonTexture = function(_, id) updated[#updated + 1] = id end
    voice.Enums.GUID.CanHaveID = function() return true end
    voice.Utils.MakeGUID = function() return "creature-guid" end
    voice.QuestOverlayUI.questPlayButtons = {[1] = {}, [2] = {}, [3] = {}}
    s.modules.QuestieLib.AddonPath = "Interface/AddOns/Questie-335/"
    env.GetQuestLogTitle = function() return "Quest title" end
    env.QuestieCompat.GetQuestLogIndexByID = function(id) return id end
    local methods = {}
    for _, name in ipairs({"SetWidth", "SetHeight", "SetHitRectInsets", "SetPoint", "ClearAllPoints", "EnableMouse", "RegisterForClicks"}) do
        methods[name] = noop
    end
    function methods:SetScript(event, callback) self.scripts[event] = callback end
    function methods:SetPoint(...) self.point = {...} end
    function methods:HookScript(event, callback)
        local previous = self.scripts[event]
        self.scripts[event] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    function methods:SetNormalTexture(texture) self.texture = texture end
    function methods:SetHighlightTexture(texture) self.highlight = texture end
    function methods:SetAlpha(alpha) self.alpha = alpha end
    function methods:SetFrameLevel(level) self.level = level end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:GetParent() return self.parent end
    env.CreateFrame = function(_, _, parent)
        return setmetatable({scripts = {}, parent = parent}, {__index = methods})
    end
    local source = read("Modules/Tracker/TrackerLinePool.lua")
    local first = assert(source:find("        local playButton = CreateFrame", 1, true))
    local finish = assert(source:find("        line.playButton = playButton", first, true))
    local helper = source:match("(local function _UpdatePlayButton%([^)]*%).-\nend)") or ""
    local prefix = [[
        local TrackerUtils = QuestieLoader:ImportModule("TrackerUtils")
        local TrackerLinePool = QuestieLoader:ImportModule("TrackerLinePool")
        local TrackerFadeTicker = QuestieLoader:ImportModule("TrackerFadeTicker")
        local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
        local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
        local GetQuestLogIndexByID = QuestieCompat.GetQuestLogIndexByID
    ]]
    local construct = compile(prefix .. helper .. "\nreturn function(line, i)\n" .. source:sub(first, finish - 1)
        .. "\nreturn playButton end", "production VoiceOver play control", env)()
    local line = {Quest = {Id = 1}}
    local button = construct(line, 1)
    button:SetPlayButton(1)
    assert(button.shown and button.alpha == 1, "available narration has an always-visible play button")
    equal(button.point[1], "CENTER", "play icon stays centered beside the other controls")
    button.scripts.OnClick(button)
    local sound = assert(voice.QuestOverlayUI.questPlayButtons[1].soundData)
    local stopped = assert(sound.stopCallback)
    s.profile.trackerShowPlayButtons = false
    button.scripts.OnClick(button)
    assert(playing[sound], "disabled tracker playback cannot stop existing VoiceOver audio")
    button:SetPlayButton(1)
    assert(not button.shown and button.mode == nil, "disabling playback clears the pooled control")
    s.profile.trackerShowPlayButtons = true
    button:SetPlayButton(1)
    assert(button.shown and button.texture:find("Stop", 1, true), "reenabling playback restores the queued audio state")
    local otherSound = {}
    voice.QuestOverlayUI.questPlayButtons[2].soundData = otherSound
    line.Quest = {Id = 2}
    button:SetPlayButton(2)
    local currentTexture = button.texture
    stopped()
    equal(voice.QuestOverlayUI.questPlayButtons[1].soundData, nil, "stopping clears its original quest's sound")
    equal(voice.QuestOverlayUI.questPlayButtons[2].soundData, otherSound, "stopping never clears a reused row's new quest")
    equal(updated[#updated], 1, "stop callback updates the original quest overlay")
    equal(button.texture, currentTexture, "a reused row keeps its current quest's play texture")
    voice.QuestOverlayUI.questPlayButtons[1].soundData = nil
    line.Quest = {Id = 1}
    button:SetPlayButton(1)
    button.scripts.OnClick(button)
    stopped = assert(voice.QuestOverlayUI.questPlayButtons[1].soundData.stopCallback)
    line.Quest = nil
    button:SetPlayButton(nil)
    local ok, message = pcall(stopped)
    assert(ok, "a stopped narration tolerates a released row: " .. tostring(message))
    assert(not button.shown, "released narration row stays hidden")
    line.Quest = {Id = 3}
    button:SetPlayButton(3)
    assert(button.shown and button.alpha < 1, "quests without audio keep a dimmed play slot")
    groups = groups + 1
end
do
    local s = setup()
    local pool, rows = s.modules.TrackerLinePool, {}
    local hovered
    local tooltipHides, tooltipShows, tooltipLine = 0, 0
    s.modules.TrackerQuestTooltip = {
        Hide = function() tooltipHides = tooltipHides + 1; tooltipLine = nil end,
        Show = function(line) tooltipShows = tooltipShows + 1; tooltipLine = line end,
    }
    local methods = {}
    function methods:IsVisible() return self.visible ~= false end
    function methods:GetParent() return self.parent end
    function methods:SetAlpha(alpha) self.alpha = alpha end
    local function frame(parent)
        return setmetatable({parent = parent}, {__index = methods})
    end
    local quest, otherQuest = {}, {}
    for i = 1, 3 do
        local row = frame({})
        row.Quest = i <= 2 and quest or otherQuest
        row.expandZone = frame(row)
        row.expandZone.visible = false
        row.statusIcon, row.playButton, row.expandQuest = frame(row), frame(row), frame(row)
        rows[i] = row
    end
    rows[1].button = frame(rows[1])
    pool.GetHighestIndex = function() return #rows end
    s.env.MouseIsOver = function(frame) return frame == hovered end
    s.env.rows = rows
    local source = read("Modules/Tracker/TrackerLinePool.lua")
    local first = assert(source:find("TrackerLinePool.OnHighlightEnter = function", 1, true))
    local last = assert(source:find("TrackerLinePool.SetMode = function", first, true))
    compile("local TrackerLinePool = QuestieLoader:ImportModule('TrackerLinePool')\n"
        .. "local TrackerQuestTooltip = QuestieLoader:ImportModule('TrackerQuestTooltip')\nlocal linePool = rows\n"
        .. source:sub(first, last - 1), "production tracker highlight lifecycle", s.env)()
    hovered = rows[1].button
    pool.RefreshHighlight()
    equal(rows[1].alpha, 1, "hovered item highlights its quest title")
    equal(rows[2].alpha, 1, "hovered item highlights its quest objectives")
    equal(rows[3].alpha, 0.5, "hovered item dims unrelated quests")
    equal(tooltipLine, rows[1], "hover restoration passes the current row to tooltip validation")
    equal(tooltipHides, 1, "redraw clears the previous tooltip first")
    rows[1].Quest = otherQuest
    pool.RefreshHighlight()
    equal(rows[2].alpha, 0.5, "redraw clears the previous quest highlight under a stationary cursor")
    equal(rows[3].alpha, 1, "redraw highlights the reused row's current quest")
    equal(tooltipLine.Quest, otherQuest, "tooltip refresh follows the reused row's current record")
    rows[1].button.parent = {}
    pool.RefreshHighlight()
    equal(rows[2].alpha, 1, "detached secure items cannot preserve a stale highlight")
    hovered = nil
    local previousTooltipShows = tooltipShows
    pool.RefreshHighlight()
    equal(rows[3].alpha, 1, "leaving the tracker clears dimming")
    equal(tooltipLine, nil, "leaving all rows clears the hovered tooltip")
    equal(tooltipShows, previousTooltipShows, "unhovered redraw does not start a new tooltip")
    groups = groups + 1
end
print("Tracker button layout: " .. groups .. " groups passed")
