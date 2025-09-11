local HLog = {}

function HLog:printLog(tag, fmt, ...)
    local t = {
        "[",
        string.upper(tostring(tag)),
        "] ",
        string.format(tostring(fmt), ...)
    }
    local logStr = table.concat(t)
    print(logStr)
    self:writeLog(logStr)
end

function HLog:printf(fmt, ...)
    if DEBUG <= 0 then return end
    local logStr = string.format(tostring(fmt), ...)
    print(logStr)
    self:writeLog(logStr)
end

function HLog:printError(fmt, ...)
    if DEBUG <= 0 then return end
    self:printLog("ERR", fmt, ...)
    local logStr = debug.traceback("", 5)
    print(logStr)
    self:writeLog(logStr)
end

function HLog:printInfo(fmt, ...)
    if type(DEBUG) ~= "number" or DEBUG < 2 then return end
    self:printLog("INFO", fmt, ...)
end

local function dump_value_(v)
    if type(v) == "string" then
        v = "\"" .. v .. "\""
    end
    return tostring(v)
end

function HLog:dump(value, desciption, nesting)
    if type(nesting) ~= "number" then nesting = 3 end

    local lookupTable = {}
    local result = {}

    local traceback = string.split(debug.traceback("", 2), "\n")
    print("dump from: " .. string.trim(traceback[3]))

    local function dump_(value, desciption, indent, nest, keylen)
        desciption = desciption or "<var>"
        local spc = ""
        if type(keylen) == "number" then
            spc = string.rep(" ", keylen - string.len(dump_value_(desciption)))
        end
        if type(value) ~= "table" then
            result[#result +1 ] = string.format("%s%s%s = %s", indent, dump_value_(desciption), spc, dump_value_(value))
        elseif lookupTable[tostring(value)] then
            result[#result +1 ] = string.format("%s%s%s = *REF*", indent, dump_value_(desciption), spc)
        else
            lookupTable[tostring(value)] = true
            if nest > nesting then
                result[#result +1 ] = string.format("%s%s = *MAX NESTING*", indent, dump_value_(desciption))
            else
                result[#result +1 ] = string.format("%s%s = {", indent, dump_value_(desciption))
                local indent2 = indent.."    "
                local keys = {}
                local keylen = 0
                local values = {}
                for k, v in pairs(value) do
                    keys[#keys + 1] = k
                    local vk = dump_value_(k)
                    local vkl = string.len(vk)
                    if vkl > keylen then keylen = vkl end
                    values[k] = v
                end
                table.sort(keys, function(a, b)
                    if type(a) == "number" and type(b) == "number" then
                        return a < b
                    else
                        return tostring(a) < tostring(b)
                    end
                end)
                for i, k in ipairs(keys) do
                    dump_(values[k], k, indent2, nest + 1, keylen)
                end
                result[#result +1] = string.format("%s}", indent)
            end
        end
    end
    dump_(value, desciption, "- ", 1)

    for i, line in ipairs(result) do
        HLog:printf(line)
    end
end

function HLog:getLocalFileName()
    local filePath = cc.FileUtils:getInstance():getWritablePath()
    local fileName = USERID .. "_log.txt"
    return filePath .. fileName
end

function HLog:writeLog(INlogContent)
    if DEBUG == 0 then return end
    local fileName = self:getLocalFileName()
    local file = io.open(fileName, 'a')
    if not file then return end
    local curTime = os.date("%c") .. ":"
    local curString = curTime .. INlogContent .. "\n"
    file:write(curString)
    file:close()
end

return HLog