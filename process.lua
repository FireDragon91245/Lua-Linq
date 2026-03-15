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

local example_list = linq.list("ABC", "abc", "aBc", "TEST", "test", "Hallo")

local example_list_copy = linq.list(example_list:enumerate())

local example_list_collect = example_list_copy:collect(function(enum)
    return linq.list(enum):add_transform(1)
end)

local example_list2 = linq.list("ABC", "abc", "aBc", "TEST", "test", "Hallo")

local step1 = example_list2:distinct(function (item)
    return string.sub(item, 1, 1)
end)

local step2 = step1:select(function (item)
    return 1
end)

local step3 = step2:collect(function ()
    return linq.list(1, 2)
end, function (acc, item)
    acc:add(item)
end)

for value in step3:iter() do
    print(value)
end