local luaunit = require('luaunit')

-- tests
require('tests.test_comparers')

print(luaunit.LuaUnit.run())