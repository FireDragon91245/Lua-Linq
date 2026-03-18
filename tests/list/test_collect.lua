local luaunit = require('luaunit')
local linq = require("linq")

TestCollect = {}

function TestCollect:testCollectConsumerOnly_Positive_SumsValues()
	local values = linq.list(1, 2, 3, 4)

	local result = values:collect(function(iter)
		local sum = 0
		for value in iter do
			sum = sum + value
		end
		return sum
	end)

	luaunit.assertEquals(result, 10)
	end

function TestCollect:testCollectConsumerOnly_Negative_EmptyEnumerable()
	local values = linq.list()

	local result = values:collect(function(iter)
		local count = 0
		for _ in iter do
			count = count + 1
		end
		return count
	end)

	luaunit.assertEquals(result, 0)
	end

function TestCollect:testCollectConsumerOnly_Edge_BuildsOrderedProjection()
	local values = linq.list("a", "b", "c")

	local result = values:collect(function(iter)
		local parts = {}
		for value in iter do
			parts[#parts + 1] = value .. value
		end
		return table.concat(parts, ",")
	end)

	luaunit.assertEquals(result, "aa,bb,cc")
	end

function TestCollect:testCollectConstructorConsumer_Positive_BuildsTable()
	local values = linq.list(1, 2, 3)

	local result = values:collect(function()
		return {}
	end, function(acc, item)
		acc[#acc + 1] = item * 2
	end)

	luaunit.assertEquals(result, { 2, 4, 6 })
	end

function TestCollect:testCollectConstructorConsumer_Negative_EmptyEnumerableKeepsInitialAccumulator()
	local values = linq.list()

	local result = values:collect(function()
		return { tag = "initial" }
	end, function(acc, item)
		acc[#acc + 1] = item
	end)

	luaunit.assertEquals(result, { tag = "initial" })
	end

function TestCollect:testCollectConstructorConsumer_Edge_TracksFalseyValues()
	local values = linq.list(false, 0, "")

	local result = values:collect(function()
		return {}
	end, function(acc, item)
		acc[#acc + 1] = type(item) .. ":" .. tostring(item)
	end)

	luaunit.assertEquals(result, { "boolean:false", "number:0", "string:" })
	end

function TestCollect:testCollectWithFinalizer_Positive_FinalizesAccumulator()
	local values = linq.list(1, 2, 3, 4)

	local result = values:collect(function()
		return { sum = 0 }
	end, function(acc, item)
		acc.sum = acc.sum + item
	end, function(acc)
		return acc.sum
	end)

	luaunit.assertEquals(result, 10)
	end

function TestCollect:testCollectWithFinalizer_Negative_EmptyEnumerableStillFinalizes()
	local values = linq.list()

	local result = values:collect(function()
		return {}
	end, function(acc, item)
		acc[#acc + 1] = item
	end, function(acc)
		return #acc
	end)

	luaunit.assertEquals(result, 0)
	end

function TestCollect:testCollectWithFinalizer_Edge_FinalizerCanReshapeResult()
	local values = linq.list("alpha", "beta")

	local result = values:collect(function()
		return {}
	end, function(acc, item)
		acc[#acc + 1] = string.upper(item)
	end, function(acc)
		return table.concat(acc, "|")
	end)

	luaunit.assertEquals(result, "ALPHA|BETA")
	end