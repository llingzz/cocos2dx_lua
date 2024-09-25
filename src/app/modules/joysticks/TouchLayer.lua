local TouchLayer = class("TouchLayer", function()
    return display.newLayer()
end)

local JOYSTICK_RADIUS = 75
local JOYSTICK_OFFSET = 20
local CLICK_TOUCH_HOLD = 5
local CAN_TOUCH_INTERVAL = 0.4
local ORIGIN_POS = cc.p(200,200)
function TouchLayer:ctor()
    self.joystickHold = 0
    self.initJoystickPos = false
    self:setTouchEnabled(true)
    self:registerScriptTouchHandler(handler(self, self.onTouch), false, 0, false)
    self:initView()
    self.dir = cc.p(0,0)
    self:scheduleUpdate(handler(self,self.update))
end

function TouchLayer:initView()
    self._currentPos = ORIGIN_POS
    self._centerPos = ORIGIN_POS
    self._controller = display.newSprite("res/modules/joystick/images/joystick_ctrl.png")
    self._controller:move(self._centerPos):addTo(self)
    self._controllerBg = display.newSprite("res/modules/joystick/images/joystick_bg.png")
    self._controllerBg:move(self._currentPos):addTo(self)
    self:showJoystick(false)
end

function TouchLayer:showJoystick(INflag)
    self._controller:setVisible(INflag)
    self._controllerBg:setVisible(INflag)
end

function TouchLayer:initJoystick(INpos)
    if self.initJoystickPos then return end
    self._currentPos = INpos
    self._centerPos = self._currentPos
    self._controller:setPosition(INpos)
    self._controllerBg:setPosition(INpos)
    self:showJoystick(true)
    self.initJoystickPos = true
end

function TouchLayer:onTouch(eventType, x, y)
    if "began" == eventType then
        return self:onTouchBegan_(x,y)
    elseif "moved" == eventType then
        self:onTouchMoved_(x,y)
    elseif "ended" == eventType then
        self:onTouchEnded_(x,y)
    end
end

function TouchLayer:onTouchBegan_(x,y)
    self.joystickHold = 0
    self:myTouchEvent(cc.p(x, y),"began")
    return true
end

function TouchLayer:onTouchMoved_(x,y)
    self.joystickHold = self.joystickHold + 1
    if self.joystickHold <= CLICK_TOUCH_HOLD then return end
    self:myTouchEvent(cc.p(x, y),"moved")
end

function TouchLayer:onTouchEnded_(x,y,flag)
    self.joystickHold = 0
    self:myTouchEvent(cc.p(x, y),"ended",flag)
end

function TouchLayer:myTouchEvent(p, type, flag)
    if "began" == type then
    elseif "moved" == type then
        self:initJoystick(p)
        self:rockerOnTouchMove(p)
    elseif "ended" == type then
        self:rockerOnTouchEnd(p)
    end
end

function TouchLayer:rockerOnTouchMove(INpos)
    self._currentPos = INpos
    local dis = cc.pGetDistance(self._centerPos,self._currentPos)
    if dis > JOYSTICK_OFFSET then self.dir = cc.pNormalize(cc.pSub(self._currentPos,self._centerPos))
    else self.dir = cc.p(0,0) end
    if dis > JOYSTICK_RADIUS then self._currentPos = cc.pAdd(self._centerPos,cc.pMul(cc.pNormalize(cc.pSub(self._currentPos,self._centerPos)),JOYSTICK_RADIUS)) end
end

function TouchLayer:rockerOnTouchEnd(INpos)
    self._currentPos = ORIGIN_POS
    self._centerPos = ORIGIN_POS
    self._controller:setPosition(self._centerPos)
    self._controllerBg:setPosition(self._centerPos)
    self:showJoystick(false)
    self._currentPos = self._centerPos
    self.initJoystickPos = false
    self.dir = cc.p(0,0)
end

function TouchLayer:rockerUpdate(dt)
    local posController = cc.p(self._controller:getPositionX(),self._controller:getPositionY())
    local newPosC = cc.pAdd(posController,cc.pMul(cc.pSub(self._currentPos,posController),CAN_TOUCH_INTERVAL))
    self._controller:setPosition(newPosC)
    self._controllerBg:setPosition(self._centerPos)
end

function TouchLayer:update(dt)
    self:rockerUpdate(dt)
end

return TouchLayer