------------------------------------------------------------------------
-- DetCollisionSystem.lua
-- Deterministic collision detection system for frame-sync games.
-- Combines configurable broad-phase with SAT narrow-phase.
-- All computations use fixed-point math for cross-platform determinism.
--
-- Usage:
--   local sys = DetCollisionSystem.new({
--       broadPhase = "spatial_hash",       -- or "sweep_and_prune" / "quadtree"
--       cellSize   = FM.fromInt(10),       -- for spatial_hash
--       worldBounds = {x, y, w, h},        -- for quadtree (fixed-point)
--   })
--   sys:addBody(id, shape, group, mask)
--   sys:updateBody(id, shape)
--   sys:removeBody(id)
--   local collisions = sys:detect()
--   -- collisions = { {idA, idB}, ... }
------------------------------------------------------------------------

local SpatialHash    = require("app.collision.DetCollision.SpatialHash")
local SweepAndPrune  = require("app.collision.DetCollision.SweepAndPrune")
local Quadtree       = require("app.collision.DetCollision.Quadtree")
local SAT            = require("app.collision.DetCollision.SAT")
local OrderedTable   = require("app.tools.OrderedTable")

local DetCollisionSystem = {}
DetCollisionSystem.__index = DetCollisionSystem

------------------------------------------------------------------------
-- Lua 5.1 compatible bitwise AND (for group/mask filtering).
-- Works for up to 16-bit masks.
------------------------------------------------------------------------
local function bitAnd(a, b)
    local result = 0
    local bitval = 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then
            result = result + bitval
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bitval = bitval * 2
    end
    return result
end

------------------------------------------------------------------------
-- Broad-phase type constants.
------------------------------------------------------------------------
DetCollisionSystem.BP_SPATIAL_HASH    = "spatial_hash"
DetCollisionSystem.BP_SWEEP_AND_PRUNE = "sweep_and_prune"
DetCollisionSystem.BP_QUADTREE        = "quadtree"

------------------------------------------------------------------------
-- Collision groups / masks for filtering.
-- group: which group this body belongs to (bitmask)
-- mask:  which groups this body can collide with (bitmask)
-- Two bodies collide only if (a.group & b.mask) ~= 0 AND (b.group & a.mask) ~= 0
------------------------------------------------------------------------

-- Default groups
DetCollisionSystem.GROUP_DEFAULT  = 1    -- 0x0001
DetCollisionSystem.GROUP_PLAYER   = 2    -- 0x0002
DetCollisionSystem.GROUP_BULLET   = 4    -- 0x0004
DetCollisionSystem.GROUP_WALL     = 8    -- 0x0008
DetCollisionSystem.MASK_ALL       = 0xFFFF

------------------------------------------------------------------------
-- Create the broad-phase backend based on config.
------------------------------------------------------------------------
local function createBroadPhase(config)
    local bpType = config.broadPhase or DetCollisionSystem.BP_SPATIAL_HASH

    if bpType == DetCollisionSystem.BP_SWEEP_AND_PRUNE then
        return SweepAndPrune.new(), bpType
    elseif bpType == DetCollisionSystem.BP_QUADTREE then
        local wb = config.worldBounds
        if not wb then
            error("DetCollisionSystem: quadtree requires 'worldBounds = {x, y, w, h}' in config")
        end
        return Quadtree.new(wb[1], wb[2], wb[3], wb[4]), bpType
    else
        -- Default: spatial hash
        local cellSize = config.cellSize or config[1]
        if not cellSize then
            error("DetCollisionSystem: spatial_hash requires 'cellSize' in config")
        end
        return SpatialHash.new(cellSize), DetCollisionSystem.BP_SPATIAL_HASH
    end
end

------------------------------------------------------------------------
-- Constructor
-- config: table or number (for backwards compatibility).
--   If number: treated as cellSize for spatial_hash (legacy API).
--   If table:
--     broadPhase  = "spatial_hash" | "sweep_and_prune" | "quadtree"
--     cellSize    = fixed-point number (for spatial_hash)
--     worldBounds = {x, y, w, h}   (for quadtree, fixed-point)
------------------------------------------------------------------------
function DetCollisionSystem.new(config)
    local self = setmetatable({}, DetCollisionSystem)

    -- Legacy API: DetCollisionSystem.new(cellSize)
    if type(config) == "number" then
        config = { broadPhase = DetCollisionSystem.BP_SPATIAL_HASH, cellSize = config }
    end

    self.config = config
    self.broadPhase, self.broadPhaseType = createBroadPhase(config)
    self.bodies = OrderedTable:new()  -- id → {shape, group, mask, active}
    self.callbacks = {}    -- list of callback functions
    return self
end

------------------------------------------------------------------------
-- Add a collision body.
------------------------------------------------------------------------
function DetCollisionSystem:addBody(id, shape, group, mask)
    self.bodies:set(id, {
        shape  = shape,
        group  = group or DetCollisionSystem.GROUP_DEFAULT,
        mask   = mask  or DetCollisionSystem.MASK_ALL,
        active = true,
    })
    self.broadPhase:insert(id, shape)
end

------------------------------------------------------------------------
-- Remove a collision body.
------------------------------------------------------------------------
function DetCollisionSystem:removeBody(id)
    self.broadPhase:remove(id)
    self.bodies:remove(id)
end

------------------------------------------------------------------------
-- Update a body's shape (after position/rotation change).
------------------------------------------------------------------------
function DetCollisionSystem:updateBody(id, shape)
    local body = self.bodies:get(id)
    if not body then return end
    body.shape = shape
    self.broadPhase:update(id, shape)
end

------------------------------------------------------------------------
-- Set a body's active state. Inactive bodies are skipped during detection.
------------------------------------------------------------------------
function DetCollisionSystem:setActive(id, active)
    local body = self.bodies:get(id)
    if body then body.active = active end
end

------------------------------------------------------------------------
-- Register a collision callback: function(idA, idB, logicFrameId)
------------------------------------------------------------------------
function DetCollisionSystem:onCollision(callback)
    self.callbacks[#self.callbacks + 1] = callback
end

------------------------------------------------------------------------
-- Clear all callbacks.
------------------------------------------------------------------------
function DetCollisionSystem:clearCallbacks()
    self.callbacks = {}
end

------------------------------------------------------------------------
-- Rebuild the broad-phase from all active bodies.
-- Call this once per logic frame before detect().
------------------------------------------------------------------------
function DetCollisionSystem:rebuild()
    -- For quadtree, we need to recreate with world bounds
    if self.broadPhaseType == DetCollisionSystem.BP_QUADTREE then
        local wb = self.config.worldBounds
        self.broadPhase = Quadtree.new(wb[1], wb[2], wb[3], wb[4])
    else
        self.broadPhase:clear()
    end
    for id, body in self.bodies:pairs() do
        if body.active then
            self.broadPhase:insert(id, body.shape)
        end
    end
end

------------------------------------------------------------------------
-- Run collision detection. Returns a deterministic list of collisions.
-- Each entry: {idA, idB}
--
-- DETERMINISM NOTE: iteration order of pairs() on Lua tables is not
-- guaranteed. To ensure determinism, we collect and sort candidate
-- pairs by their canonical id pair before running narrow-phase.
------------------------------------------------------------------------
function DetCollisionSystem:detect(logicFrameId)
    -- Broad phase: get candidate pairs
    local candidatePairs = self.broadPhase:queryPairs()

    -- Canonicalize each pair: ensure pair[1] < pair[3] (smaller id first).
    -- This guarantees identical ordering regardless of broad-phase type.
    for i = 1, #candidatePairs do
        local pair = candidatePairs[i]
        if pair[1] > pair[3] then
            pair[1], pair[2], pair[3], pair[4] = pair[3], pair[4], pair[1], pair[2]
        end
    end

    -- Sort for deterministic processing order
    table.sort(candidatePairs, function(a, b)
        if a[1] ~= b[1] then return a[1] < b[1] end
        return a[3] < b[3]
    end)

    local collisions = {}
    local bodies = self.bodies

    -- Narrow phase: SAT test each candidate pair
    for i = 1, #candidatePairs do
        local pair = candidatePairs[i]
        local idA, shapeA, idB, shapeB = pair[1], pair[2], pair[3], pair[4]

        local bodyA = bodies:get(idA)
        local bodyB = bodies:get(idB)

        -- Skip inactive or removed bodies
        if bodyA and bodyB and bodyA.active and bodyB.active then
            -- Group/mask filter
            local canCollide = false
            local gA = bodyA.group
            local mB = bodyB.mask
            local gB = bodyB.group
            local mA = bodyA.mask
            if bitAnd(gA, mB) ~= 0 and bitAnd(gB, mA) ~= 0 then
                canCollide = true
            end

            if canCollide then
                local hit = SAT.test(shapeA, shapeB)
                if hit then
                    collisions[#collisions + 1] = { idA, idB }
                end
            end
        end
    end

    -- Fire callbacks
    if #self.callbacks > 0 then
        for i = 1, #collisions do
            local c = collisions[i]
            for j = 1, #self.callbacks do
                self.callbacks[j](c[1], c[2], logicFrameId)
            end
        end
    end

    return collisions
end

------------------------------------------------------------------------
-- Convenience: run a full frame step (rebuild + detect).
------------------------------------------------------------------------
function DetCollisionSystem:step(logicFrameId)
    self:rebuild()
    return self:detect(logicFrameId)
end

------------------------------------------------------------------------
-- Clear everything.
------------------------------------------------------------------------
function DetCollisionSystem:clear()
    self.broadPhase:clear()
    self.bodies:clear()
end

------------------------------------------------------------------------
-- Get count of active bodies (for debug).
------------------------------------------------------------------------
function DetCollisionSystem:getBodyCount()
    local count = 0
    for _, body in self.bodies:pairs() do
        if body.active then count = count + 1 end
    end
    return count
end

------------------------------------------------------------------------
-- Get the current broad-phase type string.
------------------------------------------------------------------------
function DetCollisionSystem:getBroadPhaseType()
    return self.broadPhaseType
end

return DetCollisionSystem
