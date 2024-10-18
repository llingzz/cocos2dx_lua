local NodeEntity = class("NodeEntity", function ()
    local node = display.newNode()
    node:enableNodeEvents()
    return node
end)

function NodeEntity:ctor()
    self.entity = display.newSprite("res/entity.png")
    self.entity:addTo(self)
    local posVers = {
        cc.p(-15,20),
        cc.p(15,20),
        cc.p(15,-20),
        cc.p(-15,-20)
    }
    local material = {
        density = 1,
        restitution = 0,
        friction = 0
    }
    local entityBody = cc.PhysicsBody:createPolygon(posVers, material)
    if entityBody then
        entityBody:setCategoryBitmask(CollisionType.Entity)
        entityBody:setCollisionBitmask(bit._or(CollisionType.Entity,CollisionType.EdgeBox))
        entityBody:setContactTestBitmask(bit._or(CollisionType.Entity,CollisionType.EdgeBox))
        print(string.format("NodeEntity CategoryBitmask:%d CollisionBitmask:%d ContactTestBitmask:%d",entityBody:getCategoryBitmask(),entityBody:getCollisionBitmask(),entityBody:getContactTestBitmask()))
        self:setPhysicsBody(entityBody)
    end
end

function NodeEntity:onContactBegin(INnode)
    -- todo
end

function NodeEntity:onContactEnd(INnode)
    -- todo
end

return NodeEntity