---@class utf8
local utf8 = QuestieLoader:CreateModule("utf8")

-- Chinese characters are multiple bytes in Lua 5.1 strings. These helpers keep
-- wrapping code from splitting one glyph in the middle.
local _CHARPAT = "[%z\1-\127\194-\244][\128-\191]*"

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
