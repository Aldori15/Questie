---@class QuestieOptions
local QuestieOptions = QuestieLoader:CreateModule("QuestieOptions");
local QuestieOptionsEngine = QuestieLoader:ImportModule("QuestieOptionsEngine")

QuestieOptions.tabs = { ... }

StaticPopupDialogs["QUESTIE_RELOAD"] = {
    text = "Changes you have made require a UI reload",
    button1 = 'Reload UI',
    button2 = CANCEL,
    OnAccept = function()
        ReloadUI()
    end,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

-- Forward declaration
local _CreateOptionsTable

---Initializes option definitions and the settings engine.
function QuestieOptions:Initialize()
    Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieOptions]: Initializing...")

    local optionsTable = _CreateOptionsTable()

    coroutine.yield()

    LibStub("AceConfig-3.0"):RegisterOptionsTable("Questie", optionsTable)

    coroutine.yield()

    QuestieOptionsEngine:Initialize(optionsTable)

    Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieOptions]: Initialization done")
end

-- Generic function to hide the config frame.
function QuestieOptions:HideFrame()
    QuestieOptionsEngine:HideFrame()
end

-- Open the configuration window
function QuestieOptions:OpenConfigWindow()
    QuestieOptionsEngine:ToggleConfigWindow()
end

function QuestieOptions:RefreshIfShown()
    QuestieOptionsEngine:RefreshIfShown()
end

-- get option value
function QuestieOptions:GetProfileValue(info)
    return Questie.db.profile[info[#info]]
end

-- set option value
function QuestieOptions:SetProfileValue(info, value)
    if debug and Questie.db.profile[info[#info]] ~= value then
        Questie.Debug(Questie.DEBUG_SPAM, "DEBUG: global option", info[#info], "changed from '" .. tostring(Questie.db.profile[info[#info]]) .. "' to '" .. tostring(value) .. "'")
    end
    Questie.db.profile[info[#info]] = value
end

---@return table
_CreateOptionsTable = function()
    local general_tab = QuestieOptions.tabs.general:Initialize()
    coroutine.yield()
    local map_tab = QuestieOptions.tabs.map:Initialize()
    coroutine.yield()
    local icons_tab = QuestieOptions.tabs.icons:Initialize()
    coroutine.yield()
    local tracker_tab = QuestieOptions.tabs.tracker:Initialize()
    coroutine.yield()
    local auto_tab = QuestieOptions.tabs.auto:Initialize()
    coroutine.yield()
    local nameplate_tab = QuestieOptions.tabs.nameplate:Initialize()
    coroutine.yield()
    local advanced_tab = QuestieOptions.tabs.advanced:Initialize()
    coroutine.yield()
    return {
        name = "Questie-335",
        handler = Questie,
        type = "group",
        childGroups = "tab",
        args = {
            general_tab = general_tab,
            map_tab = map_tab,
            icons_tab = icons_tab,
            tracker_tab = tracker_tab,
            auto_tab = auto_tab,
            nameplate_tab = nameplate_tab,
            advanced_tab = advanced_tab,
            profiles_tab = LibStub("AceDBOptions-3.0"):GetOptionsTable(Questie.db)
        }
    }
end
