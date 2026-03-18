local luaunit = require('luaunit')
local linq = require("linq")

TestDictSelect = {}

local function collect_values(enumerable)
	local result = {}
	for value in enumerable:iter() do
		result[#result + 1] = value
	end
	return result
	end

local function collect_pairs(enumerable)
	local result = {}
	for key, value in enumerable:iter() do
		result[#result + 1] = { key = key, value = value }
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

function TestDictSelect:testSelectFunction_Positive_ProjectsKeyValuePair()
	local values = linq.dict({
		[1] = "alpha",
		[2] = "beta",
	})

	local result = collect_pairs(values:select(function(key, value)
		return "id-" .. key, string.upper(value)
	end))

	assertPairSetEquals(result, {
		{ key = "id-1", value = "ALPHA" },
		{ key = "id-2", value = "BETA" },
	})
	end

function TestDictSelect:testSelectFunction_Negative_EmptyEnumerable()
	local values = linq.dict({})

	local result = collect_pairs(values:select(function(key, value)
		return key, value
	end))

	assertPairSetEquals(result, {})
	end

function TestDictSelect:testSelectFunction_Edge_CanProjectSingleScalarValue()
	local values = linq.dict({
		[1] = "alpha",
		[2] = "beta",
	})

	local result = collect_values(values:select(function(_, value)
		return string.upper(value)
	end))

	assertScalarSetEquals(result, { "ALPHA", "BETA" })
	end

function TestDictSelect:testSelectStringProperty_Positive_ProjectsValueProperty()
	local values = linq.dict({
		[1] = { name = "alpha" },
		[2] = { name = "beta" },
		[3] = { name = "gamma" },
	})

	local result = collect_values(values:select("name"))

	assertScalarSetEquals(result, { "alpha", "beta", "gamma" })
	end

function TestDictSelect:testSelectStringProperty_Negative_EmptyEnumerable()
	local values = linq.dict({})

	local result = collect_values(values:select("name"))

	assertScalarSetEquals(result, {})
	end

function TestDictSelect:testSelectStringProperty_Edge_PreservesFalseyValueProperties()
	local values = linq.dict({
		[1] = { flag = false },
		[2] = { flag = 0 },
		[3] = { flag = "" },
	})

	local result = collect_values(values:select("flag"))

	assertScalarSetEquals(result, { false, 0, "" })
	end

function TestDictSelect:testSelectStringExpression_Positive_ProjectsKeyValuePair()
	local values = linq.dict({
		[1] = { name = "alpha" },
		[2] = { name = "beta" },
	})

	local result = collect_pairs(values:select("k, v => 'id-' .. k, string.upper(v.name)"))

	assertPairSetEquals(result, {
		{ key = "id-1", value = "ALPHA" },
		{ key = "id-2", value = "BETA" },
	})
	end

function TestDictSelect:testSelectStringExpression_Negative_EmptyEnumerable()
	local values = linq.dict({})

	local result = collect_pairs(values:select("k, v => k, v.name"))

	assertPairSetEquals(result, {})
	end

function TestDictSelect:testSelectStringExpression_Edge_CanProjectSingleScalarValue()
	local values = linq.dict({
		[1] = { name = "alpha" },
		[2] = { name = "beta" },
	})

	local result = collect_values(values:select("k, v => v.name"))

	assertScalarSetEquals(result, { "alpha", "beta" })
	end