local linq = require("linq")
local data = require("raw")

local items = linq.list(1, 2, 3)
local enum = items:enumerate()
local oit = enum:iter()

---@return table<string, number>
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
local enum2 = dict:enumerate():select("k, v => v, k")

print(enum2:max("v, k => v.age"))

