local luaunit = require('luaunit')
local linq = require("linq")

TestDictMax = {}

function TestDictMax:testMaxDefault_Positive_ReturnsLargestValue()
	local values = linq.dict({
		[1] = 4,
		[2] = 12,
		[3] = 7,
	})

	luaunit.assertEquals(values:max(), 12)
end

function TestDictMax:testMaxDefault_Edge_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	luaunit.assertNil(values:max())
end

function TestDictMax:testMaxFunctionSelector_Positive_ProjectsFromKeyAndValue()
	local values = linq.dict({
		[1] = 4,
		[2] = 12,
		[3] = 7,
	})

	local result = values:max(function(key, value)
		return key + value
	end)

	luaunit.assertEquals(result, 14)
end

function TestDictMax:testMaxFunctionSelector_Negative_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	local result = values:max(function(key, value)
		return key + value
	end)

	luaunit.assertNil(result)
end

function TestDictMax:testMaxStringSelector_Positive_ProjectsValueProperty()
	local values = linq.dict({
		["a"] = { age = 25 },
		["b"] = { age = 30 },
		["c"] = { age = 28 },
	})

	luaunit.assertEquals(values:max("age"), 30)
end

function TestDictMax:testMaxStringSelector_Negative_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	luaunit.assertNil(values:max("age"))
end

function TestDictMax:testMaxFunctionSelectorComparerFunction_Positive_UsesCustomOrdering()
	local first = { name = "iron", age = 25 }
	local second = { name = "maximilian", age = 30 }
	local third = { name = "isa", age = 28 }
	local values = linq.dict({
		["a"] = first,
		["b"] = second,
		["c"] = third,
	})

	local result = values:max(function(_, value)
		return value
	end, function(a, b)
		return #a.name > #b.name
	end)

	luaunit.assertTrue(result == second)
end

function TestDictMax:testMaxFunctionSelectorComparerFunction_Edge_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	local result = values:max(function(_, value)
		return value
	end, function(a, b)
		return a.age > b.age
	end)

	luaunit.assertNil(result)
end

function TestDictMax:testMaxStringSelectorComparerFunction_Positive_UsesCustomOrdering()
	local values = linq.dict({
		["a"] = { score = -2 },
		["b"] = { score = 7 },
		["c"] = { score = -9 },
		["d"] = { score = 4 },
	})

	local result = values:max("score", function(a, b)
		return math.abs(a) > math.abs(b)
	end)

	luaunit.assertEquals(result, -9)
end

function TestDictMax:testMaxStringSelectorComparerFunction_Edge_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	local result = values:max("score", function(a, b)
		return a > b
	end)

	luaunit.assertNil(result)
end

function TestDictMax:testMaxFunctionSelectorComparerString_Positive_UsesComparatorExpression()
	local first = { name = "tom", age = 25 }
	local second = { name = "max", age = 30 }
	local third = { name = "isa", age = 28 }
	local values = linq.dict({
		["a"] = first,
		["b"] = second,
		["c"] = third,
	})

	local result = values:max(function(_, value)
		return value
	end, "a, b => a.age > b.age")

	luaunit.assertTrue(result == second)
end

function TestDictMax:testMaxFunctionSelectorComparerString_Negative_InvalidComparatorStringErrors()
	local values = linq.dict({ [1] = { age = 25 } })

	local ok, err = pcall(function()
		values:max(function(_, value)
			return value
		end, "age")
	end)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(tostring(err), "Expected a function for is_bigger parameter", 1, true) ~= nil)
end

function TestDictMax:testMaxStringSelectorComparerString_Positive_UsesComparatorExpression()
	local values = linq.dict({
		["a"] = { name = "iron" },
		["b"] = { name = "uranium" },
		["c"] = { name = "coal" },
	})

	local result = values:max("name", "a, b => #a > #b")

	luaunit.assertEquals(result, "uranium")
end

function TestDictMax:testMaxStringSelectorComparerString_Negative_InvalidComparatorStringErrors()
	local values = linq.dict({ [1] = { name = "iron" } })

	local ok, err = pcall(function()
		values:max("name", "name")
	end)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(tostring(err), "Expected a function for is_bigger parameter", 1, true) ~= nil)
end