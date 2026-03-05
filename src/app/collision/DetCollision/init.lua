------------------------------------------------------------------------
-- init.lua
-- Entry point for the DetCollision module.
-- Usage:
--   local DetCollision = require("app.collision.DetCollision.init")
--   local FM    = DetCollision.FixedMath
--   local Shape = DetCollision.Shape
--   local SAT   = DetCollision.SAT
--   local sys   = DetCollision.System.new(cellSize)
------------------------------------------------------------------------

local DetCollision = {
    FixedMath       = require("app.collision.DetCollision.FixedMath"),
    Shape           = require("app.collision.DetCollision.Shape"),
    SAT             = require("app.collision.DetCollision.SAT"),
    SpatialHash     = require("app.collision.DetCollision.SpatialHash"),
    SweepAndPrune   = require("app.collision.DetCollision.SweepAndPrune"),
    Quadtree        = require("app.collision.DetCollision.Quadtree"),
    System          = require("app.collision.DetCollision.DetCollisionSystem"),
}

return DetCollision
