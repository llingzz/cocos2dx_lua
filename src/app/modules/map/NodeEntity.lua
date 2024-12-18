local dir_table = require "app.tools.RotationToSpeed"
local NodeEntity = class("NodeEntity", function ()
    local node = display.newNode()
    node:enableNodeEvents()
    return node
end)

function NodeEntity:ctor(INparent)
    self.token = -1
    self.parent = INparent
    self.ahead = 0
    self.rotation = 0
    self.entity = display.newSprite("res/entity.png")
    self.entity:addTo(self)

    self.frameid = 0
    self.opeCode = 0x00
    self.lastOpeCode = 0x00
    self.syncOpeCode = 0x00

    self.logicRat = 0
    self.logicPos = cc.p(display.cx*1000,display.cy*1000)
    self.predictRat = 0
    self.predictPos = cc.p(display.cx*1000,display.cy*1000)
    --self:createPhysicBody()
end

function NodeEntity:onExit()
end

function NodeEntity:createPhysicBody()
    local posVers = {
        cc.p(-15,20),
        cc.p(15,20),
        cc.p(15,-20),
        cc.p(-15,-20)
    }
    local material = cc.PhysicsMaterial(0, 1, 0)
    local entityBody = cc.PhysicsBody:createPolygon(posVers, material)
    entityBody:setCategoryBitmask(CollisionType.Entity)
    entityBody:setCollisionBitmask(bit._or(CollisionType.Entity,CollisionType.EdgeBox))
    entityBody:setContactTestBitmask(bit._or(CollisionType.Entity,CollisionType.EdgeBox))
    print(string.format("NodeEntity CategoryBitmask:%d CollisionBitmask:%d ContactTestBitmask:%d",entityBody:getCategoryBitmask(),entityBody:getCollisionBitmask(),entityBody:getContactTestBitmask()))
    self:setPhysicsBody(entityBody)
end

function NodeEntity:onContactBegin(INnode)
    return true
end

function NodeEntity:onContactEnd(INnode)
end

function NodeEntity:getKeyboardEvent(INType,INeventCode)
    if "onKeyEventPressed" == INType then
        if cc.KeyCode.KEY_W == INeventCode then self.opeCode = bit._or(self.opeCode,0x01) end
        if cc.KeyCode.KEY_S == INeventCode then self.opeCode = bit._or(self.opeCode,0x02) end
        if cc.KeyCode.KEY_A == INeventCode then self.opeCode = bit._or(self.opeCode,0x04) end
        if cc.KeyCode.KEY_D == INeventCode then self.opeCode = bit._or(self.opeCode,0x08) end
        if cc.KeyCode.KEY_SPACE == INeventCode then self.opeCode = bit._or(self.opeCode,0x10) end
    elseif "onKeyEventReleased" == INType then
        if cc.KeyCode.KEY_W == INeventCode then self.opeCode = bit._and(self.opeCode,0xfe) end
        if cc.KeyCode.KEY_S == INeventCode then self.opeCode = bit._and(self.opeCode,0xfd) end
        if cc.KeyCode.KEY_A == INeventCode then self.opeCode = bit._and(self.opeCode,0xfb) end
        if cc.KeyCode.KEY_D == INeventCode then self.opeCode = bit._and(self.opeCode,0xf7) end
        if cc.KeyCode.KEY_SPACE == INeventCode then self.opeCode = bit._and(self.opeCode,0xef) end
    end
end

function NodeEntity:capturePlayerOpts()
    if self.lastOpeCode == self.opeCode then return end
    self.parent:sendUdpData(protobuf.enum_id("pb_common.protocol_code","protocol_frame"),protobuf.encode('pb_common.data_ope', {
        userid = self.token,
        frameid = self.parent.currentFrameId,
        opecode = self.opeCode
    }))
    self.lastOpeCode = self.opeCode
end

function NodeEntity:setToken(INtoken)
    self.token = INtoken or -1
end

function NodeEntity:convertOpeCode(INopeCode)
    local ahead, rotation = 0, 0
    if bit._and(INopeCode,0x01) > 0 then ahead = ahead + 1 end
    if bit._and(INopeCode,0x02) > 0 then ahead = ahead - 1 end
    if bit._and(INopeCode,0x04) > 0 then rotation = rotation - 1 end
    if bit._and(INopeCode,0x08) > 0 then rotation = rotation + 1 end
    return ahead, rotation
end

function NodeEntity:applyInput(INframe,INopeCode)
    if self.frameid > INframe then return end
    self.ahead, self.rotation = self:convertOpeCode(INopeCode)
    self.frameid = INframe
    self.syncOpeCode = INopeCode
end

function NodeEntity:predictUpdate(INahead,INrotation)
    if INrotation ~= 0 then
        self.predictRat = self.predictRat + INrotation*15
    end
    if INahead ~= 0 then
        local dir = dir_table[math.round(self.predictRat%360)]
        self.predictPos.x = self.predictPos.x + dir.x*INahead*200
        self.predictPos.y = self.predictPos.y + dir.y*INahead*200
    end
end

function NodeEntity:logicUpdate(dt)
    if self.rotation ~= 0 then
        self.logicRat = self.logicRat + self.rotation*15
        --print(string.format("logicRat %d",self.logicRat))
    end
    if self.ahead ~= 0 then
        local dir = dir_table[math.round(self.logicRat%360)]
        self.logicPos.x = self.logicPos.x + dir.x*self.ahead*200
        self.logicPos.y = self.logicPos.y + dir.y*self.ahead*200
        --print(string.format("logicPox.x %d logicPos.y %d",self.logicPos.x,self.logicPos.y))
    end
    if bit._and(self.syncOpeCode,0x10) > 0 then
        self:fireBullet()
    end
end

function NodeEntity:renderUpdate(dt)
    self:setRotation(HelpTools:lerp(self:getRotation(),self.predictRat,0.067))
    self:setPosition(cc.pLerp(cc.p(self:getPosition()),cc.p(self.predictPos.x/1000,self.predictPos.y/1000),0.067))
    -- self:setRotation(HelpTools:lerp(self:getRotation(),self.logicRat,0.067))
    -- self:setPosition(cc.pLerp(cc.p(self:getPosition()),cc.p(self.logicPos.x/1000,self.logicPos.y/1000),0.067))
end

function NodeEntity:fireBullet()
    if not self.lastFire then self.lastFire = socket.gettime() - 1 end
    if socket.gettime() - self.lastFire <= 0.3 then return end
    self.lastFire = socket.gettime()
    local HandlerBullet = require "app.modules.map.NodeBullet"
    local bullet = HandlerBullet.new(self:getRotation())
    bullet:addTo(self.parent)
    bullet:setPosition(cc.p(self:getPosition()))
end

return NodeEntity