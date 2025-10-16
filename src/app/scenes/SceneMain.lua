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

    -- self.resourceMgr = ResourceManager:new()
    -- self.nodePool = self.resourceMgr:createSpawnPool("nodepool",
    -- {
    --     --载入方式
    --     load = function()
    --         return display.newNode()
    --     end,
    --     --预载的数量,0表示使用时载入
    --     preloadamount = 1,
    --     --是否在指定时间内载入完或一次性载入完成
    --     preloadovertime = true,
    --     --每帧载入数量
    --     preloadoneframe = 1,
    --     --载入延迟
    --     preloaddelay = 0,
    --     --闲置对象生命周期,0表示永远存在,-1表示场景切换后删除
    --     duration = 0,
    -- })
    -- self.nodePool:preload()
    -- Scheduler:performWithDelayGlobal(function()
    --     self.testNode = self.nodePool:spawn()
    --     self.testNode:addTo(self)
    --     Scheduler:performWithDelayGlobal(function()
    --         self.testNode:removeSelf()
    --     end,0)
    -- end,0)

    local mapLayer = require("src.app.modules.map.LayerMap")
    self.layerMap = mapLayer:create()
    self.layerMap:addTo(self,-1)

    self.token = -1
    self.entity = nil
    self.entities = {}
    self.begin = false
    self.standalone = false
    self.roomid = 0

    -- 服务端下发的帧数据
    self.serverFrames = {}
    self.frameId = 0
    -- 客户端同步过的帧号
    self.syncFrameId = 0
    self.inputsPending = {}
    self.syncStates = nil
    self.lastestPos = nil

    self.otherFrameid = 0
    self.otherPos = cc.p(display.cx,display.cy)

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
    --self.tickLogic = Scheduler:scheduleGlobal(handler(self, self.tickLogic), 1.0/15)
    self.tickPing = Scheduler:scheduleGlobal(handler(self,self.ping),5)
    self.lastRecv = nil
end

function SceneMain:onEnter()
    self.index = 0
    self.recvStr = ""
    self.eventProtocol = EventProtocol:new()
    self.eventProtocol:addEventListener(SocketTCP.EVENT_DATA, handler(self,self.onEventTcpData), "TCP_DATA")
    self.eventProtocol:addEventListener(SocketTCP.EVENT_CONNECTED, handler(self,self.onEventTcpConnected), "TCP_CONNECTED")
    self.tcp = SocketTCP:create()
    self.tcp:setEventProtocol(self.eventProtocol)
    self.tcp:connect("127.0.0.1",8888,true)
    self.eventProtocol:addEventListener(SocketUDP.EVENT_DATA, handler(self,self.onEventUdpData), "UDP_DATA")
    self.udp = SocketUDP:create("127.0.0.1",8889,self.eventProtocol)
    -- self.co = coroutine.create(function()
    --     while true do
    --         local idx,yieldRet = coroutine.yield()
    --         self:onEventData(yieldRet)
    --     end
    -- end)
    -- coroutine.resume(self.co, nil)
    self.pingIdx = 1
    self.tblPong = {}
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
    if self.tickPing then
        Scheduler:unscheduleGlobal(self.tickPing)
        self.tickPing = nil
    end
    self.tcp:disconnect()
    self.tcp:close()
    self.udp:close()
end

function SceneMain:onEventUdpData(INdata)
    if not INdata then return end
    self.index = self.index + 1
    local dataInfo = protobuf.decode("pb_common.data_head", INdata.data)
    protobuf.extract(dataInfo)
    --coroutine.resume(self.co, self.index, {type="udp",data=dataInfo})
    self:onEventData( {type="udp",data=dataInfo})
end

function SceneMain:onEventTcpData(INdata)
    self.recvStr = self.recvStr .. INdata.data
    local head_len = 4
    local strlen = string.len(self.recvStr)
    while strlen > head_len do
        local head_str = string.sub(self.recvStr,1,head_len)
        local _,data_len = string.unpack(head_str,"<I")
        if strlen >= head_len + data_len then
            local data_str = string.sub(self.recvStr,head_len + 1,head_len + data_len)
            local dataInfo = protobuf.decode("pb_common.data_head", data_str)
            protobuf.extract(dataInfo)
            self.index = self.index + 1
            --coroutine.resume(self.co, self.index, {type="tcp",data=dataInfo})
            self:onEventData( {type="tcp",data=dataInfo})
            self.recvStr = string.sub(self.recvStr,head_len + data_len+1,strlen)
            strlen = string.len(self.recvStr)
        else
            break
        end
    end
end

function SceneMain:onEventData(INdata)
    if not INdata then return end
    if "tcp" == INdata.type then
        -- protobuf.enum_id比较耗时
        if protobuf.enum_id("pb_common.protocol_code","protocol_begin") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_begin", INdata.data.data_str)
            protobuf.extract(dataInfo)
            math.randomseed(dataInfo.rand_seed)
            for k,v in pairs(dataInfo.userids) do
                if not self.entities[v] then self:createEntity(v) end
                if v == self.token then self.entity = self.entities[v] end
            end
            self.begin = true
        elseif protobuf.enum_id("pb_common.protocol_code","protocol_register_response") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_user_register_response", INdata.data.data_str)
            protobuf.extract(dataInfo)
            if dataInfo.return_code ~= 1 then return end
            cc.exports.USERID = dataInfo.userid
            self.token = dataInfo.userid
            self:ping()
            local pData = protobuf.encode('pb_common.data_user_join_room', {
                userid = self.token
            })
            self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_join_room"),pData)
        elseif protobuf.enum_id("pb_common.protocol_code","protocol_join_room_response") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_user_join_room_response", INdata.data.data_str)
            protobuf.extract(dataInfo)
            self.roomid = dataInfo.roomid
            local pData = protobuf.encode('pb_common.data_ready', {
                userid = self.token,
                roomid = self.roomid,
            })
            self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_ready"),pData)
        elseif protobuf.enum_id("pb_common.protocol_code","protocol_ready_response") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_ready_response", INdata.data.data_str)
            protobuf.extract(dataInfo)
            if dataInfo.return_code ~= 1 then
                print("join room error")
                return
            end
        elseif protobuf.enum_id("pb_common.protocol_code","protocol_tcp_close") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_tcp_close", INdata.data.data_str)
            protobuf.extract(dataInfo)
            if not self.entities[dataInfo.userid] then return end
            self.entities[dataInfo.userid]:removeFromParent()
            self.entities[dataInfo.userid] = nil
        elseif protobuf.enum_id("pb_common.protocol_code","protocol_leave_room_response") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_user_leave_room_response", INdata.data.data_str)
            protobuf.extract(dataInfo)
            if not self.entities[dataInfo.userid] then return end
            self.entities[dataInfo.userid]:removeFromParent()
            self.entities[dataInfo.userid] = nil
        end
    elseif "udp" == INdata.type then
        if 8 == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_frames", INdata.data.data_str)
            protobuf.extract(dataInfo)
            for i=1,#dataInfo.frames do
                local frameid = dataInfo.frames[i].frameid
                if self.syncFrameId < frameid then
                    self.serverFrames[frameid] = dataInfo.frames[i].frames
                end
            end
        elseif 13 == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_pong", INdata.data.data_str)
            protobuf.extract(dataInfo)
            if self.token ~= dataInfo.userid then return end
            self.tblPong[dataInfo.idx].endtime = socket.gettime()
        end
    end
end

function SceneMain:onEventTcpConnected()
    local pData = protobuf.encode('pb_common.data_user_register', {
        username = "",
        password = ""
    })
    self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_register"),pData)
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

function SceneMain:sendUdpData(INprotocal,INdata,INpkLoss)
    local pData = protobuf.encode('pb_common.data_head', {
        protocol_code = INprotocal,
        data_len = string.len(INdata),
        data_str = INdata
    })
    local rand = math.random(0,10)
    if INpkLoss and rand <= 0 then
        return true
    end
    self.udp:send(pData)
end

function SceneMain:ping()
    if not self.token or -1 == self.token then return end
    local total,count,packcount,delay = 0,0,10,"+999"
    for i=1,packcount do
        if self.tblPong[i] and self.tblPong[i].endtime then
            total = total + (self.tblPong[i].endtime-self.tblPong[i].time)
            count = count + 1
        end
    end
    if count ~= 0 then delay = tostring(math.floor(total*1000.0/count)) end
    print("lag:"..delay.."ms")
    self.tblPong = {}
    for i=1,packcount do
        self.tblPong[i] = {time=socket.gettime()}
        self:sendUdpData(12,protobuf.encode('pb_common.data_ping', {
            userid = self.token,
            idx = i
        }))
    end
end

function SceneMain:onKeyEventPressed(INkey,INrender)
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
    if INkey == cc.KeyCode.KEY_F1 then
        local pData = protobuf.encode('pb_common.data_user_register', {
            username = "test001",
            password = "test001"
        })
        self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_register"),pData)
    end
    if INkey == cc.KeyCode.KEY_F2 then
        local pData = protobuf.encode('pb_common.data_user_register', {
            username = "test002",
            password = "test002"
        })
        self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_register"),pData)
    end
    if INkey == cc.KeyCode.KEY_J then
        local pData = protobuf.encode('pb_common.data_user_join_room', {
            userid = self.token
        })
        self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_join_room"),pData)
    end
    if INkey == cc.KeyCode.KEY_R then
        local pData = protobuf.encode('pb_common.data_ready', {
            userid = self.token,
            roomid = self.roomid,
        })
        self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_ready"),pData)
    end
    if self.entity then self.entity:getKeyboardEvent("onKeyEventPressed",INkey) end
end

function SceneMain:onKeyEventReleased(INkey,INrender)
    if self.entity then self.entity:getKeyboardEvent("onKeyEventReleased",INkey) end
end

function SceneMain:convertOpeCode(INopeCode)
    local ahead, rotation = 0, 0
    if bit._and(INopeCode,0x01) > 0 then ahead = ahead + 1 end
    if bit._and(INopeCode,0x02) > 0 then ahead = ahead - 1 end
    if bit._and(INopeCode,0x04) > 0 then rotation = rotation - 1 end
    if bit._and(INopeCode,0x08) > 0 then rotation = rotation + 1 end
    return ahead, rotation
end

function SceneMain:createEntity(INtoken)
    local HandlerEntity = require "src.app.modules.map.NodeEntity"
    local entity = HandlerEntity.new(self)
    entity:setToken(INtoken)
    entity:addTo(self)
    entity:setPosition(cc.p(display.cx,display.cy))
    self.entities[INtoken] = entity
end

function SceneMain:lerpConstantSpeed(currentPos, targetPos, speed, dt)
    if not targetPos then return currentPos end
    local dx = targetPos.x - currentPos.x
    local dy = targetPos.y - currentPos.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance <= 0.1 then
        return targetPos
    end

    local moveDistance = speed * dt
    if moveDistance >= distance then
        return targetPos
    end

    local ratio = moveDistance / distance
    return cc.p(currentPos.x + dx * ratio, currentPos.y + dy * ratio)
end

function SceneMain:update(dt)
    if not self.begin then return end
    if not self.updateTick then self.updateTick = 0 end
    local const_dt = 1.0/15
    if self.updateTick >= const_dt then
        self.updateTick = self.updateTick - const_dt
        self:tickLogic(const_dt)
    end
    for k,v in pairs(self.entities) do
        if v then
            if k == self.token then
                local currentPos = cc.p(v:getPosition())
                local newPos = self:lerpConstantSpeed(currentPos, self.lastestPos, 100*0.2*15, dt)
                v:setPosition(newPos)
            else
                local currentPos = cc.p(v:getPosition())
                local newPos = self:lerpConstantSpeed(currentPos, self.otherPos, 100*0.2*15, dt)
                v:setPosition(newPos)
            end
        end
    end
    self.updateTick = self.updateTick + dt
end

function SceneMain:tickUpdate(dt)
    -- use fixed time and calculate 3 times per frame makes physics simulate more precisely
    for i=1,3 do
        self:getPhysicsWorld():step(1/90.0)
    end
end

function SceneMain:tickLogic(dt)
    if not self.begin then return end
    if not self.lastestPos then self.lastestPos = cc.p(self.entity:getPosition()) end
    if not self.syncStates then self.syncStates = cc.p(display.cx,display.cy) end
    self.frameId = self.frameId + 1
    local opeCodes = self.entity:getOpeCode()
    local ret = self:sendUdpData(8,protobuf.encode('pb_common.data_ope', {
        userid = self.token,
        frameid = self.frameId,
        opecode = opeCodes,
        ackframeid = self.syncFrameId
    }),true)
    if ret then
        --HLog:printf(string.format("player packet loss frameid:%d opeCode:%d",self.frameId,opeCodes))
    end
    if not self.inputsPending[self.frameId] then self.inputsPending[self.frameId] = {} end
    self.inputsPending[self.frameId] = opeCodes
    local x,y = self:convertOpeCode(opeCodes)
    if x ~= 0 or y ~= 0 then
        self.lastestPos.x = self.lastestPos.x + y * 100* 0.2
        self.lastestPos.y = self.lastestPos.y + x * 100* 0.2
    end

    while(self.serverFrames[self.syncFrameId+1]) do
        local frames = self.serverFrames[self.syncFrameId+1]
        if 0 == #frames then
            --HLog:printf(string.format("frames empty frameid:%d",self.syncFrameId+1))
        end
        for m=1,#frames do
            local v = frames[m]
            if v.userid == self.token then
                self.lastestPos.x = self.syncStates.x
                self.lastestPos.y = self.syncStates.y
                local x,y = self:convertOpeCode(v.opecode)
                if x ~= 0 or y ~= 0 then
                    self.lastestPos.x = self.lastestPos.x + y * 100* 0.2
                    self.lastestPos.y = self.lastestPos.y + x * 100* 0.2
                end
                self.syncStates = cc.p(self.lastestPos.x, self.lastestPos.y)
                --HLog:printf(string.format("[%04d]player userid %d apply frameid %04d opecode %04d logicPos %f:%f aheadPos %f:%f", self.syncFrameId+1,self.token,v.frameid,v.opecode,self.syncStates.x,self.syncStates.y,self.lastestPos.x,self.lastestPos.y))
                for i=v.frameid+1,self.frameId do
                    if self.inputsPending[i] then
                        x,y = self:convertOpeCode(self.inputsPending[i])
                        if x ~= 0 or y ~= 0 then
                            self.lastestPos.x = self.lastestPos.x + y * 100* 0.2
                            self.lastestPos.y = self.lastestPos.y + x * 100* 0.2
                        end
                    end
                end
            else
                if v.frameid > self.otherFrameid then
                    self.otherFrameid = v.frameid
                    local x,y = self:convertOpeCode(v.opecode)
                    if x ~= 0 or y ~= 0 then
                        self.otherPos.x = self.otherPos.x + y * 100* 0.2
                        self.otherPos.y = self.otherPos.y + x * 100* 0.2
                    end
                    --HLog:printf(string.format("userid %d frame %d opecode %d logicPos %f:%f",v.userid,self.otherFrameid,v.opecode,self.otherPos.x,self.otherPos.y))
                end
            end
        end
        self.syncFrameId = self.syncFrameId + 1
    end
    --print(string.format("predict frame %d acked frameid %d syncPos %f:%f localPos %f:%f",self.frameId,self.syncFrameId,self.syncStates.x,self.syncStates.y,self.lastestPos.x,self.lastestPos.y))
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