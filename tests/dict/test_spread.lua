local luaunit = require('luaunit')
local linq = require("linq")

TestDictSpread = {}

local function pack(...)
	return { n = select("#", ...), ... }
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
			if actual_entry[1] == expected_entry[1] and actual_entry[2] == expected_entry[2] then
				matched_index = index
				break
			end
		end
		luaunit.assertNotNil(matched_index)
		table.remove(remaining, matched_index)
	end
	end

local function assertErrorContains(func, expected_substring)
	local ok, err = pcall(func)
	luaunit.assertFalse(ok)
	luaunit.assertNotNil(string.find(tostring(err), expected_substring, 1, true))
end

---@param target any
---@param method_name string
---@return any
local function call_method(target, method_name, ...)
	return target[method_name](target, ...)
end

local function toPairEntries(packed)
	local entries = {}
	for i = 1, packed.n do
		entries[i] = packed[i]
	end
	return entries
end

local function toInterwovenPairs(packed)
	local entries = {}
	for i = 1, packed.n, 2 do
		entries[#entries + 1] = {
			key = packed[i],
			value = packed[i + 1]
		}
	end
	return entries
end

function TestDictSpread:testSpreadDefault_Positive_ReturnsPairTables()
	local values = linq.dict({
		alpha = 1,
		beta = 2,
	})

	local result = pack(values:enumerate():spread())

	luaunit.assertEquals(result.n, 2)
	assertPairSetEquals(toPairEntries(result), {
		{ "alpha", 1 },
		{ "beta", 2 },
	})
end

function TestDictSpread:testSpreadDefault_Edge_EmptyDictReturnsNoValues()
	local values = linq.dict({})

	local result = pack(values:enumerate():spread())

	luaunit.assertEquals(result.n, 0)
	assertPairSetEquals(toPairEntries(result), {})
end

function TestDictSpread:testSpreadPairs_Positive_ReturnsPairTables()
	local values = linq.dict({
		alpha = 1,
		beta = 2,
	})

	local result = pack(values:enumerate():spread("Pairs"))

	luaunit.assertEquals(result.n, 2)
	assertPairSetEquals(toPairEntries(result), {
		{ "alpha", 1 },
		{ "beta", 2 },
	})
end

function TestDictSpread:testSpreadPairs_Edge_EmptyDictReturnsNoValues()
	local values = linq.dict({})

	local result = pack(values:enumerate():spread("Pairs"))

	luaunit.assertEquals(result.n, 0)
	assertPairSetEquals(toPairEntries(result), {})
end

function TestDictSpread:testSpreadKeys_Positive_ReturnsKeys()
	local values = linq.dict({
		alpha = 1,
		beta = 2,
		gamma = 3,
	})

	local result = pack(values:enumerate():spread("Keys"))

	luaunit.assertEquals(result.n, 3)
	assertScalarSetEquals(result, { "alpha", "beta", "gamma" })
end

function TestDictSpread:testSpreadKeys_Edge_EmptyDictReturnsNoValues()
	local values = linq.dict({})

	local result = pack(values:enumerate():spread("Keys"))

	luaunit.assertEquals(result.n, 0)
	assertScalarSetEquals(result, {})
end

function TestDictSpread:testSpreadValues_Positive_ReturnsValues()
	local values = linq.dict({
		alpha = false,
		beta = 0,
		gamma = "",
	})

	local result = pack(values:enumerate():spread("Values"))

	luaunit.assertEquals(result.n, 3)
	assertScalarSetEquals(result, { false, 0, "" })
end

function TestDictSpread:testSpreadValues_Edge_EmptyDictReturnsNoValues()
	local values = linq.dict({})

	local result = pack(values:enumerate():spread("Values"))

	luaunit.assertEquals(result.n, 0)
	assertScalarSetEquals(result, {})
end

function TestDictSpread:testSpreadInterwoven_Positive_ReturnsAlternatingPairs()
	local values = linq.dict({
		alpha = 1,
		beta = 2,
	})

	local result = pack(values:enumerate():spread("Interwoven"))

	luaunit.assertEquals(result.n, 4)
	assertPairSetEquals(toInterwovenPairs(result), {
		{ key = "alpha", value = 1 },
		{ key = "beta", value = 2 },
	})
end

function TestDictSpread:testSpreadInterwoven_Edge_EmptyDictReturnsNoValues()
	local values = linq.dict({})

	local result = pack(values:enumerate():spread("Interwoven"))

	luaunit.assertEquals(result.n, 0)
	assertPairSetEquals(toInterwovenPairs(result), {})
end

function TestDictSpread:testSpreadInvalidMode_Negative_RaisesSignatureError()
	local values = linq.dict({ alpha = 1 })
	local enumerable = values:enumerate()

	assertErrorContains(function()
		call_method(enumerable, "spread", "Invalid")
	end, "enumerable:spread")
end

function TestDictSpread:testSpreadTooManyArgs_Negative_RaisesSignatureError()
	local values = linq.dict({ alpha = 1 })

	assertErrorContains(function()
		values:enumerate():spread("Keys", "Extra")
	end, "enumerable:spread")
end