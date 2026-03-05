------------------------------------------------------------------------
-- FixedMath.lua
-- Deterministic fixed-point math library for frame-sync collision.
-- Scale factor = 1000, all values stored as Lua numbers (integer subset).
-- Safe integer range on double: ±2^53 ≈ 9e15.
-- With SCALE=1000 and coordinates up to ±10000 (fixed ±10_000_000),
-- multiplication intermediate max ≈ 1e13, well within safe range.
------------------------------------------------------------------------

local FixedMath = {}

local SCALE = 1000
local HALF_SCALE = 500 -- for rounding in division

FixedMath.SCALE = SCALE
FixedMath.ZERO = 0
FixedMath.ONE = SCALE        -- 1.0
FixedMath.HALF = HALF_SCALE  -- 0.5
FixedMath.NEG_ONE = -SCALE

local floor = math.floor
local abs   = math.abs

-- Convert a float to fixed-point (use only at init/editor time, NOT at runtime in simulation)
function FixedMath.fromFloat(f)
    return floor(f * SCALE + 0.5)
end

-- Convert fixed-point back to float (for rendering only, NOT for logic)
function FixedMath.toFloat(a)
    return a / SCALE
end

-- Create from integer (no fractional part)
function FixedMath.fromInt(i)
    return i * SCALE
end

-- Addition (exact)
function FixedMath.add(a, b)
    return a + b
end

-- Subtraction (exact)
function FixedMath.sub(a, b)
    return a - b
end

-- Multiplication: a * b / SCALE (truncated toward zero)
function FixedMath.mul(a, b)
    local result = a * b
    -- truncate toward zero
    if result >= 0 then
        return floor(result / SCALE)
    else
        return -floor(-result / SCALE)
    end
end

-- Division: a * SCALE / b (truncated toward zero)
function FixedMath.div(a, b)
    local result = a * SCALE
    if (result >= 0) == (b >= 0) then
        return floor(result / b)
    else
        return -floor(abs(result) / abs(b))
    end
end

-- Negate
function FixedMath.neg(a)
    return -a
end

-- Absolute value
function FixedMath.abs(a)
    if a < 0 then return -a end
    return a
end

-- Min / Max
function FixedMath.min(a, b)
    if a < b then return a end
    return b
end

function FixedMath.max(a, b)
    if a > b then return a end
    return b
end

-- Clamp
function FixedMath.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Sign: returns -SCALE, 0, or +SCALE
function FixedMath.sign(a)
    if a > 0 then return SCALE end
    if a < 0 then return -SCALE end
    return 0
end

------------------------------------------------------------------------
-- Fixed-point square root using integer Newton's method.
-- Input: fixed-point value a (represents a/SCALE in real).
-- Returns: fixed-point sqrt(a/SCALE) * SCALE.
-- Algorithm: compute isqrt(a * SCALE) which equals floor(sqrt(a*SCALE)).
-- Since a represents a/SCALE, sqrt(a/SCALE)*SCALE = sqrt(a*SCALE).
-- Safe when a * SCALE < 2^53, i.e. a < 9e12 → real value < 9e9. Fine.
------------------------------------------------------------------------
function FixedMath.sqrt(a)
    if a <= 0 then return 0 end
    local val = a * SCALE
    -- Initial guess via float sqrt (only for seeding, result is deterministic
    -- because we iterate to exact integer answer)
    local x = floor(math.sqrt(val))
    -- Newton iterations to converge to exact isqrt
    -- isqrt satisfies: x*x <= val < (x+1)*(x+1)
    for _ = 1, 5 do
        if x == 0 then return 0 end
        local x1 = floor((x + floor(val / x)) / 2)
        if x1 >= x then break end
        x = x1
    end
    -- Verify and adjust (guarantees determinism regardless of initial guess)
    while x * x > val do
        x = x - 1
    end
    while (x + 1) * (x + 1) <= val do
        x = x + 1
    end
    return x
end

-- Distance squared between two fixed-point 2D points (returns fixed * fixed / SCALE = fixed)
-- Actually returns (dx*dx + dy*dy) / SCALE so the result is in fixed-point scale.
-- For comparison only (avoids sqrt). Use distSq for comparisons, sqrt only when needed.
function FixedMath.distSq(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    -- dx and dy are in fixed scale, dx*dx is in SCALE^2, divide by SCALE to get fixed scale
    return floor((dx * dx + dy * dy) / SCALE)
end

-- Dot product of two 2D vectors (fixed-point): returns fixed scale
function FixedMath.dot(ax, ay, bx, by)
    return floor((ax * bx + ay * by) / SCALE)
end

-- Cross product (2D, scalar result): returns fixed scale
function FixedMath.cross(ax, ay, bx, by)
    return floor((ax * by - ay * bx) / SCALE)
end

-- Length squared of vector (returns fixed scale)
function FixedMath.lengthSq(x, y)
    return floor((x * x + y * y) / SCALE)
end

-- Length of vector (returns fixed scale)
function FixedMath.length(x, y)
    return FixedMath.sqrt(FixedMath.lengthSq(x, y))
end

------------------------------------------------------------------------
-- Pre-computed sin/cos lookup table (1 degree resolution, fixed-point).
-- For deterministic rotation. Angles in integer degrees [0, 359].
------------------------------------------------------------------------
local sinTable = {}
local cosTable = {}

for deg = 0, 359 do
    local rad = deg * math.pi / 180
    sinTable[deg] = floor(math.sin(rad) * SCALE + 0.5)
    cosTable[deg] = floor(math.cos(rad) * SCALE + 0.5)
end

-- Get sin of angle in integer degrees (returns fixed-point)
function FixedMath.sinDeg(deg)
    deg = deg % 360
    if deg < 0 then deg = deg + 360 end
    return sinTable[deg]
end

-- Get cos of angle in integer degrees (returns fixed-point)
function FixedMath.cosDeg(deg)
    deg = deg % 360
    if deg < 0 then deg = deg + 360 end
    return cosTable[deg]
end

-- Rotate a vector (vx, vy) by integer degrees. Returns new (rx, ry) in fixed-point.
function FixedMath.rotate(vx, vy, deg)
    local s = FixedMath.sinDeg(deg)
    local c = FixedMath.cosDeg(deg)
    local rx = floor((vx * c - vy * s) / SCALE)
    local ry = floor((vx * s + vy * c) / SCALE)
    return rx, ry
end

return FixedMath
