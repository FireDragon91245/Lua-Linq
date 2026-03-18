local luaunit = require('luaunit')
local linq = require("linq")

TestDictWhere = {}

local function collect(enumerable)
	local result = {}
	for key, value in enumerable:iter() do
		result[#result + 1] = { key = key, value = value }
	end
	return result
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

function TestDictWhere:testWherePredicateFunction_Positive()
	local values = linq.dict({ [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5 })

	local result = collect(values:where(function(_, value)
		return value % 2 == 0
	end))

	assertPairSetEquals(result, {
		{ key = 2, value = 2 },
		{ key = 4, value = 4 },
	})
	end

function TestDictWhere:testWherePredicateFunction_Negative()
	local values = linq.dict({ [1] = 1, [2] = 3, [3] = 5 })

	local result = collect(values:where(function(_, value)
		return value % 2 == 0
	end))

	assertPairSetEquals(result, {})
	end

function TestDictWhere:testWherePredicateFunction_EdgeTruthySelectorStyle()
	local first = { active = true }
	local second = { active = false }
	local third = { active = true }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where(function(_, value)
		return value.active
	end))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWherePredicateString_Positive()
	local values = linq.dict({ [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5 })

	local result = collect(values:where("k, v => v > 3"))

	assertPairSetEquals(result, {
		{ key = 4, value = 4 },
		{ key = 5, value = 5 },
	})
	end

function TestDictWhere:testWherePredicateString_Negative()
	local values = linq.dict({ [1] = 1, [2] = 2, [3] = 3 })

	local result = collect(values:where("k, v => v > 9"))

	assertPairSetEquals(result, {})
	end

function TestDictWhere:testWherePredicateString_EdgeNamedParameters()
	local first = { active = true, count = 2 }
	local second = { active = false, count = 5 }
	local third = { active = true, count = 1 }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where("k, v => v.active and v.count > 1"))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
	})
	end

function TestDictWhere:testWherePredicateTable_Positive()
	local first = { a = 1, label = "keep" }
	local second = { a = 2, label = "skip" }
	local third = { a = 1, b = 2 }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where({ a = 1 }))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWherePredicateTable_Negative()
	local values = linq.dict({
		[1] = { a = 2 },
		[2] = { b = 1 },
		[3] = { a = 1, b = 2 },
	})

	local result = collect(values:where({ a = 1, c = 3 }))

	assertPairSetEquals(result, {})
	end

function TestDictWhere:testWherePredicateTable_EdgeNestedPositive()
	local first = { nested = { a = 1, b = 2 }, id = 1 }
	local second = { nested = { a = 2, b = 2 }, id = 2 }
	local third = { nested = { a = 1, b = 2, c = 3 }, id = 3 }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where({ nested = { a = 1, b = 2 } }))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWherePredicateTableComparer_Positive_TableEqual()
	local first = { a = 1, b = 2 }
	local second = { a = 1, b = 2, c = 3 }
	local third = { a = 1, b = 3 }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where({ a = 1, b = 2 }, linq.TABLE_EQUAL))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
	})
	end

function TestDictWhere:testWherePredicateTableComparer_Negative_TableEqual()
	local first = { a = 1, b = 3 }
	local second = { a = 2, b = 2 }
	local values = linq.dict({
		[1] = first,
		[2] = second,
	})

	local result = collect(values:where({ a = 1, b = 2 }, linq.TABLE_EQUAL))

	assertPairSetEquals(result, {})
	end

function TestDictWhere:testWherePredicateTableComparer_Edge_TableCheckTypes()
	local first = { a = 1, b = "x" }
	local second = { a = "1", b = "x" }
	local third = { a = 2, b = "y", extra = true }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where({ a = 0, b = "" }, linq.TABLE_CHECK_TYPES))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWhereSelectorFunctionComparer_Positive_IgnoreCase()
	local values = linq.dict({
		[1] = { name = "Alpha" },
		[2] = { name = "beta" },
		[3] = { name = "ALPHA" },
	})

	local result = collect(values:where(function(_, value)
		return value.name
	end, "alpha", linq.IGNORE_CASE))

	assertPairSetEquals(result, {
		{ key = 1, value = values[1] },
		{ key = 3, value = values[3] },
	})
	end

function TestDictWhere:testWhereSelectorFunctionComparer_Negative_TableEqual()
	local first = { meta = { a = 1, b = 3 } }
	local second = { meta = { a = 2, b = 2 } }
	local values = linq.dict({ [1] = first, [2] = second })

	local result = collect(values:where(function(_, value)
		return value.meta
	end, { a = 1, b = 2 }, linq.TABLE_EQUAL))

	assertPairSetEquals(result, {})
	end

function TestDictWhere:testWhereSelectorFunctionComparer_Edge_CombinedComparer()
	local first = { name = "  Alpha  " }
	local second = { name = "beta" }
	local third = { name = "alpha" }
	local values = linq.dict({ [1] = first, [2] = second, [3] = third })
	local comparer = linq.TRIM_EQUAL & linq.IGNORE_CASE

	local result = collect(values:where(function(_, value)
		return value.name
	end, " alpha ", comparer))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWhereSelectorFunctionValue_Positive_ExactMatch()
	local values = linq.dict({ [1] = { id = 1 }, [2] = { id = 2 }, [3] = { id = 1 } })

	local result = collect(values:where(function(_, value)
		return value.id
	end, 1))

	assertPairSetEquals(result, {
		{ key = 1, value = values[1] },
		{ key = 3, value = values[3] },
	})
	end

function TestDictWhere:testWhereSelectorFunctionValue_Negative_TableIdentity()
	local shared = { id = 1 }
	local first = { payload = shared }
	local second = { payload = { id = 1 } }
	local third = { payload = shared }
	local values = linq.dict({ [1] = first, [2] = second, [3] = third })

	local result = collect(values:where(function(_, value)
		return value.payload
	end, shared))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWhereSelectorFunctionValue_Edge_ExplicitNilValue()
	local first = { id = 1 }
	local second = { id = 2, flag = true }
	local third = { id = 3 }
	local values = linq.dict({ [1] = first, [2] = second, [3] = third })

	local result = collect(values:where(function(_, value)
		return value.flag
	end, nil))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWhereSelectorString_Positive_KeyExists()
	local first = { name = "alpha" }
	local second = {}
	local third = { name = "gamma" }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where("name"))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWhereSelectorString_Negative_MissingKey()
	local values = linq.dict({ [1] = { id = 1 }, [2] = { id = 2 } })

	local result = collect(values:where("missing"))

	assertPairSetEquals(result, {})
	end

function TestDictWhere:testWhereSelectorString_Edge_FalseValueStillExcluded()
	local first = { enabled = false }
	local second = {}
	local third = { enabled = true }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where("enabled"))

	assertPairSetEquals(result, {
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWhereSelectorStringValue_Positive_ExactMatch()
	local first = { kind = "ore" }
	local second = { kind = "plate" }
	local third = { kind = "ore" }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where("kind", "ore"))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWhereSelectorStringValue_Negative_TableIdentity()
	local shared = { id = 7 }
	local first = { payload = shared }
	local second = { payload = { id = 7 } }
	local third = { payload = shared }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where("payload", shared))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWhereSelectorStringValue_Edge_FalseValuePositive()
	local first = { enabled = false }
	local second = { enabled = true }
	local third = { enabled = false }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where("enabled", false))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWhereSelectorStringComparer_Positive_IgnoreCase()
	local first = { name = "Alpha" }
	local second = { name = "beta" }
	local third = { name = "ALPHA" }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where("name", "alpha", linq.IGNORE_CASE))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 3, value = third },
	})
	end

function TestDictWhere:testWhereSelectorStringComparer_Negative_TableEqual()
	local first = { payload = { a = 1, b = 3 } }
	local second = { payload = { a = 2, b = 2 } }
	local values = linq.dict({
		[1] = first,
		[2] = second,
	})

	local result = collect(values:where("payload", { a = 1, b = 2 }, linq.TABLE_EQUAL))

	assertPairSetEquals(result, {})
	end

function TestDictWhere:testWhereSelectorStringComparer_Edge_TableSuperset()
	local first = { payload = { a = 1, b = 2 } }
	local second = { payload = { a = 1 } }
	local third = { payload = { a = 2, b = 2 } }
	local values = linq.dict({
		[1] = first,
		[2] = second,
		[3] = third,
	})

	local result = collect(values:where("payload", { a = 1 }, linq.TABLE_SUPERSET))

	assertPairSetEquals(result, {
		{ key = 1, value = first },
		{ key = 2, value = second },
	})
	end

function TestDictWhere:testWhereInvalidSignatureErrors()
	local ok, err = pcall(function()
		local invalid = 123
		---@cast invalid any
		linq.dict({ [1] = 1, [2] = 2, [3] = 3 }):where(invalid)
	end)
	local err_text = tostring(err)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(err_text, "no signature enumerable<T>:where", 1, true) ~= nil)
	end