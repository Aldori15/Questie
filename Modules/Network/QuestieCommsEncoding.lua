---@class QuestieCommsEncoding
local QuestieCommsEncoding = QuestieLoader:CreateModule("QuestieCommsEncoding")

local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift
local floor = math.floor
local byte = string.byte
local char = string.char
local sub = string.sub
local concat = table.concat

-- Keep the marker inside the Base64 alphabet so servers that filter addon
-- message payloads do not reject the transport envelope itself.
local TRANSPORT_MARKER = "QSTB64"
local TRANSPORT_MARKER_LENGTH = string.len(TRANSPORT_MARKER)
local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_ENCODE = {}
local BASE64_DECODE = {}

for index = 1, string.len(BASE64_ALPHABET) do
    local character = sub(BASE64_ALPHABET, index, index)
    BASE64_ENCODE[index - 1] = character
    BASE64_DECODE[byte(character)] = index - 1
end

local function _Base64Encode(data)
    local encoded = {}
    local encodedIndex = 1
    local dataLength = string.len(data)

    for index = 1, dataLength, 3 do
        local first = byte(data, index)
        local second = byte(data, index + 1)
        local third = byte(data, index + 2)
        local value = lshift(first, 16) + lshift(second or 0, 8) + (third or 0)

        encoded[encodedIndex] = BASE64_ENCODE[band(rshift(value, 18), 0x3F)]
        encoded[encodedIndex + 1] = BASE64_ENCODE[band(rshift(value, 12), 0x3F)]
        encoded[encodedIndex + 2] = second and BASE64_ENCODE[band(rshift(value, 6), 0x3F)] or "="
        encoded[encodedIndex + 3] = third and BASE64_ENCODE[band(value, 0x3F)] or "="
        encodedIndex = encodedIndex + 4
    end

    return concat(encoded)
end

local function _Base64Decode(data)
    local dataLength = string.len(data)
    if dataLength == 0 then
        return ""
    end
    if dataLength % 4 ~= 0 then
        return nil, "invalid Base64 length"
    end

    local decoded = {}
    local decodedIndex = 1

    for index = 1, dataLength, 4 do
        local firstChar, secondChar, thirdChar, fourthChar = byte(data, index, index + 3)
        local thirdIsPadding = thirdChar == 61 -- "="
        local fourthIsPadding = fourthChar == 61
        local isLastBlock = index + 3 == dataLength
        local first = BASE64_DECODE[firstChar]
        local second = BASE64_DECODE[secondChar]
        local third = thirdIsPadding and 0 or BASE64_DECODE[thirdChar]
        local fourth = fourthIsPadding and 0 or BASE64_DECODE[fourthChar]

        if first == nil or second == nil or third == nil or fourth == nil then
            return nil, "invalid Base64 character"
        end
        if thirdIsPadding and (not fourthIsPadding or not isLastBlock) then
            return nil, "invalid Base64 padding"
        end
        if fourthIsPadding and not isLastBlock then
            return nil, "invalid Base64 padding"
        end
        if thirdIsPadding and band(second, 0x0F) ~= 0 then
            return nil, "non-canonical Base64 padding"
        end
        if fourthIsPadding and not thirdIsPadding and band(third, 0x03) ~= 0 then
            return nil, "non-canonical Base64 padding"
        end

        local value = lshift(first, 18) + lshift(second, 12) + lshift(third, 6) + fourth
        decoded[decodedIndex] = char(band(rshift(value, 16), 0xFF))
        decodedIndex = decodedIndex + 1

        if not thirdIsPadding then
            decoded[decodedIndex] = char(band(rshift(value, 8), 0xFF))
            decodedIndex = decodedIndex + 1
        end
        if not fourthIsPadding then
            decoded[decodedIndex] = char(band(value, 0xFF))
            decodedIndex = decodedIndex + 1
        end
    end

    return concat(decoded)
end

function QuestieCommsEncoding:Encode(data)
    return TRANSPORT_MARKER .. _Base64Encode(data)
end

function QuestieCommsEncoding:Decode(data)
    if sub(data, 1, TRANSPORT_MARKER_LENGTH) ~= TRANSPORT_MARKER then
        return data
    end

    return _Base64Decode(sub(data, TRANSPORT_MARKER_LENGTH + 1))
end

function QuestieCommsEncoding:GetEncodedLength(data)
    return TRANSPORT_MARKER_LENGTH + floor((string.len(data) + 2) / 3) * 4
end

