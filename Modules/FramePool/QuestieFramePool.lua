---@class QuestieFramePool
local QuestieFramePool = QuestieLoader:CreateModule("QuestieFramePool")
-------------------------
--Import modules.
-------------------------
---@type QuestieFrame
local QuestieFrame = QuestieLoader:ImportModule("QuestieFrame")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type MapIconTooltip
local MapIconTooltip = QuestieLoader:ImportModule("MapIconTooltip")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

local HBDPins = QuestieCompat.HBDPins or LibStub("HereBeDragonsQuestie-Pins-2.0")

-- set pins parent to QuestieFrameGroup for easier compatibility with other addons
-- cant use this because it fucks with everything, but we gotta stick with HereBeDragonsQuestie anyway
HBDPins.MinimapGroup = CreateFrame("Frame", "QuestieFrameGroup", Minimap)

local numberOfFrames = 0

---@type IconFrame[]
local unusedFrames = {}

--- Not continuously indexed with numbers, treat it as a key
---@type table<number, IconFrame>
local usedFrames = {};

local _ReinitFrame

StaticPopupDialogs["QUESTIE_CONFIRMHIDE"] = {
    text = "", -- set before showing
    questID = 0, -- set before showing
    button1 = l10n("Yes"),
    button2 = l10n("No"),
    OnAccept = function()
        QuestieQuest:HideQuest(StaticPopupDialogs["QUESTIE_CONFIRMHIDE"].questID)
    end,
    SetQuest = function(self, id)
        self.questID = id
        self.text = l10n("Are you sure you want to hide the quest '%s'?\nIf this quest isn't actually available, please report it to us!", QuestieLib:GetColoredQuestName(id, Questie.db.profile.enableTooltipsQuestLevel, false, true))

        -- locale might not be loaded when this is first created (this does happen almost always)
        self.button1 = l10n("Yes")
        self.button2 = l10n("No")
    end,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

-- Global Functions --
---@return IconFrame
function QuestieFramePool:GetFrame()
    --Questie.Debug(Questie.DEBUG_SPAM, "[QuestieFramePool:GetFrame]")

    ---@type IconFrame
    local frame = tremove(unusedFrames)
    if (not frame) then
        numberOfFrames = numberOfFrames + 1

        frame = QuestieFrame.CreateIconFrame(numberOfFrames, MapIconTooltip.Show)

        if numberOfFrames > 5000 then
            Questie.Debug(Questie.DEBUG_CRITICAL, "[QuestieFramePool] Over 5000 frames... maybe there is a leak?", numberOfFrames)
        end
    end

    _ReinitFrame(frame)

    usedFrames[frame.frameId] = frame
    return frame
end

function QuestieFramePool:UpdateGlowConfig(mini, mode)
    if mode then
        for _, icon in pairs(usedFrames) do
            if ((mini and icon.miniMapIcon) or (not mini and not icon.miniMapIcon)) and icon:IsShown() then
                icon:GetScript("OnShow")(icon) -- forces a glow update
            end
        end
    else
        for _, icon in pairs(usedFrames) do
            if (mini and icon.miniMapIcon) or (not mini and not icon.miniMapIcon) then
                icon.glowTexture:Hide()
            end
        end
    end
end

function QuestieFramePool:UpdateColorConfig(mini, enable)
    if enable then
        for _, icon in pairs(usedFrames) do
            if (mini and icon.miniMapIcon) or (not mini and not icon.miniMapIcon) then
                local colors = {1, 1, 1}
                if icon.data.IconColor ~= nil then
                    colors = icon.data.IconColor
                end
                icon.texture:SetVertexColor(colors[1], colors[2], colors[3], 1)
            end
        end
    else
        for _, icon in pairs(usedFrames) do
            if (mini and icon.miniMapIcon) or (not mini and not icon.miniMapIcon) then
                icon.texture:SetVertexColor(1, 1, 1, 1)
            end
        end
    end
end

---Unload a frame and return it to the pool.
---@param frame IconFrame
function QuestieFramePool:UnloadFrame(frame)
    if (not usedFrames[frame.frameId]) then
        -- Already pooled; another unload would mark the next icon using this frame for removal.
        return
    end

    frame:Unload()

    -- If the frame was queued for drawing but not yet processed by QuestieMap.ProcessQueue, Unload() defers and sets _needsUnload=true
    -- instead of doing a full cleanup. In that case we must not recycle yet: the draw call still holds a reference to this frame,
    -- and recycling now would allow GetFrame() to hand it out again before ProcessQueue consumes the stale draw call, causing it
    -- to draw the wrong frame. ProcessQueue detects _needsUnload after the HBDPins add and calls Unload() + recycles directly once it
    -- is safe to do so.
    if (not frame._needsUnload) then
        usedFrames[frame.frameId] = nil
        tinsert(unusedFrames, frame)
    end
end


---@param frame IconFrame @will be modified
_ReinitFrame = function(frame)
    if frame ~= nil and frame.hidden and frame._show ~= nil and frame._hide ~= nil then -- restore state to normal (toggle questie)
        frame.hidden = false
        frame.Show = frame._show;
        frame.Hide = frame._hide;
        frame._show = nil
        frame._hide = nil
    end
    frame.isManualIcon = false
    frame._needsUnload = nil
    frame._loaded = nil
    frame.FadeLogic = nil
    frame.faded = nil
    frame.miniMapIcon = nil

    frame.data = nil
    frame.x = nil;
    frame.y = nil;
    frame.AreaID = nil;
    frame.UiMapID = nil

    frame.texture:SetVertexColor(1, 1, 1, 1)
    frame:SetAlpha(1) -- party objective icons dim the frame to 0.5; reset so recycled frames (e.g. townsfolk) don't inherit it
    frame.shouldBeShowing = nil
    frame.hidden = nil

    if frame.BaseOnShow then
        frame:SetScript("OnShow", frame.BaseOnShow)
    end

    if frame.BaseOnHide then
        frame:SetScript("OnHide", frame.BaseOnHide)
    end
end
