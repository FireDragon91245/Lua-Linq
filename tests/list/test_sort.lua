local luaunit = require('luaunit')
local linq = require("linq")

TestSort = {}

local function collect(enumerable)
	local result = {}
	for value in enumerable:iter() do
		result[#result + 1] = value
	end
	return result
end

local function assertSequenceEquals(actual, expected)
	luaunit.assertEquals(#actual, #expected)
	for i = 1, #expected do
		luaunit.assertEquals(actual[i], expected[i])
	end
end

function TestSort:testSortDefault_Positive_SortsStringsAscending()
	local values = linq.list("beta", "alpha", "gamma")

	local result = collect(values:sort())

	assertSequenceEquals(result, { "alpha", "beta", "gamma" })
	end

function TestSort:testSortDefault_Negative_EmptyEnumerable()
	local values = linq.list()

	local result = collect(values:sort())

	assertSequenceEquals(result, {})
	end

function TestSort:testSortDefault_Edge_PreservesDuplicateValues()
	local values = linq.list("beta", "alpha", "alpha")

	local result = collect(values:sort())

	assertSequenceEquals(result, { "alpha", "alpha", "beta" })
	end

function TestSort:testSortComparer_Positive_UsesEqualityComparerNormalization()
	local values = linq.list("beta", "Alpha", "gamma")

	local result = collect(values:sort(linq.IGNORE_CASE))

	assertSequenceEquals(result, { "Alpha", "beta", "gamma" })
	end

function TestSort:testSortComparer_Negative_EmptyEnumerable()
	local values = linq.list()

	local result = collect(values:sort(linq.IGNORE_CASE))

	assertSequenceEquals(result, {})
	end

function TestSort:testSortComparer_Edge_CombinedComparerAppliesTrimAndCaseNormalization()
	local values = linq.list("  gamma", "beta  ", " Alpha ")
	local comparer = linq.TRIM_EQUAL & linq.IGNORE_CASE

	local result = collect(values:sort(comparer))

	assertSequenceEquals(result, { " Alpha ", "beta  ", "  gamma" })
	end

function TestSort:testSortFunctionSelectorComparer_Positive_SortsProjectedValues()
	local values = linq.list(
		{ name = "beta" },
		{ name = "Alpha" },
		{ name = "gamma" }
	)

	local result = collect(values:sort(function(item)
		return item.name
	end, linq.IGNORE_CASE):select("name"))

	assertSequenceEquals(result, { "Alpha", "beta", "gamma" })
	end

function TestSort:testSortFunctionSelectorComparer_Negative_EmptyEnumerable()
	local values = linq.list()

	local result = collect(values:sort(function(item)
		return item.name
	end, linq.IGNORE_CASE))

	assertSequenceEquals(result, {})
	end

function TestSort:testSortFunctionSelectorComparer_Edge_CombinedComparerAppliesToProjection()
	local values = linq.list(
		{ name = "  gamma" },
		{ name = "beta  " },
		{ name = " Alpha " }
	)
	local comparer = linq.TRIM_EQUAL & linq.IGNORE_CASE

	local result = collect(values:sort(function(item)
		return item.name
	end, comparer):select("name"))

	assertSequenceEquals(result, { " Alpha ", "beta  ", "  gamma" })
	end

function TestSort:testSortStringSelectorComparer_Positive_SortsPropertyWithEqualityComparer()
	local values = linq.list(
		{ name = "beta" },
		{ name = "Alpha" },
		{ name = "gamma" }
	)

	local result = collect(values:sort("name", linq.IGNORE_CASE):select("name"))

	assertSequenceEquals(result, { "Alpha", "beta", "gamma" })
	end

function TestSort:testSortStringSelectorComparer_Negative_EmptyEnumerableWithNilSelector()
	local values = linq.list()

	local result = collect(values:sort(nil, linq.IGNORE_CASE))

	assertSequenceEquals(result, {})
	end

function TestSort:testSortStringSelectorComparer_Edge_ExpressionSelectorUsesComparerNormalization()
	local values = linq.list(
		{ name = "  gamma" },
		{ name = "beta  " },
		{ name = " Alpha " }
	)
	local comparer = linq.TRIM_EQUAL & linq.IGNORE_CASE

	local result = collect(values:sort("item => item.name", comparer):select("name"))

	assertSequenceEquals(result, { " Alpha ", "beta  ", "  gamma" })
	end

function TestSort:testSortFunctionSelector_Positive_SortsByProjectedLength()
	local values = linq.list("bbb", "a", "cc")

	local result = collect(values:sort(function(item)
		return #item
	end))

	assertSequenceEquals(result, { "a", "cc", "bbb" })
	end

function TestSort:testSortFunctionSelector_Negative_EmptyEnumerable()
	local values = linq.list()

	local result = collect(values:sort(function(item)
		return #item
	end))

	assertSequenceEquals(result, {})
	end

function TestSort:testSortFunctionSelector_Edge_FalseyProjectionValuesStillSort()
	local values = linq.list(
		{ flag = true },
		{ flag = false }
	)

	local result = collect(values:sort(function(item)
		return item.flag
	end):select("flag"))

	assertSequenceEquals(result, { false, true })
	end

function TestSort:testSortStringSelector_Positive_SortsByProperty()
	local values = linq.list(
		{ name = "beta" },
		{ name = "alpha" },
		{ name = "gamma" }
	)

	local result = collect(values:sort("name"):select("name"))

	assertSequenceEquals(result, { "alpha", "beta", "gamma" })
	end

function TestSort:testSortStringSelector_Negative_EmptyEnumerable()
	local values = linq.list()

	local result = collect(values:sort("name"))

	assertSequenceEquals(result, {})
	end

function TestSort:testSortStringSelector_Edge_ExpressionSelectorSortsBySingleDigitLength()
	local values = linq.list("bbb", "a", "cc")

	local result = collect(values:sort("item => #item"))

	assertSequenceEquals(result, { "a", "cc", "bbb" })
	end

function TestSort:testSortFunctionSelectorComparerFunction_Positive_UsesCustomOrdering()
	local values = linq.list(
		{ rank = 1 },
		{ rank = 3 },
		{ rank = 2 }
	)

	local result = collect(values:sort(function(item)
		return item.rank
	end, function(a, b)
		return a > b
	end):select("rank"))

	assertSequenceEquals(result, { 3, 2, 1 })
	end

function TestSort:testSortFunctionSelectorComparerFunction_Negative_EmptyEnumerable()
	local values = linq.list()

	local result = collect(values:sort(function(item)
		return item.rank
	end, function(a, b)
		return a > b
	end))

	assertSequenceEquals(result, {})
	end

function TestSort:testSortFunctionSelectorComparerFunction_Edge_CustomOrderingCanUseDerivedMetrics()
	local values = linq.list(
		{ name = "ccc" },
		{ name = "a" },
		{ name = "bb" }
	)

	local result = collect(values:sort(function(item)
		return item.name
	end, function(a, b)
		return #a < #b
	end):select("name"))

	assertSequenceEquals(result, { "a", "bb", "ccc" })
	end

function TestSort:testSortStringSelectorComparerFunction_Positive_SortsPropertyWithCustomOrdering()
	local values = linq.list(
		{ rank = 1 },
		{ rank = 3 },
		{ rank = 2 }
	)

	local result = collect(values:sort("rank", function(a, b)
		return a > b
	end):select("rank"))

	assertSequenceEquals(result, { 3, 2, 1 })
	end

function TestSort:testSortStringSelectorComparerFunction_Negative_EmptyEnumerableWithNilSelector()
	local values = linq.list()

	local result = collect(values:sort(nil, function(a, b)
		return a > b
	end))

	assertSequenceEquals(result, {})
	end

function TestSort:testSortStringSelectorComparerFunction_Edge_ExpressionSelectorUsesCustomOrdering()
	local values = linq.list(
		{ name = "ccc" },
		{ name = "a" },
		{ name = "bb" }
	)

	local result = collect(values:sort("item => item.name", function(a, b)
		return #a < #b
	end):select("name"))

	assertSequenceEquals(result, { "a", "bb", "ccc" })
	end

function TestSort:testSortStringSelectorComparerString_Positive_UsesComparatorExpression()
	local values = linq.list(
		{ name = "ccc" },
		{ name = "a" },
		{ name = "bb" }
	)

	local result = collect(values:sort("name", "a, b => #a < #b"):select("name"))

	assertSequenceEquals(result, { "a", "bb", "ccc" })
	end

function TestSort:testSortStringSelectorComparerString_Negative_InvalidComparerStringErrors()
	local values = linq.list(
		{ name = "alpha" },
		{ name = "beta" }
	)

	local ok, err = pcall(function()
		collect(values:sort("name", "a, b => )"))
	end)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(tostring(err), "Invalid comparer string: a, b => )", 1, true) ~= nil)
	end

function TestSort:testSortStringSelectorComparerString_Edge_NilSelectorCanSortDirectValues()
	local values = linq.list("alpha", "gamma", "beta")

	local result = collect(values:sort(nil, "a, b => a > b"))

	assertSequenceEquals(result, { "gamma", "beta", "alpha" })
	end