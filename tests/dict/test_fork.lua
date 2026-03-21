local luaunit = require('luaunit')
local linq = require("linq")

TestDictFork = {}

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

local function makeSource()
	return linq.dict({
		alpha = { age = 10 },
		beta = { age = 20 },
		gamma = { age = 30 },
	})
end

local function makeDictForks(count)
	local forks = {}
	for i = 1, count do
		local multiplier = i
		forks[i] = function(enumerable)
			local sum = 0
			for _, value in enumerable:iter() do
				sum = sum + value.age
			end
			return sum * multiplier
		end
	end
	return forks
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
			if actual_entry.key == expected_entry.key and actual_entry.value.age == expected_entry.value.age then
				matched_index = index
				break
			end
		end
		luaunit.assertNotNil(matched_index)
		table.remove(remaining, matched_index)
	end
	end

local function collectPairs(enumerable)
	local result = {}
	for key, value in enumerable:iter() do
		result[#result + 1] = { key = key, value = value }
	end
	return result
end

local function pack(...)
	return { n = select("#", ...), ... }
end

local function assertForkDictResults(count)
	local forks = makeDictForks(count)
	local result = pack(makeSource():enumerate():fork(table.unpack(forks)):spread())

	luaunit.assertEquals(result.n, count)
	for i = 1, count do
		luaunit.assertEquals(result[i], 60 * i)
	end
end

function TestDictFork:testForkDefault_Positive_ReturnsTwoEnumerables()
	local left, right = makeSource():enumerate():fork()

	assertPairSetEquals(collectPairs(left), {
		{ key = "alpha", value = { age = 10 } },
		{ key = "beta", value = { age = 20 } },
		{ key = "gamma", value = { age = 30 } },
	})
	assertPairSetEquals(collectPairs(right), {
		{ key = "alpha", value = { age = 10 } },
		{ key = "beta", value = { age = 20 } },
		{ key = "gamma", value = { age = 30 } },
	})
end

function TestDictFork:testForkDefault_Edge_EmptyDictReturnsTwoEmptyEnumerables()
	local values = linq.dict({})

	local left, right = values:enumerate():fork()

	assertPairSetEquals(collectPairs(left), {})
	assertPairSetEquals(collectPairs(right), {})
end

function TestDictFork:testForkOneFunction_Negative_RaisesSignatureError()
	assertErrorContains(function()
		makeSource():enumerate():fork(function(enumerable)
			return enumerable:any()
		end)
	end, "enumerable:fork")
end

function TestDictFork:testForkNonFunctionArgument_Negative_RaisesSignatureError()
	local enumerable = makeSource():enumerate()

	assertErrorContains(function()
		call_method(enumerable, "fork", function(source)
			return source:any()
		end, "bad")
	end, "enumerable:fork")
end

function TestDictFork:testForkTooManyFunctions_Negative_RaisesSignatureError()
	local forks = makeDictForks(11)

	assertErrorContains(function()
		makeSource():enumerate():fork(table.unpack(forks))
	end, "enumerable:fork")
end

for count = 2, 10 do
	TestDictFork["testFork" .. count .. "Functions_Positive_ReturnsResultsInOrder"] = function()
		assertForkDictResults(count)
	end
end