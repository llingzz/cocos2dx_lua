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

-- 线段与 AABB 相交检测（Liang-Barsky 算法）
-- start: 线段起点 {x, y}
-- dir: 线段方向向量（终点 - 起点）{x, y}
-- aabb: AABB 边界 {x, y, width, height}，x,y 为中心点
-- 返回: 是否相交, 相交时的 t 值 (0~1)
function CollisionSystem:lineIntersectsAABB(start, dir, aabb)
    local halfW = aabb.width / 2
    local halfH = aabb.height / 2

    local minX = aabb.x - halfW
    local maxX = aabb.x + halfW
    local minY = aabb.y - halfH
    local maxY = aabb.y + halfH

    local tMin = 0
    local tMax = 1

    -- X 轴检测
    if math.abs(dir.x) < 0.0001 then
        -- 线段平行于 Y 轴
        if start.x < minX or start.x > maxX then
            return false, nil
        end
    else
        local t1 = (minX - start.x) / dir.x
        local t2 = (maxX - start.x) / dir.x
        if t1 > t2 then t1, t2 = t2, t1 end
        tMin = math.max(tMin, t1)
        tMax = math.min(tMax, t2)
        if tMin > tMax then return false, nil end
    end

    -- Y 轴检测
    if math.abs(dir.y) < 0.0001 then
        -- 线段平行于 X 轴
        if start.y < minY or start.y > maxY then
            return false, nil
        end
    else
        local t1 = (minY - start.y) / dir.y
        local t2 = (maxY - start.y) / dir.y
        if t1 > t2 then t1, t2 = t2, t1 end
        tMin = math.max(tMin, t1)
        tMax = math.min(tMax, t2)
        if tMin > tMax then return false, nil end
    end

    return true, tMin
end

-- 扫掠碰撞检测（相对速度法）
-- 检测子弹从上一帧到当前帧的运动轨迹是否与移动中的玩家相交
-- bulletCollider: 子弹碰撞体
-- playerCollider: 玩家碰撞体
-- frameId: 当前帧号
function CollisionSystem:checkSweptCollision(bulletCollider, playerCollider, frameId)
    local bullet = bulletCollider.entity
    local player = playerCollider.entity

    if not bullet or not player then return false end

    -- 获取子弹当前帧和上一帧的位置
    local bulletCurr = bullet:getLogicBounds(frameId)
    local bulletPrev = bullet:getLogicBounds(frameId - 1)

    if not bulletCurr or not bulletPrev then return false end

    -- 获取玩家当前帧和上一帧的位置
    local playerCurr = player:getLogicBounds()
    local playerPrev = player:getPrevLogicBounds()

    if not playerCurr or not playerPrev then
        -- 如果没有上一帧数据，回退到普通检测
        return self:checkAABB(bulletCurr, playerCurr)
    end

    -- 计算子弹速度向量（每帧移动量）
    local bulletVel = {
        x = bulletCurr.x - bulletPrev.x,
        y = bulletCurr.y - bulletPrev.y
    }

    -- 计算玩家速度向量（每帧移动量）
    local playerVel = {
        x = playerCurr.x - playerPrev.x,
        y = playerCurr.y - playerPrev.y
    }

    -- 计算相对速度（在玩家参考系中，子弹的运动）
    local relativeVel = {
        x = bulletVel.x - playerVel.x,
        y = bulletVel.y - playerVel.y
    }

    -- 如果相对速度为零，使用静态检测
    local relativeSpeed = math.sqrt(relativeVel.x * relativeVel.x + relativeVel.y * relativeVel.y)
    if relativeSpeed < 0.0001 then
        return self:checkAABB(bulletCurr, playerCurr)
    end

    -- 子弹在玩家参考系中的起点（上一帧子弹位置）
    local relativeStart = {
        x = bulletPrev.x,
        y = bulletPrev.y
    }

    -- 将玩家 AABB 扩展子弹尺寸（闵可夫斯基和）
    -- 这样可以将子弹视为点，简化检测
    local expandedAABB = {
        x = playerPrev.x,
        y = playerPrev.y,
        width = playerPrev.width + bulletPrev.width,
        height = playerPrev.height + bulletPrev.height
    }

    -- 检测线段与扩展后 AABB 的相交
    local hit, t = self:lineIntersectsAABB(relativeStart, relativeVel, expandedAABB)

    return hit
end

function CollisionSystem:checkCollision(colliderA, colliderB, frameId)
    -- 对于子弹与玩家的碰撞，使用扫掠检测
    local isBulletA = colliderA.layer == CollisionSystem.LAYER_BULLET
    local isBulletB = colliderB.layer == CollisionSystem.LAYER_BULLET
    local isPlayerA = colliderA.layer == CollisionSystem.LAYER_PLAYER
    local isPlayerB = colliderB.layer == CollisionSystem.LAYER_PLAYER

    if isBulletA and isPlayerB then
        return self:checkSweptCollision(colliderA, colliderB, frameId)
    elseif isBulletB and isPlayerA then
        return self:checkSweptCollision(colliderB, colliderA, frameId)
    end

    -- 其他碰撞使用原有的静态检测
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
