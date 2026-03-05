------------------------------------------------------------------------
-- SAT.lua
-- Separating Axis Theorem narrow-phase collision detection.
-- All math is deterministic fixed-point via FixedMath.
--
-- Supports: Polygon vs Polygon, Circle vs Polygon, Circle vs Circle
-- (Polygon includes AABB, OBB, and arbitrary convex polygon)
--
-- Returns: colliding (bool), mtv_x, mtv_y (minimum translation vector
--          to push shape A out of shape B; fixed-point; nil if not colliding)
------------------------------------------------------------------------

local FixedMath = require("app.collision.DetCollision.FixedMath")
local Shape     = require("app.collision.DetCollision.Shape")

local floor = math.floor
local SCALE = FixedMath.SCALE
local MAXINT = 2^50  -- sentinel "infinity" for overlap comparison

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
-- Check overlap on one axis. Returns overlap amount (positive = overlapping).
-- All projections are in the same scale (SCALE^2 for raw dot products).
------------------------------------------------------------------------
local function getOverlap(minA, maxA, minB, maxB)
    if maxA < minB or maxB < minA then
        return 0  -- separated
    end
    local o1 = maxA - minB
    local o2 = maxB - minA
    if o1 < o2 then return o1 end
    return o2
end

------------------------------------------------------------------------
-- Polygon vs Polygon SAT test.
------------------------------------------------------------------------
local function testPolygonPolygon(shapeA, shapeB)
    local vertsA = Shape.getVertices(shapeA)
    local vertsB = Shape.getVertices(shapeB)
    local normalsA = Shape.getNormals(shapeA)
    local normalsB = Shape.getNormals(shapeB)

    local minOverlap = MAXINT
    local mtvAx, mtvAy = 0, 0

    -- Test all axes from shape A
    for i = 1, #normalsA do
        local ax, ay = normalsA[i][1], normalsA[i][2]
        local minA, maxA = projectVertices(vertsA, ax, ay)
        local minB, maxB = projectVertices(vertsB, ax, ay)
        local overlap = getOverlap(minA, maxA, minB, maxB)
        if overlap <= 0 then
            return false, nil, nil
        end
        if overlap < minOverlap then
            minOverlap = overlap
            mtvAx, mtvAy = ax, ay
        end
    end

    -- Test all axes from shape B
    for i = 1, #normalsB do
        local ax, ay = normalsB[i][1], normalsB[i][2]
        local minA, maxA = projectVertices(vertsA, ax, ay)
        local minB, maxB = projectVertices(vertsB, ax, ay)
        local overlap = getOverlap(minA, maxA, minB, maxB)
        if overlap <= 0 then
            return false, nil, nil
        end
        if overlap < minOverlap then
            minOverlap = overlap
            mtvAx, mtvAy = ax, ay
        end
    end

    -- Compute MTV direction: push A away from B
    -- The MTV axis should point from B's center to A's center
    local dirX = shapeA.cx - shapeB.cx
    local dirY = shapeA.cy - shapeB.cy
    local dirDot = dirX * mtvAx + dirY * mtvAy
    if dirDot < 0 then
        mtvAx = -mtvAx
        mtvAy = -mtvAy
    end

    -- Normalize MTV and scale by overlap.
    -- MTV = normalize(axis) * overlap / |axis|^2 * axis = overlap * axis / |axis|^2
    -- Since overlap is in (axis·vertex) units, and MTV should be in position units:
    -- overlap = projection_overlap (in ax*vx units, i.e. SCALE^2)
    -- MTV_position = overlap / |axis|^2 * axis (converts back to SCALE units)
    local axisLenSq = mtvAx * mtvAx + mtvAy * mtvAy
    if axisLenSq > 0 then
        local mtvX = floor(minOverlap * mtvAx / axisLenSq)
        local mtvY = floor(minOverlap * mtvAy / axisLenSq)
        return true, mtvX, mtvY
    end

    return true, 0, 0
end

------------------------------------------------------------------------
-- Circle vs Circle test.
------------------------------------------------------------------------
local function testCircleCircle(circleA, circleB)
    local dx = circleA.cx - circleB.cx
    local dy = circleA.cy - circleB.cy
    local distSq = dx * dx + dy * dy  -- SCALE^2
    local radSum = circleA.radius + circleB.radius
    local radSumSq = radSum * radSum   -- SCALE^2

    if distSq >= radSumSq then
        return false, nil, nil
    end

    -- Compute MTV
    -- dist = sqrt(distSq), penetration = radSum - dist
    -- direction = (dx, dy) / dist
    if distSq == 0 then
        -- Coincident centers: push along arbitrary axis
        return true, circleA.radius, 0
    end

    -- Integer sqrt of distSq
    local dist = floor(math.sqrt(distSq))
    while dist * dist > distSq do dist = dist - 1 end
    while (dist + 1) * (dist + 1) <= distSq do dist = dist + 1 end

    -- penetration in SCALE units: (radSum - dist/SCALE*SCALE)...
    -- dist is sqrt of SCALE^2 values = SCALE-scale integer.
    -- Actually distSq = (dx_fixed)^2 = SCALE^2 * real_dist^2
    -- so dist = SCALE * real_dist.
    local penetration = radSum - dist  -- both in SCALE units

    -- MTV = direction * penetration = (dx/dist, dy/dist) * penetration
    -- dx is SCALE units, dist is SCALE units, so dx/dist is dimensionless.
    -- MTV = dx * penetration / dist (in SCALE units)
    local mtvX = floor(dx * penetration / dist)
    local mtvY = floor(dy * penetration / dist)

    return true, mtvX, mtvY
end

------------------------------------------------------------------------
-- Circle vs Polygon (AABB/OBB/Polygon) SAT test.
-- Additional axis: circle center to closest vertex.
------------------------------------------------------------------------
local function testCirclePolygon(circle, polygon)
    local verts = Shape.getVertices(polygon)
    local normals = Shape.getNormals(polygon)
    local nVerts = #verts

    local minOverlap = MAXINT
    local mtvAx, mtvAy = 0, 0

    -- Test polygon edge normals
    for i = 1, #normals do
        local ax, ay = normals[i][1], normals[i][2]
        local minA, maxA = projectCircle(circle, ax, ay)
        local minB, maxB = projectVertices(verts, ax, ay)
        local overlap = getOverlap(minA, maxA, minB, maxB)
        if overlap <= 0 then
            return false, nil, nil
        end
        if overlap < minOverlap then
            minOverlap = overlap
            mtvAx, mtvAy = ax, ay
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
        local overlap = getOverlap(minA, maxA, minB, maxB)
        if overlap <= 0 then
            return false, nil, nil
        end
        if overlap < minOverlap then
            minOverlap = overlap
            mtvAx, mtvAy = ax, ay
        end
    end

    -- Direction: push circle away from polygon
    local dirX = circle.cx - polygon.cx
    local dirY = circle.cy - polygon.cy
    local dirDot = dirX * mtvAx + dirY * mtvAy
    if dirDot < 0 then
        mtvAx = -mtvAx
        mtvAy = -mtvAy
    end

    local axisLenSq = mtvAx * mtvAx + mtvAy * mtvAy
    if axisLenSq > 0 then
        local mtvX = floor(minOverlap * mtvAx / axisLenSq)
        local mtvY = floor(minOverlap * mtvAy / axisLenSq)
        return true, mtvX, mtvY
    end

    return true, 0, 0
end

------------------------------------------------------------------------
-- Public API: test collision between two shapes.
-- Returns: colliding, mtvX, mtvY
-- MTV pushes shapeA out of shapeB.
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
        local hit, mx, my = testCirclePolygon(shapeA, shapeB)
        return hit, mx, my
    elseif not isCircleA and isCircleB then
        local hit, mx, my = testCirclePolygon(shapeB, shapeA)
        if hit then
            return true, -mx, -my  -- reverse MTV direction
        end
        return false, nil, nil
    else
        return testPolygonPolygon(shapeA, shapeB)
    end
end

------------------------------------------------------------------------
-- Boolean-only test (faster: skips MTV computation, returns early).
------------------------------------------------------------------------
function SAT.testBool(shapeA, shapeB)
    local tA = shapeA.type
    local tB = shapeB.type
    local TYPE_CIRCLE = Shape.TYPE_CIRCLE

    if tA == TYPE_CIRCLE and tB == TYPE_CIRCLE then
        local dx = shapeA.cx - shapeB.cx
        local dy = shapeA.cy - shapeB.cy
        local distSq = dx * dx + dy * dy
        local radSum = shapeA.radius + shapeB.radius
        return distSq < radSum * radSum
    end

    -- For polygon cases, use full test but discard MTV
    local hit = SAT.test(shapeA, shapeB)
    return hit
end

return SAT
