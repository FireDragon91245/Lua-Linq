local luaunit = require('luaunit')

package.path = "./?.lua;./?/init.lua;" .. package.path

-- tests
require('tests.test_comparers')
require('tests.test_distinct')
require('tests.test_where')

print(luaunit.LuaUnit.run())