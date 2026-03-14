local luaunit = require('luaunit')
local linq = require("linq")

TestDistinct = {}

local function collect(enumerable)
	local result = {}
	for value in enumerable:iter() do
		result[#result + 1] = value
	end
	return result
end

local function assertSequenceIs(actual, expected)
	luaunit.assertEquals(#actual, #expected)
	for i = 1, #expected do
		luaunit.assertTrue(actual[i] == expected[i])
	end
end

function TestDistinct:testDistinct_DefaultPositive_Primitives()
	local values = linq.list(1, 2, 1, 3, 2, 4)

	local result = collect(values:distinct())

	assertSequenceIs(result, { 1, 2, 3, 4 })
end

function TestDistinct:testDistinct_DefaultNegative_TableIdentityKeepsDistinctInstances()
	local first = { a = 1 }
	local second = { a = 1 }
	local shared = { a = 2 }
	local values = linq.list(first, second, shared, shared)

	local result = collect(values:distinct())

	assertSequenceIs(result, { first, second, shared })
end

function TestDistinct:testDistinct_DefaultEdge_FalseZeroAndEmptyString()
	local values = linq.list(false, false, 0, 0, "", "")

	local result = collect(values:distinct())

	assertSequenceIs(result, { false, 0, "" })
end

function TestDistinct:testDistinct_ComparerPositive_IgnoreCase()
	local values = linq.list("Alpha", "beta", "ALPHA", "Beta", "gamma")

	local result = collect(values:distinct(linq.IGNORE_CASE))

	assertSequenceIs(result, { "Alpha", "beta", "gamma" })
end

function TestDistinct:testDistinct_ComparerNegative_DifferentTypesStayDistinct()
	local values = linq.list("1", 1, "ONE", 1)

	local result = collect(values:distinct(linq.IGNORE_CASE))

	assertSequenceIs(result, { "1", 1, "ONE" })
end

function TestDistinct:testDistinct_ComparerEdge_OrderSensitiveSupersetComparer()
	local first = { a = 1 }
	local second = { a = 1, b = 2 }
	local third = { a = 1, b = 2, c = 3 }
	local values = linq.list(first, second, third)

	local result = collect(values:distinct(linq.TABLE_SUPERSET))

	assertSequenceIs(result, { first })
end

function TestDistinct:testDistinct_FunctionSelectorPositive_FirstLetter()
	local values = linq.list("alpha", "atom", "beta", "binary", "gamma")

	local result = collect(values:distinct(function(item)
		return string.sub(item, 1, 1)
	end))

	assertSequenceIs(result, { "alpha", "beta", "gamma" })
end

function TestDistinct:testDistinct_FunctionSelectorNegative_UniqueKeysKeepAll()
	local first = { id = 1, name = "alpha" }
	local second = { id = 2, name = "alpha" }
	local third = { id = 3, name = "alpha" }
	local values = linq.list(first, second, third)

	local result = collect(values:distinct(function(item)
		return item.id
	end))

	assertSequenceIs(result, { first, second, third })
end

function TestDistinct:testDistinct_FunctionSelectorEdge_NilKeysCollapseToFirst()
	local first = { id = 1 }
	local second = { id = 2 }
	local third = { id = 3, group = "a" }
	local fourth = { id = 4, group = "a" }
	local values = linq.list(first, second, third, fourth)

	local result = collect(values:distinct(function(item)
		return item.group
	end))

	assertSequenceIs(result, { first, third })
end

function TestDistinct:testDistinct_FunctionSelectorComparerPositive_IgnoreCase()
	local first = { name = "Alpha" }
	local second = { name = "beta" }
	local third = { name = "ALPHA" }
	local fourth = { name = "Beta" }
	local values = linq.list(first, second, third, fourth)

	local result = collect(values:distinct(function(item)
		return item.name
	end, linq.IGNORE_CASE))

	assertSequenceIs(result, { first, second })
end

function TestDistinct:testDistinct_FunctionSelectorComparerNegative_NonEqualKeysRemain()
	local first = { meta = { a = 1, b = 2 } }
	local second = { meta = { a = 1, b = 3 } }
	local third = { meta = { a = 1, b = 2, c = 3 } }
	local values = linq.list(first, second, third)

	local result = collect(values:distinct(function(item)
		return item.meta
	end, linq.TABLE_EQUAL))

	assertSequenceIs(result, { first, second, third })
end

function TestDistinct:testDistinct_FunctionSelectorComparerEdge_CombinedComparer()
	local first = { name = "  Alpha  " }
	local second = { name = "beta" }
	local third = { name = "alpha" }
	local fourth = { name = " BETA " }
	local values = linq.list(first, second, third, fourth)
	local comparer = linq.TRIM_EQUAL & linq.IGNORE_CASE

	local result = collect(values:distinct(function(item)
		return item.name
	end, comparer))

	assertSequenceIs(result, { first, second })
end

function TestDistinct:testDistinct_FunctionSelectorComparerEdge_NilKeysCollapseToFirst()
	local first = { id = 1 }
	local second = { id = 2 }
	local third = { id = 3, group = "Alpha" }
	local fourth = { id = 4, group = "alpha" }
	local values = linq.list(first, second, third, fourth)

	local result = collect(values:distinct(function(item)
		return item.group
	end, linq.IGNORE_CASE))

	assertSequenceIs(result, { first, third })
end

function TestDistinct:testDistinct_StringSelectorPositive_PropertyName()
	local first = { kind = "ore" }
	local second = { kind = "plate" }
	local third = { kind = "ore" }
	local fourth = { kind = "gear" }
	local values = linq.list(first, second, third, fourth)

	local result = collect(values:distinct("kind"))

	assertSequenceIs(result, { first, second, fourth })
end

function TestDistinct:testDistinct_StringSelectorNegative_UniquePropertiesKeepAll()
	local first = { kind = "ore", id = 1 }
	local second = { kind = "ore", id = 2 }
	local third = { kind = "ore", id = 3 }
	local values = linq.list(first, second, third)

	local result = collect(values:distinct("id"))

	assertSequenceIs(result, { first, second, third })
end

function TestDistinct:testDistinct_StringSelectorEdge_PredicateStringKeySelector()
	local values = linq.list("Alpha", "atom", "beta", "binary", "gamma")

	local result = collect(values:distinct("x => string.sub(x, 1, 1):lower()"))

	assertSequenceIs(result, { "Alpha", "beta", "gamma" })
end

function TestDistinct:testDistinct_StringSelectorComparerPositive_IgnoreCase()
	local first = { name = "Alpha" }
	local second = { name = "beta" }
	local third = { name = "ALPHA" }
	local fourth = { name = "Beta" }
	local values = linq.list(first, second, third, fourth)

	local result = collect(values:distinct("name", linq.IGNORE_CASE))

	assertSequenceIs(result, { first, second })
end

function TestDistinct:testDistinct_StringSelectorComparerNegative_TableValuesRemainWhenNotEqual()
	local first = { meta = { a = 1, b = 2 } }
	local second = { meta = { a = 1, b = 3 } }
	local third = { meta = { a = 1, b = 2, c = 3 } }
	local values = linq.list(first, second, third)

	local result = collect(values:distinct("meta", linq.TABLE_EQUAL))

	assertSequenceIs(result, { first, second, third })
end

function TestDistinct:testDistinct_StringSelectorComparerEdge_PredicateStringWithCombinedComparer()
	local first = { name = "  Alpha  " }
	local second = { name = "beta" }
	local third = { name = "alpha" }
	local fourth = { name = " BETA " }
	local values = linq.list(first, second, third, fourth)
	local comparer = linq.TRIM_EQUAL & linq.IGNORE_CASE

	local result = collect(values:distinct("item => item.name", comparer))

	assertSequenceIs(result, { first, second })
end

function TestDistinct:testDistinct_StringSelectorEdge_MissingKeysCollapseToFirst()
	local first = { id = 1 }
	local second = { id = 2 }
	local third = { id = 3, group = "a" }
	local fourth = { id = 4, group = "a" }
	local values = linq.list(first, second, third, fourth)

	local result = collect(values:distinct("group"))

	assertSequenceIs(result, { first, third })
end

function TestDistinct:testDistinct_StringSelectorComparerEdge_MissingKeysCollapseToFirst()
	local first = { id = 1 }
	local second = { id = 2 }
	local third = { id = 3, group = "Alpha" }
	local fourth = { id = 4, group = "alpha" }
	local values = linq.list(first, second, third, fourth)

	local result = collect(values:distinct("group", linq.IGNORE_CASE))

	assertSequenceIs(result, { first, third })
end

function TestDistinct:testDistinct_InvalidStringSelectorErrors()
	local ok, err = pcall(function()
		linq.list(1, 2, 3):distinct("x => x >")
	end)
	local err_text = tostring(err)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(err_text, "Invalid predicate string", 1, true) ~= nil)
end
