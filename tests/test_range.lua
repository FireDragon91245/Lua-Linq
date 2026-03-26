local luaunit = require('luaunit')
local linq = require("linq")

TestRange = {}

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

function TestRange:testRangeCount_Positive_ProducesZeroBasedSequence()
	local result = collect(linq.range(5))

	assertSequenceEquals(result, { 0, 1, 2, 3, 4 })
	end

function TestRange:testRangeBounds_Edge_SwappedBoundsDescendInclusively()
	local result = collect(linq.range(5, 1))

	assertSequenceEquals(result, { 5, 4, 3, 2, 1 })
	end

function TestRange:testRangeBoundsStep_Edge_SwappedBoundsNormalizeDescendingStep()
	local result = collect(linq.range(5, 1, 2))

	assertSequenceEquals(result, { 5, 3, 1 })
	end

function TestRange:testRangeBounds_Edge_NegativeRangeCrossesZero()
	local result = collect(linq.range(-2, 2))

	assertSequenceEquals(result, { -2, -1, 0, 1, 2 })
	end

function TestRange:testRangeCount_Edge_ZeroCountReturnsEmpty()
	local result = collect(linq.range(0))

	assertSequenceEquals(result, {})
	end

function TestRange:testRangeStep_Negative_ZeroStepErrors()
	local ok, err = pcall(function()
		linq.range(1, 5, 0)
	end)

	luaunit.assertFalse(ok)
	luaunit.assertTrue(string.find(tostring(err), "linq.range step cannot be 0", 1, true) ~= nil)
	end