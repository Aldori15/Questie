---@class utf8
local utf8 = QuestieLoader:CreateModule("utf8")

-- Chinese characters are multiple bytes in Lua 5.1 strings. These helpers keep
-- wrapping code from splitting one glyph in the middle.
local _CHARPAT = "[%z\1-\127\194-\244][\128-\191]*"

local function LowerCodepoint(codepoint)
    if (codepoint >= 0xC0 and codepoint <= 0xD6) or (codepoint >= 0xD8 and codepoint <= 0xDE)
        or (codepoint >= 0x391 and codepoint <= 0x3A1) or (codepoint >= 0x3A3 and codepoint <= 0x3AB)
        or (codepoint >= 0x410 and codepoint <= 0x42F) or (codepoint >= 0xFF21 and codepoint <= 0xFF3A) then
        return codepoint + 0x20
    elseif codepoint >= 0x400 and codepoint <= 0x40F then
        return codepoint + 0x50
    elseif codepoint == 0x1E9E then
        return 0xDF
    elseif codepoint == 0x178 then
        return 0xFF
    elseif ((codepoint >= 0x100 and codepoint <= 0x12F) or (codepoint >= 0x14A and codepoint <= 0x177)
        or (codepoint >= 0x460 and codepoint <= 0x480)) and codepoint % 2 == 0 then
        return codepoint + 1
    elseif ((codepoint >= 0x139 and codepoint <= 0x148) or (codepoint >= 0x179 and codepoint <= 0x17E))
        and codepoint % 2 == 1 then
        return codepoint + 1
    end
    return codepoint
end

---Case-insensitive matching for Questie's localized strings on Lua 5.1.
function utf8.lower(text)
    text = text:gsub("[A-Z]", string.lower)
    return (text:gsub("[\194-\239][\128-\191]+", function(char)
        local first, second, third = char:byte(1, 3)
        local codepoint
        if #char == 2 and first < 0xE0 then
            codepoint = (first - 0xC0) * 0x40 + second - 0x80
        elseif #char == 3 and first >= 0xE0 then
            codepoint = (first - 0xE0) * 0x1000 + (second - 0x80) * 0x40 + third - 0x80
        else
            return char
        end
        local lower = LowerCodepoint(codepoint)
        if lower == codepoint then return char end
        if lower < 0x800 then
            return string.char(0xC0 + math.floor(lower / 0x40), 0x80 + lower % 0x40)
        end
        return string.char(0xE0 + math.floor(lower / 0x1000),
            0x80 + math.floor(lower / 0x40) % 0x40, 0x80 + lower % 0x40)
    end))
end

---UTF-8 safe substring function that respects character boundaries.
---@param s string UTF-8 encoded string
---@param i number Start index in characters (1 = first char; negative = from end)
---@param j number? End index in characters (inclusive). If nil, defaults to last character.
---@return string substring
function utf8.sub(s, i, j)
    -- 1) collect byte-offsets of each UTF-8 character
    local offsets = {}
    for pos in s:gmatch("()" .. _CHARPAT) do
        offsets[#offsets + 1] = pos
    end

    local n = #offsets
    if n == 0 then return "" end

    -- 2) handle defaults & negative indices
    if not j then j = -1 end
    if i < 0 then i = n + 1 + i end
    if j < 0 then j = n + 1 + j end

    -- 3) clamp to [1..n]
    if i < 1 then i = 1 end
    if j > n then j = n end
    if i > j then return "" end

    -- 4) byte positions for slicing
    local startByte = offsets[i]
    local endByte = offsets[j + 1] and (offsets[j + 1] - 1) or #s

    return s:sub(startByte, endByte)
end

---Returns the number of UTF-8 characters in a string.
---@param s string UTF-8 encoded string
---@return number count
function utf8.strlen(s)
    local count = 0
    for _ in s:gmatch(_CHARPAT) do
        count = count + 1
    end

    return count
end
