local M = {}

function M.enabled(value)
    return value ~= false
end

function M.lift(speed, willpower)
    return math.min(5000, math.max(0, math.ceil(willpower-speed)))
end

function M.speed(attribute, magnitude, minimum, maximum, load, penalty)
    if load > 1 then return 0 end
    return math.max(0, (minimum + .01*(attribute+magnitude)*(maximum-minimum))*(1-penalty*load))
end

function M.ratio(speed, willpower, original, helper, minimum, maximum, load, penalty)
    local actual = M.speed(speed, original+helper, minimum, maximum, load, penalty)
    if actual <= 0 then return 1 end
    return math.min(1, M.speed(willpower, original, minimum, maximum, load, penalty)/actual)
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
