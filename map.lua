---@alias map_callback fun(arg: any): any
---@alias map_predicate string|map_callback
---@alias map_pattern table|function|number|string|boolean|nil

---@class map_class
---@field func_call table|nil
---@operator call(any): map_instance

---@class map_func_call
---@field func any
---@field args any[]

---@class map_instance: map_class
---@field data any
---@field match boolean
---@field result_value any
---@field cache_store table|nil
local map_class = {}

local predicate_parser = require("predicates"):get()
local FUNC_CALL_METATABLE = "map.func_call"

setmetatable(map_class, {
    __call = function(self, arg)
        return self.map(arg)
    end,
})

---@param self map_instance
---@return any
local function get_consumer_arg(self)
    if type(self.data) ~= "table" and self.cache_store == nil then
        return self.data
    end

    return setmetatable(self.cache_store or {}, { __index = self.data })
end

---@param self map_instance
---@param func map_callback
local function execute_consumer(self, func)
    self.result_value = func(get_consumer_arg(self))
end

---@param obj table
---@return integer
local function count_entries(obj)
    local count = 0
    for _, _ in pairs(obj) do
        count = count + 1
    end

    return count
end

---@param obj table|nil
---@param key any
---@return any
local function get_table_value_by_table_key(obj, key)
    if obj == nil then
        return nil
    end

    for current_key, value in pairs(obj) do
        if type(current_key) == "table" then
            if map_class:match_table(nil, current_key, key) then
                return value
            end
        end
    end
    return nil
end

---@param self map_instance|map_class
---@param cache table|nil
---@param obj any
---@param pattern table
---@return boolean
function map_class:match_table(cache, obj, pattern)
    if obj == nil then
        return false
    end

    for key, value in pairs(pattern) do
        if type(key) == "table" and getmetatable(key) == FUNC_CALL_METATABLE then
            local runtime_value = get_table_value_by_table_key(cache, key)
            if cache ~= nil and runtime_value ~= nil then
                if type(value) == "number" or type(value) == "string" then
                    if value ~= runtime_value then
                        return false
                    end
                elseif type(value) == "table" then
                    if not self:match_table(nil, runtime_value, value) then
                        return false
                    end
                else
                    error("Cant pattern match type " .. type(value))
                end
            else
                ---@cast self map_instance
                runtime_value = self:execute_func_call(key)
                if type(value) == "number" or type(value) == "string" then
                    if value ~= runtime_value then
                        return false
                    end
                elseif type(value) == "table" then
                    if not self:match_table(nil, runtime_value, value) then
                        return false
                    end
                else
                    error("Cant pattern match type " .. type(value))
                end
            end
        elseif type(value) == "number" or type(value) == "string" then
            if cache ~= nil and cache[key] ~= nil then
                if cache[key] ~= value then
                    return false
                end
            else
                if obj[key] ~= value then
                    return false
                end
            end
        elseif type(value) == "table" then
            local pattern_count = count_entries(value)

            if pattern_count == 0 then
                return type(obj) == type(value)
            end
            if not self:match_table((cache or {})[key], (cache or {})[key] or obj[key], value) then
                return false
            end
        else
            error("Cant pattern match type " .. type(value))
        end
    end

    return true
end

---@param arg any
---@return map_instance
function map_class.map(arg)
    ---@type map_instance
    local instance = { data = arg, match = false, result_value = nil }
    return setmetatable(instance, { __index = map_class }) --[[@as map_instance]]
end

---@param self map_instance
---@param condition map_pattern
---@param func map_predicate
---@return map_instance
function map_class:case(condition, func)
    if self.match then
        return self
    end

    ---@type map_callback|false
    local resolved_func = false
    if type(func) == "string" then
        resolved_func = predicate_parser:get_predicate_function(func)
    elseif type(func) ~= "function" then
        error("Cannot callback on type" .. type(func) .. "for map case")
    else
        resolved_func = func
    end

    ---@cast resolved_func map_callback
    if type(condition) == "function" then
        if condition(self.data) then
            execute_consumer(self, resolved_func)
            self.match = true
        end
    elseif type(condition) == "table" then
        if self:match_table(self.cache_store, self.data, condition) then
            execute_consumer(self, resolved_func)
            self.match = true
        end
    elseif type(condition) == "number" or type(condition) == "boolean" or type(condition) == "nil" then
        if self.data == condition then
            execute_consumer(self, resolved_func)
            self.match = true
        end
    elseif type(condition) == "string" then
        if string.find(condition, "=>") then
            local predicate = predicate_parser:get_predicate_function(condition)
            if predicate and predicate(self.data) then
                execute_consumer(self, resolved_func)
                self.match = true
            end
        elseif self.data == condition then
            execute_consumer(self, resolved_func)
            self.match = true
        end
    end

    return self
end

---@param self map_instance
---@param func map_predicate
---@return map_instance
function map_class:default(func)
    if not self.match then
        ---@type map_callback|false
        local resolved_func = false
        if type(func) == "string" then
            resolved_func = predicate_parser:get_predicate_function(func)
        elseif type(func) ~= "function" then
            error("Cannot callback on type" .. type(func) .. "for map case")
        else
            resolved_func = func
        end

        ---@cast resolved_func map_callback
        execute_consumer(self, resolved_func)
    end

    return self
end

---@param self map_instance
---@return any
function map_class:result()
    return self.result_value
end

map_class.func_call = setmetatable({}, {
    __index = function(_, key)
        ---@type map_func_call
        local case = { func = key, args = {} }
        return function(...)
            case.args = { ... }
            setmetatable(case, {
                __metatable = FUNC_CALL_METATABLE
            })
            return case
        end
    end
})

---@param self map_instance
---@param map_func_call_obj map_func_call
---@return any
function map_class:execute_func_call(map_func_call_obj)
    if type(self.data[map_func_call_obj.func]) ~= "function" then
        error("Function to cahe does not exist in the Mapped object or key is wrong value type")
    end

    return self.data[map_func_call_obj.func](table.unpack(map_func_call_obj.args))
end

-- Only use cache on func_call if the function your caching is performance intensive getters should be evaluated each case statement and not cached because cache itself is very expensive on lookup
---@param self map_instance
---@param what table|function
---@return map_instance
function map_class:cache(what)
    if self.cache_store ~= nil then
        error("Only 1 Cahe statement per map/case construct")
    end

    if type(what) ~= "table" and type(what) ~= "function" then
        error("Cash representation mus be a table or generator function")
    end

    if type(self.data) ~= "table" then
        error("Cash only applicable if map expresion is on a object (table)")
    end

    ---@cast what table
    self.cache_store = {}

    for key, value in pairs(what) do
        if type(value) == "function" then
            self.cache_store[key] = value(self.data)
        elseif type(value) == "table" then
            if getmetatable(value) == FUNC_CALL_METATABLE then
                self.cache_store[value] = self:execute_func_call(value)
            else
                self.cache_store[key] = value
            end
        else
            self.cache_store[key] = value
        end
    end

    return self
end

return map_class
