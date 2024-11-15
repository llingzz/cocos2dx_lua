
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
    self.begin = false
    self.standalone = false

    self.lastedFrameId = 0
    self.currentFrameId = 0
    self.logicFrames = {}
    self.predictFrames = {}
    self.predictFrameId = 0
    self.predictAheadFrameCount = 1

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
    self.tickLogic = Scheduler:scheduleGlobal(handler(self, self.tickLogic), 1.0/15)
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
    if self.tickLogic then
        Scheduler:unscheduleGlobal(self.tickLogic)
        self.tickLogic = nil
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
    local dataInfo = protobuf.decode("pb_common.data_head", INdata.data)
    protobuf.extract(dataInfo)
    coroutine.resume(self.co, self.index, {type="udp",data=dataInfo})
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
            self:sendUdpData(protobuf.enum_id("pb_common.protocol_code","protocol_frame"),protobuf.encode('pb_common.data_ope', {
                userid = self.token,
                frameid = -1,
                opecode = 0x00
            }))
        elseif protobuf.enum_id("pb_common.protocol_code","protocol_begin") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_begin", INdata.data.data_str)
            protobuf.extract(dataInfo)
            math.randomseed(dataInfo.rand_seed)
            for k,v in pairs(dataInfo.userids) do
                if not self.entities[v] then self:createEntity(v) end
            end
            self.begin = true
        end
    elseif "udp" == INdata.type then
        if protobuf.enum_id("pb_common.protocol_code","protocol_frame") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_frames", INdata.data.data_str)
            protobuf.extract(dataInfo)
            for i=1,#dataInfo.frames do
                if self.lastedFrameId < dataInfo.frames[i].frameid then self.lastedFrameId = dataInfo.frames[i].frameid end
                if self.currentFrameId <= dataInfo.frames[i].frameid then
                    self.logicFrames[dataInfo.frames[i].frameid] = clone(dataInfo.frames[i].frames)
                end
            end
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

function SceneMain:sendUdpData(INprotocal,INdata)
    local pData = protobuf.encode('pb_common.data_head', {
        protocol_code = INprotocal,
        data_len = string.len(INdata),
        data_str = INdata
    })
    self.udp:send(pData)
end

function SceneMain:onKeyEventPressed(INkey,INrender)
    if INkey == cc.KeyCode.KEY_R then
        local pData = protobuf.encode('pb_common.data_ready', {
            userid = self.token,
        })
        self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_ready"),pData)
    end
    if INkey == cc.KeyCode.KEY_P then
        self.begin = true
        self.standalone = true
        local HandlerEntity = require "src.app.modules.map.NodeEntity"
        self.entity = HandlerEntity.new(self)
        self.entity:addTo(self)
        self.entity:setPosition(cc.p(display.cx,display.cy))
        self.entity:setToken(1)
        self.token = 1
        self.entities[1] = self.entity
    end
    if self.entity then self.entity:getKeyboardEvent("onKeyEventPressed",INkey) end
end

function SceneMain:onKeyEventReleased(INkey,INrender)
    if self.entity then self.entity:getKeyboardEvent("onKeyEventReleased",INkey) end
end

function SceneMain:createEntity(INtoken)
    local HandlerEntity = require "src.app.modules.map.NodeEntity"
    local entity = HandlerEntity.new(self)
    entity:setToken(INtoken)
    entity:addTo(self)
    entity:setPosition(cc.p(display.cx,display.cy))
    self.entities[INtoken] = entity
end

function SceneMain:update(dt)
    if not self.begin then return end
    for k,v in pairs(self.entities) do
        if v then
            v:renderUpdate(dt)
        end
    end
end

function SceneMain:tickUpdate(dt)
    -- use fixed time and calculate 3 times per frame makes physics simulate more precisely
    for i=1,3 do
        self:getPhysicsWorld():step(1/90.0)
    end
end

function SceneMain:tickLogic(dt)
    if not self.begin then return end
    if self.entity then self.entity:capturePlayerOpts() end
    local frameid = self.currentFrameId
    if (self.standalone or frameid + self.predictAheadFrameCount >= self.predictFrameId) and not self.predictFrames[self.predictFrameId] then
        self.predictFrames[self.predictFrameId] = {}
        for k,v in pairs(self.entities) do
            local opeCode = v.syncOpeCode
            if k==self.token then opeCode = v.opeCode end
            self.predictFrames[self.predictFrameId][k] = {opecode=opeCode}
            v:predictUpdate(v:convertOpeCode(opeCode))
            --print(string.format("predict userid %d frameid %d opecode %d logic:[%d][%d:%d] predict:[%d][%d:%d]",k,self.predictFrameId,opeCode,v.logicRat,v.logicPos.x,v.logicPos.y,v.predictRat,v.predictPos.x,v.predictPos.y))
        end
        self.predictFrameId = self.predictFrameId + 1
    end
    if self.standalone then return end
    if not self.logicFrames[frameid] then
        return
    end
    for k,v in pairs(self.logicFrames[frameid]) do
        local total = #v.opecode
        for i=1,total do
            self.entities[v.userid]:applyInput(frameid, v.opecode[i])
            if i ~= total then
                self.entities[v.userid]:logicUpdate()
            end
        end
    end
    for k,v in pairs(self.entities) do
        v:logicUpdate()
        local predict = self.predictFrames[frameid]
        if predict and predict[k] then
            if v.syncOpeCode ~= predict[k].opecode then
                v.predictRat = clone(v.logicRat)
                v.predictPos = clone(v.logicPos)
                v:predictUpdate(v:convertOpeCode(v.syncOpeCode))
                --print(string.format("rollback userid %d frameid %d opecode %d %d logic:[%d][%d:%d] predict:[%d][%d:%d]",k,frameid,predict[k].opecode,v.syncOpeCode,v.logicRat,v.logicPos.x,v.logicPos.y,v.predictRat,v.predictPos.x,v.predictPos.y))
            end
        end
    end
    table.remove(self.predictFrames,frameid)
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