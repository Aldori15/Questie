-- WDM-patch N compatibility for the Blood Elf / Draenei starting zones.
--
-- Patch N (https://github.com/Trimitor/WDM-patch) adds dedicated zoom-maps
-- for Sunstrider Isle and Ammen Vale with WorldMapArea IDs 894 and 895.
-- Questie's bundled UiMapData expects the Cataclysm-retail IDs 6455 / 6456
-- and therefore does not recognise the patched-DBC entries:
-- GetCurrentUiMapID falls through to the cosmic map (946) and no pins are
-- drawn even though the textures ("SunstriderIsleStart" / "AmmenValeStart")
-- render correctly.
--
-- Fix: extend QuestieCompat so the patched mapIDs resolve to the matching
-- UiMaps (467 = Sunstrider Isle, 468 = Ammen Vale). Both UiMaps already
-- carry the correct bounds in QuestieCompat.UiMapData, so Questie's normal
-- pin pipeline handles the rest.
--
-- The override is a pure whitelist: if GetCurrentMapAreaID() does not
-- return 894 or 895 (i.e. WDM-patch N is not installed), behaviour is
-- completely unchanged.

local WDM_MAPID_TO_UIMAP = {
    [894] = 467, -- Sunstrider Isle (parent: Eversong Woods, UiMap 1941)
    [895] = 468, -- Ammen Vale      (parent: Azuremyst Isle, UiMap 1943)
}

local function Install()
    if type(QuestieCompat) ~= "table" or type(QuestieCompat.GetCurrentUiMapID) ~= "function" then
        return false
    end

    local origGetCurrentUiMapID = QuestieCompat.GetCurrentUiMapID

    QuestieCompat.GetCurrentUiMapID = function(...)
        if type(GetCurrentMapAreaID) == "function" then
            local mapped = WDM_MAPID_TO_UIMAP[GetCurrentMapAreaID()]
            if mapped then return mapped end
        end
        return origGetCurrentUiMapID(...)
    end

    return true
end

-- QuestieCompat.GetCurrentUiMapID is created during Compat's own ADDON_LOADED.
-- PLAYER_LOGIN fires strictly after every addon's ADDON_LOADED has run, so it
-- is the safest point to wrap the function.
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_LOGIN")
    Install()
end)