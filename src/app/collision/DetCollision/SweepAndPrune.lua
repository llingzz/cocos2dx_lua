------------------------------------------------------------------------
-- SweepAndPrune.lua
-- Deterministic AABB sweep-and-prune broad-phase collision detection.
-- Sorts objects by their AABB min-x, then prunes pairs whose
-- x-projections don't overlap before checking y-overlap.
-- All coordinates are fixed-point integers → deterministic.
------------------------------------------------------------------------

local Shape = require("app.collision.DetCollision.Shape")

local SweepAndPrune = {}
SweepAndPrune.__index = SweepAndPrune

------------------------------------------------------------------------
-- Constructor. No special parameters needed.
------------------------------------------------------------------------
function SweepAndPrune.new()
    local self = setmetatable({}, SweepAndPrune)
    self.objects = {}  -- array of {id, shape, minX, minY, maxX, maxY}
    self.idIndex = {}  -- id → index in self.objects
    return self
end

------------------------------------------------------------------------
-- Clear all objects.
------------------------------------------------------------------------
function SweepAndPrune:clear()
    self.objects = {}
    self.idIndex = {}
end

------------------------------------------------------------------------
-- Insert an object.
------------------------------------------------------------------------
function SweepAndPrune:insert(id, shape)
    local minX, minY, maxX, maxY = Shape.getBounds(shape)
    local entry = { id = id, shape = shape, minX = minX, minY = minY, maxX = maxX, maxY = maxY }
    local idx = #self.objects + 1
    self.objects[idx] = entry
    self.idIndex[id] = idx
end

------------------------------------------------------------------------
-- Remove an object by id.
------------------------------------------------------------------------
function SweepAndPrune:remove(id)
    local idx = self.idIndex[id]
    if not idx then return end

    local objs = self.objects
    local n = #objs
    if idx ~= n then
        objs[idx] = objs[n]
        self.idIndex[objs[idx].id] = idx
    end
    objs[n] = nil
    self.idIndex[id] = nil
end

------------------------------------------------------------------------
-- Update an object (remove + re-insert).
------------------------------------------------------------------------
function SweepAndPrune:update(id, shape)
    self:remove(id)
    self:insert(id, shape)
end

------------------------------------------------------------------------
-- Query all potential collision pairs.
-- Algorithm:
--   1. Sort objects by minX (deterministic: tie-break by id).
--   2. Sweep along x-axis: for each object, check forward until
--      the next object's minX > current maxX (no more x-overlap).
--   3. For x-overlapping pairs, also check y-overlap.
-- Returns: list of {idA, shapeA, idB, shapeB}
------------------------------------------------------------------------
function SweepAndPrune:queryPairs()
    local objs = self.objects
    local n = #objs
    if n < 2 then return {} end

    -- Update bounds for all objects
    for i = 1, n do
        local o = objs[i]
        o.minX, o.minY, o.maxX, o.maxY = Shape.getBounds(o.shape)
    end

    -- Sort by minX, tie-break by id for determinism
    table.sort(objs, function(a, b)
        if a.minX ~= b.minX then return a.minX < b.minX end
        return a.id < b.id
    end)

    -- Rebuild idIndex after sort
    for i = 1, n do
        self.idIndex[objs[i].id] = i
    end

    local pairs_res = {}

    -- Sweep
    for i = 1, n - 1 do
        local a = objs[i]
        for j = i + 1, n do
            local b = objs[j]
            -- If b's minX is beyond a's maxX, no more x-overlap possible
            if b.minX > a.maxX then
                break
            end
            -- X overlaps, check Y overlap
            if a.minY <= b.maxY and b.minY <= a.maxY then
                pairs_res[#pairs_res + 1] = { a.id, a.shape, b.id, b.shape }
            end
        end
    end

    return pairs_res
end

return SweepAndPrune
