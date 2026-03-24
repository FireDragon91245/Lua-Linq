local luaunit = require('luaunit')
local map = require('linq.map')

TestMap = {}

function TestMap:testCaseNumberMatch_ReturnsConsumerValue()
    local result = map(7)
        :case(7, function(value)
            return value * 2
        end)
        :result()

    luaunit.assertEquals(result, 14)
end

function TestMap:testCaseBooleanMatch_ReturnsConsumerValue()
    local result = map(true)
        :case(true, function(value)
            return not value
        end)
        :result()

    luaunit.assertFalse(result)
end

function TestMap:testCaseNilMatch_ReturnsFromConsumer()
    local result = map(nil)
        :case(nil, function(value)
            return value == nil
        end)
        :result()

    luaunit.assertTrue(result)
end

function TestMap:testCaseStringExpressionAndStringConsumer_WorkTogether()
    local result = map(4)
        :case("value => value % 2 == 0", "value => value * 3")
        :result()

    luaunit.assertEquals(result, 12)
end

function TestMap:testCaseFunctionCondition_MatchesPrimitiveValue()
    local result = map(9)
        :case(function(value)
            return value > 5
        end, function(value)
            return value - 4
        end)
        :result()

    luaunit.assertEquals(result, 5)
end

function TestMap:testCaseNestedTablePattern_MatchesComplexValue()
    local result = map({
            user = {
                id = 7,
                profile = {
                    rank = "captain"
                }
            }
        })
        :case({
            user = {
                id = 7,
                profile = {
                    rank = "captain"
                }
            }
        }, function(value)
            return value.user.profile.rank
        end)
        :result()

    luaunit.assertEquals(result, "captain")
end

function TestMap:testCaseEmptyTablePattern_MatchesTableType()
    local result = map({ payload = { count = 2 } })
        :case({ payload = {} }, function(value)
            return value.payload.count
        end)
        :result()

    luaunit.assertEquals(result, 2)
end

function TestMap:testCaseVariadicReturn_UnpacksAllResults()
    local first, second, third = map("a")
        :case("a", function(value)
            return value, value .. "b", value .. "c"
        end)
        :result()

    luaunit.assertEquals(first, "a")
    luaunit.assertEquals(second, "ab")
    luaunit.assertEquals(third, "ac")
end

function TestMap:testTrackCases_PassesFailedCasesToMatchingConsumer()
    local value, failed_count, first_failed, second_failed = map(3)
        :track_cases()
        :case(1, function(current)
            return current
        end)
        :case(2, function(current)
            return current
        end)
        :case(3, function(current, failed_cases)
            local tracked = failed_cases or {}
            return current, #tracked, tracked[1], tracked[2]
        end)
        :result()

    luaunit.assertEquals(value, 3)
    luaunit.assertEquals(failed_count, 2)
    luaunit.assertEquals(first_failed, 1)
    luaunit.assertEquals(second_failed, 2)
end

function TestMap:testDefault_RunsWhenNoCaseMatchesAndReceivesFailedCases()
    local value, failed_count, first_failed, second_failed = map("z")
        :track_cases()
        :case("a", function(current)
            return current
        end)
        :case("value => value == 'b'", function(current)
            return current
        end)
        :default(function(current, failed_cases)
            local tracked = failed_cases or {}
            return current, #tracked, tracked[1], tracked[2]
        end)
        :result()

    luaunit.assertEquals(value, "z")
    luaunit.assertEquals(failed_count, 2)
    luaunit.assertEquals(first_failed, "a")
    luaunit.assertEquals(second_failed, "value => value == 'b'")
end

function TestMap:testDefault_DoesNotRunAfterSuccessfulCase()
    local default_called = false

    local result = map(2)
        :case(2, function(value)
            return value * 5
        end)
        :default(function()
            default_called = true
            return 0
        end)
        :result()

    luaunit.assertEquals(result, 10)
    luaunit.assertFalse(default_called)
end

function TestMap:testCaseChainOr_ConsumesEarlierMatch()
    local result = map(1)
        :case(1)
        :case(2)
        :case(3, function(value)
            return "hit:" .. value
        end)
        :result()

    luaunit.assertEquals(result, "hit:1")
end

function TestMap:testCaseChainOr_StillMatchesCurrentCase()
    local result = map(3)
        :case(1)
        :case(2)
        :case(3, function(value)
            return "hit:" .. value
        end)
        :result()

    luaunit.assertEquals(result, "hit:3")
end

function TestMap:testCache_FunctionCallPatternUsesCachedValue()
    local call_count = 0
    local summary, original_value, calls = map({
            value = 10,
            get_kind = function()
                call_count = call_count + 1
                return "even"
            end
        })
        :cache({
            map.func_call.get_kind(),
            summary = function(value)
                return value.value + 5
            end
        })
        :case({
            [map.func_call.get_kind()] = "even",
            summary = 15
        }, function(value)
            return value.summary, value.value, call_count
        end)
        :result()

    luaunit.assertEquals(summary, 15)
    luaunit.assertEquals(original_value, 10)
    luaunit.assertEquals(calls, 1)
end
