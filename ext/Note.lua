-- Note.lua by Rouneq
-- Initially based on Write.lua by Knightly

-- Provides logging capabilities to both the MQ console and an external file

---@type OsTime
local time = require('ext.OsTime')

--- The logging severity suppoted by Note
---@alias severityType
---| 'trace'
---| 'debug'
---| 'info'
---| 'warn'
---| 'error'
---| 'fatal'

local _newline = "\r\n"

--- Note Lua Binding
---@class Note
Note = {}

local _version = '1.0'

local logLevels = {
    ['trace']  = { level = 1, color = '\27[36m',  mqcolor = '\at', abbreviation = 'TRACE', },
    ['debug']  = { level = 2, color = '\27[95m',  mqcolor = '\am', abbreviation = 'DEBUG', },
    ['info']   = { level = 3, color = '\27[92m',  mqcolor = '\ag', abbreviation = 'INFO' , },
    ['warn']   = { level = 4, color = '\27[93m',  mqcolor = '\ay', abbreviation = 'WARN' , },
    ['error']  = { level = 5, color = '\27[31m',  mqcolor = '\ao', abbreviation = 'ERROR', },
    ['fatal']  = { level = 6, color = '\27[91m',  mqcolor = '\ar', abbreviation = 'FATAL', },
    ['help']   = { level = 7, color = '\27[97m',  mqcolor = '\aw', abbreviation = 'HELP' , },
}

local luaReservedWords = {
    ['and'] = true,
    ['break'] = true,
    ['do'] = true,
    ['else'] = true,
    ['elseif'] = true,
    ['end'] = true,
    ['false'] = true,
    ['for'] = true,
    ['function'] = true,
    ['if'] = true,
    ['in'] = true,
    ['local'] = true,
    ['nil'] = true,
    ['not'] = true,
    ['or'] = true,
    ['repeat'] = true,
    ['return'] = true,
    ['then'] = true,
    ['true'] = true,
    ['until'] = true,
    ['while'] = true,
}

--- Indicates if log levels should be use colors
---@type boolean
Note.useColors = true
--- Indicates if a timestamp should be added to console output
---@type boolean
Note.useTimestampConsole = false
--- Indicates if a timestamp should be added to log output
---@type boolean
Note.useTimestampLog = true
--- The minimum level at which output is written to the console/log
---@type severityType
Note.logLevel = 'info'
--- A specific prefix added to each output
---@type string|function
Note.prefix = ''
--- Indicates if the output should be written to a log file
---@type boolean
Note.useOutfile = false
--- The path/name of the log file; if one is not defined it will be written to the default logs path for MQ with the name <server>_<character>.log
---@type string
Note.outfile = nil
--- Indicates if the log output should be appended to an existing file (if it exists) or a new file created
---@type boolean
Note.appendToOutfile = true
--- The minimum level at which caller info is included with the output
---@type severityType
Note.callerReportingLevel = 'trace'

local function terminate()
    local mq = package.loaded['mq']

    if mq then
        mq.exit()
    end

    os.exit()
end

local function getPath(filePath)
    if (not filePath or filePath == '') then
        return nil
    end

    return filePath:match("(.*[/\\])")
end

local function checkLogFile()
    local mq = package.loaded['mq']

    if (not Note.outfile or Note.outfile == '') then
        if (mq) then
            Note.outfile = string.format("%s\\%s_%s.log", mq.TLO.MacroQuest.Path('logs'), mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
        else
            Note.outfile = 'output.log'
        end
    else
        local path = getPath(Note.outfile)

        if (not path and mq) then
            Note.outfile = string.format("%s\\%s", mq.TLO.MacroQuest.Path('logs'), Note.outfile)
        end
    end
end

local function writeLog(data)
    local mode = "a"

    if (not Note.appendToOutfile) then
        mode = "w"
    end

    local file, err = io.open(Note.outfile, mode)

    if (file == nil) then
        Note.Raw('Error opening outfile: %s', err)

        return
    end

    file:write(data, "\n")
    file:close()
end

local function getColorStart(logLevel)
    if Note.useColors then
        if package.loaded['mq'] then return logLevels[logLevel].mqcolor end
        return logLevels[logLevel].color
    end

    return ''
end

local function getColorEnd()
    if Note.useColors then
        if package.loaded['mq'] then
            return '\ax'
        end

        return '\27[0m'
    end

    return ''
end

local function getCallerName()
    if (logLevels[Note.logLevel:lower()].level > logLevels[Note.callerReportingLevel].level) then
        return ''
    end

    local callName = 'unknown'
    local callerInfo = debug.getinfo(4,'Sl')

    if callerInfo and callerInfo.short_src ~= nil and callerInfo.short_src ~= '=[C]' then
        callName = string.format('%s::%s', callerInfo.short_src:match("[^\\^/]*.lua$"), callerInfo.currentline)
    end

    return string.format('(%s) ', callName)
end

local function exportstring(s)
    return string.format("%q", s)
end

local function tablePrint(data, indent)
    if not indent then indent = 0 end

    local output = "{" .. _newline
    indent = indent + 2

    for k, v in pairs(data) do
        output = output .. string.rep(" ", indent)

        if (type(k) == "number" or type(k) == "boolean") then
            output = output .. "[" .. tostring(k) .. "] = "
        elseif (type(k) == "string") then
            if (luaReservedWords[k] or tonumber(k)) then
                k = "["..exportstring(k).."]"
            end

            output = output  .. k .. " = "
        end

        if (type(v) == "number" or type(v) == "boolean") then
            output = output .. tostring(v)
        elseif (type(v) == "string") then
            output = output .. "\"" .. v .. "\""
        elseif (type(v) == "table") then
            output = output .. tablePrint(v, indent + 2)
        else
            output = output .. "\"" .. tostring(v) .. "\""
        end

        output = output .. "," .. _newline
    end

    output = output .. string.rep(" ", indent - 2) .. "}"

    return output
end

local function normalizeValue(v)
    local output

    if (v == nil) then
        output = 'nil'
---@diagnostic disable-next-line: undefined-global
    elseif (v == NULL) then
        output = 'NULL'
    elseif (type(v) == "number" or type(v) == "string") then
        output = v
    elseif (type(v) == "table") then
        output = tablePrint(v)
    else
        output = tostring(v)
    end

    return output
end

local function normalizeArgs(...)
    local normalizedArgs = {}

    for i = 1, select('#', ...) do
        table.insert(normalizedArgs, normalizeValue((select(i, ...))))
    end

    return unpack(normalizedArgs)
end

local timestampPattern = "<%04d-%02d-%02d %02d:%02d:%02d.%03d> "

---@param useTimestamp boolean
local function getTimestamp(useTimestamp)
    if (useTimestamp) then
        local lt = time.GetLocalTime()

        return string.format(timestampPattern, lt.Year, lt.Month, lt.Day, lt.Hour, lt.Minute, lt.Second, lt.Milliseconds)
    end

    return ""
end

---@param prependNewline boolean
---@vararg ...
---@return string
local function formatVarargs(prependNewline, ...)
    local output = ''

    if (select('#', ...) > 0) then
        if (prependNewline) then
            output = _newline
        else
            output = ' '
        end

        output = output .. table.concat({...}, ' ')
    end

    return output
end

local function formatOutput(message, ...)
    local output

    if (type(message) == "string") then
        output = string.format(message, normalizeArgs(...))
    elseif (type(message) == "table") then
        output = tablePrint(message) .. formatVarargs(true, ...)
    else
        output = tostring(message) .. formatVarargs(false, ...)
    end

    return output
end

---@return string
local function formatHeader()
    local header = Note.prefix

    if (type(Note.prefix) == 'function') then
        header = Note.prefix()
    end

    return header --[[@as string]]
end

local function printf(format, ...)
    print(string.format(format, ...))
end

local function logf(format, ...)
    checkLogFile()

    local log = string.format(format, ...)

    writeLog(log)
end

local function writeOutput(logLevel, message, ...)
    if logLevels[Note.logLevel:lower()].level <= logLevels[logLevel].level then
        local output = formatOutput(message, ...)
        local header = formatHeader()
        local caller = getCallerName()

        printf('%s%s%s%s[%s]%s :: %s', getTimestamp(Note.useTimestampConsole), header, caller, getColorStart(logLevel), logLevels[logLevel].abbreviation, getColorEnd(), output)

        if (Note.useOutfile) then
            logf('%s%s%s[%s] :: %s', getTimestamp(Note.useTimestampLog), header, caller, logLevels[logLevel].abbreviation, output)
        end
    end
end

---Raw console output
---@param message any A message to display to the console (only); if a string, can contain formatting directives for further parameters
---@vararg any
function Note.Raw(message, ...)
    printf('%s', formatOutput(message, ...))
end

---Raw log output
---@param message any A message to display to the log (only); if a string, can contain formatting directives for further parameters
---@vararg any
function Note.RawLog(message, ...)
    logf('%s', formatOutput(message, ...))
end

---Trace-level output
---@param message any A message to display to the console (and log if configured) at a trace level; if a string, can contain formatting directives for further parameters
---@vararg any
function Note.Trace(message, ...)
    writeOutput('trace', message, ...)
end

---Debug-level output
---@param message any A message to display to the console (and log if configured) at a debug level; if a string, can contain formatting directives for further parameters
---@vararg any
function Note.Debug(message, ...)
    writeOutput('debug', message, ...)
end

---Information-level output
---@param message any A message to display to the console (and log if configured) at an informational level; if a string, can contain formatting directives for further parameters
---@vararg any
function Note.Info(message, ...)
    writeOutput('info', message, ...)
end

---Warning-level output
---@param message any A message to display to the console (and log if configured) at an warning level; if a string, can contain formatting directives for further parameters
---@vararg any
function Note.Warn(message, ...)
    writeOutput('warn', message, ...)
end

---Error-level output
---@param message any A message to display to the console (and log if configured) at an error level; if a string, can contain formatting directives for further parameters
---@vararg any
function Note.Error(message, ...)
    writeOutput('error', message, ...)
end

---Fatal-level output
---Script will terminate after writing the message
---@param message any A message to display to the console (and log if configured) at a fatal level; if a string, can contain formatting directives for further parameters
---@vararg any
function Note.Fatal(message, ...)
    writeOutput('fatal', message, ...)
    terminate()
end

---Log output
---@param message any A message to display to the log (only); if a string, can contain formatting directives for further parameters
---@vararg any
function Note.Log(message, ...)
    local header = formatHeader()
    local caller = getCallerName()

    logf('%s%s%s[%s] :: %s', getTimestamp(Note.useTimestampLog), header, caller, logLevels[Note.logLevel].abbreviation, formatOutput(message, ...))
end

return Note