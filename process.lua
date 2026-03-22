local linq = require("linq")
local data = require("raw")

local items = linq.list(1, 2, 3)
local enum = items:enumerate()
local oit = enum:iter()

---@return table<string, { age: number }>
local function table()
    return {
        ["max"] = { age = 30 },
        ["tom"] = { age = 25 },
        ["isa"] = { age = 28 },
        ["lisa"] = { age = 22 }
    }
end

local t = table()

local dict = linq.dict(t)
local names, ages = dict
    :enumerate()
    :where(function(k, v)
        return k == "max" or k == "tom"
    end)
    :fork(function(e)
        return e:select(function(k, v)
            return k
        end):collect(linq.list)
    end, function(e)
        return e:select(function(k, v)
            return v.age
        end):collect(linq.list)
    end):spread()

print(names:first())
for name in names:iter() do
    print(name)
end

for age in ages:iter() do
    print(age)
end
