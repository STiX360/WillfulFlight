local config = require('scripts.engine_lab.config')
local M = {}
local sequence = 0

local function quote(value)
    return '"' .. tostring(value):gsub('[%z\1-\31\\"]', function(c)
        return string.format('\\u%04x', string.byte(c))
    end) .. '"'
end

local function encode(value)
    local kind = type(value)
    if value == nil then return 'null' end
    if kind == 'boolean' then return tostring(value) end
    if kind == 'number' then
        if value ~= value or math.abs(value) == math.huge then return 'null' end
        return tostring(value)
    end
    if kind ~= 'table' then return quote(value) end
    local fields = {}
    for key, item in pairs(value) do fields[#fields + 1] = quote(key) .. ':' .. encode(item) end
    table.sort(fields)
    return '{' .. table.concat(fields, ',') .. '}'
end

function M.emit(context, event, data)
    sequence = sequence + 1
    print('ENGINE_LAB_JSON ' .. encode({run_id=config.run_id, sequence=sequence,
        context=context, event=event, data=data or {}}))
end

function M.assertion(data)
    if type(data) ~= 'table' or type(data.case) ~= 'string'
        or not ({pass=true, fail=true, inconclusive=true})[data.status] then
        M.emit('player', 'assertion', {case='invalid assertion payload', status='inconclusive'})
        return
    end
    M.emit('player', 'assertion', data)
end

return M
