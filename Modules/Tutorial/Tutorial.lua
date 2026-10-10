---@class Tutorial
---@field Initialize function
local Tutorial = QuestieLoader:CreateModule("Tutorial")

function Tutorial.Initialize()
    if GetCVar("questPOI") ~= nil and (not Questie.db.global.tutorialObjectiveTypeChosen) then
        Tutorial.CreateChooseObjectiveTypeFrame()
    end
end
