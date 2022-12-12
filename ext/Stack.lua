--- Stack Table  
--- Uses a table as stack, use <table>:push(value) and <table>:pop()
-- Lua 5.1 compatible

---@class Stack
Stack = {}

--- Create a Table with stack functions
function Stack:Create()

  -- stack table
  local t = {}
  -- entry table
  t._et = {}

  --- Push a value on to the stack
  ---@vararg any @Values to push on the stack
  function t:push(...)
    if ... then
      local targs = {...}
      -- add values
      for _,v in ipairs(targs) do
        table.insert(self._et, v)
      end
    end
  end

  --- Pop a value from the stack
  ---@param num? integer Number of values to pop off the stack
  ---@return ...any
  function t:pop(num)

    -- get num values from stack
    num = num or 1

    -- return table
    local entries = {}

    -- get values into entries
    for i = 1, num do
      -- get last entry
      if #self._et ~= 0 then
        table.insert(entries, self._et[#self._et])
        -- remove last value
        table.remove(self._et)
      else
        break
      end
    end

    -- return unpacked entries
    return unpack(entries)
  end

  --- The number of entries on the stack
  function t:getn()
    return #self._et
  end

  --- Print the list of values on the stack
  function t:list()
    for i,v in pairs(self._et) do
      print(i, v)
    end
  end

  --- Returs the list of values on the stack in a string from (one line per entry)
  ---@return string
  function t:tostring()
    return table.concat(self._et, "\n")
  end

  return t
end

return Stack