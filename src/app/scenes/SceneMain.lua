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

    -- local tmx = cc.TMXTiledMap:create("res/tilemap/tilemap.tmx")
    -- tmx:addTo(self)
    -- self.borderLayer = tmx:getLayer("border")
    -- local s = tmx:getMapOrientation()
    -- local size = tmx:getMapSize()
    -- self.tileSize = tmx:getTileSize()

    local mapLayer = require("src.app.modules.map.LayerMap")
    self.layerMap = mapLayer:create()
    self.layerMap:addTo(self,-1)

    self.token = -1
    self.entity = nil
    self.entities = {}

    self.currentFrame = 1
    self.frames = {}
    self.begin = false

    local keyBoardListener = cc.EventListenerKeyboard:create()
    keyBoardListener:registerScriptHandler(handler(self,self.onKeyEventPressed), cc.Handler.EVENT_KEYBOARD_PRESSED)
    keyBoardListener:registerScriptHandler(handler(self,self.onKeyEventReleased), cc.Handler.EVENT_KEYBOARD_RELEASED)
    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(keyBoardListener, self)
    local contactListener = cc.EventListenerPhysicsContact:create()
    contactListener:registerScriptHandler(handler(self,self.onContactBegin), cc.Handler.EVENT_PHYSICS_CONTACT_BEGIN)
    contactListener:registerScriptHandler(handler(self,self.onContactEnd), cc.Handler.EVENT_PHYSICS_CONTACT_SEPARATE)
    eventDispatcher:addEventListenerWithSceneGraphPriority(contactListener, self)

    self:getPhysicsWorld():setAutoStep(false)
    if CC_SHOW_PHYSIC_MASK then self:getPhysicsWorld():setDebugDrawMask(cc.PhysicsWorld.DEBUGDRAW_ALL) end
    self.tickPhysicWorld = Scheduler:scheduleGlobal(handler(self, self.tickUpdate), 0.02)
    self:scheduleUpdate(handler(self,self.update))
end

function SceneMain:onEnter()
    self.index = 0
    self.recvStr = ""
    self.eventProtocol = EventProtocol:new()
    self.eventProtocol:addEventListener(SocketTCP.EVENT_CONNECTED, handler(self,self.onEventConnected), "SOCKET_TCP_CONNECTED")
    self.eventProtocol:addEventListener(SocketTCP.EVENT_DATA, handler(self,self.onEventTcpData), "TCP_DATA")
    self.tcp = SocketTCP:create()
    self.tcp:setEventProtocol(self.eventProtocol)
    self.tcp:connect("127.0.0.1",8888,true)
    self.eventProtocol:addEventListener(SocketUDP.EVENT_DATA, handler(self,self.onEventUdpData), "UDP_DATA")
    self.udp = SocketUDP:create("127.0.0.1",8889,self.eventProtocol)
    self.co = coroutine.create(function()
        while true do
            local idx,yieldRet = coroutine.yield()
            self:onEventData(yieldRet)
        end
    end)
    coroutine.resume(self.co, nil)
end

function SceneMain:onExit()
    if self.tickPhysicWorld then
        Scheduler:unscheduleGlobal(self.tickPhysicWorld)
        self.tickPhysicWorld = nil
    end
    self.tcp:disconnect()
    self.tcp:close()
    self.udp:close()
end

function SceneMain:onEventConnected()
    local HandlerEntity = require "src.app.modules.map.NodeEntity"
    self.entity = HandlerEntity.new(self)
    self.entity:addTo(self)
    self.entity:setPosition(cc.p(display.cx,display.cy))
end

function SceneMain:onEventUdpData(INdata)
    if not INdata then return end
    self.index = self.index + 1
    coroutine.resume(self.co, self.index, {type="udp",data=INdata.data})
end

function SceneMain:onEventTcpData(INdata)
    self.recvStr = self.recvStr .. INdata.data
    local head_len = 4
    local strlen = string.len(self.recvStr)
    if strlen > head_len then
        local _,datalen = string.unpack(string.sub(self.recvStr,1,head_len),"<I")
        if strlen >= head_len + datalen then
            local data = string.sub(self.recvStr,head_len + 1,head_len + datalen)
            local dataInfo = protobuf.decode("pb_common.data_head", data)
            protobuf.extract(dataInfo)
            self.index = self.index + 1
            coroutine.resume(self.co, self.index, {type="tcp",data=dataInfo})
            self.recvStr = string.sub(self.recvStr,head_len + datalen + 1,datalen)
        end
    end
end

function SceneMain:onEventData(INdata)
    if "tcp" == INdata.type then
        if protobuf.enum_id("pb_common.protocol_code","protocol_user_info") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_user_info", INdata.data.data_str)
            protobuf.extract(dataInfo)
            cc.exports.USERID = dataInfo.userid
            self.token = dataInfo.userid
            self.entity:setToken(dataInfo.userid)
            self.entities[self.token] = self.entity
            self:sendUdpData(protobuf.encode('pb_common.data_ope', {
                userid = self.token,
                frameid = 1,
                opecode = 0x00
            }))
        elseif protobuf.enum_id("pb_common.protocol_code","protocol_begin") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_begin", INdata.data.data_str)
            protobuf.extract(dataInfo)
            math.randomseed(dataInfo.rand_seed)
            print("begin bout!")
            self.currentFrame = 1
            self.begin = true
        end
    elseif "udp" == INdata.type then
        local dataInfo = protobuf.decode("pb_common.data_ope_frames", INdata.data)
        protobuf.extract(dataInfo)
        self.currentFrame = dataInfo.frameid
        if not self.frames[self.currentFrame] then self.frames[self.currentFrame] = {} end
        print(string.format("recv frameid %d", dataInfo.frameid))
        for i=1,#dataInfo.frames do
            if not self.entities[dataInfo.frames[i].userid] then
                local HandlerEntity = require "src.app.modules.map.NodeEntity"
                local entity = HandlerEntity.new(self)
                entity:setToken(dataInfo.frames[i].userid)
                entity:addTo(self)
                entity:setPosition(cc.p(display.cx,display.cy))
                self.entities[dataInfo.frames[i].userid] = entity
            end
            self.entities[dataInfo.frames[i].userid]:applyInput(dataInfo.frameid, dataInfo.frames[i].opecode)
            print(string.format("render frame %d userid %d opecode %d",dataInfo.frameid, dataInfo.frames[i].userid, dataInfo.frames[i].opecode))
            table.insert(self.frames[self.currentFrame],dataInfo.frames[i])
        end
    end
end

function SceneMain:sendData(INprotocal,INdata)
    local pData = protobuf.encode('pb_common.data_head', {
        protocol_code = INprotocal,
        data_len = string.len(INdata),
        data_str = INdata
    })
    local str = string.pack("<I",string.len(pData))
    self.tcp:send(str .. pData)
end

function SceneMain:sendUdpData(INdata)
    self.udp:send(INdata)
end

function SceneMain:onKeyEventPressed(INkey,INrender)
    if INkey == cc.KeyCode.KEY_R then
        local pData = protobuf.encode('pb_common.data_ready', {
            userid = self.token,
        })
        self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_ready"),pData)
    end
    if INkey == cc.KeyCode.KEY_P then
        local data = protobuf.encode('pb_common.req_test', {
            n1 = 606224,
            s1 = "hello world!",
            arr = {1,2,3,3}
        })
        self:sendData(0,data)
    end
    if INkey == cc.KeyCode.KEY_U then
        self.udp:send(tostring(os.time()))
    end
    if self.entity then self.entity:getKeyboardEvent("onKeyEventPressed",INkey) end
end

function SceneMain:onKeyEventReleased(INkey,INrender)
    if self.entity then self.entity:getKeyboardEvent("onKeyEventReleased",INkey) end
end

function SceneMain:update(dt)
    --local frames = self.frames[self.currentFrame]
    if self.entities then
        for k,v in pairs(self.entities) do
            if v then
                v:updateEntity(dt)
            end
        end
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