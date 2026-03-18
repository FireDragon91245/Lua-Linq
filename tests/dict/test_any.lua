local luaunit = require('luaunit')
local linq = require("linq")

TestDictAny = {}

function TestDictAny:testAnyDefault_Positive_NonEmptyReturnsTrue()
	local values = linq.dict({ [1] = "alpha" })

	luaunit.assertTrue(values:any())
end

function TestDictAny:testAnyDefault_Negative_EmptyReturnsFalse()
	local values = linq.dict({})

	luaunit.assertFalse(values:any())
end

function TestDictAny:testAnyFunctionPredicate_Positive_CanInspectKeyAndValue()
	local values = linq.dict({
		[1] = { count = 2 },
		[2] = { count = 7 },
		[3] = { count = 1 },
	})

	local result = values:any(function(key, value)
		return key == 2 and value.count == 7
	end)

	luaunit.assertTrue(result)
end

function TestDictAny:testAnyFunctionPredicate_Negative_NoPairsMatch()
	local values = linq.dict({
		[1] = { count = 2 },
		[2] = { count = 7 },
	})

	local result = values:any(function(key, value)
		return key == 3 or value.count > 10
	end)

	luaunit.assertFalse(result)
end

function TestDictAny:testAnyStringSelector_Positive_UsesValueProperty()
	local values = linq.dict({
		["a"] = { enabled = false },
		["b"] = { enabled = true },
	})

	luaunit.assertTrue(values:any("enabled"))
end

function TestDictAny:testAnyStringSelector_Edge_FalseyPropertiesDoNotMatch()
	local values = linq.dict({
		["a"] = { enabled = false },
		["b"] = {},
		["c"] = { enabled = false },
	})

	luaunit.assertFalse(values:any("enabled"))
end

function TestDictAny:testAnyStringExpression_Positive_CanUseKeyAndValue()
	local values = linq.dict({
		["iron"] = { count = 12 },
		["copper"] = { count = 4 },
	})

	local result = values:any("k, v => k == 'iron' and v.count >= 10")

	luaunit.assertTrue(result)
end

function TestDictAny:testAnyStringExpression_Negative_NoPairsMatch()
	local values = linq.dict({
		["iron"] = { count = 12 },
		["copper"] = { count = 4 },
	})

	local result = values:any("k, v => k == 'steel' and v.count >= 10")

	luaunit.assertFalse(result)
end