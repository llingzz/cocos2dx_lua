------------------------------------------------------------------------
-- test_det_collision.lua
-- Unit tests for the deterministic collision detection system.
-- Run: lua test_det_collision.lua (from the src directory)
------------------------------------------------------------------------

-- Adjust package path for running from src/
package.path = package.path .. ";./?.lua;./?/init.lua"

local FixedMath      = require("app.collision.DetCollision.FixedMath")
local Shape          = require("app.collision.DetCollision.Shape")
local SAT            = require("app.collision.DetCollision.SAT")
local SpatialHash    = require("app.collision.DetCollision.SpatialHash")
local SweepAndPrune  = require("app.collision.DetCollision.SweepAndPrune")
local Quadtree       = require("app.collision.DetCollision.Quadtree")
local System         = require("app.collision.DetCollision.DetCollisionSystem")

local FM = FixedMath
local passed, failed = 0, 0

local function assert_eq(a, b, msg)
    if a == b then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s (expected %s, got %s)", msg or "?", tostring(b), tostring(a)))
    end
end

local function assert_true(v, msg)
    if v then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s (expected true)", msg or "?"))
    end
end

local function assert_false(v, msg)
    if not v then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s (expected false)", msg or "?"))
    end
end

local function section(name)
    print(string.format("\n=== %s ===", name))
end

------------------------------------------------------------------------
section("FixedMath basics")
------------------------------------------------------------------------

assert_eq(FM.fromFloat(1.5), 1500, "fromFloat 1.5")
assert_eq(FM.fromFloat(-2.3), -2300, "fromFloat -2.3")
assert_eq(FM.fromInt(5), 5000, "fromInt 5")
assert_eq(FM.toFloat(2500), 2.5, "toFloat 2500")

assert_eq(FM.add(1000, 2000), 3000, "add 1+2=3")
assert_eq(FM.sub(3000, 1000), 2000, "sub 3-1=2")
assert_eq(FM.mul(2000, 3000), 6000, "mul 2*3=6")
assert_eq(FM.mul(1500, 2000), 3000, "mul 1.5*2=3")
assert_eq(FM.mul(-1500, 2000), -3000, "mul -1.5*2=-3")
assert_eq(FM.div(6000, 2000), 3000, "div 6/2=3")
assert_eq(FM.div(3000, 2000), 1500, "div 3/2=1.5")

assert_eq(FM.abs(-5000), 5000, "abs(-5)")
assert_eq(FM.min(3000, 5000), 3000, "min(3,5)")
assert_eq(FM.max(3000, 5000), 5000, "max(3,5)")
assert_eq(FM.clamp(7000, 1000, 5000), 5000, "clamp 7 to [1,5]")

------------------------------------------------------------------------
section("FixedMath sqrt")
------------------------------------------------------------------------

assert_eq(FM.sqrt(4000), 2000, "sqrt(4)=2")
assert_eq(FM.sqrt(1000), 1000, "sqrt(1)=1")
assert_eq(FM.sqrt(0), 0, "sqrt(0)=0")
-- sqrt(2) ≈ 1.414, fixed = 1414
assert_eq(FM.sqrt(2000), 1414, "sqrt(2)≈1.414")
-- sqrt(9) = 3
assert_eq(FM.sqrt(9000), 3000, "sqrt(9)=3")

------------------------------------------------------------------------
section("FixedMath dot/cross")
------------------------------------------------------------------------

-- dot((1,0),(0,1)) = 0
assert_eq(FM.dot(1000, 0, 0, 1000), 0, "dot perpendicular=0")
-- dot((1,0),(1,0)) = 1
assert_eq(FM.dot(1000, 0, 1000, 0), 1000, "dot parallel=1")
-- dot((3,4),(4,-3)) = 12-12 = 0
assert_eq(FM.dot(3000, 4000, 4000, -3000), 0, "dot (3,4)·(4,-3)=0")
-- cross((1,0),(0,1)) = 1
assert_eq(FM.cross(1000, 0, 0, 1000), 1000, "cross (1,0)x(0,1)=1")

------------------------------------------------------------------------
section("FixedMath trig lookup")
------------------------------------------------------------------------

assert_eq(FM.sinDeg(0), 0, "sin(0)=0")
assert_eq(FM.cosDeg(0), 1000, "cos(0)=1")
assert_eq(FM.sinDeg(90), 1000, "sin(90)=1")
assert_eq(FM.cosDeg(90), 0, "cos(90)=0")
assert_eq(FM.sinDeg(180), 0, "sin(180)=0")
assert_eq(FM.cosDeg(180), -1000, "cos(180)=-1")
assert_eq(FM.sinDeg(270), -1000, "sin(270)=-1")

------------------------------------------------------------------------
section("FixedMath rotate")
------------------------------------------------------------------------

-- Rotate (1,0) by 90 degrees → (0,1)
local rx, ry = FM.rotate(1000, 0, 90)
assert_eq(rx, 0, "rotate(1,0) by 90: x=0")
assert_eq(ry, 1000, "rotate(1,0) by 90: y=1")

-- Rotate (1,0) by 180 degrees → (-1,0)
rx, ry = FM.rotate(1000, 0, 180)
assert_eq(rx, -1000, "rotate(1,0) by 180: x=-1")
assert_eq(ry, 0, "rotate(1,0) by 180: y=0")

------------------------------------------------------------------------
section("FixedMath determinism")
------------------------------------------------------------------------

-- Verify that running the same operations many times gives identical results
local function deterministicTest()
    local accum = FM.fromInt(1)
    for i = 1, 100 do
        accum = FM.mul(accum, FM.fromFloat(1.01))
        accum = FM.add(accum, FM.fromFloat(0.001))
        local s = FM.sqrt(FM.abs(accum))
        accum = FM.sub(accum, FM.div(s, FM.fromInt(10)))
    end
    return accum
end

local r1 = deterministicTest()
local r2 = deterministicTest()
assert_eq(r1, r2, "determinism: repeated runs produce same result")

------------------------------------------------------------------------
section("Shape creation")
------------------------------------------------------------------------

local circle = Shape.newCircle(FM.fromInt(5), FM.fromInt(5), FM.fromInt(2))
assert_eq(circle.type, Shape.TYPE_CIRCLE, "circle type")
assert_eq(circle.cx, 5000, "circle cx")
assert_eq(circle.radius, 2000, "circle radius")

local aabb = Shape.newAABB(FM.fromInt(0), FM.fromInt(0), FM.fromInt(2), FM.fromInt(3))
assert_eq(aabb.type, Shape.TYPE_AABB, "aabb type")

local obb = Shape.newOBB(FM.fromInt(0), FM.fromInt(0), FM.fromInt(2), FM.fromInt(1), 45)
assert_eq(obb.type, Shape.TYPE_OBB, "obb type")
assert_true(obb.vertices ~= nil, "obb has vertices")
assert_eq(#obb.vertices, 4, "obb has 4 vertices")

local poly = Shape.newPolygon({
    {FM.fromInt(0), FM.fromInt(0)},
    {FM.fromInt(4), FM.fromInt(0)},
    {FM.fromInt(4), FM.fromInt(3)},
    {FM.fromInt(0), FM.fromInt(3)},
})
assert_eq(poly.type, Shape.TYPE_POLYGON, "polygon type")
assert_eq(#poly.vertices, 4, "polygon has 4 vertices")

------------------------------------------------------------------------
section("Shape bounds")
------------------------------------------------------------------------

local bMinX, bMinY, bMaxX, bMaxY = Shape.getBounds(circle)
assert_eq(bMinX, 3000, "circle bounds minX")
assert_eq(bMaxX, 7000, "circle bounds maxX")

bMinX, bMinY, bMaxX, bMaxY = Shape.getBounds(aabb)
assert_eq(bMinX, -2000, "aabb bounds minX")
assert_eq(bMaxX, 2000, "aabb bounds maxX")
assert_eq(bMinY, -3000, "aabb bounds minY")
assert_eq(bMaxY, 3000, "aabb bounds maxY")

------------------------------------------------------------------------
section("Shape translate/setPosition")
------------------------------------------------------------------------

local c2 = Shape.newCircle(0, 0, 1000)
Shape.translate(c2, 3000, 4000)
assert_eq(c2.cx, 3000, "translated circle cx")
assert_eq(c2.cy, 4000, "translated circle cy")

Shape.setPosition(c2, 10000, 20000)
assert_eq(c2.cx, 10000, "setPosition circle cx")
assert_eq(c2.cy, 20000, "setPosition circle cy")

------------------------------------------------------------------------
section("SAT: AABB vs AABB")
------------------------------------------------------------------------

-- Two overlapping AABBs
local aabb1 = Shape.newAABB(0, 0, 2000, 2000)         -- [-2, 2] x [-2, 2]
local aabb2 = Shape.newAABB(3000, 0, 2000, 2000)       -- [1, 5] x [-2, 2]  → overlap on x by 1
local hit, mtvX, mtvY = SAT.test(aabb1, aabb2)
assert_true(hit, "aabb overlap detected")
-- MTV should push aabb1 left (negative x)
assert_true(mtvX ~= nil, "mtv not nil on overlap")
print(string.format("  MTV: (%d, %d) → (%.3f, %.3f)", mtvX, mtvY, mtvX/1000, mtvY/1000))

-- Two separated AABBs
local aabb3 = Shape.newAABB(10000, 0, 2000, 2000)      -- [8, 12] x [-2, 2]
hit = SAT.test(aabb1, aabb3)
assert_false(hit, "aabb no overlap")

-- Edge-touching AABBs (exactly touching = not overlapping in strict SAT)
local aabb4 = Shape.newAABB(4000, 0, 2000, 2000)       -- [2, 6] x [-2, 2]
hit = SAT.test(aabb1, aabb4)
assert_false(hit, "aabb edge-touch = no overlap")

------------------------------------------------------------------------
section("SAT: Circle vs Circle")
------------------------------------------------------------------------

local c_a = Shape.newCircle(0, 0, 2000)
local c_b = Shape.newCircle(3000, 0, 2000)  -- dist=3, r1+r2=4, overlap=1

hit, mtvX, mtvY = SAT.test(c_a, c_b)
assert_true(hit, "circle overlap detected")
print(string.format("  MTV: (%d, %d) → (%.3f, %.3f)", mtvX, mtvY, mtvX/1000, mtvY/1000))
-- MTV should be roughly (-1, 0)
assert_true(mtvX < 0, "circle mtv pushes left")

-- No overlap
local c_c = Shape.newCircle(10000, 0, 2000)
hit = SAT.test(c_a, c_c)
assert_false(hit, "circle no overlap")

------------------------------------------------------------------------
section("SAT: Circle vs AABB")
------------------------------------------------------------------------

local circle2 = Shape.newCircle(3500, 0, 2000)
local aabb5 = Shape.newAABB(0, 0, 2000, 2000)

hit, mtvX, mtvY = SAT.test(circle2, aabb5)
assert_true(hit, "circle vs aabb overlap")
print(string.format("  MTV: (%d, %d) → (%.3f, %.3f)", mtvX, mtvY, mtvX/1000, mtvY/1000))

-- Circle far away
local circle3 = Shape.newCircle(20000, 0, 2000)
hit = SAT.test(circle3, aabb5)
assert_false(hit, "circle vs aabb no overlap")

------------------------------------------------------------------------
section("SAT: OBB vs AABB")
------------------------------------------------------------------------

-- OBB rotated 45 degrees at origin, vs AABB nearby
local obb1 = Shape.newOBB(0, 0, 2000, 1000, 45)
local aabb6 = Shape.newAABB(2000, 0, 1000, 1000)

hit, mtvX, mtvY = SAT.test(obb1, aabb6)
-- Depending on exact geometry, may or may not overlap
print(string.format("  OBB(45) vs AABB(2,0): colliding=%s", tostring(hit)))
if hit then
    print(string.format("  MTV: (%d, %d) → (%.3f, %.3f)", mtvX, mtvY, mtvX/1000, mtvY/1000))
end

-- OBB not rotated should behave like AABB
local obb2 = Shape.newOBB(0, 0, 2000, 2000, 0)
local aabb7 = Shape.newAABB(3000, 0, 2000, 2000)
hit = SAT.test(obb2, aabb7)
assert_true(hit, "obb(0deg) vs aabb overlap (same as aabb vs aabb)")

------------------------------------------------------------------------
section("SAT: Polygon vs Polygon")
------------------------------------------------------------------------

-- Triangle vs square
local tri = Shape.newPolygon({
    {0, 0},
    {4000, 0},
    {2000, 3000},
})
local sq = Shape.newPolygon({
    {1000, -1000},
    {3000, -1000},
    {3000, 1000},
    {1000, 1000},
})

hit, mtvX, mtvY = SAT.test(tri, sq)
assert_true(hit, "triangle vs square overlap")
print(string.format("  MTV: (%d, %d) → (%.3f, %.3f)", mtvX, mtvY, mtvX/1000, mtvY/1000))

------------------------------------------------------------------------
section("SAT: Boolean-only test")
------------------------------------------------------------------------

assert_true(SAT.testBool(c_a, c_b), "testBool circle overlap")
assert_false(SAT.testBool(c_a, c_c), "testBool circle no overlap")

------------------------------------------------------------------------
section("SpatialHash")
------------------------------------------------------------------------

local sh = SpatialHash.new(5000)  -- 5-unit cells

local sh_a = Shape.newAABB(0, 0, 1000, 1000)
local sh_b = Shape.newAABB(1000, 0, 1000, 1000)
local sh_c = Shape.newAABB(50000, 50000, 1000, 1000)  -- far away

sh:insert(1, sh_a)
sh:insert(2, sh_b)
sh:insert(3, sh_c)

local pairs_list = sh:queryPairs()
-- Should find pair (1,2) but not (1,3) or (2,3)
local foundPair12 = false
local foundPair13 = false
for _, p in ipairs(pairs_list) do
    local a, b = p[1], p[3]
    if (a == 1 and b == 2) or (a == 2 and b == 1) then foundPair12 = true end
    if (a == 1 and b == 3) or (a == 3 and b == 1) then foundPair13 = true end
end
assert_true(foundPair12, "spatial hash finds nearby pair")
assert_false(foundPair13, "spatial hash skips distant pair")

-- Test removal
sh:remove(2)
pairs_list = sh:queryPairs()
foundPair12 = false
for _, p in ipairs(pairs_list) do
    local a, b = p[1], p[3]
    if (a == 1 and b == 2) or (a == 2 and b == 1) then foundPair12 = true end
end
assert_false(foundPair12, "after remove, pair gone")

------------------------------------------------------------------------
section("SweepAndPrune")
------------------------------------------------------------------------

local sap = SweepAndPrune.new()

local sap_a = Shape.newAABB(0, 0, 1000, 1000)
local sap_b = Shape.newAABB(1000, 0, 1000, 1000)
local sap_c = Shape.newAABB(50000, 50000, 1000, 1000)  -- far away

sap:insert(1, sap_a)
sap:insert(2, sap_b)
sap:insert(3, sap_c)

pairs_list = sap:queryPairs()
foundPair12 = false
foundPair13 = false
for _, p in ipairs(pairs_list) do
    local a, b = p[1], p[3]
    if (a == 1 and b == 2) or (a == 2 and b == 1) then foundPair12 = true end
    if (a == 1 and b == 3) or (a == 3 and b == 1) then foundPair13 = true end
end
assert_true(foundPair12, "sweep-and-prune finds nearby pair")
assert_false(foundPair13, "sweep-and-prune skips distant pair")

-- Test removal
sap:remove(2)
pairs_list = sap:queryPairs()
foundPair12 = false
for _, p in ipairs(pairs_list) do
    local a, b = p[1], p[3]
    if (a == 1 and b == 2) or (a == 2 and b == 1) then foundPair12 = true end
end
assert_false(foundPair12, "sweep-and-prune after remove, pair gone")

-- Test update
sap:insert(4, Shape.newAABB(100000, 0, 1000, 1000))  -- far away
sap:update(4, Shape.newAABB(500, 0, 1000, 1000))     -- moved near id=1
pairs_list = sap:queryPairs()
local foundPair14 = false
for _, p in ipairs(pairs_list) do
    local a, b = p[1], p[3]
    if (a == 1 and b == 4) or (a == 4 and b == 1) then foundPair14 = true end
end
assert_true(foundPair14, "sweep-and-prune finds pair after update")

------------------------------------------------------------------------
section("Quadtree")
------------------------------------------------------------------------

-- World bounds: [-100, -100] to [100, 100] in fixed-point
local qt = Quadtree.new(FM.fromInt(-100), FM.fromInt(-100), FM.fromInt(200), FM.fromInt(200))

local qt_a = Shape.newAABB(0, 0, 1000, 1000)
local qt_b = Shape.newAABB(1000, 0, 1000, 1000)
local qt_c = Shape.newAABB(50000, 50000, 1000, 1000)  -- far away

qt:insert(1, qt_a)
qt:insert(2, qt_b)
qt:insert(3, qt_c)

pairs_list = qt:queryPairs()
foundPair12 = false
foundPair13 = false
for _, p in ipairs(pairs_list) do
    local a, b = p[1], p[3]
    if (a == 1 and b == 2) or (a == 2 and b == 1) then foundPair12 = true end
    if (a == 1 and b == 3) or (a == 3 and b == 1) then foundPair13 = true end
end
assert_true(foundPair12, "quadtree finds nearby pair")
assert_false(foundPair13, "quadtree skips distant pair")

-- Test removal
qt:remove(2)
pairs_list = qt:queryPairs()
foundPair12 = false
for _, p in ipairs(pairs_list) do
    local a, b = p[1], p[3]
    if (a == 1 and b == 2) or (a == 2 and b == 1) then foundPair12 = true end
end
assert_false(foundPair12, "quadtree after remove, pair gone")

-- Test with many objects (trigger splits)
qt:clear()
for i = 1, 20 do
    local x = FM.fromInt((i % 5) * 3)
    local y = FM.fromInt(math.floor(i / 5) * 3)
    qt:insert(i, Shape.newCircle(x, y, FM.fromInt(2)))
end
pairs_list = qt:queryPairs()
assert_true(#pairs_list > 0, "quadtree finds pairs among 20 objects")
print(string.format("  Quadtree: 20 objects → %d candidate pairs", #pairs_list))

------------------------------------------------------------------------
-- Helper: create a System with a given broad-phase type.
------------------------------------------------------------------------
local function createSystem(bpType)
    if bpType == "spatial_hash" then
        return System.new({ broadPhase = bpType, cellSize = FM.fromInt(10) })
    elseif bpType == "sweep_and_prune" then
        return System.new({ broadPhase = bpType })
    elseif bpType == "quadtree" then
        return System.new({
            broadPhase  = bpType,
            worldBounds = { FM.fromInt(-200), FM.fromInt(-200), FM.fromInt(400), FM.fromInt(400) },
        })
    end
end

------------------------------------------------------------------------
-- Run System integration tests for each broad-phase type.
------------------------------------------------------------------------
local bpTypes = { "spatial_hash", "sweep_and_prune", "quadtree" }

for _, bpType in ipairs(bpTypes) do

    section("DetCollisionSystem [" .. bpType .. "]")

    local sys = createSystem(bpType)
    assert_eq(sys:getBroadPhaseType(), bpType, bpType .. ": broad-phase type matches")

    -- Player and bullet
    local player = Shape.newCircle(FM.fromInt(5), FM.fromInt(5), FM.fromInt(2))
    local bullet = Shape.newCircle(FM.fromInt(6), FM.fromInt(5), FM.fromInt(1))
    local wall   = Shape.newAABB(FM.fromInt(50), FM.fromInt(50), FM.fromInt(5), FM.fromInt(5))

    sys:addBody("player1", player, System.GROUP_PLAYER, System.MASK_ALL)
    sys:addBody("bullet1", bullet, System.GROUP_BULLET, System.MASK_ALL)
    sys:addBody("wall1",   wall,   System.GROUP_WALL,   System.MASK_ALL)

    -- Track callbacks
    local callbackLog = {}
    sys:onCollision(function(idA, idB, mx, my)
        callbackLog[#callbackLog + 1] = {idA, idB, mx, my}
    end)

    local collisions = sys:step()

    print(string.format("  Collisions found: %d", #collisions))
    assert_true(#collisions >= 1, bpType .. ": system detects player-bullet collision")

    -- Check callback was fired
    assert_eq(#callbackLog, #collisions, bpType .. ": callbacks fired for each collision")

    -- Wall should not collide with player or bullet (too far)
    local wallCollision = false
    for _, c in ipairs(collisions) do
        if c[1] == "wall1" or c[2] == "wall1" then
            wallCollision = true
        end
    end
    assert_false(wallCollision, bpType .. ": wall too far to collide")

    -- Group/mask filtering test
    sys:clear()
    local a1 = Shape.newCircle(0, 0, 2000)
    local a2 = Shape.newCircle(1000, 0, 2000)
    -- Same group, but mask excludes each other
    sys:addBody("a", a1, System.GROUP_PLAYER, System.GROUP_WALL)
    sys:addBody("b", a2, System.GROUP_PLAYER, System.GROUP_WALL)
    collisions = sys:step()
    assert_eq(#collisions, 0, bpType .. ": group/mask filter: players don't collide with each other")

    -- Now allow player-player collision
    sys:clear()
    sys:addBody("a", a1, System.GROUP_PLAYER, System.GROUP_PLAYER + System.GROUP_WALL)
    sys:addBody("b", a2, System.GROUP_PLAYER, System.GROUP_PLAYER + System.GROUP_WALL)
    collisions = sys:step()
    assert_true(#collisions > 0, bpType .. ": group/mask filter: players collide when mask allows")

end -- bpTypes loop

------------------------------------------------------------------------
section("Legacy API: System.new(cellSize)")
------------------------------------------------------------------------

local legacySys = System.new(FM.fromInt(10))
assert_eq(legacySys:getBroadPhaseType(), "spatial_hash", "legacy API defaults to spatial_hash")
legacySys:addBody(1, Shape.newCircle(0, 0, 2000), System.GROUP_DEFAULT, System.MASK_ALL)
legacySys:addBody(2, Shape.newCircle(1000, 0, 2000), System.GROUP_DEFAULT, System.MASK_ALL)
local legacyCols = legacySys:step()
assert_true(#legacyCols > 0, "legacy API detects collisions")

------------------------------------------------------------------------
section("Determinism verification (all broad-phase types)")
------------------------------------------------------------------------

-- Run the same simulation with each broad-phase, verify:
-- 1. Each type produces identical results across two runs.
-- 2. All three types detect the same collision events (same ids, same MTV).
local function runSimulation(bpType)
    local s = createSystem(bpType)
    local results = {}

    -- Create a set of bodies
    for i = 1, 10 do
        local x = FM.fromInt(i * 3)
        local y = FM.fromInt((i % 3) * 4)
        local r = FM.fromInt(2)
        s:addBody(i, Shape.newCircle(x, y, r), System.GROUP_DEFAULT, System.MASK_ALL)
    end

    -- Simulate 10 frames with movement
    for frame = 1, 10 do
        -- Move bodies deterministically
        for i = 1, 10 do
            local body = s.bodies[i]
            if body then
                local dx = FM.fromFloat(0.5) * ((i % 2 == 0) and 1 or -1)
                local dy = FM.fromFloat(0.3) * ((i % 3 == 0) and 1 or -1)
                Shape.translate(body.shape, dx, dy)
            end
        end

        local cols = s:step()
        for _, c in ipairs(cols) do
            results[#results + 1] = string.format("%d:%s:%s:%d:%d", frame, tostring(c[1]), tostring(c[2]), c[3], c[4])
        end
    end

    return table.concat(results, "|")
end

local simResults = {}
for _, bpType in ipairs(bpTypes) do
    local sim1 = runSimulation(bpType)
    local sim2 = runSimulation(bpType)
    assert_eq(sim1, sim2, bpType .. ": two runs produce identical results")
    if sim1 == sim2 then
        local eventCount = 1
        if #sim1 > 0 then
            eventCount = select(2, sim1:gsub("|", "")) + 1
        end
        print(string.format("  [%s] Determinism VERIFIED, %d collision events", bpType, eventCount))
    end
    simResults[bpType] = sim1
end

-- Cross-check: all three broad-phase types should produce the same collision results
assert_eq(simResults["spatial_hash"], simResults["sweep_and_prune"],
    "spatial_hash and sweep_and_prune produce same results")
assert_eq(simResults["spatial_hash"], simResults["quadtree"],
    "spatial_hash and quadtree produce same results")
if simResults["spatial_hash"] == simResults["sweep_and_prune"]
    and simResults["spatial_hash"] == simResults["quadtree"] then
    print("  Cross-check: all 3 broad-phase types produce IDENTICAL collision results")
end

------------------------------------------------------------------------
-- Summary
------------------------------------------------------------------------
print(string.format("\n========================================"))
print(string.format("Results: %d passed, %d failed", passed, failed))
print(string.format("========================================"))
if failed > 0 then
    os.exit(1)
end
