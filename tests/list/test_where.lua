local luaunit = require('luaunit')
local linq = require("linq")

TestWhere = {}

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

function TestWhere:testWherePredicateFunction_Positive()
	local values = linq.list(1, 2, 3, 4, 5)

	local result = collect(values:where(function(item)
		return item % 2 == 0
	end))

	assertSequenceEquals(result, { 2, 4 })
end

function TestWhere:testWherePredicateFunction_Negative()
	local values = linq.list(1, 3, 5)

	local result = collect(values:where(function(item)
		return item % 2 == 0
	end))

	assertSequenceEquals(result, {})
end

function TestWhere:testWherePredicateFunction_TruthySelectorStyle()
	local first = { name = "alpha" }
	local second = { }
	local third = { name = "gamma" }
	local values = linq.list(first, second, third)

	local result = collect(values:where(function(item)
		return item.name
	end))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWherePredicateString_Positive()
	local values = linq.list(1, 2, 3, 4, 5)

	local result = collect(values:where("x => x > 3"))

	assertSequenceEquals(result, { 4, 5 })
end

function TestWhere:testWherePredicateString_NamedParameter()
	local first = { active = true, count = 2 }
	local second = { active = false, count = 5 }
	local third = { active = true, count = 1 }
	local values = linq.list(first, second, third)

	local result = collect(values:where("item => item.active and item.count > 1"))

	assertSequenceEquals(result, { first })
end

function TestWhere:testWherePredicateString_InvalidPredicateErrors()
	local ok, err = pcall(function()
		linq.list(1, 2, 3):where("x => x >")
	end)
	local err_text = tostring(err)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(err_text, "Invalid predicate string", 1, true) ~= nil)
end

function TestWhere:testWherePredicateTable_Positive()
	local first = { a = 1, label = "keep" }
	local second = { a = 2, label = "skip" }
	local third = { a = 1, b = 2 }
	local values = linq.list(first, second, third)

	local result = collect(values:where({ a = 1 }))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWherePredicateTable_Negative()
	local values = linq.list(
		{ a = 2 },
		{ b = 1 },
		{ a = 1, b = 2 }
	)

	local result = collect(values:where({ a = 1, c = 3 }))

	assertSequenceEquals(result, {})
end

function TestWhere:testWherePredicateTable_NestedPositive()
	local first = { nested = { a = 1, b = 2 }, id = 1 }
	local second = { nested = { a = 2, b = 2 }, id = 2 }
	local third = { nested = { a = 1, b = 2, c = 3 }, id = 3 }
	local values = linq.list(first, second, third)

	local result = collect(values:where({ nested = { a = 1, b = 2 } }))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWherePredicateTableComparer_TableEqualPositive()
	local first = { a = 1, b = 2 }
	local second = { a = 1, b = 2, c = 3 }
	local third = { a = 1, b = 3 }
	local values = linq.list(first, second, third)

	local result = collect(values:where({ a = 1, b = 2 }, linq.TABLE_EQUAL))

	assertSequenceEquals(result, { first })
end

function TestWhere:testWherePredicateTableComparer_TableCheckTypesPositive()
	local first = { a = 1, b = "x" }
	local second = { a = "1", b = "x" }
	local third = { a = 2, b = "y", extra = true }
	local values = linq.list(first, second, third)

	local result = collect(values:where({ a = 0, b = "" }, linq.TABLE_CHECK_TYPES))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWherePredicateTableComparer_TableSupersetPositive()
	local first = { a = 1, b = 2, c = 3 }
	local second = { a = 1 }
	local third = { a = 2, b = 2 }
	local values = linq.list(first, second, third)

	local result = collect(values:where({ a = 1 }, linq.TABLE_SUPERSET))

	assertSequenceEquals(result, { first, second })
end

function TestWhere:testWhereSelectorFunction_TruthyPropertyPositive()
	local first = { email = "a@example.com" }
	local second = { }
	local third = { email = "c@example.com" }
	local values = linq.list(first, second, third)

	local result = collect(values:where(function(item)
		return item.email
	end))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorFunction_FalsePropertyNegative()
	local first = { enabled = true }
	local second = { enabled = false }
	local third = { }
	local values = linq.list(first, second, third)

	local result = collect(values:where(function(item)
		return item.enabled
	end))

	assertSequenceEquals(result, { first })
end

function TestWhere:testWhereSelectorFunction_EmptyEnumerable()
	local values = linq.list()

	local result = collect(values:where(function(item)
		return item.value
	end))

	assertSequenceEquals(result, {})
end

function TestWhere:testWhereSelectorFunctionValueComparer_IgnoreCasePositive()
	local first = { name = "Alpha" }
	local second = { name = "beta" }
	local third = { name = "ALPHA" }
	local values = linq.list(first, second, third)

	local result = collect(values:where(function(item)
		return item.name
	end, "alpha", linq.IGNORE_CASE))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorFunctionValueComparer_TableEqualPositive()
	local first = { meta = { a = 1, b = 2 } }
	local second = { meta = { a = 1, b = 2, c = 3 } }
	local third = { meta = { a = 1, b = 2 } }
	local values = linq.list(first, second, third)

	local result = collect(values:where(function(item)
		return item.meta
	end, { a = 1, b = 2 }, linq.TABLE_EQUAL))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorFunctionValueComparer_CombinedComparerPositive()
	local first = { name = "  Alpha  " }
	local second = { name = "beta" }
	local third = { name = "alpha" }
	local values = linq.list(first, second, third)
	local comparer = linq.TRIM_EQUAL & linq.IGNORE_CASE

	local result = collect(values:where(function(item)
		return item.name
	end, " alpha ", comparer))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorFunctionValue_ExactMatchPositive()
	local first = { id = 1 }
	local second = { id = 2 }
	local third = { id = 1 }
	local values = linq.list(first, second, third)

	local result = collect(values:where(function(item)
		return item.id
	end, 1))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorFunctionValue_TableIdentityNegative()
	local shared = { id = 1 }
	local first = { payload = shared }
	local second = { payload = { id = 1 } }
	local third = { payload = shared }
	local values = linq.list(first, second, third)

	local result = collect(values:where(function(item)
		return item.payload
	end, shared))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorFunctionValue_ExplicitNilValue()
	local first = { id = 1 }
	local second = { id = 2, flag = true }
	local third = { id = 3 }
	local values = linq.list(first, second, third)

	local result = collect(values:where(function(item)
		return item.flag
	end, nil))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorString_KeyExistsPositive()
	local first = { name = "alpha" }
	local second = { }
	local third = { name = "gamma" }
	local values = linq.list(first, second, third)

	local result = collect(values:where("name"))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorString_FalseValueStillExists()
	local first = { enabled = false }
	local second = { }
	local third = { enabled = true }
	local values = linq.list(first, second, third)

	local result = collect(values:where("enabled"))

	assertSequenceEquals(result, { third })
end

function TestWhere:testWhereSelectorString_MissingKeyNegative()
	local values = linq.list(
		{ id = 1 },
		{ id = 2 }
	)

	local result = collect(values:where("missing"))

	assertSequenceEquals(result, {})
end

function TestWhere:testWhereSelectorStringValue_ExactMatchPositive()
	local first = { kind = "ore" }
	local second = { kind = "plate" }
	local third = { kind = "ore" }
	local values = linq.list(first, second, third)

	local result = collect(values:where("kind", "ore"))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorStringValue_FalseValuePositive()
	local first = { enabled = false }
	local second = { enabled = true }
	local third = { enabled = false }
	local values = linq.list(first, second, third)

	local result = collect(values:where("enabled", false))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorStringValue_TableIdentityNegative()
	local shared = { id = 7 }
	local first = { payload = shared }
	local second = { payload = { id = 7 } }
	local third = { payload = shared }
	local values = linq.list(first, second, third)

	local result = collect(values:where("payload", shared))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorStringValueComparer_IgnoreCasePositive()
	local first = { name = "Alpha" }
	local second = { name = "beta" }
	local third = { name = "ALPHA" }
	local values = linq.list(first, second, third)

	local result = collect(values:where("name", "alpha", linq.IGNORE_CASE))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorStringValueComparer_TableEqualPositive()
	local first = { payload = { a = 1, b = 2 } }
	local second = { payload = { a = 1, b = 2, c = 3 } }
	local third = { payload = { a = 1, b = 2 } }
	local values = linq.list(first, second, third)

	local result = collect(values:where("payload", { a = 1, b = 2 }, linq.TABLE_EQUAL))

	assertSequenceEquals(result, { first, third })
end

function TestWhere:testWhereSelectorStringValueComparer_TableSupersetPositive()
	local first = { payload = { a = 1, b = 2 } }
	local second = { payload = { a = 1 } }
	local third = { payload = { a = 2, b = 2 } }
	local values = linq.list(first, second, third)

	local result = collect(values:where("payload", { a = 1 }, linq.TABLE_SUPERSET))

	assertSequenceEquals(result, { first, second })
end

function TestWhere:testWhereInvalidSignatureErrors()
	local ok, err = pcall(function()
		local invalid = 123
		---@cast invalid any
		linq.list(1, 2, 3):where(invalid)
	end)
	local err_text = tostring(err)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(err_text, "Invalid call to enumerable:where", 1, true) ~= nil)
	luaunit.assertTrue(string.find(err_text, "Possible signatures are:", 1, true) ~= nil)
end