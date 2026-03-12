local map = require("map")

---@class linq
local linq = {}

---@alias option<T> T | nil

---@class enumerable<T>
local enumerable_impl = {}

---@class list<T>
local list_impl = {}

---@class itermeta<T>
---@operator call:(iter<T>): T

---@class iter<T> : itermeta<T>
local iter_impl = {}

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
        __call = function (self)
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
    return map({ count = select("#", ...), type = types(...)})
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