local luaunit = require('luaunit')

package.path = "./?.lua;./?/init.lua;" .. package.path

-- tests
require('tests.test_comparers')
require('tests.list.test_distinct')
require('tests.list.test_where')
require('tests.dict.test_distinct')
require('tests.dict.test_where')

print(luaunit.LuaUnit.run())