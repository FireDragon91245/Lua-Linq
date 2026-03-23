local linq = require("linq")
local data = require("raw")

local items = linq.list(1, 2, 3)
local enum = items:enumerate()
local oit = enum:iter()

---@return table<string, { age: number }>
local function make_table()
    return {
        ["max"] = { age = 30 },
        ["tom"] = { age = 25 },
        ["isa"] = { age = 28 },
        ["lisa"] = { age = 22 }
    }
end

local abc = linq.dict(make_table())
    :enumerate()
    :where(function(k, v)
        return k == 'max' or k == 'tom'
    end)
    :fork(function(e)
        local tmp = e:select(function(k, v)
            return k
        end)
        local list = tmp:collect(linq.list)
        return list
    end, function(e)
        local tmp = e:select(function(k, v)
            return v.age
        end)
        local list = tmp:collect(linq.list)
        return list
    end)

local names, ages = abc:spread()


print(names:first())
for name in names:iter() do
    print(name)
end

for age in ages:iter() do
    print(age)
end
