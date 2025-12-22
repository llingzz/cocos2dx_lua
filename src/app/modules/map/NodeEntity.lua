local dir_table = require "app.tools.RotationToSpeed"
local NodeEntity = class("NodeEntity", function ()
    local node = display.newNode()
    node:enableNodeEvents()
    return node
end)

function NodeEntity:ctor(INparent)
    self.token = -1
    self.index = 0
    self.parent = INparent
    self.ahead = 0
    self.rotation = 0
    self.entity = display.newSprite("res/entity.png")
    self.entity:addTo(self)
    self.opeCode = 0x00
    self.lastFire = socket.gettime()
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

function NodeEntity:getOpeCode()
    local opeCode = self.opeCode
    if bit._and(opeCode,0x10) > 0 then
        local now = socket.gettime()
        if now - self.lastFire < 0.3 then
            opeCode = bit._and(opeCode,0xef)
        else
            self.lastFire = now
        end
    end
    return opeCode
end

function NodeEntity:setToken(INtoken)
    self.token = INtoken or -1
end

function NodeEntity:setIndex(INindex)
    self.index = INindex or 0
end

function NodeEntity:fireBullet()
    local HandlerBullet = require "app.modules.map.NodeBullet"
    local bullet = HandlerBullet.new(self:getRotation())
    bullet:addTo(self.parent)
    bullet:setPosition(cc.p(self:getPosition()))
end

return NodeEntity