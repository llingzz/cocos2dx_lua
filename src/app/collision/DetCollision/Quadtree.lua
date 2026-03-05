------------------------------------------------------------------------
-- Quadtree.lua
-- Deterministic quadtree broad-phase collision detection.
-- All coordinates are fixed-point integers → deterministic.
------------------------------------------------------------------------

local Shape = require("app.collision.DetCollision.Shape")

local Quadtree = {}
Quadtree.__index = Quadtree

local MAX_OBJECTS = 8   -- max objects per node before split
local MAX_DEPTH   = 6   -- max tree depth

------------------------------------------------------------------------
-- Constructor.
-- bounds: {x, y, w, h} in fixed-point — the world region this node covers.
--         x,y = top-left corner; w,h = width and height.
-- depth:  current depth (internal, starts at 0).
------------------------------------------------------------------------
function Quadtree.new(x, y, w, h, depth)
    local self = setmetatable({}, Quadtree)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.depth = depth or 0
    self.objects = {}      -- array of {id, shape, minX, minY, maxX, maxY}
    self.children = nil    -- nil until split; then [1..4] = child Quadtrees
    self.allObjects = {}   -- id → entry (flat lookup for remove/update)
    self.isRoot = (self.depth == 0)
    return self
end

------------------------------------------------------------------------
-- Split this node into 4 children.
------------------------------------------------------------------------
local function split(node)
    local hw = math.floor(node.w / 2)
    local hh = math.floor(node.h / 2)
    local x, y = node.x, node.y
    local d = node.depth + 1

    node.children = {
        Quadtree.new(x,      y,      hw, hh, d),  -- top-left
        Quadtree.new(x + hw, y,      hw, hh, d),  -- top-right
        Quadtree.new(x,      y + hh, hw, hh, d),  -- bottom-left
        Quadtree.new(x + hw, y + hh, hw, hh, d),  -- bottom-right
    }
    -- Children share root's allObjects reference
    for i = 1, 4 do
        node.children[i].allObjects = node.allObjects
        node.children[i].isRoot = false
    end
end

------------------------------------------------------------------------
-- Determine which child quadrant(s) an AABB belongs to.
-- Returns indices (1-4) of overlapping children, or nil if no children.
------------------------------------------------------------------------
local function getChildIndices(node, minX, minY, maxX, maxY)
    if not node.children then return nil end

    local midX = node.x + math.floor(node.w / 2)
    local midY = node.y + math.floor(node.h / 2)

    local indices = {}
    -- top-left (1)
    if minX < midX and minY < midY then
        indices[#indices + 1] = 1
    end
    -- top-right (2)
    if maxX > midX and minY < midY then
        indices[#indices + 1] = 2
    end
    -- bottom-left (3)
    if minX < midX and maxY > midY then
        indices[#indices + 1] = 3
    end
    -- bottom-right (4)
    if maxX > midX and maxY > midY then
        indices[#indices + 1] = 4
    end
    return indices
end

------------------------------------------------------------------------
-- Insert an entry into the tree (internal recursive).
------------------------------------------------------------------------
local function insertInto(node, entry)
    if node.children then
        local indices = getChildIndices(node, entry.minX, entry.minY, entry.maxX, entry.maxY)
        if indices and #indices == 1 then
            -- Fits entirely in one child
            insertInto(node.children[indices[1]], entry)
            return
        end
        -- Spans multiple children or none: store in this node
    end

    node.objects[#node.objects + 1] = entry

    -- Split if over capacity and not at max depth
    if #node.objects > MAX_OBJECTS and node.depth < MAX_DEPTH and not node.children then
        split(node)
        -- Re-distribute existing objects
        local old = node.objects
        node.objects = {}
        for i = 1, #old do
            local o = old[i]
            local indices = getChildIndices(node, o.minX, o.minY, o.maxX, o.maxY)
            if indices and #indices == 1 then
                insertInto(node.children[indices[1]], o)
            else
                node.objects[#node.objects + 1] = o
            end
        end
    end
end

------------------------------------------------------------------------
-- Clear all objects.
------------------------------------------------------------------------
function Quadtree:clear()
    self.objects = {}
    self.children = nil
    self.allObjects = {}
end

------------------------------------------------------------------------
-- Insert an object.
------------------------------------------------------------------------
function Quadtree:insert(id, shape)
    local minX, minY, maxX, maxY = Shape.getBounds(shape)
    local entry = { id = id, shape = shape, minX = minX, minY = minY, maxX = maxX, maxY = maxY }
    self.allObjects[id] = entry
    insertInto(self, entry)
end

------------------------------------------------------------------------
-- Remove an object by id.
-- For simplicity, marks as removed; actual cleanup on next rebuild.
------------------------------------------------------------------------
function Quadtree:remove(id)
    local entry = self.allObjects[id]
    if entry then
        entry.removed = true
        self.allObjects[id] = nil
    end
end

------------------------------------------------------------------------
-- Update an object (remove + re-insert).
------------------------------------------------------------------------
function Quadtree:update(id, shape)
    self:remove(id)
    self:insert(id, shape)
end

------------------------------------------------------------------------
-- Collect all entries in a node and its children (recursive).
------------------------------------------------------------------------
local function collectAll(node, result)
    for i = 1, #node.objects do
        local o = node.objects[i]
        if not o.removed then
            result[#result + 1] = o
        end
    end
    if node.children then
        for i = 1, 4 do
            collectAll(node.children[i], result)
        end
    end
end

------------------------------------------------------------------------
-- Collect candidate pairs from a single node: objects in this node
-- can potentially collide with each other AND with objects in all
-- ancestor/same nodes. We collect all objects reachable from this
-- node downward.
------------------------------------------------------------------------
local function queryPairsRecursive(node, inherited, pairs_res, seen)
    -- "inherited" = objects from ancestor nodes that span into this region.
    -- All objects in this node + inherited can collide with each other,
    -- and also with everything in child subtrees.

    local thisObjects = {}
    for i = 1, #node.objects do
        local o = node.objects[i]
        if not o.removed then
            thisObjects[#thisObjects + 1] = o
        end
    end

    -- Check this node's objects against each other
    local nThis = #thisObjects
    for i = 1, nThis - 1 do
        for j = i + 1, nThis do
            local a, b = thisObjects[i], thisObjects[j]
            -- AABB overlap check
            if a.minX <= b.maxX and b.minX <= a.maxX and
               a.minY <= b.maxY and b.minY <= a.maxY then
                local idA, idB = a.id, b.id
                local pairKey
                if idA < idB then
                    pairKey = tostring(idA) .. "<" .. tostring(idB)
                else
                    pairKey = tostring(idB) .. "<" .. tostring(idA)
                end
                if not seen[pairKey] then
                    seen[pairKey] = true
                    pairs_res[#pairs_res + 1] = { a.id, a.shape, b.id, b.shape }
                end
            end
        end
    end

    -- Check this node's objects against inherited objects
    local nInh = #inherited
    for i = 1, nThis do
        for j = 1, nInh do
            local a, b = thisObjects[i], inherited[j]
            if a.minX <= b.maxX and b.minX <= a.maxX and
               a.minY <= b.maxY and b.minY <= a.maxY then
                local idA, idB = a.id, b.id
                local pairKey
                if idA < idB then
                    pairKey = tostring(idA) .. "<" .. tostring(idB)
                else
                    pairKey = tostring(idB) .. "<" .. tostring(idA)
                end
                if not seen[pairKey] then
                    seen[pairKey] = true
                    pairs_res[#pairs_res + 1] = { a.id, a.shape, b.id, b.shape }
                end
            end
        end
    end

    -- Recurse into children with combined inherited list
    if node.children then
        -- Build new inherited = old inherited + this node's objects
        local newInherited = {}
        for i = 1, nInh do
            newInherited[i] = inherited[i]
        end
        for i = 1, nThis do
            newInherited[nInh + i] = thisObjects[i]
        end
        for i = 1, 4 do
            queryPairsRecursive(node.children[i], newInherited, pairs_res, seen)
        end
    end
end

------------------------------------------------------------------------
-- Query all potential collision pairs.
-- Returns: list of {idA, shapeA, idB, shapeB}
------------------------------------------------------------------------
function Quadtree:queryPairs()
    local pairs_res = {}
    local seen = {}
    queryPairsRecursive(self, {}, pairs_res, seen)
    return pairs_res
end

return Quadtree
