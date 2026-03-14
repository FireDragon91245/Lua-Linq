local map = require("map")
local predicate_parser = require("predicates"):get()

---@class linq
local linq = {}

---@alias option<T> T | nil

---@class enumerable<T>
local enumerable_impl = {}

---@class list<T>
local list_impl = {}

---@class iter<T>
---@operator call:(iter<T>): T
local iter_impl = {}

---@class equality_comparer
---@operator band(equality_comparer): equality_comparer
---@field compare fun(self: equality_comparer, a: any, b: any, prep_for_next: boolean|nil): any|boolean, any
---@field is_combined fun(self: equality_comparer): boolean
---@field key fun(self: equality_comparer): string
---@field types fun(self: equality_comparer): type[]
---@field priority number
---@field comparers { [type]: equality_comparer }

---@generic T
---@param list T[]
---@param item T
local function insert(list, item)
    table.insert(list, item)
end

---@return type[]
local function types(...)
    ---@type any[]
    local items = { ... }
    ---@type type[]
    local result = {}
    for i, item in ipairs(items) do
        insert(result, type(item))
    end
    return result
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

---@generic T
---@overload fun(self: enumerable<T>): enumerable<T>
---@overload fun(self: enumerable<T>, comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<T>, keySelector: fun(item: T): (any)): enumerable<T>
---@overload fun(self: enumerable<T>, keySelector: fun(item: T): (any), comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<T>, keySelector: string): enumerable<T>
---@overload fun(self: enumerable<T>, keySelector: string, comparer: equality_comparer): enumerable<T>
function enumerable_impl:distinct(comparer_or_keySelector, comparer)
    return map({
            { type = type(comparer_or_keySelector), ext_type = getmetatable(comparer_or_keySelector) ~= nil and getmetatable(comparer_or_keySelector).__type or nil },
            { type = type(comparer),                ext_type = getmetatable(comparer) ~= nil and getmetatable(comparer).__type or nil }
        })
        :Case({
                { type = "nil" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        if value == nil then
                            return nil
                        end

                        iter.__data = iter.__data or {}
                        iter.__data.seen = iter.__data.seen or {}

                        while value ~= nil and iter.__data.seen[value] do
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end
                        if value ~= nil then
                            iter.__data.seen[value] = true
                        end
                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Case({
                { type = "table", ext_type = "equality_comparer" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, comparer: equality_comparer): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        if value == nil then
                            return nil
                        end

                        iter.__data = iter.__data or {}
                        iter.__data.seen = iter.__data.seen or {}

                        while value ~= nil do
                            local seen_by_type = iter.__data.seen[type(value)]
                            if seen_by_type == nil then
                                iter.__data.seen[type(value)] = { value }
                                break
                            else
                                local found = false
                                for _, seen_value in pairs(seen_by_type) do
                                    if comparer_or_keySelector --[[@as equality_comparer]]:compare(value, seen_value) then
                                        found = true
                                        break
                                    end
                                end
                                if not found then
                                    table.insert(seen_by_type, value)
                                    break
                                end
                            end
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end
                        if value ~= nil then
                            iter.__data.seen[value] = true
                        end
                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Case({
            { type = "function" },
            { type = "nil" }
        }, function(_)
            return setmetatable({
                __src = self,
                __next = function(iter, enumerable)
                    validateIter(iter)

                    local value = enumerable.__src.__next(iter, enumerable.__src)
                    if value == nil then
                        return nil
                    end

                    iter.__data = iter.__data or {}
                    iter.__data.seen = iter.__data.seen or {}

                    while value ~= nil and iter.__data.seen[comparer_or_keySelector(value)] do
                        value = enumerable.__src.__next(iter, enumerable.__src)
                    end
                    if value ~= nil then
                        iter.__data.seen[comparer_or_keySelector(value)] = true
                    end
                    return value
                end
            }, makeEnumerableMeta())
        end)
        :Case({
                { type = "function" },
                { type = "table",   ext_type = "equality_comparer" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, keySelector: fun(item: T): any, comparer: equality_comparer): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        if value == nil then
                            return nil
                        end

                        iter.__data = iter.__data or {}
                        iter.__data.seen = iter.__data.seen or {}

                        while value ~= nil do
                            local value_key = comparer_or_keySelector(value)
                            ---@type table
                            local seen_by_type = iter.__data.seen[type(value_key)]
                            if seen_by_type == nil then
                                iter.__data.seen[type(value_key)] = { value_key }
                                break
                            end
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
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end
                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Case({
                { type = "string" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, keySelector: string): enumerable<T>
            function(_)
                local is_predicate = string.find(comparer_or_keySelector --[[@as string]], "=>") ~= nil
                local predicate
                if is_predicate then
                    predicate = predicate_parser:GetPredicateFunction(comparer_or_keySelector)
                    if not predicate then
                        error("Invalid predicate string: " .. comparer_or_keySelector)
                    end
                else
                    predicate = function(item)
                        return item[comparer_or_keySelector]
                    end
                end
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        if value == nil then
                            return nil
                        end

                        iter.__data = iter.__data or {}
                        iter.__data.seen = iter.__data.seen or {}

                        while value ~= nil and iter.__data.seen[predicate(value)] do
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end
                        if value ~= nil then
                            iter.__data.seen[predicate(value)] = true
                        end

                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Case({
                { type = "string" },
                { type = "table", ext_type = "equality_comparer" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, keySelector: string, comparer: equality_comparer): enumerable<T>
            function(_)
                local is_predicate = string.find(comparer_or_keySelector --[[@as string]], "=>") ~= nil
                local predicate
                if is_predicate then
                    predicate = predicate_parser:GetPredicateFunction(comparer_or_keySelector)
                    if not predicate then
                        error("Invalid predicate string: " .. comparer_or_keySelector)
                    end
                else
                    predicate = function(item)
                        return item[comparer_or_keySelector]
                    end
                end
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        if value == nil then
                            return nil
                        end

                        iter.__data = iter.__data or {}
                        iter.__data.seen = iter.__data.seen or {}

                        while value ~= nil do
                            local value_key = predicate(value)
                            ---@type table
                            local seen_by_type = iter.__data.seen[type(value_key)]
                            if seen_by_type == nil then
                                iter.__data.seen[type(value_key)] = { value_key }
                                break
                            end
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
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end

                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Default(function(x)
            error("no signature enumerable<T>:distinct(" ..
                (x[1].type or "nil") .. ": " .. (x[1].ext_type or "nil") .. ", " ..
                (x[2].type or "nil") .. ": " .. (x[2].ext_type or "nil") .. ")")
        end)
        :Result()
end

---@generic T
---@overload fun(self: enumerable<T>, predicate: fun(item: T): (boolean)): enumerable<T>
---@overload fun(self: enumerable<T>, predicate: string): enumerable<T>
---@overload fun(self: enumerable<T>, predicate: table): enumerable<T>
---@overload fun(self: enumerable<T>, predicate: table, equality_comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any)): enumerable<T>
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any), value: any, equality_comparer: equality_comparer): enumerable<T>
---@overload fun(self: enumerable<T>, selector: fun(item: T): (any), value: any): enumerable<T>
---@overload fun(self: enumerable<T>, selector: string): enumerable<T>
---@overload fun(self: enumerable<T>, selector: string, value: any): enumerable<T>
---@overload fun(self: enumerable<T>, selector: string, value: any, equality_comparer: equality_comparer): enumerable<T>
function enumerable_impl:where(predicate_or_selector, value_or_comparer, equality_comparer)
    return map({
            { type = type(predicate_or_selector) },
            { type = type(value_or_comparer),    ext_type = getmetatable(value_or_comparer) ~= nil and getmetatable(value_or_comparer).__type or nil },
            { type = type(equality_comparer),    ext_type = getmetatable(equality_comparer) ~= nil and getmetatable(equality_comparer).__type or nil }
        })
        :Case({
                { type = "function" },
                { type = "nil" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, predicate: fun(item: T): boolean): enumerable<T>|fun(self: enumerable<T>, selector: fun(item: T): any): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        while value ~= nil and not predicate_or_selector(value) do
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end
                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Case({
                { type = "string" },
                { type = "nil" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, predicate: string): enumerable<T>
            function(_)
                local is_predicate = string.find(predicate_or_selector --[[@as string]], "=>") ~= nil
                local predicate
                if is_predicate then
                    predicate = predicate_parser:GetPredicateFunction(predicate_or_selector)
                    if not predicate then
                        error("Invalid predicate string: " .. predicate_or_selector)
                    end
                else
                    predicate = function(item)
                        return item[predicate_or_selector]
                    end
                end
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        while value ~= nil and not predicate(value) do
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end
                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Case({
                { type = "table" },
                { type = "nil" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, predicate: table): enumerable<T>
            function(_)
                local comparer = linq.TABLE_SUPERSET
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        while value ~= nil and not comparer:compare(value, predicate_or_selector) do
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end
                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Case({
                { type = "table" },
                { type = "table", ext_type = "equality_comparer" },
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, predicate: table, equality_comparer: equality_comparer): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        while value ~= nil and not value_or_comparer:compare(value, predicate_or_selector) do
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end
                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Case({
                { type = "function" },
                {},
                { type = "table",   ext_type = "equality_comparer" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: fun(item: T): any, value: any, equality_comparer: equality_comparer): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        while value ~= nil and not equality_comparer:compare(predicate_or_selector(value), value_or_comparer) do
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end
                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Case({
                { type = "function" },
                {},
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: fun(item: T): any, value: any): enumerable<T>
            function(_)
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        while value ~= nil and not (predicate_or_selector(value) == value_or_comparer) do
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end
                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Case({
                { type = "string" },
                {},
                { type = "nil" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string, value: any): enumerable<T>
            function(_)
                local is_predicate = string.find(predicate_or_selector --[[@as string]], "=>") ~= nil
                local predicate
                if is_predicate then
                    predicate = predicate_parser:GetPredicateFunction(predicate_or_selector)
                    if not predicate then
                        error("Invalid predicate string: " .. predicate_or_selector)
                    end
                else
                    predicate = function(item)
                        return item[predicate_or_selector]
                    end
                end
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        while value ~= nil and not (predicate(value) == value_or_comparer) do
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end
                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Case({
                { type = "string" },
                {},
                { type = "table", ext_type = "equality_comparer" }
            },
            ---@generic T
            ---@type fun(self: enumerable<T>, selector: string, value: any, equality_comparer: equality_comparer): enumerable<T>
            function(_)
                local is_predicate = string.find(predicate_or_selector --[[@as string]], "=>") ~= nil
                local predicate
                if is_predicate then
                    predicate = predicate_parser:GetPredicateFunction(predicate_or_selector)
                    if not predicate then
                        error("Invalid predicate string: " .. predicate_or_selector)
                    end
                else
                    predicate = function(item)
                        return item[predicate_or_selector]
                    end
                end
                return setmetatable({
                    __src = self,
                    __next = function(iter, enumerable)
                        validateIter(iter)

                        local value = enumerable.__src.__next(iter, enumerable.__src)
                        while value ~= nil and not equality_comparer:compare(predicate(value), value_or_comparer) do
                            value = enumerable.__src.__next(iter, enumerable.__src)
                        end
                        return value
                    end
                }, makeEnumerableMeta())
            end)
        :Default(function(x)
            error("no signature enumerable<T>:where(" ..
                (x[1].type or "nil") ..
                ", " ..
                (x[2].type or "nil") ..
                ": " ..
                (x[2].ext_type or "nil") .. ", " .. (x[3].type or "nil") .. ": " .. (x[3].ext_type or "nil") .. ")")
        end)
        :Result()
end

---@generic T
---@param self enumerable<T>
---@return iter<T>
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

local function list_from_enumerable(enumerable)
    validateEnumerable(enumerable)

    local newList = {}
    local next = enumerable:next()
    while next ~= nil do
        table.insert(newList, next)
        next = enumerable:next()
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

---@generic T
---@overload fun(...: T): list<T>
---@overload fun(list: list<T>): list<T>
---@overload fun(enumerable: enumerable<T>): list<T>
---@overload fun(table: table): list<any>
function linq.list(...)
    if select("#", ...) == 1 and type(select(1, ...)) == "table" then
        if getmetatable(select(1, ...)) ~= nil and getmetatable(select(1, ...)).__type == "list" then
            return select(1, ...):copy()
        end
        if getmetatable(select(1, ...)) ~= nil and getmetatable(select(1, ...)).__type == "enumerable" then
            return list_from_enumerable(select(1, ...))
        end
        return setmetatable(select(1, ...), makeListMeta())
    else
        return setmetatable({ ... }, makeListMeta())
    end
end

return linq
