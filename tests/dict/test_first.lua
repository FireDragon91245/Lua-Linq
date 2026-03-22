local luaunit = require('luaunit')
local linq = require("linq")

TestDictFirst = {}

function TestDictFirst:testFirstDefault_Positive_ReturnsLeadingKeyAndValue()
	local values = linq.dict({
		[7] = "iron",
	})

	local key, value = values:first()

	luaunit.assertEquals(key, 7)
	luaunit.assertEquals(value, "iron")
end

function TestDictFirst:testFirstDefault_Edge_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	local key, value = values:first()

	luaunit.assertNil(key)
	luaunit.assertNil(value)
end

function TestDictFirst:testFirstFunctionSelector_Positive_ProjectsFromKeyAndValue()
	local values = linq.dict({
		[7] = { name = "iron", count = 4 },
	})

	local result = values:first(function(key, value)
		return key .. ":" .. value.name .. ":" .. value.count
	end)

	luaunit.assertEquals(result, "7:iron:4")
end

function TestDictFirst:testFirstFunctionSelector_Negative_EmptyEnumerableReturnsNil()
	local values = linq.dict({})

	local result = values:first(function(key, value)
		return key
	end)

	luaunit.assertNil(result)
end

function TestDictFirst:testFirstStringSelector_Positive_ProjectsLeadingValueProperty()
	local values = linq.dict({
		[7] = { score = 4 },
	})

	luaunit.assertEquals(values:first("score"), 4)
end

function TestDictFirst:testFirstStringSelector_Edge_MissingLeadingPropertyReturnsNil()
	local values = linq.dict({
		[7] = {},
	})

	luaunit.assertNil(values:first("score"))
end

function TestDictFirst:testFirstStringExpression_Positive_UsesKeyAndValue()
	local values = linq.dict({
		[7] = { name = "iron", count = 4 },
	})

	local result = values:first("k, v => k .. ':' .. v.name .. ':' .. v.count")

	luaunit.assertEquals(result, "7:iron:4")
end