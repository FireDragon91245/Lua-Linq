local map = require("linq.map")
local predicate_parser = require("linq.predicates"):get()

---@class linq
local linq = {}

---@alias option<T> T | nil

---@class enumerable<T>
---@class enumerable<K, V>
local enumerable_impl = {}

---@class list<T>
local list_impl = {}

---@class dict<K, V>
local dict_impl = {}

---@class iter<T>
---@operator call:(iter<T>): T
---@class iter<K, V>
---@operator call:(iter<K, V>): K, V
local iter_impl = {}

---@class equality_comparer
---@operator band(equality_comparer): equality_comparer
---@field compare fun(self: equality_comparer, a: any, b: any, prep_for_next: boolean|nil): any|boolean, any
---@field is_combined fun(self: equality_comparer): boolean
---@field key fun(self: equality_comparer): string
---@field types fun(self: equality_comparer): type[]
---@field priority number
---@field comparers { [type]: equality_comparer }

---@param value any
---@param argc number|nil
---@param literal any|nil
---@return table
local function makeArgDescriptor(value, argc, literal)
    local descriptor = {
        type = type(value),
        ext_type = getmetatable(value) ~= nil and getmetatable(value).__type or nil
    }

    if argc ~= nil then
        descriptor.argc = argc
    end

    if literal ~= nil then
        descriptor.literal = literal
    end

    return descriptor
end

local NIL_KEY = {}

---@param value any
---@return any
local function normalizeDistinctKey(value)
    if value == nil then
        return NIL_KEY
    end

    return value
end

---@param expression string
---@param kind string
---@return function
local function compileEnumerableStringExpression(expression, kind)
    local compiled = predicate_parser:get_predicate_function(expression)
    if not compiled then
        error("Invalid " .. kind .. " string: " .. expression)
    end

    return compiled
end

---@param table table
---@return string
local function table_addres(table)
    local str = tostring(table)
    return str:sub(-16)
end

---@param table table
---@param key string
---@return string
local function get_per_table_uniq_key(table, key)
    return table_addres(table) .. key
end

---@param property string
---@return function
local function makeValuePropertySelector(property)
    return function(...)
        return select(-1, ...)[property]
    end
end

local function validateList(list)
    if getmetatable(list) == nil or getmetatable(list).__type ~= "list" then
        error("Expected list, got " .. type(list))
    end
end

local function validateEnumerable(enumerable)
    if getmetatable(enumerable) == nil or getmetatable(enumerable).__type ~= "enumerable" then
        error("Expected enumerable, got " .. type(enumerable))
    end

    if enumerable.__next == nil or type(enumerable.__next) ~= "function" then
        error("Enumerable: Invalid state, missing next() function")
    end

    if enumerable.__src == nil then
        error("Enumerable: Invalid state, missing src")
    end
end

local function validateIter(iter)
    if getmetatable(iter) == nil or getmetatable(iter).__type ~= "iter" then
        error("Expected iter, got " .. type(iter) .. "; did you call __next on an enumerable?")
    end

    if iter.__itersrc == nil then
        error("Iter: Invalid state, missing source")
    end
end

local function validateDict(dict)
    if getmetatable(dict) == nil or getmetatable(dict).__type ~= "dict" then
        error("Expected dict, got " .. type(dict))
    end
end

---@return metatable
local function makeListMeta()
    return {
        __index = list_impl,
        __type = "list"
    }
end

---@return metatable
local function makeEnumerableMeta()
    return {
        __index = enumerable_impl,
        __type = "enumerable",
    }
end

---@return metatable
local function makeIterMeta(src_view)
    return {
        __index = iter_impl,
        __type = "iter",
        __call = function(self)
            return self.__itersrc.__next(self, self.__itersrc)
        end
    }
end

---@type fun(a: equality_comparer, b: equality_comparer): equality_comparer
local combineComparers

---@return metatable
local function makeComparerMeta()
    return {
        __band = function(self, b)
            return combineComparers(self, b)
        end,
        __type = "equality_comparer"
    }
end

---@return metatable
local function makeDictMeta()
    return {
        __index = dict_impl,
        __type = "dict"
    }
end

local function makeCombinedComparer(by_types)
    return {
        comparers = by_types,
        is_combined = function() return true end,
        compare = function(self, a, b, prepare_for_next)
            if type(a) ~= type(b) then return false end
            local comparers = self.comparers[type(a)]
            if not comparers then
                if prepare_for_next then return a, b else return a == b end
            end
            local comparers_count = #comparers

            if comparers_count == 1 then
                return comparers[1].compare(self, a, b, prepare_for_next)
            else
                local to_compare_a = a
                local to_compare_b = b
                for i = 1, comparers_count - 1 do
                    to_compare_a, to_compare_b = comparers[i].compare(self, to_compare_a, to_compare_b, true)
                end
                return comparers[comparers_count].compare(self, to_compare_a, to_compare_b, prepare_for_next)
            end
        end
    }
end

combineComparers = function(a, b)
    if a:is_combined() and b:is_combined() then
        local keys_by_type = {}
        for type, comparers in pairs(a.comparers) do
            keys_by_type[type] = keys_by_type[type] or {}

            for _, comparer in ipairs(comparers) do
                keys_by_type[type][comparer:key()] = true
            end
        end
        for type, comparers in pairs(b.comparers) do
            keys_by_type[type] = keys_by_type[type] or {}

            for i, comparer in ipairs(comparers) do
                if keys_by_type[type][comparer:key()] then
                    table.remove(b.comparers[type], i)
                end
            end
        end
        local by_type = {}
        for type, comparers in pairs(a.comparers) do
            by_type[type] = by_type[type] or {}

            for _, comparer in pairs(comparers) do
                table.insert(by_type[type], comparer)
            end
        end
        for type, comparers in pairs(b.comparers) do
            by_type[type] = by_type[type] or {}

            for _, comparer in pairs(comparers) do
                table.insert(by_type[type], comparer)
            end
        end
        for _, comparers in pairs(by_type) do
            table.sort(comparers, function(aa, bb) return aa.priority > bb.priority end)
        end
        return setmetatable(makeCombinedComparer(by_type), makeComparerMeta())
    elseif not a:is_combined() and not b:is_combined() then
        if a:key() == b:key() then return a end
        if b.priority > a.priority then
            a, b = b, a
        end
        local by_type = {}
        for _, type in pairs(a:types()) do
            by_type[type] = by_type[type] or {}

            table.insert(by_type[type], a)
        end
        for _, type in pairs(b:types()) do
            by_type[type] = by_type[type] or {}

            table.insert(by_type[type], b)
        end
        return setmetatable(makeCombinedComparer(by_type), makeComparerMeta())
    else
        local combined = a:is_combined() and a or b
        local not_combined = a:is_combined() and b or a
        for _, comperers in pairs(combined.comparers) do
            for _, comparer in pairs(comperers) do
                if comparer:key() == not_combined:key() then
                    return combined
                end
            end
        end
        local by_type = {}
        for type, comparers in pairs(combined.comparers) do
            by_type[type] = by_type[type] or {}

            for _, comparer in pairs(comparers) do
                table.insert(by_type[type], comparer)
            end
        end
        for _, type in pairs(not_combined:types()) do
            by_type[type] = by_type[type] or {}

            table.insert(by_type[type], not_combined)
        end
        for _, comparers in pairs(by_type) do
            table.sort(comparers, function(aa, bb) return aa.priority > bb.priority end)
        end
        return setmetatable(makeCombinedComparer(by_type), makeComparerMeta())
    end
end

---@type equality_comparer
linq.IGNORE_CASE = setmetatable({
    compare = function(self, a, b, prepare_for_next)
        if type(a) ~= "string" or type(b) ~= "string" then return a == b end
        if prepare_for_next then return a:lower(), b:lower() else return a:lower() == b:lower() end
    end,
    is_combined = function() return false end,
    key = function()
        return "string:ignore_case"
    end,
    types = function()
        return { "string" }
    end,
    priority = 0
}, makeComparerMeta())

---@type equality_comparer
linq.IGNORE_WHITESPACE = setmetatable({
    compare = function(self, a, b, prepare_for_next)
        if type(a) ~= "string" or type(b) ~= "string" then return a == b end
        if prepare_for_next then
            return a:gsub("%s+", ""), b:gsub("%s+", "")
        else
            return a:gsub("%s+", "") ==
                b:gsub("%s+", "")
        end
    end,
    is_combined = function() return false end,
    key = function()
        return "string:ignore_whitespace"
    end,
    types = function()
        return { "string" }
    end,
    priority = 0
}, makeComparerMeta())

---@type equality_comparer
linq.TABLE_EQUAL = setmetatable({
    compare = function(self, a, b, prepare_for_next)
        if type(a) ~= "table" or type(b) ~= "table" then return a == b end
        local a_keys = {}
        local b_keys = {}
        for key in pairs(a) do
            table.insert(a_keys, key)
        end
        for key in pairs(b) do
            table.insert(b_keys, key)
        end
        table.sort(a_keys)
        table.sort(b_keys)
        if #a_keys ~= #b_keys then return false end
        for i = 1, #a_keys do
            if a_keys[i] ~= b_keys[i] then return false end
            local a_value = a[a_keys[i]]
            local b_value = b[b_keys[i]]
            if not self:compare(a_value, b_value) then return false end
        end
        return true
    end,
    is_combined = function() return false end,
    key = function()
        return "table:equal"
    end,
    types = function()
        return { "table" }
    end,
    priority = 1
}, makeComparerMeta())

---@type equality_comparer
linq.TABLE_SUBSET = setmetatable({
    compare = function(self, a, b, prepare_for_next)
        if type(a) ~= "table" or type(b) ~= "table" then return a == b end
        for key in pairs(a) do
            if b[key] == nil then return false end
            local a_value = a[key]
            local b_value = b[key]
            if not self:compare(a_value, b_value) then return false end
        end
        return true
    end,
    is_combined = function() return false end,
    key = function()
        return "table:subset"
    end,
    types = function()
        return { "table" }
    end,
    priority = 1
}, makeComparerMeta())

---@type equality_comparer
linq.TABLE_SUPERSET = setmetatable({
    compare = function(self, a, b, prepare_for_next)
        if type(a) ~= "table" or type(b) ~= "table" then return a == b end
        for key in pairs(b) do
            if a[key] == nil then return false end
            local a_value = a[key]
            local b_value = b[key]
            if not self:compare(a_value, b_value) then return false end
        end
        return true
    end,
    is_combined = function() return false end,
    key = function()
        return "table:superset"
    end,
    types = function()
        return { "table" }
    end,
    priority = 1
}, makeComparerMeta())

---@type equality_comparer
linq.TABLE_CHECK_TYPES = setmetatable({
    compare = function(self, a, b, prepare_for_next)
        if type(a) ~= "table" or type(b) ~= "table" then return a == b end
        if prepare_for_next then
            local a_with_types = {}
            local b_with_types = {}
            for key, value in pairs(a) do
                if type(value) == "table" then
                    a_with_types[key] = value
                else
                    a_with_types[key] = type(value)
                end
            end
            for key, value in pairs(b) do
                if type(value) == "table" then
                    b_with_types[key] = value
                else
                    b_with_types[key] = type(value)
                end
            end
            return a_with_types, b_with_types
        else
            for key in pairs(a) do
                if b[key] == nil then goto continue end
                local a_value = a[key]
                local b_value = b[key]
                if type(a_value) ~= type(b_value) then return false end
                if type(a_value) == "table" then
                    if not self:compare(a_value, b_value) then return false end
                end
                ::continue::
            end
            for key in pairs(b) do
                if a[key] == nil then goto continue end
                local a_value = a[key]
                local b_value = b[key]
                if type(a_value) ~= type(b_value) then return false end
                if type(a_value) == "table" then
                    if not self:compare(a_value, b_value) then return false end
                end
                ::continue::
            end
            return true
        end
    end,
    is_combined = function() return false end,
    key = function()
        return "table:check_types"
    end,
    types = function()
        return { "table" }
    end,
    priority = 2
}, makeComparerMeta())

---@type equality_comparer
linq.EPSILON_EQUAL = setmetatable({
    epsilon = 1e-10,
    compare = function(self, a, b, prepare_for_next)
        if type(a) ~= "number" or type(b) ~= "number" then return a == b end
        return math.abs(a - b) <= self.epsilon
    end,
    is_combined = function() return false end,
    key = function()
        return "number:epsilon"
    end,
    types = function()
        return { "number" }
    end,
    priority = 0
}, makeComparerMeta())

---@type equality_comparer
linq.ROUNDED_EQUAL = setmetatable({
    decimals = 2,
    compare = function(self, a, b, prepare_for_next)
        if type(a) ~= "number" or type(b) ~= "number" then return a == b end
        local factor = 10 ^ self.decimals
        return math.floor(a * factor + 0.5) == math.floor(b * factor + 0.5)
    end,
    is_combined = function() return false end,
    key = function()
        return "number:rounded"
    end,
    types = function()
        return { "number" }
    end,
    priority = 0
}, makeComparerMeta())

---@param min number
---@param max number
---@return equality_comparer
function linq.IN_RANGE(min, max)
    return setmetatable({
        min = min,
        max = max,
        compare = function(self, a, b, prepare_for_next)
            if type(a) ~= "number" then return false end
            -- b is ignored, we're checking if a is in range
            return a >= self.min and a <= self.max
        end,
        is_combined = function() return false end,
        key = function()
            return "number:range_" .. min .. "_" .. max
        end,
        types = function()
            return { "number" }
        end,
        priority = 0
    }, makeComparerMeta())
end

---@type equality_comparer
linq.TRIM_EQUAL = setmetatable({
    compare = function(self, a, b, prepare_for_next)
        if type(a) ~= "string" or type(b) ~= "string" then return a == b end
        local trimmed_a = a:match("^%s*(.-)%s*$")
        local trimmed_b = b:match("^%s*(.-)%s*$")
        if prepare_for_next then return trimmed_a, trimmed_b else return trimmed_a == trimmed_b end
    end,
    is_combined = function() return false end,
    key = function()
        return "string:trim"
    end,
    types = function()
        return { "string" }
    end,
    priority = 0
}, makeComparerMeta())

---@type equality_comparer
linq.IGNORE_MISSING = setmetatable({
    compare = function(self, a, b, prepare_for_next)
        if a == nil and b == nil then return true end
        if a == nil or b == nil then return false end
        return a == b
    end,
    is_combined = function() return false end,
    key = function()
        return "any:nil_safe"
    end,
    types = function()
        return { "nil", "string", "number", "boolean", "table", "function", "userdata", "thread" }
    end,
    priority = 1
}, makeComparerMeta())

---@param func_name string
---@param args table
---@param canidates table
local function error_invalid_signature(func_name, args, canidates)
    if #args == 0 then
        local mt = getmetatable(args)
        if mt.__index and type(mt.__index) == "table" then
            args = mt.__index
        end
    end
    local message = "\nInvalid call to " .. func_name .. ": " .. func_name .. "("
    local any_arg = false
    for i, arg in ipairs(args) do
        if arg.type ~= "nil" then
            message = message .. (arg.type or "nil")
            if arg.ext_type then
                message = message .. ": " .. arg.ext_type
            end
            if arg.literal then
                message = message .. ": \"" .. arg.literal .. "\""
            end
            message = message .. ", "
            any_arg = true
        end
    end
    if any_arg then
        message = message:sub(1, -3)
    end
    message = message .. ")\n\nPossible signatures are:\n"
    for _, candidate in ipairs(canidates) do
        message = message .. "    " .. func_name .. "("
        local any_candidate = false
        for i, arg in ipairs(candidate) do
            local arg_type = arg.type or "nil"
            if arg_type ~= "nil" then
                message = message .. arg_type
                if arg.ext_type then
                    message = message .. ": " .. arg.ext_type
                end
                if arg.literal then
                    message = message .. ": \"" .. arg.literal .. "\""
                end
                message = message .. ", "
                any_candidate = true
            end
        end
        if any_candidate then
            message = message:sub(1, -3)
        end
        message = message .. ")\n"
    end
    error(message)
end

---@generic T, K, V
---@overload fun(self: enumerable<T>): enumerable<T>
---@overload fun(self: enumerable<K, V>): enumerable<K, V>
---@overload fun(self: enumerable<T>, comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<K, V>, comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: enumerable<T>, keySelector: fun(item: T): (any)): enumerable<T>
---@overload fun(self: enumerable<K, V>, keySelector: fun(item: K, value: V): (any)): enumerable<K, V>
---@overload fun(self: enumerable<T>, keySelector: fun(item: T): (any), comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<K, V>, keySelector: fun(item: K, value: V): (any), comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: enumerable<T>, keySelector: string): enumerable<T>
---@overload fun(self: enumerable<K, V>, keySelector: string): enumerable<K, V>
---@overload fun(self: enumerable<T>, keySelector: string, comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<K, V>, keySelector: string, comparer: equality_comparer): enumerable<K, V>
function enumerable_impl:distinct(...)
    local argc = select("#", ...)
    local comparer_or_keySelector = select(1, ...)
    local comparer = select(2, ...)

    return map({
            makeArgDescriptor(comparer_or_keySelector, argc),
            makeArgDescriptor(comparer)
        })
        :track_cases()
        :case({
                { argc = 0,    type = "nil" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = { enumerable.__src.__next(iter, enumerable.__src) }
                        if #value == 0 then
                            return nil
                        end

                        iter.__data = iter.__data or {}
                        iter.__data.seen = iter.__data.seen or {}

                        while (#value ~= 0) and iter.__data.seen[value[#value]] do
                            value = { enumerable.__src.__next(iter, enumerable.__src) }
                        end
                        if #value ~= 0 then
                            iter.__data.seen[value[#value]] = true
                        end
                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 1,    type = "table", ext_type = "equality_comparer" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, comparer: equality_comparer): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = { enumerable.__src.__next(iter, enumerable.__src) }
                        if #value == 0 then
                            return nil
                        end

                        iter.__data = iter.__data or {}
                        iter.__data.seen = iter.__data.seen or {}

                        while #value ~= 0 do
                            local seen_by_type = iter.__data.seen[type(value[#value])]
                            if seen_by_type == nil then
                                iter.__data.seen[type(value[#value])] = { value[#value] }
                                break
                            else
                                local found = false
                                for _, seen_value in pairs(seen_by_type) do
                                    if comparer_or_keySelector --[[@as equality_comparer]]:compare(value[#value], seen_value) then
                                        found = true
                                        break
                                    end
                                end
                                if not found then
                                    table.insert(seen_by_type, value[#value])
                                    break
                                end
                            end
                            value = { enumerable.__src.__next(iter, enumerable.__src) }
                        end
                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :case({
            { argc = 1,    type = "function" },
            { type = "nil" }
        }, function(_)
            return setmetatable({
                __src = self,
                __next = function(iter, enumerable)
                    validateIter(iter)

                    local value = { enumerable.__src.__next(iter, enumerable.__src) }
                    if #value == 0 then
                        return nil
                    end

                    iter.__data = iter.__data or {}
                    iter.__data.seen = iter.__data.seen or {}

                    local value_key = normalizeDistinctKey(comparer_or_keySelector(table.unpack(value)))

                    while (#value ~= 0) and iter.__data.seen[value_key] do
                        value = { enumerable.__src.__next(iter, enumerable.__src) }
                        if #value ~= 0 then
                            value_key = normalizeDistinctKey(comparer_or_keySelector(table.unpack(value)))
                        end
                    end
                    if #value ~= 0 then
                        iter.__data.seen[value_key] = true
                    end
                    return table.unpack(value)
                end
            }, makeEnumerableMeta())
        end)
        :case({
                { argc = 2,       type = "function" },
                { type = "table", ext_type = "equality_comparer" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, keySelector: fun(item: T): any, comparer: equality_comparer): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = { enumerable.__src.__next(iter, enumerable.__src) }
                        if #value == 0 then
                            return nil
                        end

                        iter.__data = iter.__data or {}
                        iter.__data.seen = iter.__data.seen or {}

                        while #value ~= 0 do
                            local value_key = comparer_or_keySelector(table.unpack(value))
                            local seen_by_type = iter.__data.seen[type(value_key)]
                            if seen_by_type == nil then
                                iter.__data.seen[type(value_key)] = { value_key }
                                break
                            end
                            if value_key ~= nil then
                                local found = false
                                for _, seen_value in pairs(seen_by_type) do
                                    if comparer:compare(value_key, seen_value) then
                                        found = true
                                        break
                                    end
                                end
                                if not found then
                                    table.insert(seen_by_type, value_key)
                                    break
                                end
                            end
                            value = { enumerable.__src.__next(iter, enumerable.__src) }
                        end
                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 1,    type = "string" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, keySelector: string): enumerable<T>
            function(_)
                local is_predicate = string.find(comparer_or_keySelector --[[@as string]], "=>") ~= nil
                local predicate
                if is_predicate then
                    predicate = compileEnumerableStringExpression(comparer_or_keySelector, "predicate")
                else
                    predicate = makeValuePropertySelector(comparer_or_keySelector)
                end
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = { enumerable.__src.__next(iter, enumerable.__src) }
                        if #value == 0 then
                            return nil
                        end

                        iter.__data = iter.__data or {}
                        iter.__data.seen = iter.__data.seen or {}

                        local value_key = normalizeDistinctKey(predicate(table.unpack(value)))

                        while (#value ~= 0) and iter.__data.seen[value_key] do
                            value = { enumerable.__src.__next(iter, enumerable.__src) }
                            if #value ~= 0 then
                                value_key = normalizeDistinctKey(predicate(table.unpack(value)))
                            end
                        end
                        if #value ~= 0 then
                            iter.__data.seen[value_key] = true
                        end

                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 2,       type = "string" },
                { type = "table", ext_type = "equality_comparer" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, keySelector: string, comparer: equality_comparer): enumerable<T>
            function(_)
                local is_predicate = string.find(comparer_or_keySelector --[[@as string]], "=>") ~= nil
                local predicate
                if is_predicate then
                    predicate = compileEnumerableStringExpression(comparer_or_keySelector, "predicate")
                else
                    predicate = makeValuePropertySelector(comparer_or_keySelector)
                end
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = { enumerable.__src.__next(iter, enumerable.__src) }
                        if #value == 0 then
                            return nil
                        end

                        iter.__data = iter.__data or {}
                        iter.__data.seen = iter.__data.seen or {}

                        while #value ~= 0 do
                            local value_key = predicate(table.unpack(value))
                            local seen_by_type = iter.__data.seen[type(value_key)]
                            if seen_by_type == nil then
                                iter.__data.seen[type(value_key)] = { value_key }
                                break
                            end
                            if value_key ~= nil then
                                local found = false
                                for _, seen_value in pairs(seen_by_type) do
                                    if comparer:compare(value_key, seen_value) then
                                        found = true
                                        break
                                    end
                                end
                                if not found then
                                    table.insert(seen_by_type, value_key)
                                    break
                                end
                            end
                            value = { enumerable.__src.__next(iter, enumerable.__src) }
                        end

                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:distinct", signature, existing_signatures or {})
        end)
        :result()
end

---@generic T, K, V
---@overload fun(self: enumerable<T>, predicate: fun(item: T): (boolean)): enumerable<T>
---@overload fun(self: enumerable<K, V>, predicate: fun(key: K, value: V): (boolean)): enumerable<K, V>
---@overload fun(self: enumerable<T>, predicate: string): enumerable<T>
---@overload fun(self: enumerable<K, V>, predicate: string): enumerable<K, V>
---@overload fun(self: enumerable<T>, predicate: table): enumerable<T>
---@overload fun(self: enumerable<K, V>, predicate: table): enumerable<K, V>
---@overload fun(self: enumerable<T>, predicate: table, equality_comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<K, V>, predicate: table, equality_comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any)): enumerable<T>
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any)): enumerable<K, V>
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any), value: any, equality_comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), value: any, equality_comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any), value: any): enumerable<T>
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), value: any): enumerable<K, V>
---@overload fun(self: enumerable<T>, selector: string): enumerable<T>
---@overload fun(self: enumerable<K, V>, selector: string): enumerable<K, V>
---@overload fun(self: enumerable<T>, selector: string, value: any): enumerable<T>
---@overload fun(self: enumerable<K, V>, selector: string, value: any): enumerable<K, V>
---@overload fun(self: enumerable<T>, selector: string, value: any, equality_comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<K, V>, selector: string, value: any, equality_comparer: equality_comparer): enumerable<K, V>
function enumerable_impl:where(...)
    local argc = select("#", ...)
    local predicate_or_selector = select(1, ...)
    local value_or_comparer = select(2, ...)
    local equality_comparer = select(3, ...)

    local make_next_func = function(condition)
        return function(iter, enumerable)
            validateIter(iter)

            local value = { enumerable.__src.__next(iter, enumerable.__src) }
            while (#value ~= 0) and condition(value) do
                value = { enumerable.__src.__next(iter, enumerable.__src) }
            end
            return table.unpack(value)
        end
    end

    return map({
            makeArgDescriptor(predicate_or_selector, argc),
            makeArgDescriptor(value_or_comparer),
            makeArgDescriptor(equality_comparer)
        })
        :track_cases()
        :case({
                { argc = 1,    type = "function" },
                { type = "nil" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, predicate: fun(item: T): (boolean)): enumerable<T>|fun(self: enumerable<T>, selector: fun(item: T): any): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = make_next_func(function(value)
                        return not predicate_or_selector(table.unpack(value))
                    end)
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 1,    type = "string" },
                { type = "nil" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, predicate: string): enumerable<T>
            function(_)
                local is_predicate = string.find(predicate_or_selector --[[@as string]], "=>") ~= nil
                local predicate
                if is_predicate then
                    predicate = compileEnumerableStringExpression(predicate_or_selector, "predicate")
                else
                    predicate = makeValuePropertySelector(predicate_or_selector)
                end
                return setmetatable({
                    __src = self,
                    __next = make_next_func(function(value)
                        return not predicate(table.unpack(value))
                    end)
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 1,    type = "table" },
                { type = "nil" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, predicate: table): enumerable<T>
            function(_)
                local comparer = linq.TABLE_SUPERSET
                return setmetatable({
                    __src = self,
                    __next = make_next_func(function(value)
                        return not comparer:compare(value[#value], predicate_or_selector)
                    end)
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 2,       type = "table" },
                { type = "table", ext_type = "equality_comparer" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, predicate: table, equality_comparer: equality_comparer): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = make_next_func(function(value)
                        return not value_or_comparer:compare(value[#value], predicate_or_selector)
                    end)
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 3,       type = "function" },
                {},
                { type = "table", ext_type = "equality_comparer" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: fun(item: T): any, value: any, equality_comparer: equality_comparer): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = make_next_func(function(value)
                        return not equality_comparer:compare(predicate_or_selector(table.unpack(value)),
                            value_or_comparer)
                    end)
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 2,    type = "function" },
                {},
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: fun(item: T): any, value: any): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = make_next_func(function(value)
                        return not (predicate_or_selector(table.unpack(value)) == value_or_comparer)
                    end)
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 2,    type = "string" },
                {},
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string, value: any): enumerable<T>
            function(_)
                local is_predicate = string.find(predicate_or_selector --[[@as string]], "=>") ~= nil
                local predicate
                if is_predicate then
                    predicate = compileEnumerableStringExpression(predicate_or_selector, "predicate")
                else
                    predicate = makeValuePropertySelector(predicate_or_selector)
                end
                return setmetatable({
                    __src = self,
                    __next = make_next_func(function(value)
                        return not (predicate(table.unpack(value)) == value_or_comparer)
                    end)
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 3,       type = "string" },
                {},
                { type = "table", ext_type = "equality_comparer" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string, value: any, equality_comparer: equality_comparer): enumerable<T>
            function(_)
                local is_predicate = string.find(predicate_or_selector --[[@as string]], "=>") ~= nil
                local predicate
                if is_predicate then
                    predicate = compileEnumerableStringExpression(predicate_or_selector, "predicate")
                else
                    predicate = makeValuePropertySelector(predicate_or_selector)
                end
                return setmetatable({
                    __src = self,
                    __next = make_next_func(function(value)
                        return not equality_comparer:compare(predicate(table.unpack(value)), value_or_comparer)
                    end)
                }, makeEnumerableMeta())
            end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:where", signature, existing_signatures or {})
        end)
        :result()
end

---@generic TI, TO, KI, KO, VI, VO
---@overload fun(self: enumerable<TI>, selector: fun(item: TI): (TO)): enumerable<TO>
---@overload fun(self: enumerable<KI, VI>, selector: fun(key: KI, value: VI): (TO)): enumerable<TO>
---@overload fun(self: enumerable<KI, VI>, selector: fun(key: KI, value: VI): (KO, VO)): enumerable<KO, VO>
---@overload fun(self: enumerable<TI>, selector: string): enumerable<any>|enumerable<any, any>
---@overload fun(self: enumerable<KI, VI>, selector: string): enumerable<any>|enumerable<any, any>
function enumerable_impl:select(...)
    local argc = select("#", ...)
    local selector = select(1, ...)

    return map({
            makeArgDescriptor(selector, argc)
        })
        :track_cases()
        :case({
                { argc = 1, type = "function" }
            },
            ---@generic T, U
            ---@type fun(self: enumerable<T>, selector: fun(item: T): U): enumerable<U>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = { enumerable.__src.__next(iter, enumerable.__src) }
                        if #value == 0 then
                            return nil
                        end
                        return selector(table.unpack(value))
                    end
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 1, type = "string" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string): enumerable<any>|enumerable<any, any>
            function(_)
                local is_predicate = string.find(selector --[[@as string]], "=>") ~= nil
                local selector_func
                if is_predicate then
                    selector_func = compileEnumerableStringExpression(selector, "selector")
                else
                    selector_func = makeValuePropertySelector(selector)
                end
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = { enumerable.__src.__next(iter, enumerable.__src) }
                        if #value == 0 then
                            return nil
                        end
                        return selector_func(table.unpack(value))
                    end
                }, makeEnumerableMeta())
            end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:select", signature, existing_signatures or {})
        end)
        :result()
end

---@generic TI, TO, TFO, KI, VI
---@overload fun(self: enumerable<TI>, consumer: fun(enum: iter<TI>): (TO)): TO
---@overload fun(self: enumerable<KI, VI>, consumer: fun(enum: iter<KI, VI>): (TO)): TO
---@overload fun(self: enumerable<TI>, constructor: fun(): (TO), consumer: fun(acc: TO, item: TI)): TO
---@overload fun(self: enumerable<KI, VI>, constructor: fun(): (TO), consumer: fun(acc: TO, key: KI, value: VI)): TO
---@overload fun(self: enumerable<TI>, constructor: fun(): (TO), consumer: fun(acc: TO, item: TI), finalizer: fun(acc: TO): (TFO)): TFO
---@overload fun(self: enumerable<KI, VI>, constructor: fun(): (TO), consumer: fun(acc: TO, key: KI, value: VI), finalizer: fun(acc: TO): (TFO)): TFO
function enumerable_impl:collect(...)
    local argc = select("#", ...)
    local consumer_or_constructor = select(1, ...)
    local consumer = select(2, ...)
    local finalizer = select(3, ...)

    return map({
            makeArgDescriptor(consumer_or_constructor, argc),
            makeArgDescriptor(consumer),
            makeArgDescriptor(finalizer)
        })
        :track_cases()
        :case({
                { argc = 1,    type = "function" },
                { type = "nil" },
                { type = "nil" }
            },
            ---@generic T, U
            ---@type fun(self: enumerable<T>, consumer: fun(enum: iter<T>): U): U
            function(_)
                return consumer_or_constructor(self:iter())
            end)
        :case({
                { argc = 2,         type = "function" },
                { type = "function" },
                { type = "nil" }
            },
            ---@generic T, U
            ---@type fun(self: enumerable<T>, constructor: fun(): U, consumer: fun(acc: U, item: T)): U
            function(_)
                local acc = consumer_or_constructor()
                local iter = self:iter()
                local item = { iter() }
                while #item ~= 0 do
                    consumer(acc, table.unpack(item))
                    item = { iter() }
                end
                return acc
            end)
        :case({
                { argc = 3,         type = "function" },
                { type = "function" },
                { type = "function" }
            },
            ---@generic T, U
            ---@type fun(self: enumerable<T>, constructor: fun(): U, consumer: fun(acc: U, item: T), finalizer: fun(acc: U): U): U
            function(_)
                local acc = consumer_or_constructor()
                local iter = self:iter()
                local item = { iter() }
                while #item ~= 0 do
                    consumer(acc, table.unpack(item))
                    item = { iter() }
                end
                return finalizer(acc)
            end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:collect", signature, existing_signatures or {})
        end)
        :result()
end

---@generic T, K, V
---@overload fun(self: enumerable<T>): boolean
---@overload fun(self: enumerable<K, V>): boolean
---@overload fun(self: enumerable<T>, predicate: fun(item: T): (boolean)): boolean
---@overload fun(self: enumerable<K, V>, predicate: fun(key: K, value: V): (boolean)): boolean
---@overload fun(self: enumerable<T>, predicate: string): boolean
---@overload fun(self: enumerable<K, V>, predicate: string): boolean
function enumerable_impl:any(...)
    local argc = select("#", ...)
    local predicate = select(1, ...)

    return map({
            makeArgDescriptor(predicate, argc)
        })
        :track_cases()
        :case({
                { argc = 0, type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>): boolean
            function(_)
                for _ in self:iter() do
                    return true
                end
                return false
            end)
        :case({
                { argc = 1, type = "function" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, predicate: fun(item: T): (boolean)): boolean
            function(_)
                local iter = self:iter()
                local value = { iter() }
                while #value ~= 0 do
                    if predicate(table.unpack(value)) then
                        return true
                    end
                    value = { iter() }
                end
                return false
            end)
        :case({
                { argc = 1, type = "string" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, predicate: string): boolean
            function(_)
                local is_predicate = string.find(predicate --[[@as string]], "=>") ~= nil
                local predicate_func
                if is_predicate then
                    predicate_func = compileEnumerableStringExpression(predicate, "predicate")
                else
                    predicate_func = makeValuePropertySelector(predicate)
                end

                local iter = self:iter()
                local value = { iter() }
                while #value ~= 0 do
                    if predicate_func(table.unpack(value)) then
                        return true
                    end
                    value = { iter() }
                end
                return false
            end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:any", signature, existing_signatures or {})
        end)
        :result()
end

---@generic T, K, V
---@overload fun(self: enumerable<T>): T
---@overload fun(self: enumerable<K, V>): V
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any)): any
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any)): any
---@overload fun(self: enumerable<T>, selector: string): any
---@overload fun(self: enumerable<K, V>, selector: string): any
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any), is_bigger: fun(a: any, b: any): (boolean)): any
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), is_bigger: fun(a: any, b: any): (boolean)): any
---@overload fun(self: enumerable<T>, selector: string, is_bigger: fun(a: any, b: any): (boolean)): any
---@overload fun(self: enumerable<K, V>, selector: string, is_bigger: fun(a: any, b: any): (boolean)): any
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any), is_bigger: string): any
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), is_bigger: string): any
---@overload fun(self: enumerable<T>, selector: string, is_bigger: string): any
---@overload fun(self: enumerable<K, V>, selector: string, is_bigger: string): any
function enumerable_impl:max(...)
    local argc = select("#", ...)
    local selector_or_is_bigger = select(1, ...)
    local is_bigger = select(2, ...)

    return map({
            makeArgDescriptor(selector_or_is_bigger, argc),
            makeArgDescriptor(is_bigger)
        })
        :track_cases()
        :case({
                { argc = 0,    type = "nil" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>): T
            function(_)
                local iter = self:iter()
                local value = { iter() }
                local max_value
                while #value ~= 0 do
                    if (max_value == nil) or (value[#value] > max_value) then
                        max_value = value[#value]
                    end
                    value = { iter() }
                end
                return max_value
            end)
        :case({
                { argc = 1,    type = "function" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: fun(item: T): any): any
            function(_)
                local iter = self:iter()
                local value = { iter() }
                local max_value
                while #value ~= 0 do
                    local projected_value = selector_or_is_bigger(table.unpack(value))
                    if (max_value == nil) or (projected_value > max_value) then
                        max_value = projected_value
                    end
                    value = { iter() }
                end
                return max_value
            end)
        :case({
                { argc = 1,    type = "string" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string): any
            function(_)
                local is_predicate = string.find(selector_or_is_bigger --[[@as string]], "=>") ~= nil
                local selector_func
                if is_predicate then
                    selector_func = compileEnumerableStringExpression(selector_or_is_bigger, "selector")
                else
                    selector_func = makeValuePropertySelector(selector_or_is_bigger)
                end

                local iter = self:iter()
                local value = { iter() }
                local max_value
                while #value ~= 0 do
                    local projected_value = selector_func(table.unpack(value))
                    if (max_value == nil) or (projected_value > max_value) then
                        max_value = projected_value
                    end
                    value = { iter() }
                end
                return max_value
            end)
        :case({
                { argc = 2,         type = "function" },
                { type = "function" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: fun(item: T): any, is_bigger: fun(a: any, b: any): (boolean)): any
            function(_)
                local iter = self:iter()
                local value = { iter() }
                local max_value
                while #value ~= 0 do
                    local projected_value = selector_or_is_bigger(table.unpack(value))
                    if (max_value == nil) or is_bigger(projected_value, max_value) then
                        max_value = projected_value
                    end
                    value = { iter() }
                end
                return max_value
            end)
        :case({
                { argc = 2,         type = "string" },
                { type = "function" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string, is_bigger: fun(a: any, b: any): (boolean)): any
            function(_)
                local is_predicate = string.find(selector_or_is_bigger --[[@as string]], "=>") ~= nil
                local selector_func
                if is_predicate then
                    selector_func = compileEnumerableStringExpression(selector_or_is_bigger, "selector")
                else
                    selector_func = makeValuePropertySelector(selector_or_is_bigger)
                end

                local iter = self:iter()
                local value = { iter() }
                local max_value
                while #value ~= 0 do
                    local projected_value = selector_func(table.unpack(value))
                    if (max_value == nil) or is_bigger(projected_value, max_value) then
                        max_value = projected_value
                    end
                    value = { iter() }
                end
                return max_value
            end)
        :case({
                { argc = 2,       type = "function" },
                { type = "string" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: fun(item: T): any, is_bigger: string): any
            function(_)
                local is_predicate = string.find(is_bigger --[[@as string]], "=>") ~= nil
                if not is_predicate then
                    error("Expected a function for is_bigger parameter, got string without lambda expression: " ..
                        is_bigger)
                end
                local is_bigger_func = compileEnumerableStringExpression(is_bigger, "is_bigger")
                local iter = self:iter()
                local value = { iter() }
                local max_value
                while #value ~= 0 do
                    local projected_value = selector_or_is_bigger(table.unpack(value))
                    if (max_value == nil) or is_bigger_func(projected_value, max_value) then
                        max_value = projected_value
                    end
                    value = { iter() }
                end
                return max_value
            end)
        :case({
                { argc = 2,       type = "string" },
                { type = "string" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string, is_bigger: string): any
            function(_)
                local is_selector_predicate = string.find(selector_or_is_bigger --[[@as string]], "=>") ~= nil
                local selector_func
                if is_selector_predicate then
                    selector_func = compileEnumerableStringExpression(selector_or_is_bigger, "selector")
                else
                    selector_func = makeValuePropertySelector(selector_or_is_bigger)
                end

                local is_bigger_predicate = string.find(is_bigger --[[@as string]], "=>") ~= nil
                if not is_bigger_predicate then
                    error("Expected a function for is_bigger parameter, got string without lambda expression: " ..
                        is_bigger)
                end
                local is_bigger_func = compileEnumerableStringExpression(is_bigger, "is_bigger")

                local iter = self:iter()
                local value = { iter() }
                local max_value
                while #value ~= 0 do
                    local projected_value = selector_func(table.unpack(value))
                    if (max_value == nil) or is_bigger_func(projected_value, max_value) then
                        max_value = projected_value
                    end
                    value = { iter() }
                end
                return max_value
            end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:max", signature, existing_signatures or {})
        end)
        :result()
end

---@generic T, K, V
---@overload fun(self: enumerable<T>): T
---@overload fun(self: enumerable<K, V>): V
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any)): any
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any)): any
---@overload fun(self: enumerable<T>, selector: string): any
---@overload fun(self: enumerable<K, V>, selector: string): any
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any), is_smaller: fun(a: any, b: any): (boolean)): any
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), is_smaller: fun(a: any, b: any): (boolean)): any
---@overload fun(self: enumerable<T>, selector: string, is_smaller: fun(a: any, b: any): (boolean)): any
---@overload fun(self: enumerable<K, V>, selector: string, is_smaller: fun(a: any, b: any): (boolean)): any
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any), is_smaller: string): any
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), is_smaller: string): any
---@overload fun(self: enumerable<T>, selector: string, is_smaller: string): any
---@overload fun(self: enumerable<K, V>, selector: string, is_smaller: string): any
function enumerable_impl:min(...)
    local argc = select("#", ...)
    local selector_or_is_smaller = select(1, ...)
    local is_smaller = select(2, ...)

    return map({
            makeArgDescriptor(selector_or_is_smaller, argc),
            makeArgDescriptor(is_smaller)
        })
        :track_cases()
        :case({
                { argc = 0,    type = "nil" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>): T
            function(_)
                local iter = self:iter()
                local value = { iter() }
                local min_value
                while #value ~= 0 do
                    if (min_value == nil) or (value[#value] < min_value) then
                        min_value = value[#value]
                    end
                    value = { iter() }
                end
                return min_value
            end)
        :case({
                { argc = 1,    type = "function" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: fun(item: T): any): any
            function(_)
                local iter = self:iter()
                local value = { iter() }
                local min_value
                while #value ~= 0 do
                    local projected_value = selector_or_is_smaller(table.unpack(value))
                    if (min_value == nil) or (projected_value < min_value) then
                        min_value = projected_value
                    end
                    value = { iter() }
                end
                return min_value
            end)
        :case({
                { argc = 1,    type = "string" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string): any
            function(_)
                local is_predicate = string.find(selector_or_is_smaller --[[@as string]], "=>") ~= nil
                local selector_func
                if is_predicate then
                    selector_func = compileEnumerableStringExpression(selector_or_is_smaller, "selector")
                else
                    selector_func = makeValuePropertySelector(selector_or_is_smaller)
                end

                local iter = self:iter()
                local value = { iter() }
                local min_value
                while #value ~= 0 do
                    local projected_value = selector_func(table.unpack(value))
                    if (min_value == nil) or (projected_value < min_value) then
                        min_value = projected_value
                    end
                    value = { iter() }
                end
                return min_value
            end)
        :case({
                { argc = 2,         type = "function" },
                { type = "function" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: fun(item: T): any, is_smaller: fun(a: any, b: any): (boolean)): any
            function(_)
                local iter = self:iter()
                local value = { iter() }
                local min_value
                while #value ~= 0 do
                    local projected_value = selector_or_is_smaller(table.unpack(value))
                    if (min_value == nil) or is_smaller(projected_value, min_value) then
                        min_value = projected_value
                    end
                    value = { iter() }
                end
                return min_value
            end)
        :case({
                { argc = 2,         type = "string" },
                { type = "function" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string, is_smaller: fun(a: any, b: any): (boolean)): any
            function(_)
                local is_predicate = string.find(selector_or_is_smaller --[[@as string]], "=>") ~= nil
                local selector_func
                if is_predicate then
                    selector_func = compileEnumerableStringExpression(selector_or_is_smaller, "selector")
                else
                    selector_func = makeValuePropertySelector(selector_or_is_smaller)
                end

                local iter = self:iter()
                local value = { iter() }
                local min_value
                while #value ~= 0 do
                    local projected_value = selector_func(table.unpack(value))
                    if (min_value == nil) or is_smaller(projected_value, min_value) then
                        min_value = projected_value
                    end
                    value = { iter() }
                end
                return min_value
            end)
        :case({
                { argc = 2,       type = "function" },
                { type = "string" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: fun(item: T): any, is_smaller: string): any
            function(_)
                local is_predicate = string.find(is_smaller --[[@as string]], "=>") ~= nil
                if not is_predicate then
                    error("Expected a function for is_smaller parameter, got string without lambda expression: " ..
                        is_smaller)
                end
                local is_smaller_func = compileEnumerableStringExpression(is_smaller, "is_smaller")
                local iter = self:iter()
                local value = { iter() }
                local min_value
                while #value ~= 0 do
                    local projected_value = selector_or_is_smaller(table.unpack(value))
                    if (min_value == nil) or is_smaller_func(projected_value, min_value) then
                        min_value = projected_value
                    end
                    value = { iter() }
                end
                return min_value
            end)
        :case({
                { argc = 2,       type = "string" },
                { type = "string" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string, is_smaller: string): any
            function(_)
                local is_selector_predicate = string.find(selector_or_is_smaller --[[@as string]], "=>") ~= nil
                local selector_func
                if is_selector_predicate then
                    selector_func = compileEnumerableStringExpression(selector_or_is_smaller, "selector")
                else
                    selector_func = makeValuePropertySelector(selector_or_is_smaller)
                end

                local is_smaller_predicate = string.find(is_smaller --[[@as string]], "=>") ~= nil
                if not is_smaller_predicate then
                    error("Expected a function for is_smaller parameter, got string without lambda expression: " ..
                        is_smaller)
                end
                local is_smaller_func = compileEnumerableStringExpression(is_smaller, "is_smaller")

                local iter = self:iter()
                local value = { iter() }
                local min_value
                while #value ~= 0 do
                    local projected_value = selector_func(table.unpack(value))
                    if (min_value == nil) or is_smaller_func(projected_value, min_value) then
                        min_value = projected_value
                    end
                    value = { iter() }
                end
                return min_value
            end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:min", signature, existing_signatures or {})
        end)
        :result()
end

---@generic T, K, V, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10
---@overload fun(self: enumerable<T>): enumerable<T>, enumerable<T>
---@overload fun(self: enumerable<K, V>): enumerable<K, V>, enumerable<K, V>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2)): enumerable<R1|R2>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2)): enumerable<R1|R2>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3)): enumerable<R1|R2|R3>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3)): enumerable<R1|R2|R3>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4)): enumerable<R1|R2|R3|R4>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4)): enumerable<R1|R2|R3|R4>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4), fork5: fun(enumerable: enumerable<T>): (R5)): enumerable<R1|R2|R3|R4|R5>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4), fork5: fun(enumerable: enumerable<K, V>): (R5)): enumerable<R1|R2|R3|R4|R5>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4), fork5: fun(enumerable: enumerable<T>): (R5), fork6: fun(enumerable: enumerable<T>): (R6)): enumerable<R1|R2|R3|R4|R5|R6>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4), fork5: fun(enumerable: enumerable<K, V>): (R5), fork6: fun(enumerable: enumerable<K, V>): (R6)): enumerable<R1|R2|R3|R4|R5|R6>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4), fork5: fun(enumerable: enumerable<T>): (R5), fork6: fun(enumerable: enumerable<T>): (R6), fork7: fun(enumerable: enumerable<T>): (R7)): enumerable<R1|R2|R3|R4|R5|R6|R7>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4), fork5: fun(enumerable: enumerable<K, V>): (R5), fork6: fun(enumerable: enumerable<K, V>): (R6), fork7: fun(enumerable: enumerable<K, V>): (R7)): enumerable<R1|R2|R3|R4|R5|R6|R7>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4), fork5: fun(enumerable: enumerable<T>): (R5), fork6: fun(enumerable: enumerable<T>): (R6), fork7: fun(enumerable: enumerable<T>): (R7), fork8: fun(enumerable: enumerable<T>): (R8)): enumerable<R1|R2|R3|R4|R5|R6|R7|R8>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4), fork5: fun(enumerable: enumerable<K, V>): (R5), fork6: fun(enumerable: enumerable<K, V>): (R6), fork7: fun(enumerable: enumerable<K, V>): (R7), fork8: fun(enumerable: enumerable<K, V>): (R8)): enumerable<R1|R2|R3|R4|R5|R6|R7|R8>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4), fork5: fun(enumerable: enumerable<T>): (R5), fork6: fun(enumerable: enumerable<T>): (R6), fork7: fun(enumerable: enumerable<T>): (R7), fork8: fun(enumerable: enumerable<T>): (R8), fork9: fun(enumerable: enumerable<T>): (R9)): enumerable<R1|R2|R3|R4|R5|R6|R7|R8|R9>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4), fork5: fun(enumerable: enumerable<K, V>): (R5), fork6: fun(enumerable: enumerable<K, V>): (R6), fork7: fun(enumerable: enumerable<K, V>): (R7), fork8: fun(enumerable: enumerable<K, V>): (R8), fork9: fun(enumerable: enumerable<K, V>): (R9)): enumerable<R1|R2|R3|R4|R5|R6|R7|R8|R9>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4), fork5: fun(enumerable: enumerable<T>): (R5), fork6: fun(enumerable: enumerable<T>): (R6), fork7: fun(enumerable: enumerable<T>): (R7), fork8: fun(enumerable: enumerable<T>): (R8), fork9: fun(enumerable: enumerable<T>): (R9), fork10: fun(enumerable: enumerable<T>): (R10)): enumerable<R1|R2|R3|R4|R5|R6|R7|R8|R9|R10>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4), fork5: fun(enumerable: enumerable<K, V>): (R5), fork6: fun(enumerable: enumerable<K, V>): (R6), fork7: fun(enumerable: enumerable<K, V>): (R7), fork8: fun(enumerable: enumerable<K, V>): (R8), fork9: fun(enumerable: enumerable<K, V>): (R9), fork10: fun(enumerable: enumerable<K, V>): (R10)): enumerable<R1|R2|R3|R4|R5|R6|R7|R8|R9|R10>
function enumerable_impl:fork(...)
    local argc = select("#", ...)
    local forks = { ... }

    return map({
            makeArgDescriptor(forks[1], argc),
            makeArgDescriptor(forks[2]),
            makeArgDescriptor(forks[3]),
            makeArgDescriptor(forks[4]),
            makeArgDescriptor(forks[5]),
            makeArgDescriptor(forks[6]),
            makeArgDescriptor(forks[7]),
            makeArgDescriptor(forks[8]),
            makeArgDescriptor(forks[9]),
            makeArgDescriptor(forks[10])
        })
        :track_cases()
        :case({
            { argc = 0, type = "nil" },
            {},
            {},
            {},
            {},
            {},
            {},
            {},
            {},
            {}
        }, function(_)
            return self, self
        end)
        :case({
            { argc = 2,         type = "function" },
            { type = "function" },
            {},
            {},
            {},
            {},
            {},
            {},
            {},
            {}
        })
        :case({
            { argc = 3,         type = "function" },
            { type = "function" },
            { type = "function" },
            {},
            {},
            {},
            {},
            {},
            {},
            {}
        })
        :case({
            { argc = 4,         type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            {},
            {},
            {},
            {},
            {},
            {}
        })
        :case({
            { argc = 5,         type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            {},
            {},
            {},
            {},
            {}
        })
        :case({
            { argc = 6,         type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            {},
            {},
            {},
            {}
        })
        :case({
            { argc = 7,         type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            {},
            {},
            {}
        })
        :case({
            { argc = 8,         type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            {},
            {}
        })
        :case({
            { argc = 9,         type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            {}
        })
        :case({
            { argc = 10,        type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" },
            { type = "function" }
        }, function(_)
            local results = {}
            for i = 1, argc do
                local value = forks[i](self)
                if value ~= nil then
                    table.insert(results, value)
                end
            end
            return setmetatable({
                __src = results,
                __next = function(iter, enumerable)
                    validateIter(iter)

                    iter.__data = iter.__data or {}
                    if iter.__data.idx == nil then
                        iter.__data.idx = 1
                    end
                    local value = enumerable.__src[iter.__data.idx]
                    iter.__data.idx = iter.__data.idx + 1
                    return value
                end
            }, makeEnumerableMeta())
        end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:fork", signature, existing_signatures or {})
        end)
        :result()
end

---@generic T, K, V
---@overload fun(self: enumerable<T>): ...: T
---@overload fun(self: enumerable<K, V>): ...: { [1]: K, [2]: V }
---@overload fun(self: enumerable<K, V>, mode: "Pairs"): ...: { [1]: K, [2]: V }
---@overload fun(self: enumerable<K, V>, mode: "Keys"): ...: K
---@overload fun(self: enumerable<K, V>, mode: "Values"): ...: V
---@overload fun(self: enumerable<K, V>, mode: "Interwoven"): ...: K|V
function enumerable_impl:spread(...)
    local argc = select("#", ...)
    local arg = select(1, ...)

    return map({
            makeArgDescriptor(arg, argc, arg)
        })
        :track_cases()
        :case({
            { argc = 0, type = "nil" }
        })
        :case({
                { argc = 1, type = "string", literal = "Pairs" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>): ...: T
            ---@generic K, V
            ---@type fun(self: enumerable<K, V>): ...: { [1]: K, [2]: V }
            ---@generic K, V
            ---@type fun(self: enumerable<K, V>, mode: "Pairs"): ...: { [1]: K, [2]: V }
            function(_)
                local iter = self:iter()
                local item = { iter() }
                local items = {}
                while #item ~= 0 do
                    if #item == 1 then
                        table.insert(items, item[1])
                    else
                        table.insert(items, item)
                    end
                    item = { iter() }
                end
                return table.unpack(items)
            end)
        :case({
                { argc = 1, type = "string", literal = "Keys" }
            },
            ---@generic K, V
            ---@type fun(self: enumerable<K, V>, mode: "Keys"): ...: K
            function(_)
                local iter = self:iter()
                local key = iter();
                local keys = {}
                while key ~= nil do
                    table.insert(keys, key)
                    key = iter()
                end
                return table.unpack(keys)
            end)
        :case({
                { argc = 1, type = "string", literal = "Values" }
            },
            ---@generic K, V
            ---@type fun(self: enumerable<K, V>, mode: "Values"): ...: V
            function(_)
                local iter = self:iter()
                local value = { iter() }
                local values = {}
                while #value ~= 0 do
                    table.insert(values, value[#value])
                    value = { iter() }
                end
                return table.unpack(values)
            end)
        :case({
                { argc = 1, type = "string", literal = "Interwoven" }
            },
            ---@generic K, V
            ---@type fun(self: enumerable<K, V>, mode: "Interwoven"): ...: K|V
            function(_)
                local iter = self:iter()
                local item = { iter() }
                local items = {}
                while #item ~= 0 do
                    for _, value in ipairs(item) do
                        table.insert(items, value)
                    end
                    item = { iter() }
                end
                return table.unpack(items)
            end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:spread", signature, existing_signatures or {})
        end)
        :result()
end

---@generic T, K, V, R
---@overload fun(self: enumerable<T>): T
---@overload fun(self: enumerable<K, V>): (K, V)
---@overload fun(self: enumerable<T>, selector: fun(item: T): (R)): R
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (R)): R
---@overload fun(self: enumerable<T>, selector: string): any
---@overload fun(self: enumerable<K, V>, selector: string): any
function enumerable_impl:first(...)
    local argc = select("#", ...)
    local selector = select(1, ...)

    return map({
            makeArgDescriptor(selector, argc)
        })
        :track_cases()
        :case({
                { argc = 0, type = "nil" },
            },
            ---@generic T
            ---@type fun(self: enumerable<T>): T
            function(_)
                local iter = self:iter()
                return iter()
            end)
        :case({
                { argc = 1, type = "function" },
            },
            ---@generic T, R
            ---@type fun(self: enumerable<T>, selector: fun(item: T): (R)): R
            function(_)
                local iter = self:iter()
                local item = { iter() }
                if #item ~= 0 then
                    local projected_value = selector(table.unpack(item))
                    if projected_value ~= nil then
                        return projected_value
                    else
                        return nil
                    end
                end
                return nil
            end)
        :case({
                { argc = 1, type = "string" },
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string): any
            function(_)
                local is_predicate = string.find(selector --[[@as string]], "=>") ~= nil
                local selector_func
                if is_predicate then
                    selector_func = compileEnumerableStringExpression(selector, "selector")
                else
                    selector_func = makeValuePropertySelector(selector)
                end

                local iter = self:iter()
                local item = { iter() }
                if #item ~= 0 then
                    local projected_value = selector_func(table.unpack(item))
                    if projected_value ~= nil then
                        return projected_value
                    else
                        return nil
                    end
                    item = { iter() }
                end
                return nil
            end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:first", signature, existing_signatures or {})
        end)
        :result()
end

---@generic T, K, V, R
---@overload fun(self: enumerable<T>): T
---@overload fun(self: enumerable<K, V>): (K, V)
---@overload fun(self: enumerable<T>, selector: fun(item: T): (R)): R
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (R)): R
---@overload fun(self: enumerable<T>, selector: string): any
---@overload fun(self: enumerable<K, V>, selector: string): any
function enumerable_impl:last(...)
    local argc = select("#", ...)
    local selector = select(1, ...)

    return map({
            makeArgDescriptor(selector, argc)
        })
        :track_cases()
        :case({
                { argc = 0, type = "nil" },
            },
            ---@generic T
            ---@type fun(self: enumerable<T>): T
            function(_)
                local iter = self:iter()
                local item = { iter() }
                local last_item = item

                while #item ~= 0 do
                    last_item = item
                    item = { iter() }
                end

                return table.unpack(last_item)
            end)
        :case({
                { argc = 1, type = "function" },
            },
            ---@generic T, R
            ---@type fun(self: enumerable<T>, selector: fun(item: T): (R)): R
            function(_)
                local iter = self:iter()
                local item = { iter() }
                local last_item = item

                while #item ~= 0 do
                    last_item = item
                    item = { iter() }
                end

                if #last_item ~= 0 then
                    local projected_value = selector(table.unpack(last_item))
                    if projected_value ~= nil then
                        return projected_value
                    else
                        return nil
                    end
                end
                return nil
            end)
        :case({
                { argc = 1, type = "string" },
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string): any
            function(_)
                local is_predicate = string.find(selector --[[@as string]], "=>") ~= nil
                local selector_func
                if is_predicate then
                    selector_func = compileEnumerableStringExpression(selector, "selector")
                else
                    selector_func = makeValuePropertySelector(selector)
                end

                local iter = self:iter()
                local item = { iter() }
                local last_item = item

                while #item ~= 0 do
                    last_item = item
                    item = { iter() }
                end

                if #last_item ~= 0 then
                    local projected_value = selector_func(table.unpack(last_item))
                    if projected_value ~= nil then
                        return projected_value
                    else
                        return nil
                    end
                end
                return nil
            end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:last", signature, existing_signatures or {})
        end)
        :result()
end

---@generic T, K, V, R1, R2
---@overload fun(self: enumerable<T>): enumerable<T>
---@overload fun(self: enumerable<K, V>): enumerable<K, V>
---@overload fun(self: enumerable<T>, comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<K, V>, comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any), comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: enumerable<T>, selector: string|nil, comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<K, V>, selector: string|nil, comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any)): enumerable<T>
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any)): enumerable<K, V>
---@overload fun(self: enumerable<T>, selector: string): enumerable<any>
---@overload fun(self: enumerable<K, V>, selector: string): enumerable<any, any>
---@overload fun(self: enumerable<T>, selector: fun(item: T): (R1), comparer: fun(a: R1, b: R1): (boolean)): enumerable<T>
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (R1), comparer: fun(value1: R1, value2: R1): (boolean)): enumerable<K, V>
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (R1, R2), comparer: fun(key1: R1, value1: R2, key2: R1, value2: R2): (boolean)): enumerable<K, V>
---@overload fun(self: enumerable<T>, selector: string|nil, comparer: fun(a: any, b: any): (boolean)): enumerable<T>
---@overload fun(self: enumerable<K, V>, selector: string|nil, comparer: fun(value1: any, value2: any): (boolean)): enumerable<K, V>
---@overload fun(self: enumerable<T>, selector: string|nil, comparer: string): enumerable<T>
---@overload fun(self: enumerable<K, V>, selector: string|nil, comparer: string): enumerable<K, V>
function enumerable_impl:sort(...)
    local argc = select("#", ...)
    local selector_or_comparer = select(1, ...)
    local comparer = select(2, ...)

    ---@param selector (fun(...: any): (any))|nil
    ---@param cmp equality_comparer|(fun(a: any, b: any): (boolean))|nil
    ---@return fun(a: any, b: any): boolean
    local make_sort_callback = function(selector, cmp)
        return function(a, b)
            local projected_a
            local projected_b
            if selector ~= nil then
                projected_a = selector(table.unpack(a))
                projected_b = selector(table.unpack(b))
            else
                projected_a = a[#a]
                projected_b = b[#b]
            end
            if type(cmp) == "table" then
                projected_a, projected_b = cmp:compare(projected_a, projected_b, true)
            elseif type(cmp) == "function" then
                return cmp(projected_a, projected_b)
            end

            if projected_a == nil then
                return true
            elseif projected_b == nil then
                return false
            elseif type(projected_a) == "number" and type(projected_b) == "number" then
                return projected_a < projected_b
            else
                return tostring(projected_a) < tostring(projected_b)
            end
        end
    end

    return map({
            makeArgDescriptor(selector_or_comparer, argc),
            makeArgDescriptor(comparer)
        })
        :track_cases()
        :case({
                { argc = 0,    type = "nil" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>): enumerable<T>
            function(_)
                local data_key = get_per_table_uniq_key(self, "sort")
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        iter.__data = iter.__data or {}
                        if iter.__data[data_key] == nil then
                            local data = {}
                            local source_iter = enumerable.__src:iter()
                            local value = { source_iter() }
                            while #value ~= 0 do
                                table.insert(data, value)
                                value = { source_iter() }
                            end
                            table.sort(data, make_sort_callback(nil, nil))
                            data.idx = 1
                            iter.__data[data_key] = data
                        end

                        local value = iter.__data[data_key][iter.__data[data_key].idx]
                        if value == nil or #value == 0 then
                            return nil
                        end
                        iter.__data[data_key].idx = iter.__data[data_key].idx + 1
                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 1,    type = "table", ext_type = "equality_comparer" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, comparer: equality_comparer): enumerable<T>
            function(_)
                local data_key = get_per_table_uniq_key(self, "sort")
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        iter.__data = iter.__data or {}
                        if iter.__data[data_key] == nil then
                            local data = {}
                            local source_iter = enumerable.__src:iter()
                            local value = { source_iter() }
                            while #value ~= 0 do
                                table.insert(data, value)
                                value = { source_iter() }
                            end
                            table.sort(data, make_sort_callback(nil, selector_or_comparer --[[@as equality_comparer]]))
                            data.idx = 1
                            iter.__data[data_key] = data
                        end

                        local value = iter.__data[data_key][iter.__data[data_key].idx]
                        if value == nil or #value == 0 then
                            return nil
                        end
                        iter.__data[data_key].idx = iter.__data[data_key].idx + 1
                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 2,       type = "function" },
                { type = "table", ext_type = "equality_comparer" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: fun(item: T): (any), comparer: equality_comparer): enumerable<T>
            function(_)
                local data_key = get_per_table_uniq_key(self, "sort")
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        iter.__data = iter.__data or {}
                        if iter.__data[data_key] == nil then
                            local data = {}
                            local source_iter = enumerable.__src:iter()
                            local value = { source_iter() }
                            while #value ~= 0 do
                                table.insert(data, value)
                                value = { source_iter() }
                            end
                            table.sort(data,
                                make_sort_callback(selector_or_comparer --[[@as fun(...: any): (any)]],
                                    comparer --[[@as equality_comparer]]))
                            data.idx = 1
                            iter.__data[data_key] = data
                        end

                        local value = iter.__data[data_key][iter.__data[data_key].idx]
                        if value == nil or #value == 0 then
                            return nil
                        end
                        iter.__data[data_key].idx = iter.__data[data_key].idx + 1
                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end
        )
        :case({
            { argc = 2,       type = "string" },
            { type = "table", ext_type = "equality_comparer" }
        })
        :case({
                { argc = 2,       type = "nil" },
                { type = "table", ext_type = "equality_comparer" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string|nil, comparer: equality_comparer): enumerable<T>
            function(_)
                local selector_func
                if type(selector_or_comparer) == "string" then
                    local is_selector_predicate = string.find(selector_or_comparer --[[@as string]], "=>") ~= nil
                    if is_selector_predicate then
                        selector_func = compileEnumerableStringExpression(selector_or_comparer, "selector")
                    else
                        selector_func = makeValuePropertySelector(selector_or_comparer)
                    end
                else
                    selector_func = function(...)
                        return select(-1, ...)
                    end
                end
                local data_key = get_per_table_uniq_key(self, "sort")
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        iter.__data = iter.__data or {}
                        if iter.__data[data_key] == nil then
                            local data = {}
                            local source_iter = enumerable.__src:iter()
                            local value = { source_iter() }
                            while #value ~= 0 do
                                table.insert(data, value)
                                value = { source_iter() }
                            end
                            table.sort(data, make_sort_callback(selector_func, comparer --[[@as equality_comparer]]))
                            data.idx = 1
                            iter.__data[data_key] = data
                        end

                        local value = iter.__data[data_key][iter.__data[data_key].idx]
                        if value == nil or #value == 0 then
                            return nil
                        end
                        iter.__data[data_key].idx = iter.__data[data_key].idx + 1
                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 1,    type = "function" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: fun(item: T): (any)): enumerable<T>
            function(_)
                local data_key = get_per_table_uniq_key(self, "sort")
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        iter.__data = iter.__data or {}
                        if iter.__data[data_key] == nil then
                            local data = {}
                            local source_iter = enumerable.__src:iter()
                            local value = { source_iter() }
                            while #value ~= 0 do
                                table.insert(data, value)
                                value = { source_iter() }
                            end
                            table.sort(data, make_sort_callback(selector_or_comparer --[[@as fun(...: any): (any)]], nil))
                            data.idx = 1
                            iter.__data[data_key] = data
                        end

                        local value = iter.__data[data_key][iter.__data[data_key].idx]
                        if value == nil or #value == 0 then
                            return nil
                        end
                        iter.__data[data_key].idx = iter.__data[data_key].idx + 1
                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 1,    type = "string" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string): enumerable<T>
            function(_)
                local is_selector_predicate = string.find(selector_or_comparer --[[@as string]], "=>") ~= nil
                local selector_func
                if is_selector_predicate then
                    selector_func = compileEnumerableStringExpression(selector_or_comparer, "selector")
                else
                    selector_func = makeValuePropertySelector(selector_or_comparer)
                end
                local data_key = get_per_table_uniq_key(self, "sort")
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        iter.__data = iter.__data or {}
                        if iter.__data[data_key] == nil then
                            local data = {}
                            local source_iter = enumerable.__src:iter()
                            local value = { source_iter() }
                            while #value ~= 0 do
                                table.insert(data, value)
                                value = { source_iter() }
                            end
                            table.sort(data, make_sort_callback(selector_func, nil))
                            data.idx = 1
                            iter.__data[data_key] = data
                        end

                        local value = iter.__data[data_key][iter.__data[data_key].idx]
                        if value == nil or #value == 0 then
                            return nil
                        end
                        iter.__data[data_key].idx = iter.__data[data_key].idx + 1
                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :case({
                { argc = 2,         type = "function" },
                { type = "function" }
            },
            ---@generic T, R1
            ---@type fun(self: enumerable<T>, selector: fun(item: T): (R1), comparer: fun(a: R1, b: R1): (boolean)): enumerable<T>
            function(_)
                local data_key = get_per_table_uniq_key(self, "sort")
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        iter.__data = iter.__data or {}
                        if iter.__data[data_key] == nil then
                            local data = {}
                            local source_iter = enumerable.__src:iter()
                            local value = { source_iter() }
                            while #value ~= 0 do
                                table.insert(data, value)
                                value = { source_iter() }
                            end
                            table.sort(data,
                                make_sort_callback(selector_or_comparer --[[@as fun(...: any): (any)]],
                                    comparer --[[@as fun(a: any, b: any): (boolean)]]))
                            data.idx = 1
                            iter.__data[data_key] = data
                        end

                        local value = iter.__data[data_key][iter.__data[data_key].idx]
                        if value == nil or #value == 0 then
                            return nil
                        end
                        iter.__data[data_key].idx = iter.__data[data_key].idx + 1
                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :case({
            { argc = 2,         type = "string" },
            { type = "function" }
        })
        :case({
                { argc = 2,         type = "nil" },
                { type = "function" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string|nil, comparer: fun(a: any, b: any): (boolean)): enumerable<T>
            function(_)
                local selector_func
                if type(selector_or_comparer) == "string" then
                    local is_selector_predicate = string.find(selector_or_comparer --[[@as string]], "=>") ~= nil
                    if is_selector_predicate then
                        selector_func = compileEnumerableStringExpression(selector_or_comparer, "selector")
                    else
                        selector_func = makeValuePropertySelector(selector_or_comparer)
                    end
                else
                    selector_func = function(...)
                        return select(-1, ...)
                    end
                end
                local data_key = get_per_table_uniq_key(self, "sort")
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        iter.__data = iter.__data or {}
                        if iter.__data[data_key] == nil then
                            local data = {}
                            local source_iter = enumerable.__src:iter()
                            local value = { source_iter() }
                            while #value ~= 0 do
                                table.insert(data, value)
                                value = { source_iter() }
                            end
                            table.sort(data,
                                make_sort_callback(selector_func, comparer --[[@as fun(a: any, b: any): (boolean)]]))
                            data.idx = 1
                            iter.__data[data_key] = data
                        end

                        local value = iter.__data[data_key][iter.__data[data_key].idx]
                        if value == nil or #value == 0 then
                            return nil
                        end
                        iter.__data[data_key].idx = iter.__data[data_key].idx + 1
                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :case({
            { argc = 2,       type = "string" },
            { type = "string" }
        })
        :case({
                { argc = 2,       type = "nil" },
                { type = "string" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string|nil, comparer: string): enumerable<T>
            function(_)
                local selector_func
                if type(selector_or_comparer) == "string" then
                    local is_selector_predicate = string.find(selector_or_comparer --[[@as string]], "=>") ~= nil
                    if is_selector_predicate then
                        selector_func = compileEnumerableStringExpression(selector_or_comparer, "selector")
                    else
                        selector_func = makeValuePropertySelector(selector_or_comparer)
                    end
                else
                    selector_func = function(...)
                        return select(-1, ...)
                    end
                end
                local comparer_func = compileEnumerableStringExpression(comparer, "comparer")
                local data_key = get_per_table_uniq_key(self, "sort")
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        iter.__data = iter.__data or {}
                        if iter.__data[data_key] == nil then
                            local data = {}
                            local source_iter = enumerable.__src:iter()
                            local value = { source_iter() }
                            while #value ~= 0 do
                                table.insert(data, value)
                                value = { source_iter() }
                            end
                            table.sort(data,
                                make_sort_callback(selector_func, comparer_func --[[@as fun(a: any, b: any): (boolean)]]))
                            data.idx = 1
                            iter.__data[data_key] = data
                        end

                        local value = iter.__data[data_key][iter.__data[data_key].idx]
                        if value == nil or #value == 0 then
                            return nil
                        end
                        iter.__data[data_key].idx = iter.__data[data_key].idx + 1
                        return table.unpack(value)
                    end
                }, makeEnumerableMeta())
            end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:sort", signature, existing_signatures or {})
        end)
        :result()
end

---@generic T, K, V
---@overload fun(self: enumerable<T>, action: fun(item: T))
---@overload fun(self: enumerable<K, V>, action: fun(key: K, value: V))
---@overload fun(self: enumerable<T>, action: string)
---@overload fun(self: enumerable<K, V>, action: string)
function enumerable_impl:foreach(...)
    local argc = select("#", ...)
    local action = select(1, ...)

    return map({
            makeArgDescriptor(action, argc)
        })
        :track_cases()
        :case({
                { argc = 1, type = "function" },
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, action: fun(item: T))
            function(_)
                local iter = self:iter()
                local value = { iter() }
                while #value ~= 0 do
                    action(table.unpack(value))
                    value = { iter() }
                end
            end)
        :case({
                { argc = 1, type = "string" },
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, action: string)
            function(_)
                local action_func = compileEnumerableStringExpression(action, "action")
                local iter = self:iter()
                local value = { iter() }
                while #value ~= 0 do
                    action_func(table.unpack(value))
                    value = { iter() }
                end
            end)
        :default(function(signature, existing_signatures)
            error_invalid_signature("enumerable:foreach", signature, existing_signatures or {})
        end)
        :result()
end

---@generic T, K, V
---@overload fun(self: enumerable<T>): iter<T>
---@overload fun(self: enumerable<K, V>): iter<K, V>
function enumerable_impl:iter()
    validateEnumerable(self)

    return setmetatable({
        __itersrc = self,
    }, makeIterMeta(self))
end

---@generic T
---@param self enumerable<T>
---@return list<T>
function enumerable_impl:tolist()
    return linq.list(self)
end

local function list_impl_enumerable_next(iter, enumerator)
    validateIter(iter)

    iter.__data = iter.__data or {}
    if iter.__data.idx == nil then
        iter.__data.idx = 1
    end
    local value = enumerator.__src[iter.__data.idx]
    iter.__data.idx = iter.__data.idx + 1
    return value
end

---@generic T
---@param self list<T>
---@return enumerable<T>
function list_impl:enumerate()
    validateList(self)

    return setmetatable({
        __src = self,
        __next = list_impl_enumerable_next
    }, makeEnumerableMeta())
end

---@generic T
---@overload fun(self: list<T>): enumerable<T>
---@overload fun(self: list<T>, comparer: equality_comparer): enumerable<T>
---@overload fun(self: list<T>, keySelector: fun(item: T): (any)): enumerable<T>
---@overload fun(self: list<T>, keySelector: fun(item: T): (any), comparer: equality_comparer): enumerable<T>
---@overload fun(self: list<T>, keySelector: string): enumerable<T>
---@overload fun(self: list<T>, keySelector: string, comparer: equality_comparer): enumerable<T>
function list_impl:distinct(...)
    validateList(self)

    return self:enumerate():distinct(...)
end

---@generic T
---@overload fun(self: list<T>, predicate: fun(item: T): (boolean)): enumerable<T>
---@overload fun(self: list<T>, predicate: string): enumerable<T>
---@overload fun(self: list<T>, predicate: table): enumerable<T>
---@overload fun(self: list<T>, predicate: table, equality_comparer: equality_comparer): enumerable<T>
---@overload fun(self: list<T>, selector: fun(item: T): (any)): enumerable<T>
---@overload fun(self: list<T>, selector: fun(item: T): (any), value: any, equality_comparer: equality_comparer): enumerable<T>
---@overload fun(self: list<T>, selector: fun(item: T): (any), value: any): enumerable<T>
---@overload fun(self: list<T>, selector: string): enumerable<T>
---@overload fun(self: list<T>, selector: string, value: any): enumerable<T>
---@overload fun(self: list<T>, selector: string, value: any, equality_comparer: equality_comparer): enumerable<T>
function list_impl:where(...)
    validateList(self)

    return self:enumerate():where(...)
end

---@generic T, U
---@overload fun(self: list<T>, selector: fun(item: T): (U)): enumerable<U>
---@overload fun(self: list<T>, selector: string): enumerable<any>|enumerable<any, any>
function list_impl:select(...)
    validateList(self)

    return self:enumerate():select(...)
end

---@generic T, TO, TFO
---@overload fun(self: enumerable<T>, consumer: fun(enum: iter<T>): (TO)): TO
---@overload fun(self: enumerable<T>, constructor: fun(): (TO), consumer: fun(acc: TO, item: T)): TO
---@overload fun(self: enumerable<T>, constructor: fun(): (TO), consumer: fun(acc: TO, item: T), finalizer: fun(acc: TO): (TFO)): TFO
function list_impl:collect(...)
    validateList(self)

    return self:enumerate():collect(...)
end

---@generic T
---@overload fun(self: list<T>): boolean
---@overload fun(self: list<T>, predicate: fun(item: T): (boolean)): boolean
---@overload fun(self: list<T>, predicate: string): boolean
function list_impl:any(...)
    validateList(self)

    return self:enumerate():any(...)
end

---@generic T
---@overload fun(self: list<T>): T
---@overload fun(self: list<T>, selector: fun(item: T): (any)): any
---@overload fun(self: list<T>, selector: string): any
---@overload fun(self: list<T>, selector: fun(item: T): (any), is_bigger: fun(a: any, b: any): (boolean)): any
---@overload fun(self: list<T>, selector: string, is_bigger: fun(a: any, b: any): (boolean)): any
---@overload fun(self: list<T>, selector: fun(item: T): (any), is_bigger: string): any
---@overload fun(self: list<T>, selector: string, is_bigger: string): any
function list_impl:max(...)
    validateList(self)

    return self:enumerate():max(...)
end

---@generic T
---@overload fun(self: list<T>): T
---@overload fun(self: list<T>, selector: fun(item: T): (any)): any
---@overload fun(self: list<T>, selector: string): any
---@overload fun(self: list<T>, selector: fun(item: T): (any), is_smaller: fun(a: any, b: any): (boolean)): any
---@overload fun(self: list<T>, selector: string, is_smaller: fun(a: any, b: any): (boolean)): any
---@overload fun(self: list<T>, selector: fun(item: T): (any), is_smaller: string): any
---@overload fun(self: list<T>, selector: string, is_smaller: string): any
function list_impl:min(...)
    validateList(self)

    return self:enumerate():min(...)
end

---@generic T, R1
---@overload fun(self: list<T>): enumerable<T>
---@overload fun(self: list<T>, comparer: equality_comparer): enumerable<T>
---@overload fun(self: list<T>, selector: fun(item: T): (any), comparer: equality_comparer): enumerable<T>
---@overload fun(self: list<T>, selector: string|nil, comparer: equality_comparer): enumerable<T>
---@overload fun(self: list<T>, selector: fun(item: T): (any)): enumerable<T>
---@overload fun(self: list<T>, selector: string): enumerable<any>|enumerable<any, any>
---@overload fun(self: list<T>, selector: fun(item: T): (R1), comparer: fun(a: R1, b: R1): (boolean)): enumerable<T>
---@overload fun(self: list<T>, selector: string|nil, comparer: fun(a: any, b: any): (boolean)): enumerable<T>
---@overload fun(self: list<T>, selector: string|nil, comparer: string): enumerable<T>
function list_impl:sort(...)
    validateList(self)

    return self:enumerate():sort(...)
end

---@generic T
---@overload fun(self: list<T>, action: fun(item: T))
---@overload fun(self: list<T>, action: string)
function list_impl:foreach(...)
    validateList(self)

    return self:enumerate():foreach(...)
end

---@generic T, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10
---@overload fun(self: enumerable<T>): enumerable<T>, enumerable<T>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2)): enumerable<R1|R2>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3)): enumerable<R1|R2|R3>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4)): enumerable<R1|R2|R3|R4>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4), fork5: fun(enumerable: enumerable<T>): (R5)): enumerable<R1|R2|R3|R4|R5>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4), fork5: fun(enumerable: enumerable<T>): (R5), fork6: fun(enumerable: enumerable<T>): (R6)): enumerable<R1|R2|R3|R4|R5|R6>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4), fork5: fun(enumerable: enumerable<T>): (R5), fork6: fun(enumerable: enumerable<T>): (R6), fork7: fun(enumerable: enumerable<T>): (R7)): enumerable<R1|R2|R3|R4|R5|R6|R7>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4), fork5: fun(enumerable: enumerable<T>): (R5), fork6: fun(enumerable: enumerable<T>): (R6), fork7: fun(enumerable: enumerable<T>): (R7), fork8: fun(enumerable: enumerable<T>): (R8)): enumerable<R1|R2|R3|R4|R5|R6|R7|R8>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4), fork5: fun(enumerable: enumerable<T>): (R5), fork6: fun(enumerable: enumerable<T>): (R6), fork7: fun(enumerable: enumerable<T>): (R7), fork8: fun(enumerable: enumerable<T>): (R8), fork9: fun(enumerable: enumerable<T>): (R9)): enumerable<R1|R2|R3|R4|R5|R6|R7|R8|R9>
---@overload fun(self: enumerable<T>, fork1: fun(enumerable: enumerable<T>): (R1), fork2: fun(enumerable: enumerable<T>): (R2), fork3: fun(enumerable: enumerable<T>): (R3), fork4: fun(enumerable: enumerable<T>): (R4), fork5: fun(enumerable: enumerable<T>): (R5), fork6: fun(enumerable: enumerable<T>): (R6), fork7: fun(enumerable: enumerable<T>): (R7), fork8: fun(enumerable: enumerable<T>): (R8), fork9: fun(enumerable: enumerable<T>): (R9), fork10: fun(enumerable: enumerable<T>): (R10)): enumerable<R1|R2|R3|R4|R5|R6|R7|R8|R9|R10>
function list_impl:fork(...)
    validateList(self)

    return self:enumerate():fork(...)
end

---@generic T
---@param self list<T>
---@return T ...
function list_impl:spread(...)
    validateList(self)

    return self:enumerate():spread(...)
end

---@generic T, R
---@overload fun(self: enumerable<T>): T
---@overload fun(self: enumerable<T>, selector: fun(item: T): (R)): R
---@overload fun(self: enumerable<T>, selector: string): any
function list_impl:first(...)
    validateList(self)

    return self:enumerate():first(...)
end

---@generic T, R
---@overload fun(self: enumerable<T>): T
---@overload fun(self: enumerable<T>, selector: fun(item: T): (R)): R
---@overload fun(self: enumerable<T>, selector: string): any
function list_impl:last(...)
    validateList(self)

    return self:enumerate():last(...)
end

---@generic T
---@param self list<T>
---@return list<T>
function list_impl:copy()
    validateList(self)

    local newList = {}
    for i, v in ipairs(self) do
        newList[i] = v
    end
    return setmetatable(newList, makeListMeta())
end

---@generic T
---@param self list<T>
---@param item T
function list_impl:add(item)
    validateList(self)

    table.insert(self, item)
end

---@generic T, U
---@param self list<T>
---@param item U
---@return list<T|U>
function list_impl:add_transform(item)
    validateList(self)

    table.insert(self, item)

    return self
end

---@generic T
---@param iter iter<T>
---@return list<T>
local function list_from_iter(iter)
    validateIter(iter)

    local newList = {}
    for value in iter do
        table.insert(newList, value)
    end
    return setmetatable(newList, makeListMeta())
end

---@generic T
---@param self list<T>
---@return iter<T>
function list_impl:iter()
    validateList(self)

    return self:enumerate():iter()
end

---@generic K, V
---@param self dict<K, V>
---@return enumerable<K>
function dict_impl:keys()
    validateDict(self)

    return setmetatable({
        __src = self,
        __next = function(iter, enumerable)
            validateIter(iter)

            iter.__data = iter.__data or {}
            iter.__data.last_key = iter.__data.last_key or nil

            local next_key, _ = next(enumerable.__src, iter.__data.last_key)
            iter.__data.last_key = next_key
            return next_key
        end
    }, makeEnumerableMeta())
end

---@generic K, V
---@param self dict<K, V>
---@return enumerable<V>
function dict_impl:values()
    validateDict(self)

    return setmetatable({
        __src = self,
        __next = function(iter, enumerable)
            validateIter(iter)

            iter.__data = iter.__data or {}
            iter.__data.last_key = iter.__data.last_key or nil

            local next_key, next_value = next(enumerable.__src, iter.__data.last_key)
            iter.__data.last_key = next_key
            return next_value
        end
    }, makeEnumerableMeta())
end

---@generic K, V
---@param self dict<K, V>
---@return enumerable<K, V>
function dict_impl:enumerate()
    validateDict(self)

    return setmetatable({
        __src = self,
        __next = function(iter, enumerable)
            validateIter(iter)

            iter.__data = iter.__data or {}
            iter.__data.last_key = iter.__data.last_key or nil

            local next_key, next_value = next(enumerable.__src, iter.__data.last_key)
            iter.__data.last_key = next_key
            if next_key == nil then
                return nil
            end
            return next_key, next_value
        end
    }, makeEnumerableMeta())
end

---@generic K, V
---@param self dict<K, V>
---@return iter<K, V>
function dict_impl:iter()
    validateDict(self)

    return self:enumerate():iter()
end

---@generic K, V
---@overload fun(self: dict<K, V>): enumerable<K, V>
---@overload fun(self: dict<K, V>, comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: dict<K, V>, keySelector: fun(item: K, value: V): (any)): enumerable<K, V>
---@overload fun(self: dict<K, V>, keySelector: fun(item: K, value: V): (any), comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: dict<K, V>, keySelector: string): enumerable<K, V>
---@overload fun(self: dict<K, V>, keySelector: string, comparer: equality_comparer): enumerable<K, V>
function dict_impl:distinct(...)
    validateDict(self)

    return self:enumerate():distinct(...)
end

---@generic K, V
---@overload fun(self: enumerable<K, V>, predicate: fun(key: K, value: V): (boolean)): enumerable<K, V>
---@overload fun(self: enumerable<K, V>, predicate: string): enumerable<K, V>
---@overload fun(self: enumerable<K, V>, predicate: table): enumerable<K, V>
---@overload fun(self: enumerable<K, V>, predicate: table, equality_comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any)): enumerable<K, V>
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), value: any, equality_comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), value: any): enumerable<K, V>
---@overload fun(self: enumerable<K, V>, selector: string): enumerable<K, V>
---@overload fun(self: enumerable<K, V>, selector: string, value: any): enumerable<K, V>
---@overload fun(self: enumerable<K, V>, selector: string, value: any, equality_comparer: equality_comparer): enumerable<K, V>
function dict_impl:where(...)
    validateDict(self)

    return self:enumerate():where(...)
end

---@generic KI, VI, KO, VO
---@overload fun(self: enumerable<KI, VI>, selector: fun(key: KI, value: VI): (VO)): enumerable<VO>
---@overload fun(self: enumerable<KI, VI>, selector: fun(key: KI, value: VI): (KO, VO)): enumerable<KO, VO>
---@overload fun(self: enumerable<KI, VI>, selector: string): enumerable<any>|enumerable<any, any>
function dict_impl:select(...)
    validateDict(self)

    return self:enumerate():select(...)
end

---@generic TO, TFO, KI, VI
---@overload fun(self: enumerable<KI, VI>, consumer: fun(enum: iter<KI, VI>): (TO)): TO
---@overload fun(self: enumerable<KI, VI>, constructor: fun(): (TO), consumer: fun(acc: TO, key: KI, value: VI)): TO
---@overload fun(self: enumerable<KI, VI>, constructor: fun(): (TO), consumer: fun(acc: TO, key: KI, value: VI), finalizer: fun(acc: TO): (TFO)): TFO
function dict_impl:collect(...)
    validateDict(self)

    return self:enumerate():collect(...)
end

---@generic K, V
---@overload fun(self: enumerable<K, V>): boolean
---@overload fun(self: enumerable<K, V>, predicate: fun(key: K, value: V): (boolean)): boolean
---@overload fun(self: enumerable<K, V>, predicate: string): boolean
function dict_impl:any(...)
    validateDict(self)

    return self:enumerate():any(...)
end

---@generic K, V
---@overload fun(self: enumerable<K, V>): V
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any)): any
---@overload fun(self: enumerable<K, V>, selector: string): any
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), is_bigger: fun(a: any, b: any): (boolean)): any
---@overload fun(self: enumerable<K, V>, selector: string, is_bigger: fun(a: any, b: any): (boolean)): any
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), is_bigger: string): any
---@overload fun(self: enumerable<K, V>, selector: string, is_bigger: string): any
function dict_impl:max(...)
    validateDict(self)

    return self:enumerate():max(...)
end

---@generic K, V
---@overload fun(self: enumerable<K, V>): V
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any)): any
---@overload fun(self: enumerable<K, V>, selector: string): any
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), is_smaller: fun(a: any, b: any): (boolean)): any
---@overload fun(self: enumerable<K, V>, selector: string, is_smaller: fun(a: any, b: any): (boolean)): any
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (any), is_smaller: string): any
---@overload fun(self: enumerable<K, V>, selector: string, is_smaller: string): any
function dict_impl:min(...)
    validateDict(self)

    return self:enumerate():min(...)
end

---@generic K, V, R1
---@overload fun(self: dict<K, V>): enumerable<K, V>
---@overload fun(self: dict<K, V>, comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: dict<K, V>, selector: fun(key: K, value: V): (any), comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: dict<K, V>, selector: string|nil, comparer: equality_comparer): enumerable<K, V>
---@overload fun(self: dict<K, V>, selector: fun(key: K, value: V): (any)): enumerable<K, V>
---@overload fun(self: dict<K, V>, selector: string): enumerable<any>|enumerable<any, any>
---@overload fun(self: dict<K, V>, selector: fun(key: K, value: V): (R1), comparer: fun(a: R1, b: R1): (boolean)): enumerable<K, V>
---@overload fun(self: dict<K, V>, selector: string|nil, comparer: fun(a: any, b: any): (boolean)): enumerable<K, V>
---@overload fun(self: dict<K, V>, selector: string|nil, comparer: string): enumerable<K, V>
function dict_impl:sort(...)
    validateDict(self)

    return self:enumerate():sort(...)
end

---@generic K, V
---@overload fun(self: enumerable<K, V>, action: fun(key: K, value: V))
---@overload fun(self: enumerable<K, V>, action: string)
function dict_impl:foreach(...)
    validateDict(self)

    return self:enumerate():foreach(...)
end

---@generic K, V, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10
---@overload fun(self: enumerable<K, V>): enumerable<K, V>, enumerable<K, V>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2)): enumerable<R1|R2>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3)): enumerable<R1|R2|R3>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4)): enumerable<R1|R2|R3|R4>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4), fork5: fun(enumerable: enumerable<K, V>): (R5)): enumerable<R1|R2|R3|R4|R5>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4), fork5: fun(enumerable: enumerable<K, V>): (R5), fork6: fun(enumerable: enumerable<K, V>): (R6)): enumerable<R1|R2|R3|R4|R5|R6>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4), fork5: fun(enumerable: enumerable<K, V>): (R5), fork6: fun(enumerable: enumerable<K, V>): (R6), fork7: fun(enumerable: enumerable<K, V>): (R7)): enumerable<R1|R2|R3|R4|R5|R6|R7>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4), fork5: fun(enumerable: enumerable<K, V>): (R5), fork6: fun(enumerable: enumerable<K, V>): (R6), fork7: fun(enumerable: enumerable<K, V>): (R7), fork8: fun(enumerable: enumerable<K, V>): (R8)): enumerable<R1|R2|R3|R4|R5|R6|R7|R8>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4), fork5: fun(enumerable: enumerable<K, V>): (R5), fork6: fun(enumerable: enumerable<K, V>): (R6), fork7: fun(enumerable: enumerable<K, V>): (R7), fork8: fun(enumerable: enumerable<K, V>): (R8), fork9: fun(enumerable: enumerable<K, V>): (R9)): enumerable<R1|R2|R3|R4|R5|R6|R7|R8|R9>
---@overload fun(self: enumerable<K, V>, fork1: fun(enumerable: enumerable<K, V>): (R1), fork2: fun(enumerable: enumerable<K, V>): (R2), fork3: fun(enumerable: enumerable<K, V>): (R3), fork4: fun(enumerable: enumerable<K, V>): (R4), fork5: fun(enumerable: enumerable<K, V>): (R5), fork6: fun(enumerable: enumerable<K, V>): (R6), fork7: fun(enumerable: enumerable<K, V>): (R7), fork8: fun(enumerable: enumerable<K, V>): (R8), fork9: fun(enumerable: enumerable<K, V>): (R9), fork10: fun(enumerable: enumerable<K, V>): (R10)): enumerable<R1|R2|R3|R4|R5|R6|R7|R8|R9|R10>
function dict_impl:fork(...)
    validateDict(self)

    return self:enumerate():fork(...)
end

---@generic K, V
---@overload fun(self: enumerable<K, V>): ...: { [1]: K, [2]: V }
---@overload fun(self: enumerable<K, V>, mode: "Pairs"): ...: { [1]: K, [2]: V }
---@overload fun(self: enumerable<K, V>, mode: "Keys"): ...: K
---@overload fun(self: enumerable<K, V>, mode: "Values"): ...: V
---@overload fun(self: enumerable<K, V>, mode: "Interwoven"): ...: K|V
function dict_impl:spread(...)
    validateDict(self)

    return self:enumerate():spread(...)
end

---@generic K, V, R
---@overload fun(self: enumerable<K, V>): (K, V)
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (R)): R
---@overload fun(self: enumerable<K, V>, selector: string): any
function dict_impl:first(...)
    validateDict(self)

    return self:enumerate():first(...)
end

---@generic K, V, R
---@overload fun(self: enumerable<K, V>): (K, V)
---@overload fun(self: enumerable<K, V>, selector: fun(key: K, value: V): (R)): R
---@overload fun(self: enumerable<K, V>, selector: string): any
function dict_impl:last(...)
    validateDict(self)

    return self:enumerate():last(...)
end

---@generic T
---@overload fun(): list<any>
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
---@overload fun(iter: iter<T>): list<T>
---@overload fun(table: table): list<any>
function linq.list(...)
    if select("#", ...) == 1 and type(select(1, ...)) == "table" then
        if getmetatable(select(1, ...)) ~= nil and getmetatable(select(1, ...)).__type == "list" then
            return select(1, ...):copy()
        end
        if getmetatable(select(1, ...)) ~= nil and getmetatable(select(1, ...)).__type == "enumerable" then
            return list_from_iter(select(1, ...):iter())
        end
        if getmetatable(select(1, ...)) ~= nil and getmetatable(select(1, ...)).__type == "iter" then
            return list_from_iter(select(1, ...))
        end
        return setmetatable(select(1, ...), makeListMeta())
    else
        return setmetatable({ ... }, makeListMeta())
    end
end

---@generic K, V
---@overload fun(): dict<any, any>
---@overload fun(table: { [K]: V }): dict<K, V>
---@overload fun(dict: dict<K, V>): dict<K, V>
---@overload fun(enumerable: enumerable<K, V>): dict<K, V>
---@overload fun(iter: iter<K, V>): dict<K, V>
---@overload fun(table: table): dict<any, any>
function linq.dict(...)
    if select("#", ...) == 1 and type(select(1, ...)) == "table" then
        if getmetatable(select(1, ...)) ~= nil and getmetatable(select(1, ...)).__type == "dict" then
            return select(1, ...):copy()
        end
        if getmetatable(select(1, ...)) ~= nil and getmetatable(select(1, ...)).__type == "enumerable" then
            local newDict = {}
            for k, v in select(1, ...):iter() do
                newDict[k] = v
            end
            return setmetatable(newDict, makeDictMeta())
        end
        if getmetatable(select(1, ...)) ~= nil and getmetatable(select(1, ...)).__type == "iter" then
            local newDict = {}
            for k, v in select(1, ...) do
                newDict[k] = v
            end
            return setmetatable(newDict, makeDictMeta())
        end
        return setmetatable(select(1, ...), makeDictMeta())
    else
        local newDict = {}
        for i = 1, select("#", ...) do
            local pair = select(i, ...)
            for k, v in pairs(pair) do
                newDict[k] = v
            end
        end
        return setmetatable(newDict, makeDictMeta())
    end
end

---@overload fun(start: number, end: number): enumerable<number>
---@overload fun(count: number): enumerable<number>
---@overload fun(start: number, end: number, step: number): enumerable<number>
function linq.range(...)
    local argc = select("#", ...)
    local arg1 = select(1, ...)
    local arg2 = select(2, ...)
    local arg3 = select(3, ...)

    ---@param definition table
    ---@return enumerable<number>
    local function makeRangeEnumerable(definition)
        definition.__src = definition
        return setmetatable(definition, makeEnumerableMeta())
    end

    return map({
            makeArgDescriptor(arg1, argc),
            makeArgDescriptor(arg2),
            makeArgDescriptor(arg3),
        })
        :track_cases()
        :case({
            { argc = 2,       type = "number" },
            { type = "number" },
        }, function(_)
            local step = arg1 <= arg2 and 1 or -1
            return makeRangeEnumerable({
                __start = arg1,
                __end = arg2,
                __step = step,
                __next = function(iter, enumerable)
                    validateIter(iter)

                    iter.__data = iter.__data or {}
                    if iter.__data.current == nil then
                        iter.__data.current = enumerable.__start
                    else
                        iter.__data.current = iter.__data.current + enumerable.__step
                    end

                    if (enumerable.__step > 0 and iter.__data.current > enumerable.__end) or (enumerable.__step < 0 and iter.__data.current < enumerable.__end) then
                        return nil
                    end

                    return iter.__data.current
                end,
            })
        end)
        :case({
            { argc = 1, type = "number" },
        }, function(_)
            local count = arg1
            return makeRangeEnumerable({
                __count = count,
                __next = function(iter, enumerable)
                    validateIter(iter)

                    iter.__data = iter.__data or {}
                    if iter.__data.current == nil then
                        iter.__data.current = 0
                    else
                        iter.__data.current = iter.__data.current + 1
                    end

                    if iter.__data.current >= enumerable.__count then
                        return nil
                    end

                    return iter.__data.current
                end,
            })
        end)
        :case({
            { argc = 3,       type = "number" },
            { type = "number" },
            { type = "number" },
        }, function(_)
            if arg3 == 0 then
                error("linq.range step cannot be 0")
            end
            local step = arg1 <= arg2 and math.abs(arg3) or -math.abs(arg3)
            return makeRangeEnumerable({
                __start = arg1,
                __end = arg2,
                __step = step,
                __next = function(iter, enumerable)
                    validateIter(iter)

                    iter.__data = iter.__data or {}
                    if iter.__data.current == nil then
                        iter.__data.current = enumerable.__start
                    else
                        iter.__data.current = iter.__data.current + enumerable.__step
                    end

                    if (enumerable.__step > 0 and iter.__data.current > enumerable.__end) or (enumerable.__step < 0 and iter.__data.current < enumerable.__end) then
                        return nil
                    end

                    return iter.__data.current
                end,
            })
        end)
        :default(function(signature, available_signatures)
            error_invalid_signature("linq.range", signature, available_signatures or {})
        end)
        :result()
end

return linq
