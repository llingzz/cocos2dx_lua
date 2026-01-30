local CollisionSystem = class("CollisionSystem")

-- 碰撞层级定义
CollisionSystem.LAYER_PLAYER = 1
CollisionSystem.LAYER_BULLET = 2
CollisionSystem.LAYER_ENVIRONMENT = 4

-- 碰撞形状类型
CollisionSystem.SHAPE_AABB = 1
CollisionSystem.SHAPE_CIRCLE = 2

function CollisionSystem:ctor()
    self.colliders = {}
    self.colliderCount = 0
    -- 碰撞矩阵：定义哪些层级之间可以碰撞
    self.collisionMatrix = {
        [CollisionSystem.LAYER_PLAYER] = {
            [CollisionSystem.LAYER_BULLET] = true,
            [CollisionSystem.LAYER_PLAYER] = false,
            [CollisionSystem.LAYER_ENVIRONMENT] = true,
        },
        [CollisionSystem.LAYER_BULLET] = {
            [CollisionSystem.LAYER_PLAYER] = true,
            [CollisionSystem.LAYER_BULLET] = false,
            [CollisionSystem.LAYER_ENVIRONMENT] = true,
        },
        [CollisionSystem.LAYER_ENVIRONMENT] = {
            [CollisionSystem.LAYER_PLAYER] = true,
            [CollisionSystem.LAYER_BULLET] = true,
            [CollisionSystem.LAYER_ENVIRONMENT] = false,
        },
    }
    -- 碰撞事件回调
    self.onCollision = nil
end

function CollisionSystem:addCollider(entity, shape, layer, params)
    local collider = {
        entity = entity,
        shape = shape,
        layer = layer,
        params = params or {},
        enabled = true,
    }
    self.colliders[entity] = collider
    self.colliderCount = self.colliderCount + 1
    return collider
end

function CollisionSystem:removeCollider(entity)
    if self.colliders[entity] then
        self.colliders[entity] = nil
        self.colliderCount = self.colliderCount - 1
    end
end

function CollisionSystem:setColliderEnabled(entity, enabled)
    if self.colliders[entity] then
        self.colliders[entity].enabled = enabled
    end
end

function CollisionSystem:canCollide(layerA, layerB)
    if self.collisionMatrix[layerA] then
        return self.collisionMatrix[layerA][layerB] == true
    end
    return false
end

function CollisionSystem:getColliderBounds(collider, frameId)
    local entity = collider.entity
    if entity.getLogicBounds then
        if collider.layer == CollisionSystem.LAYER_BULLET then
            return entity:getLogicBounds(frameId)
        else
            return entity:getLogicBounds()
        end
    end
    return nil
end

-- AABB 碰撞检测
function CollisionSystem:checkAABB(boundsA, boundsB)
    if not boundsA or not boundsB then return false end

    local aLeft = boundsA.x - boundsA.width / 2
    local aRight = boundsA.x + boundsA.width / 2
    local aTop = boundsA.y + boundsA.height / 2
    local aBottom = boundsA.y - boundsA.height / 2

    local bLeft = boundsB.x - boundsB.width / 2
    local bRight = boundsB.x + boundsB.width / 2
    local bTop = boundsB.y + boundsB.height / 2
    local bBottom = boundsB.y - boundsB.height / 2

    return aLeft < bRight and aRight > bLeft and aTop > bBottom and aBottom < bTop
end

-- 圆形碰撞检测
function CollisionSystem:checkCircle(boundsA, radiusA, boundsB, radiusB)
    if not boundsA or not boundsB then return false end

    local dx = boundsA.x - boundsB.x
    local dy = boundsA.y - boundsB.y
    local distSq = dx * dx + dy * dy
    local radiusSum = radiusA + radiusB

    return distSq <= radiusSum * radiusSum
end

-- 圆形与 AABB 碰撞检测
function CollisionSystem:checkCircleAABB(circleBounds, radius, aabbBounds)
    if not circleBounds or not aabbBounds then return false end

    local aabbLeft = aabbBounds.x - aabbBounds.width / 2
    local aabbRight = aabbBounds.x + aabbBounds.width / 2
    local aabbTop = aabbBounds.y + aabbBounds.height / 2
    local aabbBottom = aabbBounds.y - aabbBounds.height / 2

    -- 找到 AABB 上离圆心最近的点
    local closestX = math.max(aabbLeft, math.min(circleBounds.x, aabbRight))
    local closestY = math.max(aabbBottom, math.min(circleBounds.y, aabbTop))

    local dx = circleBounds.x - closestX
    local dy = circleBounds.y - closestY
    local distSq = dx * dx + dy * dy

    return distSq <= radius * radius
end

function CollisionSystem:checkCollision(colliderA, colliderB, frameId)
    local boundsA = self:getColliderBounds(colliderA, frameId)
    local boundsB = self:getColliderBounds(colliderB, frameId)

    if not boundsA or not boundsB then return false end

    local shapeA = colliderA.shape
    local shapeB = colliderB.shape

    if shapeA == CollisionSystem.SHAPE_AABB and shapeB == CollisionSystem.SHAPE_AABB then
        return self:checkAABB(boundsA, boundsB)
    elseif shapeA == CollisionSystem.SHAPE_CIRCLE and shapeB == CollisionSystem.SHAPE_CIRCLE then
        local radiusA = colliderA.params.radius or (boundsA.width / 2)
        local radiusB = colliderB.params.radius or (boundsB.width / 2)
        return self:checkCircle(boundsA, radiusA, boundsB, radiusB)
    elseif shapeA == CollisionSystem.SHAPE_CIRCLE and shapeB == CollisionSystem.SHAPE_AABB then
        local radiusA = colliderA.params.radius or (boundsA.width / 2)
        return self:checkCircleAABB(boundsA, radiusA, boundsB)
    elseif shapeA == CollisionSystem.SHAPE_AABB and shapeB == CollisionSystem.SHAPE_CIRCLE then
        local radiusB = colliderB.params.radius or (boundsB.width / 2)
        return self:checkCircleAABB(boundsB, radiusB, boundsA)
    end

    return false
end

function CollisionSystem:update(frameId)
    local collisions = {}
    local colliderList = {}

    -- 收集所有启用的碰撞体
    for entity, collider in pairs(self.colliders) do
        if collider.enabled then
            table.insert(colliderList, collider)
        end
    end

    -- 两两检测碰撞
    local count = #colliderList
    for i = 1, count - 1 do
        for j = i + 1, count do
            local colliderA = colliderList[i]
            local colliderB = colliderList[j]

            -- 检查碰撞矩阵
            if self:canCollide(colliderA.layer, colliderB.layer) then
                if self:checkCollision(colliderA, colliderB, frameId) then
                    table.insert(collisions, {
                        colliderA = colliderA,
                        colliderB = colliderB,
                        frameId = frameId,
                    })
                end
            end
        end
    end

    -- 触发碰撞回调
    for _, collision in ipairs(collisions) do
        if self.onCollision then
            self.onCollision(collision.colliderA, collision.colliderB, collision.frameId)
        end
    end

    return collisions
end

function CollisionSystem:setOnCollision(callback)
    self.onCollision = callback
end

return CollisionSystem
