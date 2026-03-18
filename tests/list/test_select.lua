local luaunit = require('luaunit')
local linq = require("linq")

TestSelect = {}

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

function TestSelect:testSelectFunction_Positive_ProjectsNumbers()
	local values = linq.list(1, 2, 3, 4)

	local result = collect(values:select(function(item)
		return item * 10
	end))

	assertSequenceEquals(result, { 10, 20, 30, 40 })
	end

function TestSelect:testSelectFunction_Negative_EmptyEnumerable()
	local values = linq.list()

	local result = collect(values:select(function(item)
		return item * 10
	end))

	assertSequenceEquals(result, {})
	end

function TestSelect:testSelectFunction_Edge_PreservesFalseyNonNilValues()
	local values = linq.list(true, false, 0, "")

	local result = collect(values:select(function(item)
		return item
	end))

	assertSequenceEquals(result, { true, false, 0, "" })
	end

function TestSelect:testSelectStringProperty_Positive_ProjectsProperty()
	local first = { name = "alpha" }
	local second = { name = "beta" }
	local third = { name = "gamma" }
	local values = linq.list(first, second, third)

	local result = collect(values:select("name"))

	assertSequenceEquals(result, { "alpha", "beta", "gamma" })
	end

function TestSelect:testSelectStringProperty_Negative_EmptyEnumerable()
	local values = linq.list()

	local result = collect(values:select("name"))

	assertSequenceEquals(result, {})
	end

function TestSelect:testSelectStringProperty_Edge_PreservesFalseAndZero()
	local values = linq.list(
		{ flag = false },
		{ flag = 0 },
		{ flag = "" }
	)

	local result = collect(values:select("flag"))

	assertSequenceEquals(result, { false, 0, "" })
	end

function TestSelect:testSelectStringExpression_Positive_ProjectsExpression()
	local values = linq.list(1, 2, 3, 4)

	local result = collect(values:select("x => x * x"))

	assertSequenceEquals(result, { 1, 4, 9, 16 })
	end

function TestSelect:testSelectStringExpression_Negative_EmptyEnumerable()
	local values = linq.list()

	local result = collect(values:select("x => x * x"))

	assertSequenceEquals(result, {})
	end

function TestSelect:testSelectStringExpression_Edge_UsesNamedParameter()
	local values = linq.list(
		{ name = "alpha", count = 2 },
		{ name = "beta", count = 5 }
	)

	local result = collect(values:select("item => item.name .. ':' .. item.count"))

	assertSequenceEquals(result, { "alpha:2", "beta:5" })
	end