local luaunit = require('luaunit')

package.path = "./?.lua;./?/init.lua;" .. package.path

-- tests
require('tests.test_comparers')
require('tests.list.test_distinct')
require('tests.list.test_where')
require('tests.list.test_select')
require('tests.list.test_collect')
require('tests.list.test_any')
require('tests.list.test_max')
require('tests.dict.test_distinct')
require('tests.dict.test_where')
require('tests.dict.test_select')
require('tests.dict.test_collect')
require('tests.dict.test_any')
require('tests.dict.test_max')

print(luaunit.LuaUnit.run())