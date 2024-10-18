local SceneMain = class("SceneMain", function()
    local scene = display.newScene("SceneMain")
    scene:initWithPhysics()
    scene:getPhysicsWorld():setGravity(cc.p(0, 0))
    scene:enableNodeEvents()
    return scene
end)

function SceneMain:ctor()
    -- local uiloader = cc.load('uiloader')
    -- local layer = uiloader:load("res/modules/LayerTest.csb")
    -- local width = display.width
    -- local height = display.height
    -- layer:setContentSize(width, height)
    -- layer:enableNodeEvents()
    -- ccui.Helper:doLayout(layer)
    -- layer:addTo(self)

    -- local touchLayer = require "src.app.modules.joysticks.TouchLayer"
    -- touchLayer:new():addTo(self)

    -- local spine = sp.SkeletonAnimation:createWithBinaryFile("res/spine/spineboy-pro.skel","res/spine/spineboy.atlas")
    -- local anis = spine:getAnimations()
    -- local tblAni = string.split(anis,"#")
    -- dump(tblAni)
    -- spine:setToSetupPose()
    -- spine:setAnimation(0,"run",true)
    -- spine:update(0)
    -- spine:setTimeScale(1)
    -- spine:addTo(self)
    -- spine:setScale(0.5)
    -- spine:setPosition(cc.p(display.cx,display.cy))

    -- self.fsm = StateMachine:new()
    -- self.fsm:setupState({
    --     initial = "idle",
    --     events = {
    --         {name = "move", from = {"idle", "jump"}, to = "walk"},
    --         {name = "attack", from = {"idle", "walk"}, to = "jump"},
    --         {name = "normal", from = {"walk", "jump"}, to = "idle"},
    --     },
    --     callbacks = {
    --         onenteridle = function ()
    --             print("onenteridle")
    --         end,
    --         onenterwalk = function ()
    --             print("onenterwalk")
    --         end,
    --         onenterjump = function ()
    --             print("onenterjump")
    --         end,
    --     },
    -- })

    local tmx = cc.TMXTiledMap:create("res/tilemap/tilemap.tmx")
    tmx:addTo(self)
    self.borderLayer = tmx:getLayer("border")
    local s = tmx:getMapOrientation()
    local size = tmx:getMapSize()
    self.tileSize = tmx:getTileSize()

    local HandlerEntity = require "src.app.modules.map.NodeEntity"
    self.entity = HandlerEntity.new()
    self.entity:addTo(self)
    self.entity:setPosition(cc.p(display.cx,display.cy))
    self.rotation = 0
    self.ahead = 0

    local keyBoardListener = cc.EventListenerKeyboard:create()
    keyBoardListener:registerScriptHandler(handler(self,self.onKeyEventPressed), cc.Handler.EVENT_KEYBOARD_PRESSED)
    keyBoardListener:registerScriptHandler(handler(self,self.onKeyEventReleased), cc.Handler.EVENT_KEYBOARD_RELEASED)
    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(keyBoardListener, self)
    local contactListener = cc.EventListenerPhysicsContact:create()
    contactListener:registerScriptHandler(handler(self,self.onContactBegin), cc.Handler.EVENT_PHYSICS_CONTACT_BEGIN)
    contactListener:registerScriptHandler(handler(self,self.onContactEnd), cc.Handler.EVENT_PHYSICS_CONTACT_SEPARATE)
    eventDispatcher:addEventListenerWithSceneGraphPriority(contactListener, self)

    local mapLayer = require("src.app.modules.map.LayerMap")
    self.layerMap = mapLayer:create()
    self.layerMap:addTo(self,-1)
    self:getPhysicsWorld():setAutoStep(false)
    if DEBUG > 0 then self:getPhysicsWorld():setDebugDrawMask(cc.PhysicsWorld.DEBUGDRAW_ALL) end
    self.tickPhysicWorld = Scheduler:scheduleGlobal(handler(self, self.tickUpdate), 0.02)
    self:scheduleUpdate(handler(self,self.update))
end

function SceneMain:onEnter()
    self.recvStr = ""
    self.eventProtocol = EventProtocol:new()
    self.eventProtocol:addEventListener(SocketTCP.EVENT_DATA, handler(self,self.onEventData), "TCP_DATA")
    self.tcp = SocketTCP:create()
    self.tcp:setEventProtocol(self.eventProtocol)
    self.tcp:connect("127.0.0.1",8888,true)
    self.co = coroutine.create(function()
        while true do
            local idx,yieldRet = coroutine.yield()
            dump(yieldRet, tostring(idx))
        end
    end)
    coroutine.resume(self.co, nil)
end

function SceneMain:onExit()
    if self.tickPhysicWorld then
        Scheduler:unscheduleGlobal(self.tickPhysicWorld)
        self.tickPhysicWorld = nil
    end
end

function SceneMain:onEventData(INdata)
    if not self.index then self.index = 0 end
    self.recvStr = self.recvStr .. INdata.data
    local strlen = string.len(self.recvStr)
    if strlen > 8 then
        local datalen = tonumber(string.sub(self.recvStr,1,8))
        if strlen >= 8 + datalen then
            local data = string.sub(self.recvStr,8+1,8 + datalen)
            local dataInfo = protobuf.decode("pb_common.data_head", data)
            protobuf.extract(dataInfo)
            self.index = self.index + 1
            coroutine.resume(self.co, self.index, dataInfo)
            self.recvStr = string.sub(self.recvStr,8 + datalen+1,datalen)
        end
    end
end

function SceneMain:sendData(INprotocal,INdata)
    local pData = protobuf.encode('pb_common.data_head', {
        protocol_code = INprotocal,
        data_len = string.len(INdata),
        data_str = INdata
    })
    local str = string.format("%08d",string.len(pData))
    self.tcp:send(str .. pData)
end

function SceneMain:onKeyEventPressed(INkey,INrender)
    if INkey == cc.KeyCode.KEY_W then
        -- local ret = self.fsm:doEvent("move")
        -- print("press W "..tostring(ret))
        self.ahead = self.ahead + 1
    end
    if INkey == cc.KeyCode.KEY_S then
        -- local ret = self.fsm:doEvent("move")
        -- print("press W "..tostring(ret))
        self.ahead = self.ahead - 1
    end
    if INkey == cc.KeyCode.KEY_A then
        -- local ret = self.fsm:doEvent("attack")
        -- print("press A "..tostring(ret))
        self.rotation = self.rotation - 1
    end
    if INkey == cc.KeyCode.KEY_D then
        -- local ret = self.fsm:doEvent("normal")
        -- print("press D "..tostring(ret))
        self.rotation = self.rotation + 1
    end
    if INkey == cc.KeyCode.KEY_F then
        self.tcp:send(tostring(os.time()))
    end
    if INkey == cc.KeyCode.KEY_P then
        local data = protobuf.encode('pb_common.req_test', {
            n1 = 606224,
            s1 = "hello world!",
            arr = {1,2,3,3}
        })
        self:sendData(0,data)
    end
end

function SceneMain:onKeyEventReleased(INkey,INrender)
    if INkey == cc.KeyCode.KEY_W then
        self.ahead = self.ahead - 1
    end
    if INkey == cc.KeyCode.KEY_S then
        self.ahead = self.ahead + 1
    end
    if INkey == cc.KeyCode.KEY_A then
        self.rotation = self.rotation + 1
    end
    if INkey == cc.KeyCode.KEY_D then
        self.rotation = self.rotation - 1
    end
end

function SceneMain:update(dt)
    if self.rotation ~= 0 then
        local rotation = self.entity:getRotation()
        self.entity:setRotation(rotation+self.rotation*dt*200)
    end
    local pos = cc.p(self.entity:getPosition())
    local col,row = math.floor(pos.x/self.tileSize.width),math.floor(pos.x/self.tileSize.height)
    if self.ahead ~= 0 then
        local rotation = self.entity:getRotation() % 360
        local dir = cc.p(math.sin(rotation*math.pi/180),math.cos(rotation*math.pi/180))
        self.entity:setPosition(cc.pAdd(pos,cc.pMul(dir,self.ahead*dt*200)))
    end
end

function SceneMain:tickUpdate(dt)
    -- use fixed time and calculate 3 times per frame makes physics simulate more precisely
    for i=1,3 do
        self:getPhysicsWorld():step(1/90.0)
    end
end

function SceneMain:onContactBegin(INcontact)
    local nodeA = INcontact:getShapeA():getBody():getNode()
    local nodeB = INcontact:getShapeB():getBody():getNode()
    if not nodeA or not nodeB then return end
    if nodeA.onContactBegin then nodeA:onContactBegin(nodeB) end
    if nodeB.onContactBegin then nodeB:onContactBegin(nodeA) end
    return true
end

function SceneMain:onContactEnd(INcontact)
    local nodeA = INcontact:getShapeA():getBody():getNode()
    local nodeB = INcontact:getShapeB():getBody():getNode()
    if not nodeA or not nodeB then return end
    if nodeA.onContactEnd then nodeA:onContactEnd(nodeB) end
    if nodeB.onContactEnd then nodeB:onContactEnd(nodeA) end
    return true
end

return SceneMain