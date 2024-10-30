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
    -- local posVers = {
    --     cc.p(-15,20),
    --     cc.p(15,20),
    --     cc.p(15,-20),
    --     cc.p(-15,-20)
    -- }
    -- local material = cc.PhysicsMaterial(0, 1, 0)
    -- local entityBody = cc.PhysicsBody:createPolygon(posVers, material)
    -- entityBody:setCategoryBitmask(CollisionType.Entity)
    -- entityBody:setCollisionBitmask(bit._or(CollisionType.Entity,CollisionType.EdgeBox))
    -- entityBody:setContactTestBitmask(bit._or(CollisionType.Entity,CollisionType.EdgeBox))
    -- print(string.format("NodeEntity CategoryBitmask:%d CollisionBitmask:%d ContactTestBitmask:%d",entityBody:getCategoryBitmask(),entityBody:getCollisionBitmask(),entityBody:getContactTestBitmask()))
    -- self:setPhysicsBody(entityBody)
    self.frameid = 0
    self.opeCode = 0x00
end

function NodeEntity:onExit()
end

function NodeEntity:onContactBegin(INnode)
    return true
end

function NodeEntity:onContactEnd(INnode)
end

function NodeEntity:getKeyboardEvent(INType,INeventCode)
    local opeCode = self.opeCode
    if "onKeyEventPressed" == INType then
        if cc.KeyCode.KEY_W == INeventCode then
            --self.ahead = self.ahead + 1
            self.opeCode = bit._or(self.opeCode,0x01)
        end
        if cc.KeyCode.KEY_S == INeventCode then
            --self.ahead = self.ahead - 1
            self.opeCode = bit._or(self.opeCode,0x02)
        end
        if cc.KeyCode.KEY_A == INeventCode then
            --self.rotation = self.rotation - 1
            self.opeCode = bit._or(self.opeCode,0x04)
        end
        if cc.KeyCode.KEY_D == INeventCode then
            --self.rotation = self.rotation + 1
            self.opeCode = bit._or(self.opeCode,0x08)
        end
        if cc.KeyCode.KEY_SPACE == INeventCode then
            self:fireBullet()
            self.opeCode = bit._or(self.opeCode,0x10)
        end
    elseif "onKeyEventReleased" == INType then
        if cc.KeyCode.KEY_W == INeventCode then
            --self.ahead = self.ahead - 1
            self.opeCode = bit._and(self.opeCode,0xfe)
        end
        if cc.KeyCode.KEY_S == INeventCode then
            --self.ahead = self.ahead + 1
            self.opeCode = bit._and(self.opeCode,0xfd)
        end
        if cc.KeyCode.KEY_A == INeventCode then
            --self.rotation = self.rotation + 1
            self.opeCode = bit._and(self.opeCode,0xfb)
        end
        if cc.KeyCode.KEY_D == INeventCode then
            --self.rotation = self.rotation - 1
            self.opeCode = bit._and(self.opeCode,0xf7)
        end
        if cc.KeyCode.KEY_SPACE == INeventCode then
            self.opeCode = bit._and(self.opeCode,0xef)
        end
    end
    if self.opeCode == opeCode then return end
    if not self.parent.begin then return end
    self.parent:sendUdpData(protobuf.encode('pb_common.data_ope', {
        userid = self.token,
        frameid = self.parent.currentFrame,
        opecode = self.opeCode
    }))
    print(string.format("input frameid:%d opeCode:%d",self.parent.currentFrame,self.opeCode))
end

function NodeEntity:setToken(INtoken)
    self.token = INtoken or -1
end

function NodeEntity:applyInput(INframe,INopeCode)
    local ahead, rotation = 0, 0
    if bit._and(INopeCode,0x01) > 0 then ahead = ahead + 1 end
    if bit._and(INopeCode,0x02) > 0 then ahead = ahead - 1 end
    if bit._and(INopeCode,0x04) > 0 then rotation = rotation - 1 end
    if bit._and(INopeCode,0x08) > 0 then rotation = rotation + 1 end
    self.ahead, self.rotation = ahead, rotation
end

function NodeEntity:updateEntity(dt)
    if self.rotation ~= 0 then
        local rotation = self:getRotation()
        self:setRotation(rotation+self.rotation*dt*200)
    end
    if self.ahead ~= 0 then
        local rotation = self:getRotation() % 360
        local dir = cc.p(math.sin(rotation*math.pi/180),math.cos(rotation*math.pi/180))
        local pos = cc.p(self:getPosition())
        pos = cc.pAdd(pos,cc.pMul(dir,self.ahead*dt*200))
        --if 0 == self.token then HLog:printf("frame %d pos.x %f pos.y %f dt %f",self.parent.currentFrame,pos.x,pos.y,dt) end
        self:setPosition(pos)
    end
end

function NodeEntity:fireBullet()
    local HandlerBullet = require "app.modules.map.NodeBullet"
    local bullet = HandlerBullet.new(self:getRotation())
    bullet:addTo(self.parent)
    bullet:setPosition(cc.p(self:getPosition()))
end

return NodeEntity