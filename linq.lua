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
---@field compare fun(comparer: equality_comparer, a: any, b: any): any, any, boolean|nil
---@field compareable_types type[]
---@field priority number
---@field group number

local function makeEqualityComparerMeta()
    return {}
end

local function deepCopyTable(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end

    local copy = {}
    for k, v in pairs(tbl) do
        copy[deepCopyTable(k)] = deepCopyTable(v)
    end
    return copy
end

---@type equality_comparer
linq.IGNORE_CASE = setmetatable({
    compare = function(comparer, a, b)
        if type(a) == "string" and type(b) == "string" then
            local lowera = a:lower()
            local lowerb = b:lower()
            return lowera, lowerb, lowera == lowerb
        end
        return nil, nil, nil
    end,
    compareable_types = { "string" },
    priority = 1,
    group = 1
}, makeEqualityComparerMeta())
linq.IGNORE_WHITESPACE = setmetatable({
    compare = function(comparer, a, b)
        if type(a) == "string" and type(b) == "string" then
            local cleanA = a:gsub("%s+", "")
            local cleanB = b:gsub("%s+", "")
            return cleanA, cleanB, cleanA == cleanB
        end
        return nil, nil, nil
    end,
    compareable_types = { "string" },
    priority = 2,
    group = 1
}, makeEqualityComparerMeta())
linq.TABLE_EQUAL = setmetatable({
    compare = function(comparer, a, b)
        if type(a) == "table" and type(b) == "table" then
            for k, v in pairs(a) do
                if not comparer:compare(v, b[k]) then
                    return nil, nil, false
                end
            end
            for k, v in pairs(b) do
                if not comparer:compare(v, a[k]) then
                    return nil, nil, false
                end
            end
            return nil, nil, true
        end
        return nil, nil, nil
    end,
    compareable_types = { "table" },
    priority = 1,
    group = 2
}, makeEqualityComparerMeta())
linq.TABLE_SUBSET = setmetatable({
    compare = function(comparer, a, b)
        if type(a) == "table" and type(b) == "table" then
            for k, v in pairs(a) do
                if not comparer:compare(v, b[k]) then
                    return nil, nil, false
                end
            end
            return nil, nil, true
        end
        return nil, nil, nil
    end,
    compareable_types = { "table" },
    priority = 1,
    group = 2
}, makeEqualityComparerMeta())
linq.TABLE_SUPERSET = setmetatable({
    compare = function(comparer, a, b)
        if type(a) == "table" and type(b) == "table" then
            for k, v in pairs(b) do
                if not comparer:compare(v, a[k]) then
                    return nil, nil, false
                end
            end
            return nil, nil, true
        end
        return nil, nil, nil
    end,
    compareable_types = { "table" },
    priority = 1,
    group = 2
}, makeEqualityComparerMeta())
linq.TABLE_KEY_ONLY = setmetatable({
    compare = function(comparer, a, b)
        if type(a) == "table" and type(b) == "table" then
            
            for k, _ in pairs(a) do
                
            end
        end
        return nil, nil, true
    end,
    compareable_types = { "table" },
    priority = 1,
    group = 2
}, makeEqualityComparerMeta())

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

local function makeListMeta()
    return {
        __index = list_impl,
        __type = "list"
    }
end

local function makeEnumerableMeta()
    return {
        __index = enumerable_impl,
        __type = "enumerable",
    }
end

local function makeIterMeta(src_view)
    return {
        __index = iter_impl,
        __type = "iter",
        __call = function(self)
            return self.__itersrc.__next(self, self.__itersrc)
        end
    }
end

local function enumerable_impl_distinct_next_self(iter, enumerable)
    validateIter(iter)

    local value = enumerable.__src.__next(iter, enumerable.__src)
    if value == nil then
        return nil
    end

    local seen = (iter.__data or {}).seen
    if seen == nil then
        iter.__data = { seen = {} }
    end

    while value ~= nil and iter.__data.seen[value] do
        value = enumerable.__src.__next(iter, enumerable.__src)
    end
    if value ~= nil then
        iter.__data.seen[value] = true
    end
    return value
end

---@generic T
---@param self enumerable<T>
---@return enumerable<T>
function enumerable_impl:distinct(...)
    return map({ count = select("#", ...), type = types(...) })
        :Case({ count = 0 }, function(x)
            return setmetatable({
                __src = self,
                __next = enumerable_impl_distinct_next_self
            }, makeEnumerableMeta())
        end)
        :Case({ count = 1 }, function(x)

        end)
        :Case("x => x.count > 1", function(x)

        end)
        :Result()
end

---@param tab table
---@param compere table
---@param mode 'subset'|'equal'|'superset'
local function match_table(tab, compere, mode)
    return map(mode)
        :Case('subset', function(_)
            for k, v in pairs(tab) do
                local res = map(type(v))
                    :Case('number', function(_)
                        if compere[k] == nil or compere[k] ~= v then
                            return false
                        end
                    end)
                    :Case('string', function(_)
                        if compere[k] == nil or compere[k] ~= v then
                            return false
                        end
                    end)
                    :Case('function', function(_)
                        if compere[k] == nil or compere[k] ~= v then
                            return false
                        end
                    end)
                    :Case('boolean', function(_)
                        if compere[k] == nil or compere[k] ~= v then
                            return false
                        end
                    end)
                    :Case('table', function(_)
                        if compere[k] == nil or not match_table(v, compere[k], mode) then
                            return false
                        end
                    end)
                    :Default(function(x)
                        error("Unsupported type in pattern: " .. x)
                    end)
                    :Result()
                if res == false then
                    return false
                end
            end
        end)
        :Case('equal', function(_)
            for k, v in pairs(compere) do
                local res = map(type(v))
                    :Case('number', function(_)
                        if tab[k] ~= v then
                            return false
                        end
                    end)
                    :Case('string', function(_)
                        if tab[k] ~= v then
                            return false
                        end
                    end)
                    :Case('function', function(_)
                        if tab[k] ~= v then
                            return false
                        end
                    end)
                    :Case('boolean', function(_)
                        if tab[k] ~= v then
                            return false
                        end
                    end)
                    :Case('table', function(_)
                        if not match_table(tab[k], v, mode) then
                            return false
                        end
                    end)
                    :Default(function(x)
                        error("Unsupported type in pattern: " .. x)
                    end)
                    :Result()
                if res == false then
                    return false
                end
            end
        end)
        :Case('superset', function(_)
            for k, v in pairs(compere) do
                local res = map(type(v))
                    :Case('number', function(_)
                        if tab[k] == nil or tab[k] ~= v then
                            return false
                        end
                    end)
                    :Case('string', function(_)
                        if tab[k] == nil or tab[k] ~= v then
                            return false
                        end
                    end)
                    :Case('function', function(_)
                        if tab[k] == nil or tab[k] ~= v then
                            return false
                        end
                    end)
                    :Case('boolean', function(_)
                        if tab[k] == nil or tab[k] ~= v then
                            return false
                        end
                    end)
                    :Case('table', function(_)
                        if tab[k] == nil or not match_table(tab[k], v, mode) then
                            return false
                        end
                    end)
                    :Default(function(x)
                        error("Unsupported type in pattern: " .. x)
                    end)
                    :Result()
                if res == false then
                    return false
                end
            end
        end)
        :Default(function(x)
            error("Unsupported match mode: " .. x)
        end)
        :Result()
end

---@generic T
---@overload fun(self: enumerable<T>, predicate: fun(item: T): boolean): enumerable<T>
---@overload fun(self: enumerable<T>, predicate: string): enumerable<T>
---@overload fun(self: enumerable<T>, predicate: table): enumerable<T>
---@overload fun(self: enumerable<T>, predicate: table, equality_comparer: equality_comparer): enumerable<T>
function enumerable_impl:where(predicate, comparer)
    return map(type(predicate))
        :Case("function", function(_)
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
        :Case("string", function(_)
            local func = predicate_parser:GetPredicateFunction(predicate)
            if func == nil then
                error("Invalid predicate string: " .. predicate)
            end

            return setmetatable({
                __src = self,
                __next = function(iter, enumerable)
                    validateIter(iter)

                    local value = enumerable.__src.__next(iter, enumerable.__src)
                    while value ~= nil and not func(value) do
                        value = enumerable.__src.__next(iter, enumerable.__src)
                    end
                    return value
                end
            }, makeEnumerableMeta())
        end)
        :Case("table", function(_)
        end)
        :Default(function(x)
            error("Unsupported predicate type: " .. x)
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
---@overload fun(self: list<T>, keySelector: fun(item: T): any): enumerable<T>
function list_impl:distinct(...)
    validateList(self)

    return self:enumerate():distinct(...)
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
