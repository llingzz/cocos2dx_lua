local HelpTools = {}

function HelpTools:creatBinaryEnumTable(INtbl)
    local enumtbl = {}
    for i, v in ipairs(INtbl) do
        enumtbl[v] = math.pow(2, (i - 1))
    end
    return enumtbl
end

return HelpTools