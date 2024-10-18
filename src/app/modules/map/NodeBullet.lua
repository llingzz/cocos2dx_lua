local NodeBullet = class("NodeBullet", function ()
    local node = display.newNode()
    node:enableNodeEvents()
    return node
end)

local speed = 500
function NodeBullet:ctor(INrotation)
    self.bullet = display.newSprite("res/bullet.png")
    self.bullet:addTo(self)
    local material = cc.PhysicsMaterial(0, 1, 0)
    local physicsBody = cc.PhysicsBody:createCircle(5, material)
    physicsBody:setCategoryBitmask(CollisionType.Bullet)
    physicsBody:setCollisionBitmask(bit._or(CollisionType.Bullet,CollisionType.EdgeBox))
    physicsBody:setContactTestBitmask(bit._or(CollisionType.Bullet,CollisionType.EdgeBox))
    print(string.format("NodeBullet CategoryBitmask:%d CollisionBitmask:%d ContactTestBitmask:%d",physicsBody:getCategoryBitmask(),physicsBody:getCollisionBitmask(),physicsBody:getContactTestBitmask()))
    local rotation = INrotation % 360
    local dir = cc.p(math.sin(rotation*math.pi/180),math.cos(rotation*math.pi/180))
    self:setPosition(cc.pAdd(cc.p(self:getPosition()),cc.pMul(dir,20/speed)))
    local velocity = cc.pMul(dir, speed)
    physicsBody:setVelocity(velocity)
    physicsBody:setGravityEnable(false)
    self:setPhysicsBody(physicsBody)
end

function NodeBullet:onContactBegin(INnode)
    self:removeFromParent()
    return
end

function NodeBullet:onContactEnd(INnode)
end

return NodeBullet