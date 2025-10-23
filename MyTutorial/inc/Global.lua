---@type Mq
local mq = require("mq")
---@type Note
local Note = require("ext.Note")
---@type Stack
local Stack = require("ext.Stack")

---@class Location
---@field Y number
---@field X number
---@field Z number

---@enum DebuggingRanks
DebuggingRanks = {
	None = 0,
	Basic = 1,
	Task = 2,
	Detail = 3,
	Function = 4,
	Deep = 5,
}

---@type DebuggingRanks
DebugLevel = DebuggingRanks.Basic
ChatTitle = ""
---@type string
TaskName = ""
CallStack = Stack:Create()

function Delay(timeout, condition)
    if ((not timeout and not condition) or type(timeout) ~= "number") then
        return
    end

    if (not condition) then
        mq.delay(timeout)

        return
    end

    local predicate = function ()
        mq.doevents()

        return condition()
    end

    mq.delay(timeout, predicate)
end

---@param minLevel DebuggingRanks
---@param message string
---@vararg any
function PrintDebugMessage(minLevel, message, ...)
	if (DebugLevel >= minLevel) then
		Note.Info(message, ...)
	end
end

function SetChatTitle(text)
	mq.cmd.setchattitle(text)
	ChatTitle = text
end

---@param minLevel? DebuggingRanks
function FunctionEnter(minLevel)
	if (not minLevel) then
		minLevel = DebuggingRanks.Function
	end

	local callerName = debug.getinfo(2, "n").name
	PrintDebugMessage(minLevel, "\at%s enter", callerName)
	CallStack:push(callerName)

	if (minLevel == DebuggingRanks.Task) then
		TaskName = callerName
	end
end

---@param minLevel? DebuggingRanks
function FunctionDepart(minLevel)
	if (not minLevel) then
		minLevel = DebuggingRanks.Function
	end

	local callerName = debug.getinfo(2, "n").name
	PrintDebugMessage(minLevel, "\at%s depart", callerName)
	CallStack:pop()

	if (minLevel == DebuggingRanks.Task) then
		TaskName = ""
	end
end
