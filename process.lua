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

for value in list:where("x => x.a", 1):iter() do
    print(value.a)
end

print("----")

local distinct = list:distinct()

local iter = distinct:iter()

for value in iter do
    print(value)
end

print("----")

local list2 = linq.list("ABC", "abc", "aBc", "TEST", "test", "Hallo")

for value in list2:distinct(function (item)
    return string.sub(item, 1, 1)
end):iter() do
    print(value)
end