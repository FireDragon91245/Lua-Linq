local luaunit = require('luaunit')
local linq = require("linq")

TestListFork = {}

local function pack(...)
	return { n = select("#", ...), ... }
end

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

local function makeListForks(count)
	local forks = {}
	for i = 1, count do
		local multiplier = i
		forks[i] = function(enumerable)
			return enumerable:select(function(item)
				return item * multiplier
			end):collect(linq.list)
		end
	end
	return forks
end

local function assertForkListResults(count)
	local values = linq.list(1, 2, 3)
	local forks = makeListForks(count)

	local result = pack(values:enumerate():fork(table.unpack(forks)):spread())

	luaunit.assertEquals(result.n, count)
	for i = 1, count do
		assertSequenceEquals(collect(result[i]), { i, i * 2, i * 3 })
	end
end

function TestListFork:testForkDefault_Positive_ReturnsTwoEnumerables()
	local values = linq.list(1, 2, 3)

	local left, right = values:enumerate():fork()

	assertSequenceEquals(collect(left), { 1, 2, 3 })
	assertSequenceEquals(collect(right), { 1, 2, 3 })
end

function TestListFork:testForkDefault_Edge_EmptyListReturnsTwoEmptyEnumerables()
	local values = linq.list()

	local left, right = values:enumerate():fork()

	assertSequenceEquals(collect(left), {})
	assertSequenceEquals(collect(right), {})
end

function TestListFork:testForkOneFunction_Negative_RaisesSignatureError()
	local values = linq.list(1, 2, 3)

	assertErrorContains(function()
		values:enumerate():fork(function(enumerable)
			return enumerable:any()
		end)
	end, "enumerable:fork")
end

function TestListFork:testForkNonFunctionArgument_Negative_RaisesSignatureError()
	local values = linq.list(1, 2, 3)
	local enumerable = values:enumerate()

	assertErrorContains(function()
		call_method(enumerable, "fork", function(source)
			return source:any()
		end, "bad")
	end, "enumerable:fork")
end

function TestListFork:testForkTooManyFunctions_Negative_RaisesSignatureError()
	local values = linq.list(1, 2, 3)
	local forks = makeListForks(11)

	assertErrorContains(function()
		values:enumerate():fork(table.unpack(forks))
	end, "enumerable:fork")
end

for count = 2, 10 do
	TestListFork["testFork" .. count .. "Functions_Positive_ReturnsResultsInOrder"] = function()
		assertForkListResults(count)
	end
end