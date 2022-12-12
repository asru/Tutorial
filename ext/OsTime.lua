-- OsTime.lua by Rouneq
-- Provides methods to obtain either the local time or UTC time from the base Os at millisecond resolution
local ffi = require('ffi')

---@class SYSTEMTIME
---@field Year integer
---@field Month integer
---@field DayOfWeek integer
---@field Day integer
---@field Hour integer
---@field Minute integer
---@field Second integer
---@field Milliseconds integer

ffi.cdef[[
    typedef unsigned short      WORD;
    typedef struct _SYSTEMTIME {
        WORD Year;
        WORD Month;
        WORD DayOfWeek;
        WORD Day;
        WORD Hour;
        WORD Minute;
        WORD Second;
        WORD Milliseconds;
    } SYSTEMTIME, *PSYSTEMTIME, *LPSYSTEMTIME;

    void GetLocalTime(
        LPSYSTEMTIME lpSystemTime
        );

    void GetSystemTime(
        LPSYSTEMTIME lpSystemTime
        );
]]

--- Provides methods to obtain the time at millisecond resolution
---@class OsTime
OsTime = {}

--- Gets the local time from the operating system in millisecond resolution
---@return SYSTEMTIME
OsTime.GetLocalTime = function ()
    local timestruct = ffi.new('SYSTEMTIME') --[[@as SYSTEMTIME]]
    ffi.C.GetLocalTime(timestruct)

    return timestruct
end

--- Gets the UTC time from the operating system in millisecond resolution
---@return SYSTEMTIME
OsTime.GetSystemTime = function ()
    local timestruct = ffi.new('SYSTEMTIME') --[[@as SYSTEMTIME]]
    ffi.C.GetSystemTime(timestruct)

    return timestruct
end

return OsTime