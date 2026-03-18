local luaunit = require('luaunit')
local linq = require("linq")

TestDictDistinct = {}

local MISSING = {}

local function collect(enumerable)
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

local function assertScalarSetEquals(actual, expected)
	luaunit.assertEquals(#actual, #expected)
	local remaining = {}
	for i = 1, #actual do
		remaining[i] = actual[i]
	end
	for _, expected_value in ipairs(expected) do
		local matched_index = nil
		for index, actual_value in ipairs(remaining) do
			if actual_value == expected_value then
				matched_index = index
				break
			end
		end
		luaunit.assertNotNil(matched_index)
		table.remove(remaining, matched_index)
	end
end

local function assertPairSetEquals(actual, expected)
	luaunit.assertEquals(#actual, #expected)
	local remaining = {}
	for i = 1, #actual do
		remaining[i] = actual[i]
	end
	for _, expected_entry in ipairs(expected) do
		local matched_index = nil
		for index, actual_entry in ipairs(remaining) do
			if actual_entry.key == expected_entry.key and actual_entry.value == expected_entry.value then
				matched_index = index
				break
			end
		end
		luaunit.assertNotNil(matched_index)
		table.remove(remaining, matched_index)
	end
end

function TestDictDistinct:testDistinct_DefaultPositive_PrimitiveValues()
	local values = linq.dict({
		[1] = 1,
		[2] = 2,
		[3] = 1,
		[4] = 3,
		[5] = 2,
	})

	local result = collect(values:distinct())

	assertScalarSetEquals(project(result, function(_, value)
		return value
	end), { 1, 2, 3 })
	end

function TestDictDistinct:testDistinct_DefaultNegative_TableIdentityKeepsDistinctInstances()
	local first = { a = 1 }
	local second = { a = 1 }
	local shared = { a = 2 }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = shared,
		[4] = shared,
	})

	local result = collect(values:distinct())

	assertScalarSetEquals(project(result, function(_, value)
		return value
	end), { first, second, shared })
	end

function TestDictDistinct:testDistinct_DefaultEdge_FalseZeroAndEmptyString()
	local values = linq.dict({
		[1] = false,
		[2] = false,
		[3] = 0,
		[4] = 0,
		[5] = "",
		[6] = "",
	})

	local result = collect(values:distinct())

	assertScalarSetEquals(project(result, function(_, value)
		return value
	end), { false, 0, "" })
	end

function TestDictDistinct:testDistinct_ComparerPositive_IgnoreCase()
	local values = linq.dict({
		[1] = "Alpha",
		[2] = "beta",
		[3] = "ALPHA",
		[4] = "Beta",
		[5] = "gamma",
	})

	local result = collect(values:distinct(linq.IGNORE_CASE))

	assertScalarSetEquals(project(result, function(_, value)
		return string.lower(value)
	end), { "alpha", "beta", "gamma" })
	end

function TestDictDistinct:testDistinct_ComparerNegative_DifferentTypesStayDistinct()
	local values = linq.dict({
		[1] = "1",
		[2] = 1,
		[3] = "ONE",
		[4] = 1,
	})

	local result = collect(values:distinct(linq.IGNORE_CASE))

	luaunit.assertEquals(#result, 3)
	local lowercase_strings = project(result, function(_, value)
		if type(value) == "string" then
			return string.lower(value)
		end
		return value
	end)
	assertScalarSetEquals(lowercase_strings, { "1", 1, "one" })
	end

function TestDictDistinct:testDistinct_ComparerEdge_OrderSensitiveSupersetComparer()
	local first = { a = 1 }
	local second = { a = 1 }
	local third = { a = 1 }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:distinct(linq.TABLE_SUPERSET))

	luaunit.assertEquals(#result, 1)
	luaunit.assertTrue(result[1].value == first or result[1].value == second or result[1].value == third)
	end

function TestDictDistinct:testDistinct_FunctionSelectorPositive_FirstLetter()
	local values = linq.dict({
		[1] = "alpha",
		[2] = "atom",
		[3] = "beta",
		[4] = "binary",
		[5] = "gamma",
	})

	local result = collect(values:distinct(function(_, value)
		return string.sub(value, 1, 1)
	end))

	assertScalarSetEquals(project(result, function(_, value)
		return string.sub(value, 1, 1)
	end), { "a", "b", "g" })
	end

function TestDictDistinct:testDistinct_FunctionSelectorNegative_UniqueKeysKeepAll()
	local values = linq.dict({
		[1] = "alpha",
		[2] = "alpha",
		[3] = "alpha",
	})

	local result = collect(values:distinct(function(key)
		return key
	end))

	assertPairSetEquals(result, {
		{ key = 1, value = "alpha" },
		{ key = 2, value = "alpha" },
		{ key = 3, value = "alpha" },
	})
	end

function TestDictDistinct:testDistinct_FunctionSelectorEdge_NilKeysCollapseToFirst()
	local values = linq.dict({
		[1] = { id = 1 },
		[2] = { id = 2 },
		[3] = { id = 3, group = "a" },
		[4] = { id = 4, group = "a" },
	})

	local result = collect(values:distinct(function(_, value)
		return value.group
	end))

	assertScalarSetEquals(project(result, function(_, value)
		return value.group or MISSING
	end), { MISSING, "a" })
	end

function TestDictDistinct:testDistinct_FunctionSelectorComparerPositive_IgnoreCase()
	local values = linq.dict({
		[1] = { name = "Alpha" },
		[2] = { name = "beta" },
		[3] = { name = "ALPHA" },
		[4] = { name = "Beta" },
	})

	local result = collect(values:distinct(function(_, value)
		return value.name
	end, linq.IGNORE_CASE))

	assertScalarSetEquals(project(result, function(_, value)
		return string.lower(value.name)
	end), { "alpha", "beta" })
	end

function TestDictDistinct:testDistinct_FunctionSelectorComparerNegative_NonEqualKeysRemain()
	local first = { meta = { a = 1, b = 2 } }
	local second = { meta = { a = 1, b = 3 } }
	local third = { meta = { a = 1, b = 2, c = 3 } }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:distinct(function(_, value)
		return value.meta
	end, linq.TABLE_EQUAL))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 2, value = second },
		{ key = 3, value = third },
	})
	end

function TestDictDistinct:testDistinct_FunctionSelectorComparerEdge_CombinedComparer()
	local values = linq.dict({
		[1] = { name = "  Alpha  " },
		[2] = { name = "beta" },
		[3] = { name = "alpha" },
		[4] = { name = " BETA " },
	})
	local comparer = linq.TRIM_EQUAL & linq.IGNORE_CASE

	local result = collect(values:distinct(function(_, value)
		return value.name
	end, comparer))

	assertScalarSetEquals(project(result, function(_, value)
		return value.name:match("^%s*(.-)%s*$"):lower()
	end), { "alpha", "beta" })
	end

function TestDictDistinct:testDistinct_StringSelectorPositive_PropertyName()
	local values = linq.dict({
		[1] = { kind = "ore" },
		[2] = { kind = "plate" },
		[3] = { kind = "ore" },
		[4] = { kind = "gear" },
	})

	local result = collect(values:distinct("kind"))

	assertScalarSetEquals(project(result, function(_, value)
		return value.kind
	end), { "ore", "plate", "gear" })
	end

function TestDictDistinct:testDistinct_StringSelectorNegative_UniquePropertiesKeepAll()
	local first = { kind = "ore", id = 1 }
	local second = { kind = "ore", id = 2 }
	local third = { kind = "ore", id = 3 }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:distinct("id"))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 2, value = second },
		{ key = 3, value = third },
	})
	end

function TestDictDistinct:testDistinct_StringSelectorEdge_PredicateStringKeySelector()
	local values = linq.dict({
		[1] = "Alpha",
		[2] = "atom",
		[3] = "beta",
		[4] = "binary",
		[5] = "gamma",
	})

	local result = collect(values:distinct("k, v => string.sub(v, 1, 1):lower()"))

	assertScalarSetEquals(project(result, function(_, value)
		return string.sub(value, 1, 1):lower()
	end), { "a", "b", "g" })
	end

function TestDictDistinct:testDistinct_StringSelectorComparerPositive_IgnoreCase()
	local first = { name = "Alpha" }
	local second = { name = "beta" }
	local third = { name = "ALPHA" }
	local fourth = { name = "Beta" }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
		[4] = fourth,
	})

	local result = collect(values:distinct("k, v => v.name", linq.IGNORE_CASE))

	assertScalarSetEquals(project(result, function(_, value)
		return string.lower(value.name)
	end), { "alpha", "beta" })
	end

function TestDictDistinct:testDistinct_StringSelectorComparerNegative_UniquePredicateKeysKeepAll()
	local first = { name = "Alpha" }
	local second = { name = "Beta" }
	local third = { name = "Gamma" }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:distinct("k, v => v.name", linq.IGNORE_CASE))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 2, value = second },
		{ key = 3, value = third },
	})
	end

function TestDictDistinct:testDistinct_StringSelectorComparerEdge_MissingKeysCollapseToFirst()
	local first = { id = 1 }
	local second = { id = 2 }
	local third = { id = 3, group = "Alpha" }
	local fourth = { id = 4, group = "alpha" }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
		[4] = fourth,
	})

	local result = collect(values:distinct("k, v => v.group", linq.IGNORE_CASE))

	assertScalarSetEquals(project(result, function(_, value)
		return value.group and string.lower(value.group) or MISSING
	end), { MISSING, "alpha" })
	end

function TestDictDistinct:testDistinct_InvalidStringSelectorErrors()
	local ok, err = pcall(function()
		linq.dict({ [1] = 1, [2] = 2, [3] = 3 }):distinct("k, v => v >")
	end)
	local err_text = tostring(err)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(err_text, "Invalid predicate string", 1, true) ~= nil)
	end