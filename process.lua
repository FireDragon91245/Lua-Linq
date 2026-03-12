local linq = require("linq")
local data = require("raw")

local list = linq.list{1, 2, 2, 3, 4, 4, 5}

for value in list do
    print(value)
end

print("----")

for value in list:distinct() do
    print(value)
end