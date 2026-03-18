local predicates = {}
predicates.metatable = {
    __index = predicates,
}
setmetatable(predicates, { __call = function(self) return self:get() end })

if loadstring == nil then
    loadstring = load
end

local md5_shifts = {
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
}

local md5_constants = {}
for i = 1, 64 do
    md5_constants[i] = math.floor(math.abs(math.sin(i)) * 4294967296) & 0xffffffff
end

local function left_rotate(value, amount)
    return ((value << amount) | (value >> (32 - amount))) & 0xffffffff
end

local function trim(str)
    return (str:gsub("^%s*(.-)%s*$", "%1"))
end

local function split(str, sep)
    if sep == nil or sep == "" then
        return { str }
    end

    local parts = {}
    local start_index = 1

    while true do
        local match_start, match_end = string.find(str, sep, start_index, true)
        if not match_start then
            parts[#parts + 1] = string.sub(str, start_index)
            break
        end

        parts[#parts + 1] = string.sub(str, start_index, match_start - 1)
        start_index = match_end + 1
    end

    return parts
end

local function md5(value)
    local message = tostring(value)
    local original_length = #message
    local bytes = { string.byte(message, 1, original_length) }

    bytes[#bytes + 1] = 0x80
    while (#bytes % 64) ~= 56 do
        bytes[#bytes + 1] = 0
    end

    local bit_length = original_length * 8
    for i = 0, 7 do
        bytes[#bytes + 1] = (bit_length >> (8 * i)) & 0xff
    end

    local a0 = 0x67452301
    local b0 = 0xefcdab89
    local c0 = 0x98badcfe
    local d0 = 0x10325476

    for chunk_start = 1, #bytes, 64 do
        local words = {}
        for i = 0, 15 do
            local index = chunk_start + (i * 4)
            words[i] = bytes[index]
                | (bytes[index + 1] << 8)
                | (bytes[index + 2] << 16)
                | (bytes[index + 3] << 24)
        end

        local a = a0
        local b = b0
        local c = c0
        local d = d0

        for i = 0, 63 do
            local f
            local g

            if i < 16 then
                f = ((b & c) | ((~b) & d)) & 0xffffffff
                g = i
            elseif i < 32 then
                f = ((d & b) | ((~d) & c)) & 0xffffffff
                g = ((5 * i) + 1) % 16
            elseif i < 48 then
                f = (b ~ c ~ d) & 0xffffffff
                g = ((3 * i) + 5) % 16
            else
                f = (c ~ (b | (~d))) & 0xffffffff
                g = (7 * i) % 16
            end

            local temp = d
            d = c
            c = b
            b = (b + left_rotate((a + f + md5_constants[i + 1] + words[g]) & 0xffffffff, md5_shifts[i + 1])) & 0xffffffff
            a = temp
        end

        a0 = (a0 + a) & 0xffffffff
        b0 = (b0 + b) & 0xffffffff
        c0 = (c0 + c) & 0xffffffff
        d0 = (d0 + d) & 0xffffffff
    end

    local function to_hex_le(word)
        return string.format(
            "%02x%02x%02x%02x",
            word & 0xff,
            (word >> 8) & 0xff,
            (word >> 16) & 0xff,
            (word >> 24) & 0xff
        )
    end

    return to_hex_le(a0) .. to_hex_le(b0) .. to_hex_le(c0) .. to_hex_le(d0)
end

function predicates:get()
    if not self.instance then
        self.instance = self:new()
    end
    return self.instance
end

function predicates:new()
    local instance = setmetatable({}, predicates.metatable)

    instance.compiledFunctions = {
    }

    instance.funcHeader = "return function(...)\n"
    instance.funcArgs = "local args = {...}\n"
    instance.footer = "\nend;"

    return instance
end

function predicates:get_locals_unrolled(args_count)
    local localStr = "local "

    for i = 1, args_count do
        if i ~= 1 then
            localStr = localStr .. ","
        end
        localStr = localStr .. string.char(96 + i)
    end

    for i = 1, args_count do
        localStr = localStr .. "\n" .. string.char(96 + i) .. " = args[" .. i .. "];"
    end
    localStr = localStr .. "\n"
    return localStr
end

function predicates:get_locals_named(args_names)
    local args_count = #args_names
    local localStr = "local "

    for i = 1, args_count do
        local name = args_names[i]
        if not name then
            name = string.char(96 + i)
        end
        if i ~= 1 then
            localStr = localStr .. ","
        end
        localStr = localStr .. name
    end

    for i = 1, args_count do
        local name = args_names[i]
        if not name then
            name = string.char(96 + i)
        end
        localStr = localStr .. "\n" .. name .. " = args[" .. i .. "];"
    end
    localStr = localStr .. "\n"
    return localStr
end

function predicates:is_named_parameters(predicate)
    local arrowPos = predicate:find("=>")
    if not arrowPos then return false end

    local args = self:trim(predicate:sub(1, arrowPos - 1))
    local args_names = self:split(args, ",")
    if not args_names then return false end

    local pred_real = self:trim(predicate:sub(arrowPos + 2, #predicate))

    return true, pred_real, args_names
end

---@return function|nil
function predicates:get_query_function(predicate)
    local is_named, pred, args_names = self:is_named_parameters(predicate)
    local localsString = nil
    local args_count = 1

    if is_named then
        predicate = pred
        args_count = #args_names
        localsString = self:get_locals_named(args_names)
    else
        localsString = self:get_locals_unrolled(args_count)
    end

    local hash = self:hash_value(args_count .. "-" .. predicate)
    if not self.compiledFunctions[hash] then
        local hasReturn = predicate:find("return")
        local fullFunc = self.funcHeader .. self.funcArgs .. localsString
        if not hasReturn then
            fullFunc = fullFunc .. "return "
        end
        fullFunc = fullFunc .. predicate .. self.footer
        local loaded = loadstring(fullFunc)
        if loaded == nil then
            return nil
        end
        self.compiledFunctions[hash] = loaded()
    end
    return self.compiledFunctions[hash]
end

function predicates:get_predicate_function(pred)
    ---@type function|nil|boolean
    local func = false
    if type(pred) == "function" then
        func = pred
    elseif type(pred) == "string" then
        func = self:get_query_function(pred)
    else
        return false
    end
    return func
end

function predicates:sorting_function(data, predicate)
    local sortingCache = {}
    local func = self:get_predicate_function(predicate)
    if not func then
        error("Invalid sorting predicate: " .. tostring(predicate))
    end
    for ind, val in ipairs(data) do
        sortingCache[val] = func(val)
    end
    table.sort(data, function(a, b) return sortingCache[a] < sortingCache[b] end)
end

function predicates:hash_value(val)
    return md5(val)
end

function predicates:split(str, sep)
    return split(str, sep)
end

function predicates:trim(str)
    return trim(str)
end

return predicates