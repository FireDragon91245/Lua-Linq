local luaunit = require('luaunit')
local linq = require("linq")

TestAny = {}

function TestAny:testAnyDefault_Positive_NonEmptyReturnsTrue()
	local values = linq.list(1, 2, 3)

	luaunit.assertTrue(values:any())
end

function TestAny:testAnyDefault_Negative_EmptyReturnsFalse()
	local values = linq.list()

	luaunit.assertFalse(values:any())
end

function TestAny:testAnyFunctionPredicate_Positive_FindsLaterMatch()
	local values = linq.list(1, 3, 5, 8)

	local result = values:any(function(item)
		return item % 2 == 0
	end)

	luaunit.assertTrue(result)
end

function TestAny:testAnyFunctionPredicate_Negative_NoItemsMatch()
	local values = linq.list(1, 3, 5)

	local result = values:any(function(item)
		return item % 2 == 0
	end)

	luaunit.assertFalse(result)
end

function TestAny:testAnyStringSelector_Positive_PropertyTruthy()
	local values = linq.list(
		{ enabled = false },
		{ enabled = false },
		{ enabled = true }
	)

	luaunit.assertTrue(values:any("enabled"))
end

function TestAny:testAnyStringSelector_Edge_FalseyAndMissingPropertiesReturnFalse()
	local values = linq.list(
		{ enabled = false },
		{},
		{ enabled = false }
	)

	luaunit.assertFalse(values:any("enabled"))
end

function TestAny:testAnyStringExpression_Positive_UsesNamedParameter()
	local values = linq.list(
		{ count = 1 },
		{ count = 4 },
		{ count = 2 }
	)

	local result = values:any("item => item.count > 3")

	luaunit.assertTrue(result)
end

function TestAny:testAnyStringExpression_Negative_EmptyEnumerableReturnsFalse()
	local values = linq.list()

	local result = values:any("item => item.count > 3")

	luaunit.assertFalse(result)
end