------------------------------------------------------------------------
-- DetCollisionDemo.lua
-- Standalone demo: 2 entities + 4 bullets with DetCollision system.
-- Entities wander randomly, bullets bounce off screen edges.
-- Call SceneMain:runDetCollisionDemo() to start.
--
-- Usage in SceneMain:ctor() or via hotkey:
--   self:runDetCollisionDemo()
------------------------------------------------------------------------

local DetCollision = require("src.app.collision.DetCollision.init")
local FM    = DetCollision.FixedMath
local Shape = DetCollision.Shape
local System = DetCollision.System

local GROUP_ENTITY = 2   -- 0x0002
local GROUP_BULLET = 4   -- 0x0004
local GROUP_WALL   = 8   -- 0x0008

local DetCollisionDemo = {}

------------------------------------------------------------------------
-- Setup the demo on a SceneMain instance.
------------------------------------------------------------------------
function DetCollisionDemo:runDetCollisionDemo(INscene)
    -- Screen boundaries (fixed-point)
    local WALL_THICK = FM.fromInt(10)
    local SCREEN_W   = FM.fromInt(display.width)
    local SCREEN_H   = FM.fromInt(display.height)
    local MIN_X = WALL_THICK
    local MIN_Y = WALL_THICK
    local MAX_X = SCREEN_W - WALL_THICK
    local MAX_Y = SCREEN_H - WALL_THICK

    -- Speeds per logic tick (fixed-point)
    local entitySpeed = FM.fromFloat(ENTITY_MOVE_SPEED)
    local bulletSpeed = FM.fromFloat(BULLET_MOVE_SPEED)

    -- Collision system (sweep-and-prune, no extra config needed)
    --local colSys = System.new({ broadPhase = "sweep_and_prune" })
    --local colSys = System.new({broadPhase = "spatial_hash",cellSize   = FM.fromInt(10),})
    local colSys = System.new({broadPhase = "quadtree", worldBounds = {FM.fromInt(display.cx), FM.fromInt(display.cy), FM.fromInt(display.cx*2), FM.fromInt(display.cy*2)}})

    -- Container layer for demo objects
    local demoLayer = display.newLayer()
    demoLayer:addTo(INscene, 10)

    -- Debug label
    local label = cc.Label:createWithSystemFont("DetCollision Demo", "Arial", 16)
    label:setPosition(display.cx, display.height - 20)
    label:setTextColor(cc.c4b(255, 255, 0, 255))
    label:addTo(demoLayer, 100)

    --------------------------------------------------------------------
    -- Random fixed-point direction (unit-ish vector, no sqrt needed).
    -- Returns dx, dy in fixed-point where magnitude ≈ 1.0 (SCALE).
    --------------------------------------------------------------------
    local function randomDirection()
        local angle = math.random(0, 359)
        return FM.cosDeg(angle), FM.sinDeg(angle)
    end

    --------------------------------------------------------------------
    -- Create entities
    --------------------------------------------------------------------
    local demoEntities = {}
    for i = 1, 1 do
        local sprite = display.newSprite("res/entity.png")
        local startX = FM.fromInt(300 + i * 200)
        local startY = FM.fromInt(200 + i * 100)
        local dx, dy = randomDirection()

        local entity = {
            id     = "entity_" .. i,
            sprite = sprite,
            -- Logic position (fixed-point)
            x = startX,
            y = startY,
            -- Movement direction (fixed-point, unit vector)
            dx = dx,
            dy = dy,
            -- Collision shape: circle with ENTITY_RADIUS
            --shape = Shape.newCircle(startX, startY, FM.fromInt(ENTITY_RADIUS)),
            shape = Shape.newAABB(FM.fromInt(startX), FM.fromInt(startY), FM.fromInt(15), FM.fromInt(20)),
            -- Timer for random direction change
            dirTimer    = 0,
            dirInterval = math.random(30, 90),  -- change direction every 30~90 logic ticks
        }

        sprite:setPosition(FM.toFloat(startX), FM.toFloat(startY))
        sprite:addTo(demoLayer)

        colSys:addBody(entity.id, entity.shape, GROUP_ENTITY,
            GROUP_ENTITY + GROUP_BULLET)  -- entities collide with entities and bullets

        demoEntities[i] = entity
    end

    --------------------------------------------------------------------
    -- Create bullets
    --------------------------------------------------------------------
    local demoBullets = {}
    for i = 1, 20 do
        local sprite = display.newSprite("res/bullet.png")
        local startX = FM.fromInt(math.random(100, 1100))
        local startY = FM.fromInt(math.random(100, 600))
        local dx, dy = randomDirection()

        local bullet = {
            id     = "bullet_" .. i,
            sprite = sprite,
            x  = startX,
            y  = startY,
            dx = dx,
            dy = dy,
            --shape = Shape.newCircle(startX, startY, FM.fromFloat(BULLET_RADIUS)),
            shape = Shape.newAABB(FM.fromInt(startX), FM.fromInt(startY), FM.fromFloat(2.5), FM.fromInt(5)),
        }

        sprite:setPosition(FM.toFloat(startX), FM.toFloat(startY))
        sprite:addTo(demoLayer)

        colSys:addBody(bullet.id, bullet.shape, GROUP_BULLET,
            GROUP_ENTITY + GROUP_WALL)  -- bullets collide with entities and walls

        demoBullets[i] = bullet
    end

    --------------------------------------------------------------------
    -- Create wall shapes (4 edges) for bullet boundary bounce.
    -- We don't use wall bodies in the collision system; instead we
    -- check boundary directly for bullets (simpler & no extra shapes).
    --------------------------------------------------------------------

    --------------------------------------------------------------------
    -- Collision callback
    --------------------------------------------------------------------
    colSys:onCollision(function(idA, idB, mtvX, mtvY)
        -- Flash the colliding sprites red briefly
        local function flashSprite(id)
            for _, e in ipairs(demoEntities) do
                if e.id == id then
                    e.sprite:setColor(cc.c3b(255, 0, 0))
                    e.flashTimer = 5
                    return
                end
            end
            for _, b in ipairs(demoBullets) do
                if b.id == id then
                    b.sprite:setColor(cc.c3b(255, 0, 0))
                    b.flashTimer = 5
                    return
                end
            end
        end
        flashSprite(idA)
        flashSprite(idB)
    end)

    --------------------------------------------------------------------
    -- Logic tick counter
    --------------------------------------------------------------------
    local logicAccum = 0
    local logicDt = 1.0 / LOGIC_FPS
    local frameCount = 0

    --------------------------------------------------------------------
    -- Per-frame update
    --------------------------------------------------------------------
    local function demoUpdate(dt)
        logicAccum = logicAccum + dt
        if logicAccum < logicDt then return end
        logicAccum = logicAccum - logicDt
        frameCount = frameCount + 1

        ----------------------------------------------------------------
        -- Update entities: random wander + boundary clamp
        ----------------------------------------------------------------
        for _, e in ipairs(demoEntities) do
            -- Randomly change direction
            e.dirTimer = e.dirTimer + 1
            if e.dirTimer >= e.dirInterval then
                e.dirTimer = 0
                e.dirInterval = math.random(30, 90)
                e.dx, e.dy = randomDirection()
            end

            -- Move
            e.x = e.x + FM.mul(e.dx, entitySpeed)
            e.y = e.y + FM.mul(e.dy, entitySpeed)

            -- Bounce off boundaries
            local r = FM.fromInt(ENTITY_RADIUS)
            if e.x - r < MIN_X then e.x = MIN_X + r; e.dx = FM.abs(e.dx) end
            if e.x + r > MAX_X then e.x = MAX_X - r; e.dx = -FM.abs(e.dx) end
            if e.y - r < MIN_Y then e.y = MIN_Y + r; e.dy = FM.abs(e.dy) end
            if e.y + r > MAX_Y then e.y = MAX_Y - r; e.dy = -FM.abs(e.dy) end

            -- Update shape & sprite
            Shape.setPosition(e.shape, e.x, e.y)

            -- Flash color reset
            if e.flashTimer and e.flashTimer > 0 then
                e.flashTimer = e.flashTimer - 1
                if e.flashTimer == 0 then
                    e.sprite:setColor(cc.c3b(255, 255, 255))
                end
            end
        end

        ----------------------------------------------------------------
        -- Update bullets: constant velocity + boundary bounce
        ----------------------------------------------------------------
        for _, b in ipairs(demoBullets) do
            b.x = b.x + FM.mul(b.dx, bulletSpeed)
            b.y = b.y + FM.mul(b.dy, bulletSpeed)

            -- Bounce off boundaries
            local r = FM.fromFloat(BULLET_RADIUS)
            if b.x - r < MIN_X then b.x = MIN_X + r; b.dx = FM.abs(b.dx) end
            if b.x + r > MAX_X then b.x = MAX_X - r; b.dx = -FM.abs(b.dx) end
            if b.y - r < MIN_Y then b.y = MIN_Y + r; b.dy = FM.abs(b.dy) end
            if b.y + r > MAX_Y then b.y = MAX_Y - r; b.dy = -FM.abs(b.dy) end

            Shape.setPosition(b.shape, b.x, b.y)

            if b.flashTimer and b.flashTimer > 0 then
                b.flashTimer = b.flashTimer - 1
                if b.flashTimer == 0 then
                    b.sprite:setColor(cc.c3b(255, 255, 255))
                end
            end
        end

        ----------------------------------------------------------------
        -- Run collision detection
        ----------------------------------------------------------------
        local collisions = colSys:step()

        ----------------------------------------------------------------
        -- Apply collision response: push entities apart using MTV
        ----------------------------------------------------------------
        for _, col in ipairs(collisions) do
            local idA, idB, mtvX, mtvY = col[1], col[2], col[3], col[4]
            -- Find the objects
            local objA, objB
            for _, e in ipairs(demoEntities) do
                if e.id == idA then objA = e end
                if e.id == idB then objB = e end
            end
            for _, b in ipairs(demoBullets) do
                if b.id == idA then objA = b end
                if b.id == idB then objB = b end
            end
            -- Push A away from B by MTV
            -- if objA then
            --     objA.x = objA.x + mtvX
            --     objA.y = objA.y + mtvY
            --     Shape.setPosition(objA.shape, objA.x, objA.y)
            -- end
        end

        ----------------------------------------------------------------
        -- Sync sprite rendering positions
        ----------------------------------------------------------------
        for _, e in ipairs(demoEntities) do
            e.sprite:setPosition(FM.toFloat(e.x), FM.toFloat(e.y))
        end
        for _, b in ipairs(demoBullets) do
            b.sprite:setPosition(FM.toFloat(b.x), FM.toFloat(b.y))
        end

        ----------------------------------------------------------------
        -- Update debug label
        ----------------------------------------------------------------
        label:setString(string.format(
            "DetCollision Demo | Frame: %d | Collisions: %d | BP: %s",
            frameCount, #collisions, colSys:getBroadPhaseType()
        ))
    end

    --------------------------------------------------------------------
    -- Register update via scheduler
    --------------------------------------------------------------------
    local schedulerEntry = cc.Director:getInstance():getScheduler():scheduleScriptFunc(
        function(dt) demoUpdate(dt) end, 0, false
    )

    -- Store reference for cleanup
    self._demoScheduler = schedulerEntry
    self._demoLayer = demoLayer
    self._demoColSys = colSys

    print("[DetCollisionDemo] Started: 2 entities, 4 bullets, sweep_and_prune")
end

------------------------------------------------------------------------
-- Stop and cleanup the demo.
------------------------------------------------------------------------
function DetCollisionDemo:stopDetCollisionDemo()
    if self._demoScheduler then
        cc.Director:getInstance():getScheduler():unscheduleScriptEntry(self._demoScheduler)
        self._demoScheduler = nil
    end
    if self._demoLayer then
        self._demoLayer:removeFromParent()
        self._demoLayer = nil
    end
    if self._demoColSys then
        self._demoColSys:clear()
        self._demoColSys = nil
    end
    print("[DetCollisionDemo] Stopped")
end

return DetCollisionDemo