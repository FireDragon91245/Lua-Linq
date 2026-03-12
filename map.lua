local mapClass = {}
local mapInstanceMt = {
    __index = mapClass
}

local predicateParser = require("predicates")

setmetatable(mapClass, {
    __call = function(self, arg)
        return self.Map(arg)
    end,
})

local function GetConsumerArg(self)
    if type(self.data) ~= "table" and self.cache == nil then
        return self.data
    end

    return setmetatable(self.cache or {}, { __index = self.data })
end

local function ExecuteConsumer(self, func)
    self.result = func(GetConsumerArg(self))
end

local function Count(obj)
    local count = 0
    for k, _ in ipairs(obj) do
        count = count + 1
    end

    return count
end

local function GetTableValueByTableKey(obj, key)
    if obj == nil then
        return nil
    end

    for k, v in pairs(obj) do
        if type(k) == "table" then
            if mapClass:MatchTable(nil, k, key) then
                return v
            end
        end
    end
    return nil
end

function mapClass.MatchTable(self, cache, obj, pattern)
    if obj == nil then
        return false
    end

    for k, v in pairs(pattern) do
        if type(k) == "table" and getmetatable(k) == "Map.FUNC_CALL" then
            local rtValue = GetTableValueByTableKey(cache, k)
            if cache ~= nil and rtValue ~= nil then
                if type(v) == "number" or type(v) == "string" then
                    if v ~= rtValue then
                        return false
                    end
                elseif type(v) == "table" then
                    if not self:MatchTable(nil, rtValue, v) then
                        return false
                    end
                else
                    error("Cant pattern match type " .. type(v))
                end
            else
                rtValue = self:ExecuteFuncCall(k)
                if type(v) == "number" or type(v) == "string" then
                    if v ~= rtValue then
                        return false
                    end
                elseif type(v) == "table" then
                    if not self:MatchTable(nil, rtValue, v) then
                        return false
                    end
                else
                    error("Cant pattern match type " .. type(v))
                end
            end
        elseif type(v) == "number" or type(v) == "string" then
            if cache ~= nil and cache[k] ~= nil then
                if cache[k] ~= v then
                    return false
                end
            else
                if obj[k] ~= v then
                    return false
                end
            end
        elseif type(v) == "table" then
            local patternCount = Count(v)

            if patternCount == 0 then
                return type(obj) == type(v)
            end
            if not self:MatchTable((cache or {})[k], (cache or {})[k] or obj[k], v) then
                return false
            end
        else
            error("Cant pattern match type " .. type(v))
        end
    end

    return true
end

function mapClass.Map(arg)
    return setmetatable({ data = arg, match = false, result = nil }, mapInstanceMt)
end

function mapClass.Case(self, condition, func)
    if self.match then
        return self
    end

    if type(func) == "string" then
        func = predicateParser():GetPredicateFunction(func)
    else
        if type(func) ~= "function" then
            error("Cannot callback on type" .. type(func) .. "for Map Case")
        end
    end

    if type(condition) == "function" then
        if condition(self.data) then
            ExecuteConsumer(self, func)
            self.match = true
        end
    elseif type(condition) == "table" then
        if self:MatchTable(self.cache, self.data, condition) then
            ExecuteConsumer(self, func)
            self.match = true
        end
    elseif type(condition) == "number" or type(condition) == "boolean" or type(condition) == "nil" then
        if self.data == condition then
            ExecuteConsumer(self, func)
            self.match = true
        end
    elseif type(condition) == "string" then
        if string.find(condition, "=>") then
            local ff = predicateParser():GetPredicateFunction(condition)
            if ff(self.data) then
                ExecuteConsumer(self, func)
                self.match = true
            end
        else
            if self.data == condition then
                ExecuteConsumer(self, func)
                self.match = true
            end
        end
    end

    return self
end

function mapClass.Default(self, func)
    if not self.match then
        if type(func) == "string" then
            func = predicateParser():GetPredicateFunction(func)
        else
            if type(func) ~= "function" then
                error("Cannot callback on type" .. type(func) .. "for Map Case")
            end
        end
        ExecuteConsumer(self, func)
    end

    return self
end

function mapClass.Result(self)
    return self.result
end

mapClass.FUNC_CALL = setmetatable({}, {
    __index = function(self, key)
        local case = { func = key }
        return function(...)
            case.args = { ... }
            setmetatable(case, {
                __metatable = "Map.FUNC_CALL"
            })
            return case
        end
    end
})

function mapClass.ExecuteFuncCall(self, mapFuncCallObj)
    if type(self.data[mapFuncCallObj.func]) ~= "function" then
        error("Function to cahe does not exist in the Mapped object or key is wrong value type")
    end

    return self.data[mapFuncCallObj.func](table.unpack(mapFuncCallObj.args))
end

-- Only use cache on FUNC_CALL if the function your caching is performance intensive getters should be evaluated each Case statement and not cached because cache itself is very expensive on lookup
function mapClass.Cache(self, what)
    if self.cache ~= nil then
        error("Only 1 Cahe statement per Map/Case construct")
    end

    if type(what) ~= "table" and type(what) ~= "function" then
        error("Cash representation mus be a table or generator function")
    end

    if type(self.data) ~= "table" then
        error("Cash only applicable if Map expresion is on a object (table)")
    end

    self.cache = {}

    for k, v in pairs(what) do
        if type(v) == "function" then
            self.cache[k] = v(self.data)
        elseif type(v) == "table" then
            if getmetatable(v) == "Map.FUNC_CALL" then
                self.cache[v] = self:ExecuteFuncCall(v)
            else
                self.cache[k] = v
            end
        else
            self.cache[k] = v
        end
    end

    return self
end

return mapClass
