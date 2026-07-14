local NodeEntity = class("NodeEntity", function ()
    local node = display.newNode()
    node:enableNodeEvents()
    return node
end)

function NodeEntity:ctor(INparent,INoriginPos)
    self.token = -1
    self.index = 0
    self.parent = INparent
    self.ahead = 0
    self.rotation = 0
    self.base = display.newSprite("res/entity.png")
    self.base:addTo(self)
    self.barrel = display.newSprite("res/barrel.png")
    self.barrel:setAnchorPoint(cc.p(0.5,0))
    self.barrel:addTo(self)
    self.barrel:setPosition(cc.p(0,0))
    self.opeCode = 0x00
    self.type = 1
    self.syncFrameId = 0
    self.logicInfo = {
        pos = cc.p(INoriginPos),
        rotation = 0,
        barrel_rotation = 0
    }
    self.syncState = {
        pos = cc.p(INoriginPos),
        rotation = 0
    }
    self.preLogicX = INoriginPos.x
    self.preLogicY = INoriginPos.y
    self.width = 30
    self.height = 40
    self.colliding = false
    self.collidedWith = nil
end

function NodeEntity:getLogicBounds()
    return {
        x = self.logicInfo.pos.x,
        y = self.logicInfo.pos.y,
        width = self.width,
        height = self.height
    }
end

function NodeEntity:onExit()
end

function NodeEntity:getKeyboardEvent(INType,INeventCode)
    if "onKeyEventPressed" == INType then
        if cc.KeyCode.KEY_W == INeventCode then self.opeCode = bit._or(self.opeCode,0x01) end
        if cc.KeyCode.KEY_S == INeventCode then self.opeCode = bit._or(self.opeCode,0x02) end
        if cc.KeyCode.KEY_A == INeventCode then self.opeCode = bit._or(self.opeCode,0x04) end
        if cc.KeyCode.KEY_D == INeventCode then self.opeCode = bit._or(self.opeCode,0x08) end
        if cc.KeyCode.KEY_SPACE == INeventCode then self.opeCode = bit._or(self.opeCode,0x10) end
    elseif "onKeyEventReleased" == INType then
        if cc.KeyCode.KEY_W == INeventCode then self.opeCode = bit._and(self.opeCode,0xfe) end
        if cc.KeyCode.KEY_S == INeventCode then self.opeCode = bit._and(self.opeCode,0xfd) end
        if cc.KeyCode.KEY_A == INeventCode then self.opeCode = bit._and(self.opeCode,0xfb) end
        if cc.KeyCode.KEY_D == INeventCode then self.opeCode = bit._and(self.opeCode,0xf7) end
        if cc.KeyCode.KEY_SPACE == INeventCode then self.opeCode = bit._and(self.opeCode,0xef) end
    end
end

function NodeEntity:getOpeCode()
    return self.opeCode
end

function NodeEntity:setToken(INtoken)
    self.token = INtoken or -1
    if self.info then return end
    self.info = ccui.Text:create():setString("ID:"..self.token):addTo(self)
    :setFontSize(20)
    :setPosition(cc.p(0, -self.height))
end

function NodeEntity:updateNodeUI(INrotation)
    if not self.info then return end
    local parentWorldPos = self:convertToWorldSpace(cc.p(0,0))
    local worldOffset = cc.p(0, -self.height)
    local targetWorldPos = cc.p(parentWorldPos.x + worldOffset.x, parentWorldPos.y + worldOffset.y)
    local localPos = self:convertToNodeSpace(targetWorldPos)
    self.info:setPosition(localPos)
    self.info:setRotation(-1*INrotation)
end

function NodeEntity:setIndex(INindex)
    self.index = INindex or 0
end

function NodeEntity:getLogicBounds()
    return {
        x = self.logicInfo.pos.x,
        y = self.logicInfo.pos.y,
        width = self.width,
        height = self.height
    }
end

return NodeEntity