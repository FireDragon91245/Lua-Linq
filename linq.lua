local map = require("map")

---@class linq
local linq = {}

---@alias option<T> T | nil
---@alias iter<T> fun(table: T[], i?: integer):integer, T

---@class enumerable<T>
---@field distinct fun(self: enumerable<T>): enumerable<T>
---@field distinct fun(self: enumerable<T>, keySelector: fun(item: T): any): enumerable<T>
---@field tolist fun(self: enumerable<T>): list<T>

---@class list<T>
---@field distinct fun(self: list<T>): enumerable<T>
---@field distinct fun(self: list<T>, keySelector: fun(item: T): any): list<T>
---@field enumerate fun(self: list<T>): enumerable<T>
---@field copy fun(self: list<T>): list<T>
---@field iter fun(self: list<T>): iter<T>

local enumerable_impl = {}
local list_impl = {}

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

    if enumerable.next == nil or type(enumerable.next) ~= "function" then
        error("Enumerable: Invalid state, missing next() function")
    end

    if enumerable.src == nil then
        error("Enumerable: Invalid state, missing src")
    end
end

local function makeListMeta()
    return {
        __index = list_impl,
        __type = "list",
        __iter_idx = nil,
        __call = function(self, ...)
            local mt = getmetatable(self)
            if mt.__iter_idx == nil then
                mt.__iter_idx = 1
            else
                mt.__iter_idx = mt.__iter_idx + 1
            end
            local item = self[mt.__iter_idx]
            if item == nil then
                mt.__iter_idx = nil
                return nil
            end

            return item
        end
    }
end

local function makeEnumerableMeta()
    return {
        __index = enumerable_impl,
        __type = "enumerable",
        __call = function(self, ...)
            return self:next()
        end
    }
end

local function enumerable_impl_distinct_next_self(self)
    validateEnumerable(self)

    local value = self.src:next()
    if value == nil then
        return nil
    end

    local seen = (self.data or {}).seen
    if seen == nil then
        self.data = { seen = {} }
    end

    while value ~= nil and self.data.seen[value] do
        value = self.src:next()
    end
    if value ~= nil then
        self.data.seen[value] = true
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
                src = self,
                next = enumerable_impl_distinct_next_self
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
---@return list<T>
function enumerable_impl:tolist()
    return linq.list(self)
end

local function list_impl_enumerable_next(self)
    validateEnumerable(self)

    local idx = (self.data or {}).idx
    if idx == nil then
        self.data = { idx = 1 }
        idx = 1
    end
    local value = self.src[idx]
    self.data.idx = idx + 1
    return value
end

---@generic T
---@param self list<T>
---@return enumerable<T>
function list_impl:enumerate()
    validateList(self)

    return setmetatable({
        src = self,
        next = list_impl_enumerable_next
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
---@overload fun(table: table): list<any>
---@overload fun(enumerable: enumerable<T>): list<T>
---@overload fun(list: list<T>): list<T>
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