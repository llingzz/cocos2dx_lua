------------------------------------------------------------------------
-- SAT.lua
-- Separating Axis Theorem narrow-phase collision detection.
-- All math is deterministic fixed-point via FixedMath.
--
-- Supports: Polygon vs Polygon, Circle vs Polygon, Circle vs Circle
-- (Polygon includes AABB, OBB, and arbitrary convex polygon)
--
-- Returns: colliding (bool)
------------------------------------------------------------------------

local Shape = require("app.collision.DetCollision.Shape")

local MAXINT = 2^50  -- sentinel "infinity" for closest-vertex search

local SAT = {}

------------------------------------------------------------------------
-- Project all vertices onto axis (ax, ay) (not normalized).
-- Returns min, max of dot products.
------------------------------------------------------------------------
local function projectVertices(vertices, ax, ay)
    local d = vertices[1][1] * ax + vertices[1][2] * ay  -- no /SCALE needed for comparison
    local pmin, pmax = d, d
    for i = 2, #vertices do
        d = vertices[i][1] * ax + vertices[i][2] * ay
        if d < pmin then pmin = d end
        if d > pmax then pmax = d end
    end
    return pmin, pmax
end

------------------------------------------------------------------------
-- Project a circle onto an axis.
-- Circle center projected ± radius * axisLength.
-- Since axis is not normalized, radius projection = radius * length(axis).
-- To avoid sqrt, we scale: proj = center·axis ± radius * |axis|.
-- But |axis| requires sqrt. Instead we project center and offset by
-- radius * |axis|. We can compute |axis|^2 and compare squared overlaps...
--
-- Actually, for uniform comparison we need the offset in the same units.
-- We'll compute axisLenSq = ax*ax + ay*ay, and project everything
-- multiplied by axisLen (defer sqrt). But that complicates overlap
-- computation.
--
-- Simpler approach: compute axisLen via FixedMath.sqrt for circle cases
-- only. Circle tests are less frequent and sqrt is O(1) with few iterations.
------------------------------------------------------------------------
local function projectCircle(shape, ax, ay)
    -- ax, ay are in fixed-point scale
    -- center dot axis (result in SCALE^2, but we keep raw for comparison)
    local centerProj = shape.cx * ax + shape.cy * ay
    -- axis length in fixed scale: sqrt((ax*ax+ay*ay)/SCALE) ... but we need
    -- the raw axis length to scale the radius projection correctly.
    -- |axis| in raw units: sqrt(ax*ax + ay*ay), where ax,ay are in SCALE units.
    -- radius projection = radius * |axis| (both in SCALE), result in SCALE^2.
    -- This matches centerProj units (SCALE^2) since center coords are in SCALE.

    local axisLenRaw = ax * ax + ay * ay  -- in SCALE^2
    -- We need sqrt of this in integer space
    local axisLen = 0
    if axisLenRaw > 0 then
        -- integer sqrt
        local x = floor(math.sqrt(axisLenRaw))
        while x * x > axisLenRaw do x = x - 1 end
        while (x + 1) * (x + 1) <= axisLenRaw do x = x + 1 end
        axisLen = x
    end

    local offset = shape.radius * axisLen  -- SCALE * integer = SCALE-ish
    -- But centerProj is in SCALE*SCALE... we need consistent units.
    -- Let's keep everything in SCALE^2 space for projection comparison:
    -- offset should also be in SCALE^2 units.
    -- radius is SCALE units, axisLen is integer sqrt of SCALE^2 = SCALE units.
    -- So offset = radius * axisLen = SCALE * SCALE = SCALE^2. Correct!

    return centerProj - offset, centerProj + offset
end

------------------------------------------------------------------------
-- Polygon vs Polygon SAT test.
------------------------------------------------------------------------
local function testPolygonPolygon(shapeA, shapeB)
    local vertsA = Shape.getVertices(shapeA)
    local vertsB = Shape.getVertices(shapeB)
    local normalsA = Shape.getNormals(shapeA)
    local normalsB = Shape.getNormals(shapeB)

    -- Test all axes from shape A
    for i = 1, #normalsA do
        local ax, ay = normalsA[i][1], normalsA[i][2]
        local minA, maxA = projectVertices(vertsA, ax, ay)
        local minB, maxB = projectVertices(vertsB, ax, ay)
        if maxA < minB or maxB < minA then
            return false
        end
    end

    -- Test all axes from shape B
    for i = 1, #normalsB do
        local ax, ay = normalsB[i][1], normalsB[i][2]
        local minA, maxA = projectVertices(vertsA, ax, ay)
        local minB, maxB = projectVertices(vertsB, ax, ay)
        if maxA < minB or maxB < minA then
            return false
        end
    end

    return true
end

------------------------------------------------------------------------
-- Circle vs Circle test.
------------------------------------------------------------------------
local function testCircleCircle(circleA, circleB)
    local dx = circleA.cx - circleB.cx
    local dy = circleA.cy - circleB.cy
    local distSq = dx * dx + dy * dy  -- SCALE^2
    local radSum = circleA.radius + circleB.radius
    return distSq < radSum * radSum
end

------------------------------------------------------------------------
-- Circle vs Polygon (AABB/OBB/Polygon) SAT test.
-- Additional axis: circle center to closest vertex.
------------------------------------------------------------------------
local function testCirclePolygon(circle, polygon)
    local verts = Shape.getVertices(polygon)
    local normals = Shape.getNormals(polygon)
    local nVerts = #verts

    -- Test polygon edge normals
    for i = 1, #normals do
        local ax, ay = normals[i][1], normals[i][2]
        local minA, maxA = projectCircle(circle, ax, ay)
        local minB, maxB = projectVertices(verts, ax, ay)
        if maxA < minB or maxB < minA then
            return false
        end
    end

    -- Find closest vertex to circle center
    local closestDistSq = MAXINT
    local closestVx, closestVy = verts[1][1], verts[1][2]
    for i = 1, nVerts do
        local vx, vy = verts[i][1], verts[i][2]
        local ddx = vx - circle.cx
        local ddy = vy - circle.cy
        local dsq = ddx * ddx + ddy * ddy
        if dsq < closestDistSq then
            closestDistSq = dsq
            closestVx = vx
            closestVy = vy
        end
    end

    -- Test axis from circle center to closest vertex
    local ax = closestVx - circle.cx
    local ay = closestVy - circle.cy
    if ax ~= 0 or ay ~= 0 then
        local minA, maxA = projectCircle(circle, ax, ay)
        local minB, maxB = projectVertices(verts, ax, ay)
        if maxA < minB or maxB < minA then
            return false
        end
    end

    return true
end

------------------------------------------------------------------------
-- Public API: test collision between two shapes.
-- Returns: colliding (bool)
------------------------------------------------------------------------
function SAT.test(shapeA, shapeB)
    local tA = shapeA.type
    local tB = shapeB.type
    local TYPE_CIRCLE = Shape.TYPE_CIRCLE

    local isCircleA = (tA == TYPE_CIRCLE)
    local isCircleB = (tB == TYPE_CIRCLE)

    if isCircleA and isCircleB then
        return testCircleCircle(shapeA, shapeB)
    elseif isCircleA and not isCircleB then
        return testCirclePolygon(shapeA, shapeB)
    elseif not isCircleA and isCircleB then
        -- Swap: test polygon vs circle with args reversed (order doesn't matter for boolean)
        return testCirclePolygon(shapeB, shapeA)
    else
        return testPolygonPolygon(shapeA, shapeB)
    end
end

------------------------------------------------------------------------
-- Boolean-only test (delegates to SAT.test, which is now boolean-only).
------------------------------------------------------------------------
function SAT.testBool(shapeA, shapeB)
    return SAT.test(shapeA, shapeB)
end

return SAT
