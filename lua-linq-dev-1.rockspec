package = "Lua-Linq"
version = "dev-1"
rockspec_format = "3.0"
source = {
   url = "git+https://github.com/FireDragon91245/Lua-Linq.git"
}
description = {
   homepage = "https://github.com/FireDragon91245/Lua-Linq",
   license = "MIT"
}
dependencies = {}
build_dependencies = {}
build = {
   type = "builtin",
   modules = {
      linq = "linq.lua",
      map = "map.lua",
      predicates = "predicates.lua",
      process = "process.lua",
      raw = "raw.lua"
   },
   copy_directories = {
      "tests"
   }
}
test_dependencies = {
   "LuaUnit"
}
test = {
   platforms = {
      windows = {
         type = "command",
         command = "lua.bat tests/test.lua"
      }
   }
}