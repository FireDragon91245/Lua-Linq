local linq = require("linq")
local data = require("raw")

local items = linq.list(1, 2, 3)
local enum = items:enumerate()
local oit = enum:iter()

---@return table<string, number>
local function table()
    return {
        ["a"] = 1,
        ["b"] = 2,
        [1] = 3
    }
end

local t = table()

local dict = linq.dict(t)
local enum2 = dict:enumerate():where("k, v => k == 1")
local it = enum2:iter()

for k, v in it do
    print(k, v)
end

