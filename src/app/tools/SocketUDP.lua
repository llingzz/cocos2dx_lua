local socket = require "socket"

local SocketUDP = class("SocketUDP")
SocketUDP.EVENT_DATA = "SOCKET_UDP_DATA"
function SocketUDP:ctor(__host, __port, __eventProtocol)
    self.socket = socket.udp()
    self.socket:settimeout(0)
    self.socket:setpeername(__host, __port)
    self.tickScheduler = Scheduler:scheduleGlobal(handler(self,self.receive), 0.1)
    self.eventProtocol = __eventProtocol
end

function SocketUDP:receive(dt)
    local chunck, status, partial = self.socket:receive()
    if (chunck and #chunck == 0) or (partial and #partial == 0) then
        return
    end
    local content = ''
    if partial and #partial > 0 then
        content = content .. partial
    elseif chunck and #chunck > 0 then
        content = content .. chunck
    end
    if self.eventProtocol and content ~= '' then
        self.eventProtocol:dispatchEvent({name=SocketUDP.EVENT_DATA, data=content})
    end
end

function SocketUDP:send(data)
    local i, err = self.socket:send(data)
    if err then print("SocketUDP:send error " .. err) end
end

function SocketUDP:close()
    if self.tickScheduler then
        Scheduler:unscheduleGlobal(self.tickScheduler)
        self.tickScheduler = nil
    end
    self.socket:close()
end

return SocketUDP