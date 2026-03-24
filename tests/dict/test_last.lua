local luaunit = require('luaunit')
local linq = require("linq")

TestDictLast = {}

function TestDictLast:testLastDefault_Positive_ReturnsTrailingKeyAndValue()
	local values = linq.dict({
		[7] = "iron",
	})

	local key, value = values:last()

	luaunit.assertEquals(key, 7)
	luaunit.assertEquals(value, "iron")
end

function TestDictLast:testLastDefault_Edge_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	local key, value = values:last()

	luaunit.assertNil(key)
	luaunit.assertNil(value)
end

function TestDictLast:testLastFunctionSelector_Positive_ProjectsFromKeyAndValue()
	local values = linq.dict({
		[7] = { name = "iron", count = 4 },
	})

	local result = values:last(function(key, value)
		return key .. ":" .. value.name .. ":" .. value.count
	end)

	luaunit.assertEquals(result, "7:iron:4")
end

function TestDictLast:testLastFunctionSelector_Negative_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	local result = values:last(function(key, value)
		return key
	end)

	luaunit.assertNil(result)
end

function TestDictLast:testLastStringSelector_Positive_ProjectsTrailingValueProperty()
	local values = linq.dict({
		[7] = { score = 4 },
	})

	luaunit.assertEquals(values:last("score"), 4)
end

function TestDictLast:testLastStringSelector_Edge_MissingTrailingPropertyReturnsNil()
	local values = linq.dict({
		[7] = {},
	})

	luaunit.assertNil(values:last("score"))
end

function TestDictLast:testLastStringExpression_Positive_UsesKeyAndValue()
	local values = linq.dict({
		[7] = { name = "iron", count = 4 },
	})

	local result = values:last("k, v => k .. ':' .. v.name .. ':' .. v.count")

	luaunit.assertEquals(result, "7:iron:4")
end
