local luaunit = require('luaunit')
local linq = require("linq")

TestDictMin = {}

function TestDictMin:testMinDefault_Positive_ReturnsSmallestValue()
	local values = linq.dict({
		[1] = 4,
		[2] = 12,
		[3] = 7,
	})

	luaunit.assertEquals(values:min(), 4)
end

function TestDictMin:testMinDefault_Edge_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	luaunit.assertNil(values:min())
end

function TestDictMin:testMinFunctionSelector_Positive_ProjectsFromKeyAndValue()
	local values = linq.dict({
		[1] = 4,
		[2] = 12,
		[3] = 7,
	})

	local result = values:min(function(key, value)
		return key + value
	end)

	luaunit.assertEquals(result, 5)
end

function TestDictMin:testMinFunctionSelector_Negative_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	local result = values:min(function(key, value)
		return key + value
	end)

	luaunit.assertNil(result)
end

function TestDictMin:testMinStringSelector_Positive_ProjectsValueProperty()
	local values = linq.dict({
		["a"] = { age = 25 },
		["b"] = { age = 30 },
		["c"] = { age = 28 },
	})

	luaunit.assertEquals(values:min("age"), 25)
end

function TestDictMin:testMinStringSelector_Negative_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	luaunit.assertNil(values:min("age"))
end

function TestDictMin:testMinFunctionSelectorComparerFunction_Positive_UsesCustomOrdering()
	local first = { name = "tom", age = 25 }
	local second = { name = "maximilian", age = 30 }
	local third = { name = "isa", age = 28 }
	local values = linq.dict({
		["a"] = first,
		["b"] = second,
		["c"] = third,
	})

	local result = values:min(function(_, value)
		return value
	end, function(a, b)
		return #a.name < #b.name
	end)

	luaunit.assertTrue(result == first or result == third)
end

function TestDictMin:testMinFunctionSelectorComparerFunction_Edge_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	local result = values:min(function(_, value)
		return value
	end, function(a, b)
		return a.age < b.age
	end)

	luaunit.assertNil(result)
end

function TestDictMin:testMinStringSelectorComparerFunction_Positive_UsesCustomOrdering()
	local values = linq.dict({
		["a"] = { score = -2 },
		["b"] = { score = 7 },
		["c"] = { score = -9 },
		["d"] = { score = 4 },
	})

	local result = values:min("score", function(a, b)
		return math.abs(a) < math.abs(b)
	end)

	luaunit.assertEquals(result, -2)
end

function TestDictMin:testMinStringSelectorComparerFunction_Edge_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	local result = values:min("score", function(a, b)
		return a < b
	end)

	luaunit.assertNil(result)
end

function TestDictMin:testMinFunctionSelectorComparerString_Positive_UsesComparatorExpression()
	local first = { name = "tom", age = 25 }
	local second = { name = "max", age = 30 }
	local third = { name = "isa", age = 28 }
	local values = linq.dict({
		["a"] = first,
		["b"] = second,
		["c"] = third,
	})

	local result = values:min(function(_, value)
		return value
	end, "a, b => a.age < b.age")

	luaunit.assertTrue(result == first)
end

function TestDictMin:testMinFunctionSelectorComparerString_Negative_InvalidComparatorStringErrors()
	local values = linq.dict({ [1] = { age = 25 } })

	local ok, err = pcall(function()
		values:min(function(_, value)
			return value
		end, "age")
	end)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(tostring(err), "Expected a function for is_smaller parameter", 1, true) ~= nil)
end

function TestDictMin:testMinStringSelectorComparerString_Positive_UsesComparatorExpression()
	local values = linq.dict({
		["a"] = { name = "iron" },
		["b"] = { name = "uranium" },
		["c"] = { name = "coal" },
	})

	local result = values:min("name", "a, b => #a < #b")

	luaunit.assertTrue(result == "iron" or result == "coal")
end

function TestDictMin:testMinStringSelectorComparerString_Negative_InvalidComparatorStringErrors()
	local values = linq.dict({ [1] = { name = "iron" } })

	local ok, err = pcall(function()
		values:min("name", "name")
	end)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(tostring(err), "Expected a function for is_smaller parameter", 1, true) ~= nil)
end