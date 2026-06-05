---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

-- No timeres or other fancy stuff as 1.12 client is very limited.

-- StaticPopup has very limited width, so text is split to many lines.
local msg = {
    l10n("Questie-335 did not load correctly."),
    l10n("The AddOns folder name is likely wrong."),

    l10n("Rename the folder to Questie-335"),
    l10n("so WoW loads Questie-335.toc."),

    l10n("Do not rename Questie-335.toc"),
    l10n("to Questie.toc."),
}

StaticPopupDialogs["QUESTIE_VERSION_ERROR"] = {
    text = "|cffff0000ERROR|r\n" .. msg[1] .. "\n" .. msg[2] .. "\n\n" .. msg[3] .. "\n" .. msg[4] .. "\n\n" .. msg[5] .. "\n" .. msg[6],
    button2 = "OK",
    hasEditBox = false,
    whileDead = true
}

StaticPopup_Show("QUESTIE_VERSION_ERROR")

DEFAULT_CHAT_FRAME:AddMessage("---------------------------------")
DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ERROR|r: |cff42f5ad" .. msg[1] .. " " .. msg[2] .. "|r")
DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ERROR|r: |cff42f5ad" .. msg[3] .. " " .. msg[4] .. "|r")
DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ERROR|r: |cff42f5ad" .. msg[5] .. " " .. msg[6] .. "|r")
DEFAULT_CHAT_FRAME:AddMessage("---------------------------------")
