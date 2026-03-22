local luaunit = require('luaunit')
local linq = require("linq")

TestFirst = {}

function TestFirst:testFirstDefault_Positive_ReturnsLeadingItem()
	local values = linq.list(4, 12, 7)

	luaunit.assertEquals(values:first(), 4)
end

function TestFirst:testFirstDefault_Edge_EmptyEnumerableReturnsNil()
	local values = linq.list()

	luaunit.assertNil(values:first())
end

function TestFirst:testFirstFunctionSelector_Positive_ProjectsLeadingItem()
	local values = linq.list(
		{ name = "iron", count = 4 },
		{ name = "copper", count = 7 }
	)

	local result = values:first(function(item)
		return item.name .. ":" .. item.count
	end)

	luaunit.assertEquals(result, "iron:4")
end

function TestFirst:testFirstFunctionSelector_Negative_EmptyEnumerableReturnsNil()
	local values = linq.list()

	local result = values:first(function(item)
		return item.name
	end)

	luaunit.assertNil(result)
end

function TestFirst:testFirstStringSelector_Positive_ProjectsLeadingProperty()
	local values = linq.list(
		{ score = 4 },
		{ score = 12 }
	)

	luaunit.assertEquals(values:first("score"), 4)
end

function TestFirst:testFirstStringSelector_Edge_MissingLeadingPropertyReturnsNil()
	local values = linq.list(
		{},
		{ score = 12 }
	)

	luaunit.assertNil(values:first("score"))
end

function TestFirst:testFirstStringExpression_Positive_UsesNamedParameter()
	local values = linq.list(
		{ name = "iron", count = 4 },
		{ name = "copper", count = 7 }
	)

	local result = values:first("item => item.name .. ':' .. item.count")

	luaunit.assertEquals(result, "iron:4")
end