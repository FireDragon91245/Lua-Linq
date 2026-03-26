local luaunit = require('luaunit')
local linq = require("linq")

TestListForeach = {}

function TestListForeach:testForeachFunction_Positive_VisitsItemsInListOrder()
	local values = linq.list(1, 2, 3)
	local seen = {}

	values:foreach(function(item)
		seen[#seen + 1] = item * 2
	end)

	luaunit.assertEquals(seen, { 2, 4, 6 })
	end