---@type QuestieStream
local QuestieStream = QuestieLoader:ImportModule("QuestieStreamLib")

--[[
    xpcall wrapper implementation
]]
local xpcall = xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
	local code = [[
		local xpcall, errorhandler = ...
		local method, ARGS
		local function call() return method(ARGS) end

		local function dispatch(func, eh, ...)
			 method = func
			 if not method then return end
			 ARGS = ...
			 return xpcall(call, eh or errorhandler)
		end

		return dispatch
	]]

	local ARGS = {}
	for i = 1, argCount do ARGS[i] = "arg"..i end
	code = code:gsub("ARGS", table.concat(ARGS, ", "))
	return assert(loadstring(code, "safecall Dispatcher["..argCount.."]"))(xpcall, errorhandler)
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

Dispatchers[0] = function(func, eh)
	return xpcall(func, eh or errorhandler)
end

function QuestieCompat.xpcall(func, eh, ...)
    if type(func) == "function" then
		return Dispatchers[select('#', ...)](func, eh, ...)
	end
end

--[[
    It seems that the table size is capped in 3.3.5, with a maximum of 524,288 entries.
    For instance, this code triggers an error message: 'memory allocation error: block too big.

    local t = {}
	for i=1, 524289 do
		t[i] = true
	end

    Spliting the table into multiple subtables should do the trick.
]]

local stringchar = string.char
local MAX_TABLE_SIZE = 524288

function QuestieCompat._writeByte(self, val)
	local subIndex = math.ceil(self._pointer / MAX_TABLE_SIZE)
	local index = self._pointer - (subIndex - 1) * MAX_TABLE_SIZE

	self._bin[subIndex] = self._bin[subIndex] or {}
	self._bin[subIndex][index] = stringchar(val)

    self._pointer = self._pointer + 1
end

function QuestieCompat._readByte(self)
	local subIndex = math.ceil(self._pointer / MAX_TABLE_SIZE)
	local index = self._pointer - (subIndex - 1) * MAX_TABLE_SIZE

    self._pointer = self._pointer + 1

	return self._bin[subIndex][index]
end

function QuestieCompat.Save(self)
	local result = ""
	for i=1, #self._bin do
		result = result .. table.concat(self._bin[i])
	end
	return result
end

function QuestieCompat.RegisterStreamCompatibility()
    QuestieStream._writeByte = QuestieCompat._writeByte
    QuestieStream._readByte = QuestieCompat._readByte
    QuestieStream.Save = QuestieCompat.Save
end
