local M = {}

function M.enabled(value)
    return value ~= false
end

local function number(value, default, maximum, minimum)
    if type(value) ~= 'number' or value ~= value or value < (minimum or 0) or value > maximum then return default end
    return value
end

function M.options(values)
    values = type(values) == 'table' and values or {}
    return {
        willpowerWeight=number(values.willpowerWeight,100,1000),
        speedWeight=number(values.speedWeight,0,1000),
        multiplier=number(values.multiplier,1,3,.1),
    }
end

function M.attribute(speed, willpower, options)
    options = M.options(options)
    return willpower*options.willpowerWeight/100 + speed*options.speedWeight/100
end

function M.lift(speed, willpower, original, minimum, maximum, options)
    options = M.options(options)
    local target = M.attribute(speed,willpower,options)
    if options.multiplier ~= 1 then
        original, minimum, maximum = original or 0, minimum or 0, maximum or 1
        if maximum <= minimum then return 0 end
        -- Invert the flight formula, including its minimum-speed term and source magnitude.
        local offset = original + minimum/(.01*(maximum-minimum))
        target = options.multiplier*(target+offset)-offset
    end
    return math.min(5000, math.max(0, math.ceil(target-speed)))
end

function M.speed(attribute, magnitude, minimum, maximum, load, penalty)
    if load > 1 then return 0 end
    return math.max(0, (minimum + .01*(attribute+magnitude)*(maximum-minimum))*(1-penalty*load))
end

function M.target(speed, willpower, original, minimum, maximum, load, penalty, options)
    options = M.options(options)
    return M.speed(M.attribute(speed,willpower,options),original,minimum,maximum,load,penalty)*options.multiplier
end

function M.ratio(speed, willpower, original, helper, minimum, maximum, load, penalty, options)
    local actual = M.speed(speed, original+helper, minimum, maximum, load, penalty)
    if actual <= 0 then return 1 end
    return math.min(1, M.target(speed,willpower,original,minimum,maximum,load,penalty,options)/actual)
end

function M.inputs(forward, side, ratio)
    local length = math.sqrt(forward*forward+side*side)
    local scale = ratio / math.max(1, length)
    return forward*scale, side*scale, math.min(1,length)*ratio
end

function M.matchesFlight(current, expected, factor)
    if factor <= .001 or expected <= 0 then return false end
    local value = expected*factor
    local tolerance = math.max(.05,value*.005)
    return math.abs(current-value) <= tolerance or math.abs(current-value*.75) <= tolerance
end

return M
