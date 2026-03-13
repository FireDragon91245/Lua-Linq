local linq = require("linq")
local data = require("raw")

---@type table
local test = {};

local test1 = linq.list(test)

---@type number
local test = 1

local list = linq.list(
    { a = 1 },
    { b = 2 },
    { a = 1, c = 3},
    { a = "ABC" }
)

for value in list:iter() do
    print(value)
end

print("----")

for value in list:where({ a = "abc" }, linq.TABLE_EQUAL & linq.IGNORE_CASE):iter() do
    print(value.a)
end

print("----")

local distinct = list:distinct()

local iter = distinct:iter()

for value in iter do
    print(value)
end