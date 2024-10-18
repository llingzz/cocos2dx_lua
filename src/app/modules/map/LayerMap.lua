local LayerMap = class("LayerMap", function()
    local layer = display.newLayer()
    layer:enableNodeEvents()
    return layer
end)

function LayerMap:ctor()
    local wallThick = 10
    local edgeBoxBody = cc.PhysicsBody:createEdgeBox(cc.size(display.width - wallThick*2, display.height - wallThick*2), cc.PhysicsMaterial(0, 1, 0), wallThick)
    edgeBoxBody:setDynamic(false)
    edgeBoxBody:setCategoryBitmask(CollisionType.EdgeBox)
    edgeBoxBody:setCollisionBitmask(bit._or(CollisionType.Entity,CollisionType.EdgeBox))
    edgeBoxBody:setContactTestBitmask(bit._or(CollisionType.Entity,CollisionType.EdgeBox))
    print(string.format("LayerMap CategoryBitmask:%d CollisionBitmask:%d ContactTestBitmask:%d",edgeBoxBody:getCategoryBitmask(),edgeBoxBody:getCollisionBitmask(),edgeBoxBody:getContactTestBitmask()))
    self:setPhysicsBody(edgeBoxBody)
end

function LayerMap:onContactBegin(INnode)
    return true
end

function LayerMap:onContactEnd(INnode)
end

return LayerMap