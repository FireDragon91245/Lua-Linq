local luaunit = require('luaunit')
local linq = require("linq")

TestDictCollect = {}

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

function TestDictCollect:testCollectConsumerOnly_Positive_ReadsEntireIterator()
	local values = linq.dict({ [1] = 10, [2] = 20, [3] = 30 })

	local result = values:collect(function(iter)
		local sum = 0
		for _, value in iter do
			sum = sum + value
		end
		return sum
	end)

	luaunit.assertEquals(result, 60)
	end

function TestDictCollect:testCollectConsumerOnly_Negative_EmptyEnumerable()
	local values = linq.dict({})

	local result = values:collect(function(iter)
		local count = 0
		for _ in iter do
			count = count + 1
		end
		return count
	end)

	luaunit.assertEquals(result, 0)
	end

function TestDictCollect:testCollectConsumerOnly_Edge_CanBuildSortedProjection()
	local values = linq.dict({ [2] = "beta", [1] = "alpha" })

	local result = values:collect(function(iter)
		local parts = {}
		for key, value in iter do
			parts[#parts + 1] = key .. ":" .. value
		end
		table.sort(parts)
		return table.concat(parts, ",")
	end)

	luaunit.assertEquals(result, "1:alpha,2:beta")
	end

function TestDictCollect:testCollectConstructorConsumer_Positive_BuildsArray()
	local values = linq.dict({ [1] = "alpha", [2] = "beta" })

	local result = values:collect(function()
		return {}
	end, function(acc, key, value)
		acc[#acc + 1] = key .. ":" .. string.upper(value)
	end)

	assertScalarSetEquals(result, { "1:ALPHA", "2:BETA" })
	end

function TestDictCollect:testCollectConstructorConsumer_Negative_EmptyEnumerableKeepsInitialAccumulator()
	local values = linq.dict({})

	local result = values:collect(function()
		return { tag = "initial" }
	end, function(acc, key, value)
		acc[key] = value
	end)

	luaunit.assertEquals(result, { tag = "initial" })
	end

function TestDictCollect:testCollectConstructorConsumer_Edge_PreservesFalseyValues()
	local values = linq.dict({ [1] = false, [2] = 0, [3] = "" })

	local result = values:collect(function()
		return {}
	end, function(acc, key, value)
		acc[key] = type(value) .. ":" .. tostring(value)
	end)

	luaunit.assertEquals(result[1], "boolean:false")
	luaunit.assertEquals(result[2], "number:0")
	luaunit.assertEquals(result[3], "string:")
	end

function TestDictCollect:testCollectWithFinalizer_Positive_FinalizesAccumulator()
	local values = linq.dict({ [1] = 10, [2] = 20, [3] = 30 })

	local result = values:collect(function()
		return { sum = 0 }
	end, function(acc, _, value)
		acc.sum = acc.sum + value
	end, function(acc)
		return acc.sum
	end)

	luaunit.assertEquals(result, 60)
	end

function TestDictCollect:testCollectWithFinalizer_Negative_EmptyEnumerableStillFinalizes()
	local values = linq.dict({})

	local result = values:collect(function()
		return {}
	end, function(acc, key, value)
		acc[key] = value
	end, function(acc)
		return next(acc) == nil
	end)

	luaunit.assertTrue(result)
	end

function TestDictCollect:testCollectWithFinalizer_Edge_FinalizerCanReshapeResult()
	local values = linq.dict({ [2] = "beta", [1] = "alpha" })

	local result = values:collect(function()
		return {}
	end, function(acc, key, value)
		acc[#acc + 1] = key .. ":" .. value
	end, function(acc)
		table.sort(acc)
		return table.concat(acc, "|")
	end)

	luaunit.assertEquals(result, "1:alpha|2:beta")
	end