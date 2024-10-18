local NodeEntity = class("NodeEntity", function ()
    local node = display.newNode()
    node:enableNodeEvents()
    return node
end)

function NodeEntity:ctor(INparent)
    self.parent = INparent
    self.ahead = 0
    self.rotation = 0
    self.entity = display.newSprite("res/entity.png")
    self.entity:addTo(self)
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
        if cc.KeyCode.KEY_W == INeventCode then self.ahead = self.ahead + 1 end
        if cc.KeyCode.KEY_S == INeventCode then self.ahead = self.ahead - 1 end
        if cc.KeyCode.KEY_A == INeventCode then self.rotation = self.rotation - 1 end
        if cc.KeyCode.KEY_D == INeventCode then self.rotation = self.rotation + 1 end
        if cc.KeyCode.KEY_SPACE == INeventCode then self:fireBullet() end
    elseif "onKeyEventReleased" == INType then
        if cc.KeyCode.KEY_W == INeventCode then self.ahead = self.ahead - 1 end
        if cc.KeyCode.KEY_S == INeventCode then self.ahead = self.ahead + 1 end
        if cc.KeyCode.KEY_A == INeventCode then self.rotation = self.rotation + 1 end
        if cc.KeyCode.KEY_D == INeventCode then self.rotation = self.rotation - 1 end
    end
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
        self:setPosition(cc.pAdd(pos,cc.pMul(dir,self.ahead*dt*200)))
    end
end

function NodeEntity:fireBullet()
    local HandlerBullet = require "app.modules.map.NodeBullet"
    local bullet = HandlerBullet.new(self:getRotation())
    bullet:addTo(self.parent)
    bullet:setPosition(cc.p(self:getPosition()))
end

return NodeEntity