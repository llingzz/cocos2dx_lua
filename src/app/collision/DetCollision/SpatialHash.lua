------------------------------------------------------------------------
-- SpatialHash.lua
-- Deterministic spatial hash grid for broad-phase collision detection.
-- Uses integer grid cells → naturally deterministic.
------------------------------------------------------------------------

local Shape = require("app.collision.DetCollision.Shape")

local floor = math.floor

local SpatialHash = {}
SpatialHash.__index = SpatialHash

------------------------------------------------------------------------
-- Create a new spatial hash grid.
-- cellSize: fixed-point value representing the width/height of each cell.
--           Should be >= the diameter of the largest object for best results.
------------------------------------------------------------------------
function SpatialHash.new(cellSize)
    local self = setmetatable({}, SpatialHash)
    self.cellSize = cellSize
    self.cells = {}       -- key: "cx,cy" → list of {id, shape}
    self.objectCells = {} -- id → list of cell keys (for fast removal)
    return self
end

-- Hash a fixed-point coordinate to cell index
local function toCell(coord, cellSize)
    -- Floor division (works for negatives too)
    if coord >= 0 then
        return floor(coord / cellSize)
    else
        return -floor((-coord + cellSize - 1) / cellSize)
    end
end

local function cellKey(cx, cy)
    return cx * 1000003 + cy  -- integer hash, no string allocation
end

------------------------------------------------------------------------
-- Clear all objects from the grid.
------------------------------------------------------------------------
function SpatialHash:clear()
    self.cells = {}
    self.objectCells = {}
end

------------------------------------------------------------------------
-- Insert an object (id + shape) into the grid.
-- Object may span multiple cells.
------------------------------------------------------------------------
function SpatialHash:insert(id, shape)
    local cs = self.cellSize
    local minX, minY, maxX, maxY = Shape.getBounds(shape)

    local cellMinX = toCell(minX, cs)
    local cellMinY = toCell(minY, cs)
    local cellMaxX = toCell(maxX, cs)
    local cellMaxY = toCell(maxY, cs)

    local entry = { id = id, shape = shape }
    local keys = {}

    for gx = cellMinX, cellMaxX do
        for gy = cellMinY, cellMaxY do
            local key = cellKey(gx, gy)
            local cell = self.cells[key]
            if not cell then
                cell = {}
                self.cells[key] = cell
            end
            cell[#cell + 1] = entry
            keys[#keys + 1] = key
        end
    end

    self.objectCells[id] = keys
end

------------------------------------------------------------------------
-- Remove an object by id.
------------------------------------------------------------------------
function SpatialHash:remove(id)
    local keys = self.objectCells[id]
    if not keys then return end

    for i = 1, #keys do
        local cell = self.cells[keys[i]]
        if cell then
            for j = #cell, 1, -1 do
                if cell[j].id == id then
                    cell[j] = cell[#cell]
                    cell[#cell] = nil
                    break
                end
            end
        end
    end

    self.objectCells[id] = nil
end

------------------------------------------------------------------------
-- Update an object's position in the grid (remove + re-insert).
------------------------------------------------------------------------
function SpatialHash:update(id, shape)
    self:remove(id)
    self:insert(id, shape)
end

------------------------------------------------------------------------
-- Query all potential collision pairs.
-- Returns a list of {idA, shapeA, idB, shapeB} with no duplicate pairs.
-- Uses a seen-set keyed by ordered id pairs.
------------------------------------------------------------------------
function SpatialHash:queryPairs()
    local pairs_res = {}
    local seen = {}

    for _, cell in pairs(self.cells) do
        local n = #cell
        if n > 1 then
            for i = 1, n - 1 do
                for j = i + 1, n do
                    local a = cell[i]
                    local b = cell[j]
                    local idA, idB = a.id, b.id
                    -- Canonical ordering for dedup
                    local pairKey
                    if idA < idB then
                        --pairKey = idA * 1000000 + idB
                        pairKey = tostring(idA) .. "<" .. tostring(idB)
                    else
                        --pairKey = idB * 1000000 + idA
                        pairKey = tostring(idB) .. "<" .. tostring(idA)
                    end
                    if not seen[pairKey] then
                        seen[pairKey] = true
                        pairs_res[#pairs_res + 1] = { a.id, a.shape, b.id, b.shape }
                    end
                end
            end
        end
    end

    return pairs_res
end

------------------------------------------------------------------------
-- Query objects near a given shape (returns list of {id, shape}).
------------------------------------------------------------------------
function SpatialHash:queryShape(shape)
    local cs = self.cellSize
    local minX, minY, maxX, maxY = Shape.getBounds(shape)

    local cellMinX = toCell(minX, cs)
    local cellMinY = toCell(minY, cs)
    local cellMaxX = toCell(maxX, cs)
    local cellMaxY = toCell(maxY, cs)

    local results = {}
    local seen = {}

    for gx = cellMinX, cellMaxX do
        for gy = cellMinY, cellMaxY do
            local key = cellKey(gx, gy)
            local cell = self.cells[key]
            if cell then
                for i = 1, #cell do
                    local entry = cell[i]
                    if not seen[entry.id] then
                        seen[entry.id] = true
                        results[#results + 1] = entry
                    end
                end
            end
        end
    end

    return results
end

------------------------------------------------------------------------
-- Query objects within an AABB region (fixed-point coordinates).
------------------------------------------------------------------------
function SpatialHash:queryRegion(minX, minY, maxX, maxY)
    local cs = self.cellSize
    local cellMinX = toCell(minX, cs)
    local cellMinY = toCell(minY, cs)
    local cellMaxX = toCell(maxX, cs)
    local cellMaxY = toCell(maxY, cs)

    local results = {}
    local seen = {}

    for gx = cellMinX, cellMaxX do
        for gy = cellMinY, cellMaxY do
            local key = cellKey(gx, gy)
            local cell = self.cells[key]
            if cell then
                for i = 1, #cell do
                    local entry = cell[i]
                    if not seen[entry.id] then
                        seen[entry.id] = true
                        results[#results + 1] = entry
                    end
                end
            end
        end
    end

    return results
end

return SpatialHash
