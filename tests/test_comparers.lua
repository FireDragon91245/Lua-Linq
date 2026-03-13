local luaunit = require('luaunit')
local linq = require("linq")

TestComparers = {}

-- Tests for IGNORE_CASE comparer
function TestComparers:testIgnoreCase_Positive()
    local a = "Hello World"
    local b = "hello world"
    luaunit.assertTrue(linq.IGNORE_CASE:compare(a, b))
end

function TestComparers:testIgnoreCase_Negative()
    local a = "Hello World"
    local b = "Hello World!"
    luaunit.assertFalse(linq.IGNORE_CASE:compare(a, b))
end

function TestComparers:testIgnoreCase_NonString()
    local a = 42
    local b = 42
    luaunit.assertTrue(linq.IGNORE_CASE:compare(a, b))
end

-- Tests for IGNORE_WHITESPACE comparer
function TestComparers:testIgnoreWhitespace_Positive()
    local a = "Hello\t World \n"
    local b = "HelloWorld"
    luaunit.assertTrue(linq.IGNORE_WHITESPACE:compare(a, b))
end

function TestComparers:testIgnoreWhitespace_Negative()
    local a = "Hello World"
    local b = "Hello Earth"
    luaunit.assertFalse(linq.IGNORE_WHITESPACE:compare(a, b))
end

function TestComparers:testIgnoreWhitespace_MultipleSpaces()
    local a = "  Hello   World  "
    local b = "HelloWorld"
    luaunit.assertTrue(linq.IGNORE_WHITESPACE:compare(a, b))
end

-- Tests for TRIM_EQUAL comparer
function TestComparers:testTrimEqual_Positive()
    local a = "  Hello World  "
    local b = "Hello World"
    luaunit.assertTrue(linq.TRIM_EQUAL:compare(a, b))
end

function TestComparers:testTrimEqual_Negative()
    local a = "  Hello World  "
    local b = "Hello Earth"
    luaunit.assertFalse(linq.TRIM_EQUAL:compare(a, b))
end

function TestComparers:testTrimEqual_TabsAndNewlines()
    local a = "\t\nHello\t\n"
    local b = "Hello"
    luaunit.assertTrue(linq.TRIM_EQUAL:compare(a, b))
end

-- Tests for TABLE_EQUAL comparer
function TestComparers:testTableEqual_SimplePositive()
    local a = {x = 1, y = 2}
    local b = {y = 2, x = 1}
    luaunit.assertTrue(linq.TABLE_EQUAL:compare(a, b))
end

function TestComparers:testTableEqual_SimpleNegative()
    local a = {x = 1, y = 2}
    local b = {x = 1, y = 3}
    luaunit.assertFalse(linq.TABLE_EQUAL:compare(a, b))
end

function TestComparers:testTableEqual_NestedPositive()
    local a = {x = 1, nested = {a = 1, b = 2}}
    local b = {x = 1, nested = {b = 2, a = 1}}
    luaunit.assertTrue(linq.TABLE_EQUAL:compare(a, b))
end

function TestComparers:testTableEqual_NestedNegative()
    local a = {x = 1, nested = {a = 1, b = 2}}
    local b = {x = 1, nested = {a = 1, b = 3}}
    luaunit.assertFalse(linq.TABLE_EQUAL:compare(a, b))
end

function TestComparers:testTableEqual_DifferentKeys()
    local a = {x = 1, y = 2}
    local b = {x = 1, z = 2}
    luaunit.assertFalse(linq.TABLE_EQUAL:compare(a, b))
end

function TestComparers:testTableEqual_DifferentSize()
    local a = {x = 1, y = 2}
    local b = {x = 1, y = 2, z = 3}
    luaunit.assertFalse(linq.TABLE_EQUAL:compare(a, b))
end

-- Tests for TABLE_SUBSET comparer
function TestComparers:testTableSubset_Positive()
    local a = {x = 1, y = 2}
    local b = {x = 1, y = 2, z = 3}
    luaunit.assertTrue(linq.TABLE_SUBSET:compare(a, b))
end

function TestComparers:testTableSubset_Negative()
    local a = {x = 1, y = 2, w = 4}
    local b = {x = 1, y = 2, z = 3}
    luaunit.assertFalse(linq.TABLE_SUBSET:compare(a, b))
end

function TestComparers:testTableSubset_Equal()
    local a = {x = 1, y = 2}
    local b = {x = 1, y = 2}
    luaunit.assertTrue(linq.TABLE_SUBSET:compare(a, b))
end

function TestComparers:testTableSubset_NestedPositive()
    local a = {nested = {a = 1}}
    local b = {nested = {a = 1, b = 2}, other = 3}
    luaunit.assertTrue(linq.TABLE_SUBSET:compare(a, b))
end

-- Tests for TABLE_SUPERSET comparer
function TestComparers:testTableSuperset_Positive()
    local a = {x = 1, y = 2, z = 3}
    local b = {x = 1, y = 2}
    luaunit.assertTrue(linq.TABLE_SUPERSET:compare(a, b))
end

function TestComparers:testTableSuperset_Negative()
    local a = {x = 1, y = 2}
    local b = {x = 1, y = 2, z = 3}
    luaunit.assertFalse(linq.TABLE_SUPERSET:compare(a, b))
end

function TestComparers:testTableSuperset_Equal()
    local a = {x = 1, y = 2}
    local b = {x = 1, y = 2}
    luaunit.assertTrue(linq.TABLE_SUPERSET:compare(a, b))
end

-- Tests for TABLE_CHECK_TYPES comparer
function TestComparers:testTableCheckTypes_Positive()
    local a = {x = 1, y = "hello", z = true}
    local b = {x = 42, y = "world", z = false}
    luaunit.assertTrue(linq.TABLE_CHECK_TYPES:compare(a, b))
end

function TestComparers:testTableCheckTypes_Negative()
    local a = {x = 1, y = "hello"}
    local b = {x = "1", y = "hello"}
    luaunit.assertFalse(linq.TABLE_CHECK_TYPES:compare(a, b))
end

function TestComparers:testTableCheckTypes_NestedPositive()
    local a = {nested = {a = 1, b = "test"}}
    local b = {nested = {a = 42, b = "other"}}
    luaunit.assertTrue(linq.TABLE_CHECK_TYPES:compare(a, b))
end

function TestComparers:testTableCheckTypes_NestedNegative()
    local a = {nested = {a = 1}}
    local b = {nested = {a = "1"}}
    luaunit.assertFalse(linq.TABLE_CHECK_TYPES:compare(a, b))
end

-- Tests for EPSILON_EQUAL comparer
function TestComparers:testEpsilonEqual_Positive()
    local a = 1.0
    local b = 1.00000000005  -- Very tiny difference within epsilon
    luaunit.assertTrue(linq.EPSILON_EQUAL:compare(a, b))
end

function TestComparers:testEpsilonEqual_Negative()
    local a = 1.0
    local b = 1.1
    luaunit.assertFalse(linq.EPSILON_EQUAL:compare(a, b))
end

function TestComparers:testEpsilonEqual_ExactlyEqual()
    local a = 1.0
    local b = 1.0
    luaunit.assertTrue(linq.EPSILON_EQUAL:compare(a, b))
end

function TestComparers:testEpsilonEqual_NonNumber()
    local a = "hello"
    local b = "hello"
    luaunit.assertTrue(linq.EPSILON_EQUAL:compare(a, b))
end

-- Tests for ROUNDED_EQUAL comparer (default 2 decimals)
function TestComparers:testRoundedEqual_Positive()
    local a = 1.234
    local b = 1.233  -- Both round to 1.23
    luaunit.assertTrue(linq.ROUNDED_EQUAL:compare(a, b))
end

function TestComparers:testRoundedEqual_Negative()
    local a = 1.23
    local b = 1.25
    luaunit.assertFalse(linq.ROUNDED_EQUAL:compare(a, b))
end

function TestComparers:testRoundedEqual_ExactlyEqual()
    local a = 1.23
    local b = 1.23
    luaunit.assertTrue(linq.ROUNDED_EQUAL:compare(a, b))
end

function TestComparers:testRoundedEqual_EdgeCase()
    local a = 1.234
    local b = 1.234
    luaunit.assertTrue(linq.ROUNDED_EQUAL:compare(a, b))
end

-- Tests for IGNORE_MISSING comparer  
function TestComparers:testIgnoreMissing_BothNil()
    local a = nil
    local b = nil
    luaunit.assertTrue(linq.IGNORE_MISSING:compare(a, b))
end

function TestComparers:testIgnoreMissing_OneNil()
    local a = nil
    local b = "hello"
    luaunit.assertFalse(linq.IGNORE_MISSING:compare(a, b))
end

function TestComparers:testIgnoreMissing_BothPresent()
    local a = "hello"
    local b = "hello"
    luaunit.assertTrue(linq.IGNORE_MISSING:compare(a, b))
end

function TestComparers:testIgnoreMissing_DifferentValues()
    local a = "hello"
    local b = "world"
    luaunit.assertFalse(linq.IGNORE_MISSING:compare(a, b))
end

-- Tests for IN_RANGE function comparer
function TestComparers:testInRange_Inside()
    local range_comparer = linq.IN_RANGE(1, 10)
    luaunit.assertTrue(range_comparer:compare(5, nil))
end

function TestComparers:testInRange_Outside()
    local range_comparer = linq.IN_RANGE(1, 10)
    luaunit.assertFalse(range_comparer:compare(15, nil))
end

function TestComparers:testInRange_LowerBound()
    local range_comparer = linq.IN_RANGE(1, 10)
    luaunit.assertTrue(range_comparer:compare(1, nil))
end

function TestComparers:testInRange_UpperBound()
    local range_comparer = linq.IN_RANGE(1, 10)
    luaunit.assertTrue(range_comparer:compare(10, nil))
end

function TestComparers:testInRange_NonNumber()
    local range_comparer = linq.IN_RANGE(1, 10)
    luaunit.assertFalse(range_comparer:compare("hello", nil))
end

function TestComparers:testInRange_NegativeRange()
    local range_comparer = linq.IN_RANGE(-5, 5)
    luaunit.assertTrue(range_comparer:compare(-3, nil))
    luaunit.assertTrue(range_comparer:compare(0, nil))
    luaunit.assertTrue(range_comparer:compare(3, nil))
    luaunit.assertFalse(range_comparer:compare(-10, nil))
    luaunit.assertFalse(range_comparer:compare(10, nil))
end