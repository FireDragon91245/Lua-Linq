local luaunit = require('luaunit')
local linq = require("linq")

TestDictSort = {}

local function collect_pairs(enumerable)
	local result = {}
	for key, value in enumerable:iter() do
		result[#result + 1] = { key = key, value = value }
	end
	return result
end

local function project(entries, selector)
	local result = {}
	for _, entry in ipairs(entries) do
		result[#result + 1] = selector(entry.key, entry.value)
	end
	return result
end

local function assertSequenceEquals(actual, expected)
	luaunit.assertEquals(#actual, #expected)
	for i = 1, #expected do
		luaunit.assertEquals(actual[i], expected[i])
	end
end

function TestDictSort:testSortDefault_Positive_SortsByValueAscending()
	local values = linq.dict({
		[1] = "beta",
		[2] = "alpha",
		[3] = "gamma",
	})

	local result = project(collect_pairs(values:sort()), function(key, value)
		return key .. ":" .. value
	end)

	assertSequenceEquals(result, { "2:alpha", "1:beta", "3:gamma" })
	end

function TestDictSort:testSortDefault_Negative_EmptyEnumerable()
	local values = linq.dict({})

	local result = collect_pairs(values:sort())

	assertSequenceEquals(result, {})
	end

function TestDictSort:testSortDefault_Edge_SingleEntryRemainsUnchanged()
	local values = linq.dict({
		[4] = "solo",
	})

	local result = project(collect_pairs(values:sort()), function(key, value)
		return key .. ":" .. value
	end)

	assertSequenceEquals(result, { "4:solo" })
	end

function TestDictSort:testSortComparer_Positive_UsesEqualityComparerNormalization()
	local values = linq.dict({
		[1] = "beta",
		[2] = "Alpha",
		[3] = "gamma",
	})

	local result = project(collect_pairs(values:sort(linq.IGNORE_CASE)), function(key, value)
		return key .. ":" .. value
	end)

	assertSequenceEquals(result, { "2:Alpha", "1:beta", "3:gamma" })
	end

function TestDictSort:testSortComparer_Negative_EmptyEnumerable()
	local values = linq.dict({})

	local result = collect_pairs(values:sort(linq.IGNORE_CASE))

	assertSequenceEquals(result, {})
	end

function TestDictSort:testSortComparer_Edge_CombinedComparerAppliesTrimAndCaseNormalization()
	local values = linq.dict({
		[1] = "  gamma",
		[2] = "beta  ",
		[3] = " Alpha ",
	})
	local comparer = linq.TRIM_EQUAL & linq.IGNORE_CASE

	local result = project(collect_pairs(values:sort(comparer)), function(key, value)
		return key .. ":" .. value
	end)

	assertSequenceEquals(result, { "3: Alpha ", "2:beta  ", "1:  gamma" })
	end

function TestDictSort:testSortFunctionSelectorComparer_Positive_SortsProjectedValues()
	local values = linq.dict({
		[1] = { name = "beta" },
		[2] = { name = "Alpha" },
		[3] = { name = "gamma" },
	})

	local result = project(collect_pairs(values:sort(function(_, value)
		return value.name
	end, linq.IGNORE_CASE)), function(key, value)
		return key .. ":" .. value.name
	end)

	assertSequenceEquals(result, { "2:Alpha", "1:beta", "3:gamma" })
	end

function TestDictSort:testSortFunctionSelectorComparer_Negative_EmptyEnumerable()
	local values = linq.dict({})

	local result = collect_pairs(values:sort(function(_, value)
		return value.name
	end, linq.IGNORE_CASE))

	assertSequenceEquals(result, {})
	end

function TestDictSort:testSortFunctionSelectorComparer_Edge_CombinedComparerAppliesToProjection()
	local values = linq.dict({
		[1] = { name = "  gamma" },
		[2] = { name = "beta  " },
		[3] = { name = " Alpha " },
	})
	local comparer = linq.TRIM_EQUAL & linq.IGNORE_CASE

	local result = project(collect_pairs(values:sort(function(_, value)
		return value.name
	end, comparer)), function(key, value)
		return key .. ":" .. value.name
	end)

	assertSequenceEquals(result, { "3: Alpha ", "2:beta  ", "1:  gamma" })
	end

function TestDictSort:testSortStringSelectorComparer_Positive_SortsPropertyWithEqualityComparer()
	local values = linq.dict({
		[1] = { name = "beta" },
		[2] = { name = "Alpha" },
		[3] = { name = "gamma" },
	})

	local result = project(collect_pairs(values:sort("name", linq.IGNORE_CASE)), function(key, value)
		return key .. ":" .. value.name
	end)

	assertSequenceEquals(result, { "2:Alpha", "1:beta", "3:gamma" })
	end

function TestDictSort:testSortStringSelectorComparer_Negative_EmptyEnumerableWithNilSelector()
	local values = linq.dict({})

	local result = collect_pairs(values:sort(nil, linq.IGNORE_CASE))

	assertSequenceEquals(result, {})
	end

function TestDictSort:testSortStringSelectorComparer_Edge_ExpressionSelectorUsesComparerNormalization()
	local values = linq.dict({
		[1] = { name = "  gamma" },
		[2] = { name = "beta  " },
		[3] = { name = " Alpha " },
	})
	local comparer = linq.TRIM_EQUAL & linq.IGNORE_CASE

	local result = project(collect_pairs(values:sort("k, v => v.name", comparer)), function(key, value)
		return key .. ":" .. value.name
	end)

	assertSequenceEquals(result, { "3: Alpha ", "2:beta  ", "1:  gamma" })
	end

function TestDictSort:testSortFunctionSelector_Positive_SortsByProjectedRank()
	local values = linq.dict({
		[1] = { rank = 2 },
		[2] = { rank = 1 },
		[3] = { rank = 3 },
	})

	local result = project(collect_pairs(values:sort(function(_, value)
		return value.rank
	end)), function(key, value)
		return key .. ":" .. value.rank
	end)

	assertSequenceEquals(result, { "2:1", "1:2", "3:3" })
	end

function TestDictSort:testSortFunctionSelector_Negative_EmptyEnumerable()
	local values = linq.dict({})

	local result = collect_pairs(values:sort(function(_, value)
		return value.rank
	end))

	assertSequenceEquals(result, {})
	end

function TestDictSort:testSortFunctionSelector_Edge_NilAndFalseyProjectionValuesAreHandled()
	local values = linq.dict({
		["truthy"] = { flag = true },
		["missing"] = {},
		["falsey"] = { flag = false },
	})

	local result = project(collect_pairs(values:sort(function(_, value)
		return value.flag
	end)), function(key)
		return key
	end)

	assertSequenceEquals(result, { "missing", "falsey", "truthy" })
	end

function TestDictSort:testSortStringSelector_Positive_SortsByProperty()
	local values = linq.dict({
		[1] = { name = "beta" },
		[2] = { name = "alpha" },
		[3] = { name = "gamma" },
	})

	local result = project(collect_pairs(values:sort("name")), function(key, value)
		return key .. ":" .. value.name
	end)

	assertSequenceEquals(result, { "2:alpha", "1:beta", "3:gamma" })
	end

function TestDictSort:testSortStringSelector_Negative_EmptyEnumerable()
	local values = linq.dict({})

	local result = collect_pairs(values:sort("name"))

	assertSequenceEquals(result, {})
	end

function TestDictSort:testSortStringSelector_Edge_ExpressionSelectorSortsBySingleDigitLength()
	local values = linq.dict({
		[1] = { name = "ccc" },
		[2] = { name = "a" },
		[3] = { name = "bb" },
	})

	local result = project(collect_pairs(values:sort("k, v => #v.name")), function(key, value)
		return key .. ":" .. value.name
	end)

	assertSequenceEquals(result, { "2:a", "3:bb", "1:ccc" })
	end

function TestDictSort:testSortFunctionSelectorComparerFunction_Positive_UsesCustomOrdering()
	local values = linq.dict({
		[1] = { rank = 1 },
		[2] = { rank = 3 },
		[3] = { rank = 2 },
	})

	local result = project(collect_pairs(values:sort(function(_, value)
		return value.rank
	end, function(a, b)
		return a > b
	end)), function(key, value)
		return key .. ":" .. value.rank
	end)

	assertSequenceEquals(result, { "2:3", "3:2", "1:1" })
	end

function TestDictSort:testSortFunctionSelectorComparerFunction_Negative_EmptyEnumerable()
	local values = linq.dict({})

	local result = collect_pairs(values:sort(function(_, value)
		return value.rank
	end, function(a, b)
		return a > b
	end))

	assertSequenceEquals(result, {})
	end

function TestDictSort:testSortFunctionSelectorComparerFunction_Edge_CustomOrderingCanUseDerivedMetrics()
	local values = linq.dict({
		[1] = { name = "ccc" },
		[2] = { name = "a" },
		[3] = { name = "bb" },
	})

	local result = project(collect_pairs(values:sort(function(_, value)
		return value.name
	end, function(a, b)
		return #a < #b
	end)), function(key, value)
		return key .. ":" .. value.name
	end)

	assertSequenceEquals(result, { "2:a", "3:bb", "1:ccc" })
	end

function TestDictSort:testSortStringSelectorComparerFunction_Positive_SortsPropertyWithCustomOrdering()
	local values = linq.dict({
		[1] = { rank = 1 },
		[2] = { rank = 3 },
		[3] = { rank = 2 },
	})

	local result = project(collect_pairs(values:sort("rank", function(a, b)
		return a > b
	end)), function(key, value)
		return key .. ":" .. value.rank
	end)

	assertSequenceEquals(result, { "2:3", "3:2", "1:1" })
	end

function TestDictSort:testSortStringSelectorComparerFunction_Negative_EmptyEnumerableWithNilSelector()
	local values = linq.dict({})

	local result = collect_pairs(values:sort(nil, function(a, b)
		return a > b
	end))

	assertSequenceEquals(result, {})
	end

function TestDictSort:testSortStringSelectorComparerFunction_Edge_ExpressionSelectorUsesCustomOrdering()
	local values = linq.dict({
		[1] = { name = "ccc" },
		[2] = { name = "a" },
		[3] = { name = "bb" },
	})

	local result = project(collect_pairs(values:sort("k, v => v.name", function(a, b)
		return #a < #b
	end)), function(key, value)
		return key .. ":" .. value.name
	end)

	assertSequenceEquals(result, { "2:a", "3:bb", "1:ccc" })
	end

function TestDictSort:testSortStringSelectorComparerString_Positive_UsesComparatorExpression()
	local values = linq.dict({
		[1] = { name = "ccc" },
		[2] = { name = "a" },
		[3] = { name = "bb" },
	})

	local result = project(collect_pairs(values:sort("name", "a, b => #a < #b")), function(key, value)
		return key .. ":" .. value.name
	end)

	assertSequenceEquals(result, { "2:a", "3:bb", "1:ccc" })
	end

function TestDictSort:testSortStringSelectorComparerString_Negative_InvalidComparerStringErrors()
	local values = linq.dict({
		[1] = { name = "alpha" },
		[2] = { name = "beta" },
	})

	local ok, err = pcall(function()
		collect_pairs(values:sort("name", "a, b => )"))
	end)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(tostring(err), "Invalid comparer string: a, b => )", 1, true) ~= nil)
	end

function TestDictSort:testSortStringSelectorComparerString_Edge_NilSelectorCanSortDirectValues()
	local values = linq.dict({
		[1] = "alpha",
		[2] = "gamma",
		[3] = "beta",
	})

	local result = project(collect_pairs(values:sort(nil, "a, b => a > b")), function(key, value)
		return key .. ":" .. value
	end)

	assertSequenceEquals(result, { "2:gamma", "3:beta", "1:alpha" })
	end