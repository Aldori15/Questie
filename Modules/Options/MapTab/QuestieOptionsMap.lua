---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions");
---@type QuestieOptionsDefaults
local QuestieOptionsDefaults = QuestieLoader:ImportModule("QuestieOptionsDefaults");
---@type QuestieOptionsUtils
local QuestieOptionsUtils = QuestieLoader:ImportModule("QuestieOptionsUtils");
---@type QuestieFramePool
local QuestieFramePool = QuestieLoader:ImportModule("QuestieFramePool");
---@type QuestieCoords
local QuestieCoords = QuestieLoader:ImportModule("QuestieCoords");
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap");
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type WorldMapButton
local WorldMapButton = QuestieLoader:ImportModule("WorldMapButton")

QuestieOptions.tabs.map = {...}
local optionsDefaults = QuestieOptionsDefaults:Load()


function QuestieOptions.tabs.map:Initialize()
    return {
        name = function() return l10n('Map'); end,
        type = "group",
        order = 5.5,
        args = {
            worldmap_button_header = {
                type = "header",
                order = 1,
                name = function() return l10n('World Map Button'); end,
            },
            mapShowHideEnabled = {
                type = "toggle",
                order = 2,
                name = function() return l10n('Show Questie Map Button'); end,
                desc = function() return l10n('Enable or disable the Show/Hide Questie Button on Map (May fix some Map Addon interactions).'); end,
                width = 1.55,
                get = function(info) return QuestieOptions:GetProfileValue(info); end,
                set = function(info, value)
                    QuestieOptions:SetProfileValue(info, value)
                    WorldMapButton.Toggle(value)
                end,
            },
            worldMapButtonPosition = {
                type = "select",
                order = 3,
                style = "dropdown",
                name = function() return l10n('Button Position'); end,
                desc = function() return l10n('Choose which corner of the world map the Questie button appears in. If that corner is occupied by another button, the Questie button will shift inward automatically.'); end,
                disabled = function() return not Questie.db.profile.mapShowHideEnabled end,
                values = {
                    TOPRIGHT    = l10n('Top Right'),
                    TOPLEFT     = l10n('Top Left'),
                    BOTTOMRIGHT = l10n('Bottom Right'),
                    BOTTOMLEFT  = l10n('Bottom Left'),
                },
                get = function() return Questie.db.profile.worldMapButtonPosition end,
                set = function(_, value)
                    Questie.db.profile.worldMapButtonPosition = value
                    WorldMapButton.RefreshLayout()
                end,
            },
            coordinates_header = {
                type = "header",
                order = 4,
                name = function() return l10n('Map Coordinates'); end,
            },
            mapCoordinatesEnabled = {
                type = "toggle",
                order = 5,
                name = function() return l10n('Show Map Coordinates'); end,
                desc = function() return l10n("Place the Player's coordinates and Cursor's coordinates on the Map's title."); end,
                width = 1.55,
                get = function(info) return QuestieOptions:GetProfileValue(info); end,
                set = function(info, value)
                    QuestieOptions:SetProfileValue(info, value)
                    if not value then
                        QuestieCoords:ResetMapText();
                        QuestieCoords:ResetMiniWorldMapText();
                    end
                end,
            },
            showManualTooltipCoordinates = {
                type = "toggle",
                order = 6,
                name = function() return l10n('Show Tooltip Coordinates'); end,
                desc = function() return l10n('When enabled, map notes will include coordinates in their tooltip.'); end,
                width = 1.55,
                get = function(info) return QuestieOptions:GetProfileValue(info); end,
                set = function(info, value)
                    QuestieOptions:SetProfileValue(info, value)
                end,
            },
            mapCoordinatePrecision = {
                type = "range",
                order = 6,
                name = function() return l10n('Map Coordinates Decimal Precision'); end,
                desc = function() return l10n('How many decimals to include in the precision on the Map for Player and Cursor coordinates.\n(Default: %s)', optionsDefaults.profile.mapCoordinatePrecision); end,
                width = 1.4,
                min = 0,
                max = 5,
                step = 1,
                disabled = function() return not Questie.db.profile.mapCoordinatesEnabled end,
                get = function(info) return QuestieOptions:GetProfileValue(info); end,
                set = function(info, value)
                    QuestieOptions:SetProfileValue(info, value)
                end,
            },
            waypoint_lines_header = {
                type = "header",
                order = 7,
                name = function() return l10n('Waypoint Lines'); end,
            },
            showWaypointLines = {
                type = "toggle",
                order = 8,
                name = function() return l10n('Show Waypoint Lines'); end,
                desc = function() return l10n('Draw path lines for NPCs and other map waypoints.'); end,
                width = 1.55,
                get = function(info) return QuestieOptions:GetProfileValue(info); end,
                set = function(info, value)
                    QuestieOptions:SetProfileValue(info, value)
                    QuestieMap:SetWaypointLinesVisible(value)
                end,
            },
        },
    }
end
