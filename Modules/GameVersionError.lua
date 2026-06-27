-- No timers or other dependencies here. This file is loaded
-- by Questie.toc when WoW cannot load Questie-335.toc.

-- StaticPopup has very limited width, so text is split to many lines.
local msg = {
    "Questie-335 did not load correctly.",
    "The AddOns folder name is likely wrong.",

    "Rename the folder to Questie-335",
    "so WoW loads Questie-335.toc.",

    "Do not rename Questie-335.toc",
    "to Questie.toc.",
}

if StaticPopupDialogs and StaticPopup_Show then
    StaticPopupDialogs["QUESTIE_VERSION_ERROR"] = {
        text = "|cffff0000ERROR|r\n" .. msg[1] .. "\n" .. msg[2] .. "\n\n" .. msg[3] .. "\n" .. msg[4] .. "\n\n" .. msg[5] .. "\n" .. msg[6],
        button1 = OKAY or "OK",
        hasEditBox = false,
        whileDead = true
    }

    StaticPopup_Show("QUESTIE_VERSION_ERROR")
end

if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("---------------------------------")
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ERROR|r: |cff42f5ad" .. msg[1] .. " " .. msg[2] .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ERROR|r: |cff42f5ad" .. msg[3] .. " " .. msg[4] .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ERROR|r: |cff42f5ad" .. msg[5] .. " " .. msg[6] .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("---------------------------------")
end
