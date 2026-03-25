![LuaRocks](https://img.shields.io/luarocks/v/firedragon91245/lua-linq?style=for-the-badge&label=Lua-Linq&labelColor=2C4067&color=FFFFFF&link=https%3A%2F%2Fluarocks.org%2Fmodules%2Ffiredragon91245%2Flua-linq)
# Lua-Linq

Lua-Linq is a small LINQ-style library for Lua built around lazy, stateless enumerables. It wraps array-like tables as lists and map-like tables as dicts, lets you compose queries without mutating the source, and keeps the final step close to normal Lua iteration.

## Quick example

```lua
local linq = require("linq")

local numbers = linq.list(1, 2, 3, 4, 5, 6)

local doubled_evens = numbers
    :where(function(n) return n % 2 == 0 end)
    :select(function(n) return n * 2 end)

for value in doubled_evens:iter() do
    print(value)
end
-- 4
-- 8
-- 12
```

`list` and `dict` are lightweight wrappers. Query steps stay lazy, and iteration state lives in each `:iter()` call, so the same enumerable can be reused safely.

## Core ideas

Lua-Linq works with both single-value sequences and key/value sequences. Lists expose value-focused enumeration, while dicts expose keys, values, or full key/value pairs. The API keeps a Lua-ish style: build a pipeline, then consume it with `for value in query:iter() do` or `for key, value in dict_query:iter() do`.

Most query methods accept regular Lua functions. Several also support string selectors and predicate expressions, which makes compact table filtering and projection possible when that style fits.

## Method overview

The main enumerable pipeline supports `distinct`, `where`, `select`, `collect`, `any`, `max`, `min`, `first`, `last`, `fork`, `spread`, `iter`, and `tolist`.

`linq.list(...)` creates a list wrapper for array-like data. In addition to the enumerable methods, lists provide `enumerate`, `copy`, `add`, `add_transform`, and `iter`.

`linq.dict(...)` creates a dict wrapper for table-like key/value data. Dicts provide `keys`, `values`, `enumerate`, `iter`, and the same query helpers adapted for key/value sequences.

## Installation and testing

From this repository, install the rock locally with:

```powershell
luarocks make lua-linq-0.1-0.rockspec
```

Run the test suite with:

```powershell
luarocks test
```

The rockspec runs `lua.bat tests/test.lua` on Windows and `lua tests/test.lua` on Linux, so you can also invoke the test runner directly if needed.

## More documentation

This README is the short version. For method-by-method details and extra examples, see the [wiki](https://github.com/FireDragon91245/Lua-Linq/wiki)
