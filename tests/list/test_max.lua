local luaunit = require('luaunit')
local linq = require("linq")

TestMax = {}

function TestMax:testMaxDefault_Positive_ReturnsLargestPrimitive()
	local values = linq.list(4, 12, 7, 3)

	luaunit.assertEquals(values:max(), 12)
end

function TestMax:testMaxDefault_Edge_EmptyEnumerableReturnsNil()
	local values = linq.list()

	luaunit.assertNil(values:max())
end

function TestMax:testMaxFunctionSelector_Positive_ProjectsPropertyMaximum()
	local values = linq.list(
		{ score = 4 },
		{ score = 12 },
		{ score = 7 }
	)

	local result = values:max(function(item)
		return item.score
	end)

	luaunit.assertEquals(result, 12)
end

function TestMax:testMaxFunctionSelector_Negative_EmptyEnumerableReturnsNil()
	local values = linq.list()

	local result = values:max(function(item)
		return item.score
	end)

	luaunit.assertNil(result)
end

function TestMax:testMaxStringSelector_Positive_ProjectsPropertyMaximum()
	local values = linq.list(
		{ score = 4 },
		{ score = 12 },
		{ score = 7 }
	)

	luaunit.assertEquals(values:max("score"), 12)
end

function TestMax:testMaxStringSelector_Negative_EmptyEnumerableReturnsNil()
	local values = linq.list()

	luaunit.assertNil(values:max("score"))
end

function TestMax:testMaxFunctionSelectorComparerFunction_Positive_UsesCustomOrdering()
	local values = linq.list(-2, 7, -9, 4)

	local result = values:max(function(item)
		return item
	end, function(a, b)
		return math.abs(a) > math.abs(b)
	end)

	luaunit.assertEquals(result, -9)
end

function TestMax:testMaxFunctionSelectorComparerFunction_Edge_EmptyEnumerableReturnsNil()
	local values = linq.list()

	local result = values:max(function(item)
		return item
	end, function(a, b)
		return a > b
	end)

	luaunit.assertNil(result)
end

function TestMax:testMaxStringSelectorComparerFunction_Positive_UsesCustomOrdering()
	local values = linq.list(
		{ score = -2 },
		{ score = 7 },
		{ score = -9 },
		{ score = 4 }
	)

	local result = values:max("score", function(a, b)
		return math.abs(a) > math.abs(b)
	end)

	luaunit.assertEquals(result, -9)
end

function TestMax:testMaxStringSelectorComparerFunction_Edge_EmptyEnumerableReturnsNil()
	local values = linq.list()

	local result = values:max("score", function(a, b)
		return a > b
	end)

	luaunit.assertNil(result)
end

function TestMax:testMaxFunctionSelectorComparerString_Positive_UsesComparatorExpression()
	local first = { name = "iron", weight = 10 }
	local second = { name = "steel", weight = 20 }
	local third = { name = "copper", weight = 15 }
	local values = linq.list(first, second, third)

	local result = values:max(function(item)
		return item
	end, "a, b => a.weight > b.weight")

	luaunit.assertTrue(result == second)
end

function TestMax:testMaxFunctionSelectorComparerString_Negative_InvalidComparatorStringErrors()
	local values = linq.list(1, 2, 3)

	local ok, err = pcall(function()
		values:max(function(item)
			return item
		end, "not_a_lambda")
	end)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(tostring(err), "Expected a function for is_bigger parameter", 1, true) ~= nil)
end

function TestMax:testMaxStringSelectorComparerString_Positive_UsesComparatorExpression()
	local values = linq.list(
		{ name = "iron" },
		{ name = "uranium" },
		{ name = "coal" }
	)

	local result = values:max("name", "a, b => #a > #b")

	luaunit.assertEquals(result, "uranium")
end

function TestMax:testMaxStringSelectorComparerString_Negative_InvalidComparatorStringErrors()
	local values = linq.list(
		{ name = "iron" },
		{ name = "coal" }
	)

	local ok, err = pcall(function()
		values:max("name", "name")
	end)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(tostring(err), "Expected a function for is_bigger parameter", 1, true) ~= nil)
end