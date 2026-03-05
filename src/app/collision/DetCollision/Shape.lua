------------------------------------------------------------------------
-- Shape.lua
-- Deterministic shape definitions for SAT collision detection.
-- All coordinates are in fixed-point (FixedMath.SCALE = 1000).
------------------------------------------------------------------------

local FixedMath = require("app.collision.DetCollision.FixedMath")

local floor = math.floor
local SCALE = FixedMath.SCALE

local Shape = {}
Shape.__index = Shape

------------------------------------------------------------------------
-- Shape types
------------------------------------------------------------------------
Shape.TYPE_CIRCLE  = 1
Shape.TYPE_AABB    = 2
Shape.TYPE_OBB     = 3
Shape.TYPE_POLYGON = 4

------------------------------------------------------------------------
-- Circle
-- Fields: type, cx, cy, radius (all fixed-point)
------------------------------------------------------------------------
function Shape.newCircle(cx, cy, radius)
    return {
        type   = Shape.TYPE_CIRCLE,
        cx     = cx,
        cy     = cy,
        radius = radius,
    }
end

------------------------------------------------------------------------
-- AABB (Axis-Aligned Bounding Box)
-- Fields: type, cx, cy, hw, hh (center + half-extents, all fixed-point)
-- Vertices computed on demand.
------------------------------------------------------------------------
function Shape.newAABB(cx, cy, halfWidth, halfHeight)
    return {
        type = Shape.TYPE_AABB,
        cx   = cx,
        cy   = cy,
        hw   = halfWidth,
        hh   = halfHeight,
    }
end

------------------------------------------------------------------------
-- OBB (Oriented Bounding Box)
-- Stored as center + half-extents + rotation angle (integer degrees).
-- Vertices are computed and cached; call Shape.updateOBB after changing
-- position or angle.
------------------------------------------------------------------------
function Shape.newOBB(cx, cy, halfWidth, halfHeight, angleDeg)
    local obb = {
        type     = Shape.TYPE_OBB,
        cx       = cx,
        cy       = cy,
        hw       = halfWidth,
        hh       = halfHeight,
        angle    = angleDeg or 0,
        vertices = nil,  -- computed by updateOBB
        normals  = nil,
    }
    Shape.updateOBB(obb)
    return obb
end

function Shape.updateOBB(obb)
    local cx, cy = obb.cx, obb.cy
    local hw, hh = obb.hw, obb.hh
    local deg    = obb.angle

    -- Local-space corners (before rotation)
    local corners = {
        {-hw, -hh},
        { hw, -hh},
        { hw,  hh},
        {-hw,  hh},
    }

    local verts = {}
    for i = 1, 4 do
        local lx, ly = corners[i][1], corners[i][2]
        local rx, ry = FixedMath.rotate(lx, ly, deg)
        verts[i] = { cx + rx, cy + ry }
    end
    obb.vertices = verts

    -- Edge normals (perpendicular to each edge, only 2 unique axes for a box)
    local normals = {}
    for i = 1, 4 do
        local j = (i % 4) + 1
        local ex = verts[j][1] - verts[i][1]
        local ey = verts[j][2] - verts[i][2]
        -- Normal: (-ey, ex) — no need to normalize for SAT overlap test
        normals[i] = { -ey, ex }
    end
    obb.normals = normals
end

------------------------------------------------------------------------
-- Convex Polygon
-- vertices: array of {x, y} in fixed-point, counter-clockwise order.
-- Normals computed from edges.
------------------------------------------------------------------------
function Shape.newPolygon(vertices)
    local poly = {
        type     = Shape.TYPE_POLYGON,
        cx       = 0,
        cy       = 0,
        vertices = {},
        normals  = {},
    }

    local n = #vertices
    local sumX, sumY = 0, 0
    for i = 1, n do
        poly.vertices[i] = { vertices[i][1], vertices[i][2] }
        sumX = sumX + vertices[i][1]
        sumY = sumY + vertices[i][2]
    end
    poly.cx = floor(sumX / n)
    poly.cy = floor(sumY / n)

    -- Compute edge normals
    for i = 1, n do
        local j = (i % n) + 1
        local ex = poly.vertices[j][1] - poly.vertices[i][1]
        local ey = poly.vertices[j][2] - poly.vertices[i][2]
        poly.normals[i] = { -ey, ex }
    end

    return poly
end

------------------------------------------------------------------------
-- Move shape by (dx, dy) in fixed-point.
------------------------------------------------------------------------
function Shape.translate(shape, dx, dy)
    local t = shape.type
    if t == Shape.TYPE_CIRCLE or t == Shape.TYPE_AABB then
        shape.cx = shape.cx + dx
        shape.cy = shape.cy + dy
    elseif t == Shape.TYPE_OBB then
        shape.cx = shape.cx + dx
        shape.cy = shape.cy + dy
        Shape.updateOBB(shape)
    elseif t == Shape.TYPE_POLYGON then
        shape.cx = shape.cx + dx
        shape.cy = shape.cy + dy
        for i = 1, #shape.vertices do
            shape.vertices[i][1] = shape.vertices[i][1] + dx
            shape.vertices[i][2] = shape.vertices[i][2] + dy
        end
        -- Normals are direction vectors, not affected by translation
    end
end

------------------------------------------------------------------------
-- Set position of shape center.
------------------------------------------------------------------------
function Shape.setPosition(shape, x, y)
    local dx = x - shape.cx
    local dy = y - shape.cy
    Shape.translate(shape, dx, dy)
end

------------------------------------------------------------------------
-- Set rotation for OBB (integer degrees).
------------------------------------------------------------------------
function Shape.setRotation(shape, angleDeg)
    if shape.type == Shape.TYPE_OBB then
        shape.angle = angleDeg
        Shape.updateOBB(shape)
    end
end

------------------------------------------------------------------------
-- Get AABB bounds for broad-phase (returns minX, minY, maxX, maxY).
------------------------------------------------------------------------
function Shape.getBounds(shape)
    local t = shape.type
    if t == Shape.TYPE_CIRCLE then
        return shape.cx - shape.radius, shape.cy - shape.radius,
               shape.cx + shape.radius, shape.cy + shape.radius
    elseif t == Shape.TYPE_AABB then
        return shape.cx - shape.hw, shape.cy - shape.hh,
               shape.cx + shape.hw, shape.cy + shape.hh
    elseif t == Shape.TYPE_OBB or t == Shape.TYPE_POLYGON then
        local verts = shape.vertices
        local minX, minY = verts[1][1], verts[1][2]
        local maxX, maxY = minX, minY
        for i = 2, #verts do
            local vx, vy = verts[i][1], verts[i][2]
            if vx < minX then minX = vx end
            if vx > maxX then maxX = vx end
            if vy < minY then minY = vy end
            if vy > maxY then maxY = vy end
        end
        return minX, minY, maxX, maxY
    end
    return 0, 0, 0, 0
end

------------------------------------------------------------------------
-- Get vertices for polygon-like shapes (used by SAT).
-- Circle returns nil (handled separately).
------------------------------------------------------------------------
function Shape.getVertices(shape)
    local t = shape.type
    if t == Shape.TYPE_AABB then
        local cx, cy = shape.cx, shape.cy
        local hw, hh = shape.hw, shape.hh
        return {
            { cx - hw, cy - hh },
            { cx + hw, cy - hh },
            { cx + hw, cy + hh },
            { cx - hw, cy + hh },
        }
    elseif t == Shape.TYPE_OBB or t == Shape.TYPE_POLYGON then
        return shape.vertices
    end
    return nil
end

------------------------------------------------------------------------
-- Get candidate separation axes for SAT (edge normals).
-- For AABB, only x and y axes are needed.
------------------------------------------------------------------------
function Shape.getNormals(shape)
    local t = shape.type
    if t == Shape.TYPE_AABB then
        -- Axis-aligned: x-axis and y-axis normals
        return {
            { SCALE, 0 },
            { 0, SCALE },
        }
    elseif t == Shape.TYPE_OBB or t == Shape.TYPE_POLYGON then
        return shape.normals
    end
    return nil
end

return Shape
