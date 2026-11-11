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
local QuestieWaypoints = QuestieLoader:ImportModule("QuestieWaypoints")

QuestieOptions.tabs.map = {...}
local optionsDefaults = QuestieOptionsDefaults:Load()

local function get(info) return QuestieOptions:GetProfileValue(info) end
local function set(info, value)
    QuestieOptions:SetProfileValue(info, value)
    QuestieWaypoints.Refresh()
end
local function getColor(info) return unpack(Questie.db.profile[info[#info]]) end
local function setColor(info, r, g, b, a)
    Questie.db.profile[info[#info]] = {r, g, b, a}
    QuestieWaypoints.Refresh()
end


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
                desc = function() return l10n("Display the Player's and Cursor's coordinates on the world map."); end,
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
            waypointMinimapEnabled = {
                type = "toggle", order = 9, width = 1.55,
                name = function() return l10n("Enable Minimap Waypoints") end,
                desc = function() return l10n("Draws NPC patrol paths on the minimap. Minimap icons must be enabled too.") end,
                get = get, set = set,
            },
            waypointWidth = {
                type = "range", order = 10, width = 1.4, min = 1, max = 10, step = 0.5,
                name = function() return l10n("Line width") end,
                get = get, set = set,
            },
            waypointOpacity = {
                type = "range", order = 11, width = 1.4, min = 0.1, max = 2, step = 0.05, isPercent = true,
                name = function() return l10n("Line opacity") end,
                desc = function() return l10n("Scales patrol opacity in addition to each color's opacity.") end,
                get = get, set = set,
            },
            waypointHighlight = {
                type = "toggle", order = 12, width = "full",
                name = function() return l10n("Highlight patrol paths on hover") end,
                get = get, set = set,
            },
            waypointColor = {
                type = "color", order = 13, hasAlpha = true,
                name = function() return l10n("Patrol color") end,
                get = getColor, set = setColor,
            },
            waypointHostileColor = {
                type = "color", order = 14, hasAlpha = true,
                name = function() return l10n("Hostile patrol color") end,
                get = getColor, set = setColor,
            },
            waypointHighlightColor = {
                type = "color", order = 15, hasAlpha = true,
                name = function() return l10n("Highlight color") end,
                get = getColor, set = setColor,
            },
            waypointSmoothing = {
                type = "range", order = 16, width = "full", min = 0, max = 2, step = 0.05,
                name = function() return l10n("Waypoint smoothing") end,
                desc = function() return l10n("Rounds patrol corners. Zero keeps sharp corners; higher values can cut farther from the true route.") end,
                get = get, set = set,
            },
        },
    }
end
