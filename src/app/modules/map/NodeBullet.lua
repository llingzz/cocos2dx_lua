local NodeBullet = class("NodeBullet", function ()
    local node = display.newNode()
    node:enableNodeEvents()
    return node
end)

function NodeBullet:ctor(INid,INuserid,INframeid,INoriginPos,INdir)
    self.entity = display.newSprite("res/bullet.png")
    self.entity:addTo(self)
    self.type = 0
    self.id = INid
    self.owner = INuserid
    self.birthFrameId = INframeid
    self.birthPos = cc.p(INoriginPos.x, INoriginPos.y)
    self.vx = INdir.x
    self.vy = INdir.y
    self.destroy = false
    self.width = 8
    self.height = 8
end

function NodeBullet:getLogicPos(INframe)
    if not INframe or INframe <= self.birthFrameId then return cc.p(self.birthPos.x, self.birthPos.y) end
    local frames = (INframe - self.birthFrameId)
    --HLog:printf(string.format("getLogicPos %d %d %d, bPos %d:%d v %d:%d", self.id, INframe, self.birthFrameId, self.birthPos.x, self.birthPos.y,  self.vx, self.vy))
    return cc.p(self.birthPos.x + self.vx * frames, self.birthPos.y + self.vy * frames)
end

function NodeBullet:getLogicBounds(INframeId)
    local logicPos = self:getLogicPos(INframeId)
    return {
        x = logicPos.x,
        y = logicPos.y,
        width = self.width,
        height = self.height
    }
end

function NodeBullet:onCollison(INbody,INlogicFrameId)
    --print(string.format("[Collision] FrameID:%d logicPos:%d:%d", INlogicFrameId, self:getLogicPos(INlogicFrameId).x, self:getLogicPos(INlogicFrameId).y))
end

return NodeBullet