local luaunit = require('luaunit')
local linq = require("linq")

TestLast = {}

function TestLast:testLastDefault_Positive_ReturnsTrailingItem()
	local values = linq.list(4, 12, 7)

	luaunit.assertEquals(values:last(), 7)
end

function TestLast:testLastDefault_Edge_EmptyEnumerableReturnsNil()
	local values = linq.list()

	luaunit.assertNil(values:last())
end

function TestLast:testLastFunctionSelector_Positive_ProjectsTrailingItem()
	local values = linq.list(
		{ name = "iron", count = 4 },
		{ name = "copper", count = 7 }
	)

	local result = values:last(function(item)
		return item.name .. ":" .. item.count
	end)

	luaunit.assertEquals(result, "copper:7")
end

function TestLast:testLastFunctionSelector_Negative_EmptyEnumerableReturnsNil()
	local values = linq.list()

	local result = values:last(function(item)
		return item.name
	end)

	luaunit.assertNil(result)
end

function TestLast:testLastStringSelector_Positive_ProjectsTrailingProperty()
	local values = linq.list(
		{ score = 4 },
		{ score = 12 }
	)

	luaunit.assertEquals(values:last("score"), 12)
end

function TestLast:testLastStringSelector_Edge_MissingTrailingPropertyReturnsNil()
	local values = linq.list(
		{ score = 4 },
		{}
	)

	luaunit.assertNil(values:last("score"))
end

function TestLast:testLastStringExpression_Positive_UsesNamedParameter()
	local values = linq.list(
		{ name = "iron", count = 4 },
		{ name = "copper", count = 7 }
	)

	local result = values:last("item => item.name .. ':' .. item.count")

	luaunit.assertEquals(result, "copper:7")
end
