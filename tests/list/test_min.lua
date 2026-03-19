local luaunit = require('luaunit')
local linq = require("linq")

TestMin = {}

function TestMin:testMinDefault_Positive_ReturnsSmallestPrimitive()
	local values = linq.list(4, 12, 7, 3)

	luaunit.assertEquals(values:min(), 3)
end

function TestMin:testMinDefault_Edge_EmptyEnumerableReturnsNil()
	local values = linq.list()

	luaunit.assertNil(values:min())
end

function TestMin:testMinFunctionSelector_Positive_ProjectsPropertyMinimum()
	local values = linq.list(
		{ score = 4 },
		{ score = 12 },
		{ score = 7 }
	)

	local result = values:min(function(item)
		return item.score
	end)

	luaunit.assertEquals(result, 4)
end

function TestMin:testMinFunctionSelector_Negative_EmptyEnumerableReturnsNil()
	local values = linq.list()

	local result = values:min(function(item)
		return item.score
	end)

	luaunit.assertNil(result)
end

function TestMin:testMinStringSelector_Positive_ProjectsPropertyMinimum()
	local values = linq.list(
		{ score = 4 },
		{ score = 12 },
		{ score = 7 }
	)

	luaunit.assertEquals(values:min("score"), 4)
end

function TestMin:testMinStringSelector_Negative_EmptyEnumerableReturnsNil()
	local values = linq.list()

	luaunit.assertNil(values:min("score"))
end

function TestMin:testMinFunctionSelectorComparerFunction_Positive_UsesCustomOrdering()
	local values = linq.list(-2, 7, -9, 4)

	local result = values:min(function(item)
		return item
	end, function(a, b)
		return math.abs(a) < math.abs(b)
	end)

	luaunit.assertEquals(result, -2)
end

function TestMin:testMinFunctionSelectorComparerFunction_Edge_EmptyEnumerableReturnsNil()
	local values = linq.list()

	local result = values:min(function(item)
		return item
	end, function(a, b)
		return a < b
	end)

	luaunit.assertNil(result)
end

function TestMin:testMinStringSelectorComparerFunction_Positive_UsesCustomOrdering()
	local values = linq.list(
		{ score = -2 },
		{ score = 7 },
		{ score = -9 },
		{ score = 4 }
	)

	local result = values:min("score", function(a, b)
		return math.abs(a) < math.abs(b)
	end)

	luaunit.assertEquals(result, -2)
end

function TestMin:testMinStringSelectorComparerFunction_Edge_EmptyEnumerableReturnsNil()
	local values = linq.list()

	local result = values:min("score", function(a, b)
		return a < b
	end)

	luaunit.assertNil(result)
end

function TestMin:testMinFunctionSelectorComparerString_Positive_UsesComparatorExpression()
	local first = { name = "iron", weight = 10 }
	local second = { name = "steel", weight = 20 }
	local third = { name = "copper", weight = 15 }
	local values = linq.list(first, second, third)

	local result = values:min(function(item)
		return item
	end, "a, b => a.weight < b.weight")

	luaunit.assertTrue(result == first)
end

function TestMin:testMinFunctionSelectorComparerString_Negative_InvalidComparatorStringErrors()
	local values = linq.list(1, 2, 3)

	local ok, err = pcall(function()
		values:min(function(item)
			return item
		end, "not_a_lambda")
	end)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(tostring(err), "Expected a function for is_smaller parameter", 1, true) ~= nil)
end

function TestMin:testMinStringSelectorComparerString_Positive_UsesComparatorExpression()
	local values = linq.list(
		{ name = "iron" },
		{ name = "uranium" },
		{ name = "coal" }
	)

	local result = values:min("name", "a, b => #a < #b")

	luaunit.assertEquals(result, "iron")
end

function TestMin:testMinStringSelectorComparerString_Negative_InvalidComparatorStringErrors()
	local values = linq.list(
		{ name = "iron" },
		{ name = "coal" }
	)

	local ok, err = pcall(function()
		values:min("name", "name")
	end)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(tostring(err), "Expected a function for is_smaller parameter", 1, true) ~= nil)
end