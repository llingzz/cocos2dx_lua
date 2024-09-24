require "pack"

local function test()
    local bpack=string.pack
    local bunpack=string.unpack

    local function hex(s)
        s=string.gsub(s,"(.)",function (x) return string.format("%02X",string.byte(x)) end)
        return s
    end

    local a=bpack("Ab8","\027Lua",5*16+1,0,1,4,4,4,8,0)
    print(hex(a),string.len(a))

    local b=string.dump(hex)
    b=string.sub(b,1,string.len(a))
    print(a==b,string.len(b))
    print(bunpack(b,"bA3b8"))

    local i=314159265
    local f="<I>I=I"
    a=bpack(f,i,i,i)
    print(hex(a))
    print(bunpack(a,f))

    i=3.14159265
    f="<d>d=d"
    a=bpack(f,i,i,i)
    print(hex(a))
    print(bunpack(a,f))
end

local lpack = {
    test = test,
}

return lpack