local luaunit = require('luaunit')
local linq = require("linq")

TestDictForeach = {}

function TestDictForeach:testForeachFunction_Positive_VisitsEveryPair()
	local values = linq.dict({
		alpha = 10,
		beta = 20,
		gamma = 30,
	})
	local seen = {}
	local sum = 0

	values:foreach(function(key, value)
		seen[key] = true
		sum = sum + value
	end)

	luaunit.assertEquals(seen, {
		alpha = true,
		beta = true,
		gamma = true,
	})
	luaunit.assertEquals(sum, 60)
	end