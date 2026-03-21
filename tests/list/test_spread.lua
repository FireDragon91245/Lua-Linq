local luaunit = require('luaunit')
local linq = require("linq")

TestListSpread = {}

local function pack(...)
	return { n = select("#", ...), ... }
end

local function assertSequenceEquals(actual, expected)
	luaunit.assertEquals(#actual, #expected)
	for i = 1, #expected do
		luaunit.assertEquals(actual[i], expected[i])
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

function TestListSpread:testSpreadDefault_Positive_UnpacksListValues()
	local values = linq.list("alpha", "beta", "gamma")

	local result = pack(values:enumerate():spread())

	luaunit.assertEquals(result.n, 3)
	assertSequenceEquals(result, { "alpha", "beta", "gamma" })
end

function TestListSpread:testSpreadDefault_Edge_EmptyListReturnsNoValues()
	local values = linq.list()

	local result = pack(values:enumerate():spread())

	luaunit.assertEquals(result.n, 0)
	assertSequenceEquals(result, {})
end

function TestListSpread:testSpreadDefault_Edge_PreservesFalseyValues()
	local values = linq.list(false, 0, "")

	local result = pack(values:enumerate():spread())

	luaunit.assertEquals(result.n, 3)
	assertSequenceEquals(result, { false, 0, "" })
end

function TestListSpread:testSpreadInvalidMode_Negative_RaisesSignatureError()
	local values = linq.list(1, 2, 3)
	local enumerable = values:enumerate()

	assertErrorContains(function()
		call_method(enumerable, "spread", "Invalid")
	end, "enumerable:spread")
end

function TestListSpread:testSpreadTooManyArgs_Negative_RaisesSignatureError()
	local values = linq.list(1, 2, 3)

	assertErrorContains(function()
		values:enumerate():spread("Pairs", "Extra")
	end, "enumerable:spread")
end