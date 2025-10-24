---@class ICaseTable : table<string, any>
ICaseTable = {}

--- Creates a table with case insensitive string lookup.  
--- Table can be used to store and lookup non-string keys as well.  
--- Keys are case preserved while iterating (calling pairs).  
--- The case will be updated after a set operation.  
---  
--- E.g:  
--- * keys "ABC", "abc" and "aBc" are all considered the same key.  
--- * Setting "ABC", "abc" then "aBc" the case returned when iterating will be "aBc".
---@param data? table @An optional table with an initial set of data
---@return ICaseTable|table<string, any> @A table with case insensitive lookup.
function CreateIcaseTable(data)
    -- For case preservation.
    local lookup = {}

    -- Stores the values so we can properly update. We need the main table to always return nil on lookup
    -- so __newindex is called when setting a value. If this doesn't happen then a case change (FOO to foo)
    -- won't happen because __newindex is only called when the lookup fails (there isn't a metamethod for 
    -- lookup we can use).
    local values = {}
    local template = {}

    local function __genOrderedIndex()
        local orderedIndex = {}

        for key in pairs(values) do
            table.insert(orderedIndex, key)
        end

        table.sort(orderedIndex)

        return orderedIndex
    end

    ---@param t table
    ---@param state string
    local function __orderedNext(t, state)
        local key = nil

        if (state == nil) then
            -- the first time, generate the index
            t.__orderedIndex = __genOrderedIndex()
            key = t.__orderedIndex[1]
        else
            -- fetch the next value
            for i = 1,#(t.__orderedIndex) do
                if t.__orderedIndex[i] == state:lower() then
                    key = t.__orderedIndex[i + 1]
                end
            end
        end

        if (key) then
            return lookup[key] or key, values[key]
        end

        -- no more value to return, cleanup
        t.__orderedIndex = nil
    end

     function template.ordered()
        return __orderedNext, template, nil
    end

    ---@param t table
    ---@param state string
    local function __nextPairs(t, state)
        if (state ~= nil) then
            -- Check that strings that have been normalized exist in the table.
            if type(state) == "string" and values[state:lower()] ~= nil then
                state = state:lower()
            end

            -- Ensure the value exists in the table.
            if values[state] == nil then
                return nil
            end
        end

        local key,value = next(values, state)

        return lookup[key] or key, value
    end

    function template.pairs()
        return __nextPairs, template, nil
    end

    local mt = {
        __index=function(t, k)
            local v = nil

            if type(k) == "string" then
                -- Try to get the value for the key normalized.
                v = values[k:lower()]
            end

            if v == nil then
                v = values[k]
            end

            return v
        end,
        __newindex=function(t, k, v)
            -- Store all strings normalized as lowercase.
            if type(k) == "string" then
                lookup[k:lower()] = v ~= nil and k or nil -- Clear the lookup value if we're setting to nil.
                k = k:lower()
            end

            values[k] = v
        end,
        -- __pairs=function(t)
        --     local function n(t, i)
        --         if i ~= nil then
        --             -- Check that strings that have been normalized exist in the table.
        --             if type(i) == "string" and values[i:lower()] ~= nil then
        --                 i = i:lower()
        --             end
        --             -- Ensure the value exists in the table.
        --             if values[i] == nil then
        --                 return nil
        --             end
        --         end
        --         local k,v = next(values, i)
        --         return lookup[k] or k, v
        --     end
        --     return n, t, nil
        -- end
    }

    local modified = setmetatable(template, mt)

    if (data and type(data) == "table") then
        for key, value in pairs(data) do
            modified[key] = value
        end
    end

    return modified
end

--- Returns an iterator sorted by the keys
function ICaseTable.ordered() end

--- Returns an iterator
function ICaseTable.pairs() end

return ICaseTable