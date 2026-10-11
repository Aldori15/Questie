QuestieLoader:StampLoadBoundary("Modules/VersionCheck.lua")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer

if Questie then
    C_Timer.After(4, function()
        error("ERROR!! -> Questie already loaded! Please only have one Questie installed!")
    end);
    error("ERROR!! -> Questie already loaded! Please only have one Questie installed!")
end

--Initialized below
---@class Questie : AceAddon, AceConsole-3.0, AceEvent-3.0, AceTimer-3.0, AceComm-3.0, AceBucket-3.0
Questie = LibStub("AceAddon-3.0"):NewAddon("Questie", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceComm-3.0", "AceBucket-3.0")

-- preinit placeholder to stop tukui crashing from literally force-removing one of our features no matter what users select in the config ui
Questie.db = {profile={minimap={hide=false}}}

-- prevent multiple warnings for the same ID, not sure the best place to put this
Questie._sessionWarnings = {}
