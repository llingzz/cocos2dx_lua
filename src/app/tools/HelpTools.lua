local HelpTools = {}

function HelpTools:creatBinaryEnumTable(INtbl)
    local enumtbl = {}
    for i, v in ipairs(INtbl) do
        enumtbl[v] = math.pow(2, (i - 1))
    end
    return enumtbl
end

function HelpTools:clamp(num, min, max)
    if num < min then num = min
    elseif num > max then num = max
    end
    return num
end

function HelpTools:lerp(from, to, t)
    return from + (to - from) * self:clamp(t, 0, 1)
end

function HelpTools:toFixed(INnum)
    return math.floor(INnum*math.pow(10,4))/math.pow(10,4)
end

return HelpTools