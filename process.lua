local linq = require("linq")
local data = require("raw")

---@type list<integer|string>
local union_test = linq.list(1, "")

---@type number
local test = 1

local list = linq.list(1, 2, 2, 3, 4, test, 5.1, "")

local list2 = linq.list(list)

local list3 = list:copy()

for value in list:iter() do
    print(value)
end

print("----")

local distinct = list:distinct()

local iter = distinct:iter()

for value in iter do
    print(value)
end