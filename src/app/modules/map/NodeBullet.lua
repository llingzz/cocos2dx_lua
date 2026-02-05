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
    self.vx = HelpTools:toFixed(INdir.x*BULLET_MOVE_SPEED/1000)
    self.vy = HelpTools:toFixed(INdir.y*BULLET_MOVE_SPEED/1000)
    self.destroy = false
    self.width = 5
    self.height = 5
end

function NodeBullet:getLogicBounds(INframeId)
    local elapsedFrames = INframeId - self.birthFrameId
    return {
        x = self.birthPos.x + self.vx * elapsedFrames,
        y = self.birthPos.y + self.vy * elapsedFrames,
        width = self.width,
        height = self.height
    }
end

-- 获取子弹速度向量
function NodeBullet:getVelocity()
    return {
        x = self.vx,
        y = self.vy
    }
end

return NodeBullet