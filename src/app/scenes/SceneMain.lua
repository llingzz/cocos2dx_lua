local SceneMain = class("SceneMain", function()
    local scene = display.newScene("SceneMain")
    scene:initWithPhysics()
    scene:getPhysicsWorld():setGravity(cc.p(0, 0))
    scene:enableNodeEvents()
    return scene
end)

-- todo:N逻辑帧同步校验/断线重连/lua定点数封装
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

    -- 初始化碰撞系统
    local CollisionSystem = require("src.app.collision.CollisionSystem")
    self.collisionSystem = CollisionSystem.new()
    self.collisionSystem:setOnCollision(handler(self, self.onCollision))

    self.token = -1
    self.entity = nil
    self.entities = OrderedTable:new()
    self.nodeBullets = OrderedTable:new()
    self.begin = false
    self.roomid = 0

    -- 服务端下发的帧数据
    self.serverFrames = OrderedTable:new()
    self.frameId = 0
    -- 客户端同步过的帧号
    self.syncFrameId = 0
    self.inputsPending = OrderedTable:new()
    -- 待发送的发射操作队列
    self.pendingFires = {}
    self.lastFireTime = 0

    local keyBoardListener = cc.EventListenerKeyboard:create()
    keyBoardListener:registerScriptHandler(handler(self,self.onKeyEventPressed), cc.Handler.EVENT_KEYBOARD_PRESSED)
    keyBoardListener:registerScriptHandler(handler(self,self.onKeyEventReleased), cc.Handler.EVENT_KEYBOARD_RELEASED)
    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(keyBoardListener, self)

    self:scheduleUpdate(handler(self,self.update))
    self.tickPing = Scheduler:scheduleGlobal(handler(self,self.ping),0.5)
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
    if self.tickPing then
        Scheduler:unscheduleGlobal(self.tickPing)
        self.tickPing = nil
    end
    self.tcp:disconnect()
    self.tcp:close()
    self.udp:close()
    self:unscheduleUpdate()
end

function SceneMain:onEventUdpData(INdata)
    if not INdata then return end
    self.index = self.index + 1
    local dataInfo = protobuf.decode("pb_common.data_head", INdata.data)
    protobuf.extract(dataInfo)
    --coroutine.resume(self.co, self.index, {type="udp",data=dataInfo})
    self:onEventData({type="udp",data=dataInfo})
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
            self:onEventData({type="tcp",data=dataInfo})
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
        if protobuf.enum_id("pb_common.protocol_code","protocol_begin") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_begin", INdata.data.data_str)
            protobuf.extract(dataInfo)
            math.randomseed(dataInfo.rand_seed)
            for k,v in ipairs(dataInfo.playerinfos) do
                if not self.entities:get(v.userid) then self:createEntity(v) end
                if v.userid == self.token then self.entity = self.entities:get(v.userid) end
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
            if not self.entities:get(dataInfo.userid) then return end
            self.entities:get(dataInfo.userid):removeFromParent()
            self.entities:remove(dataInfo.userid)
        elseif protobuf.enum_id("pb_common.protocol_code","protocol_leave_room_response") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_user_leave_room_response", INdata.data.data_str)
            protobuf.extract(dataInfo)
            if not self.entities:get(dataInfo.userid) then return end
            self.entities:get(dataInfo.userid):removeFromParent()
            self.entities:remove(dataInfo.userid)
        end
    elseif "udp" == INdata.type then
        if 8 == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_frames", INdata.data.data_str)
            protobuf.extract(dataInfo)
            local frameid = 0
            for i=1,#dataInfo.frames do
                frameid = dataInfo.frames[i].frameid
                if self.syncFrameId < frameid then
                    self.serverFrames:set(frameid,dataInfo.frames[i].frames)
                    for k,v in ipairs(self.serverFrames:get(frameid)) do
                        v.cmds = {}
                        for kk,vv in ipairs(v.opecode) do
                            if 1 == vv.opetype then
                                local cmd = protobuf.decode("pb_common.ope_move", vv.opestring)
                                protobuf.extract(cmd)
                                cmd.opetype = 1
                                table.insert(v.cmds,cmd)
                            elseif 2 == vv.opetype then
                                local cmd = protobuf.decode("pb_common.ope_fire_bullet", vv.opestring)
                                protobuf.extract(cmd)
                                cmd.opetype = 2
                                table.insert(v.cmds,cmd)
                            end
                        end
                    end
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
    if not self.pingIdx then self.pingIdx = 1 end
    if not self.token or -1 == self.token then return end
    if self.pingIdx%10 == 0 and self.tblPong then
        local total,count = 0,0
        for k,v in pairs(self.tblPong) do
            if v and v.endtime and v.time then
                total = total + (v.endtime-v.time)
                count = count + 1
            end
        end
        self.tblPong = {}
        print("lag:"..math.floor(total*1000/count).."ms")
    end
    self:sendUdpData(12,protobuf.encode('pb_common.data_ping', {
        userid = self.token,
        idx = self.pingIdx
    }))
    self.tblPong[self.pingIdx] = {time=socket.gettime()}
    self.pingIdx = self.pingIdx + 1
end

function SceneMain:onKeyEventPressed(INkey,INrender)
    if self.entity then
        self.entity:getKeyboardEvent("onKeyEventPressed",INkey)
        -- 发射键按下时立即处理
        if cc.KeyCode.KEY_SPACE == INkey and self.begin then
            self:tryFire()
        end
    end
end

function SceneMain:onKeyEventReleased(INkey,INrender)
    if self.entity then self.entity:getKeyboardEvent("onKeyEventReleased",INkey) end
end

function SceneMain:tryFire()
    local now = socket.gettime()
    if now - self.lastFireTime < 0.3 then
        return
    end
    self.lastFireTime = now

    local curPos = cc.p(self.entity:getPosition())
    local rotation = self.entity:getRotation() % 360
    local bdir = cc.p(math.sin(rotation*math.pi/180),math.cos(rotation*math.pi/180))
    bdir = cc.pNormalize(bdir)

    local fireData = {
        startposx = HelpTools:toFixed(curPos.x),
        startposy = HelpTools:toFixed(curPos.y),
        directionx = HelpTools:toFixed(bdir.x*1000),
        directiony = HelpTools:toFixed(bdir.y*1000),
        rotation = rotation
    }

    -- 立即创建本地子弹
    local bulletId = self.token*1000000 + self.frameId + #self.pendingFires + 1
    self:createBullet(self.token, bulletId, curPos, fireData)

    -- 加入待发送队列
    table.insert(self.pendingFires, fireData)
end

function SceneMain:convertOpeCode(INopeCode,INpack)
    local ahead, rotation = 0, 0
    if bit._and(INopeCode,0x01) > 0 then ahead = ahead + 1 end
    if bit._and(INopeCode,0x02) > 0 then ahead = ahead - 1 end
    if bit._and(INopeCode,0x04) > 0 then rotation = rotation - 1 end
    if bit._and(INopeCode,0x08) > 0 then rotation = rotation + 1 end
    local dir = cc.p(0,0)
    if ahead ~= 0 then
        local rotation = self.entity:getRotation() % 360
        dir = cc.pMul(cc.p(math.cos(rotation*math.pi/180),math.sin(rotation*math.pi/180)),ahead)
        dir = cc.pNormalize(dir)
    end
    local ope_move = {
        movex = HelpTools:toFixed(dir.x*1000),
        movey = HelpTools:toFixed(dir.y*1000),
        turn = rotation
    }
    local resData = {}
    if INpack then
        table.insert(resData,{
            opetype = 1,
            opestring = protobuf.encode('pb_common.ope_move', ope_move)
        })
        -- 从队列中取出待发送的发射操作
        for _, fireData in ipairs(self.pendingFires) do
            table.insert(resData,{
                opetype = 2,
                opestring = protobuf.encode('pb_common.ope_fire_bullet', fireData)
            })
        end
        self.pendingFires = {}
    end
    return ope_move, resData
end

function SceneMain:createEntity(data)
    local CollisionSystem = require("src.app.collision.CollisionSystem")
    local HandlerEntity = require "src.app.modules.map.NodeEntity"
    local originPos = cc.p(ENTITY_ORIGIN_POS.x+data.index*100,ENTITY_ORIGIN_POS.y+data.index*100)
    local entity = HandlerEntity.new(self,originPos)
    entity:setToken(data.userid)
    entity:setIndex(data.index)
    entity:addTo(self)
    entity:setPosition(originPos)
    self.entities:set(data.userid,entity)
    -- 添加碰撞体
    self.collisionSystem:addCollider(
        entity,
        CollisionSystem.SHAPE_AABB,
        CollisionSystem.LAYER_PLAYER
    )
end

function SceneMain:createBullet(INuserid,INframeid,INpos,INdata)
    local CollisionSystem = require("src.app.collision.CollisionSystem")
    local bulletId = INuserid*1000000+INframeid
    if not self.nodeBullets:get(bulletId) then
        local HandlerBullet = require "src.app.modules.map.NodeBullet"
        -- 统一使用本地帧号，保证所有子弹在同一帧号体系下计算位置
        local bullet = HandlerBullet.new(bulletId,INuserid,self.frameId,INpos,cc.p(INdata.directionx,INdata.directiony))
        bullet:setPosition(INpos)
        bullet:setRotation(INdata.rotation)
        bullet:addTo(self)
        self.nodeBullets:set(bulletId,bullet)
        -- 添加碰撞体
        self.collisionSystem:addCollider(
            bullet,
            CollisionSystem.SHAPE_CIRCLE,
            CollisionSystem.LAYER_BULLET,
            { radius = BULLET_RADIUS }
        )
    end
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
    local const_dt = 1.0/LOGIC_FPS
    if self.updateTick >= const_dt then
        self.updateTick = self.updateTick - const_dt
        self:tickLogic(const_dt)
    end
    for k,v in self.entities:pairs() do
        if v then
            local currentPos = cc.p(v:getPosition())
            local newPos = self:lerpConstantSpeed(currentPos, v.logicInfo.pos, ENTITY_MOVE_SPEED*LOGIC_FPS, dt)
            v:setPosition(newPos)
            local rotation = v:getRotation()
            local newRotation = HelpTools:lerp(rotation, v.logicInfo.rotation, ENTITY_ROTATE_SPEED*LOGIC_FPS*dt)
            v:setRotation(newRotation)
        end
    end
    for k,v in self.nodeBullets:pairs() do
        if v and not v.destroy then
            local frameProgress = self.updateTick / (1.0/LOGIC_FPS)
            local elapsedFrames = (self.frameId - v.birthFrameId) + frameProgress
            local newPos = cc.p(
                v.birthPos.x + v.vx * elapsedFrames,
                v.birthPos.y + v.vy * elapsedFrames
            )
            v:setPosition(newPos)
        end
    end
    self.updateTick = self.updateTick + dt
end

function SceneMain:tickLogic(dt)
    if not self.begin then return end
    self.frameId = self.frameId + 1
    local opeCodes = self.entity:getOpeCode()
    local ope_move, data = self:convertOpeCode(opeCodes,true)
    local ret = self:sendUdpData(8,protobuf.encode('pb_common.data_ope', {
        userid = self.token,
        frameid = self.frameId,
        opecode = data,
        ackframeid = self.syncFrameId
    }),false)
    --if ret then HLog:printf(string.format("player packet loss frameid:%d opeCode:%d",self.frameId,opeCodes)) end
    if not self.inputsPending:get(self.frameId) then self.inputsPending:set(self.frameId,{}) end
    self.inputsPending:set(self.frameId,{
        move=ope_move
    })
    if ope_move.turn ~= 0 then
        self.entity.logicInfo.rotation = self.entity.logicInfo.rotation + ope_move.turn * ENTITY_ROTATE_SPEED
    end
    if ope_move.movex ~= 0 or ope_move.movey ~= 0 then
        self.entity.logicInfo.pos.x = self.entity.logicInfo.pos.x + HelpTools:toFixed(ENTITY_MOVE_SPEED * ope_move.movey / 1000)
        self.entity.logicInfo.pos.y = self.entity.logicInfo.pos.y + HelpTools:toFixed(ENTITY_MOVE_SPEED * ope_move.movex / 1000)
        self.entity.vx = HelpTools:toFixed(ENTITY_MOVE_SPEED * ope_move.movey / 1000)
        self.entity.vy = HelpTools:toFixed(ENTITY_MOVE_SPEED * ope_move.movex / 1000)
    end

    while(self.serverFrames:get(self.syncFrameId+1)) do
        local frames = self.serverFrames:get(self.syncFrameId+1)
        --if 0 == #frames then HLog:printf(string.format("frames empty frameid:%d",self.syncFrameId+1)) end
        for m=1,#frames do
            local v = frames[m]
            if v.userid == self.token then
                self.entity.logicInfo.pos.x = self.entity.syncState.pos.x
                self.entity.logicInfo.pos.y = self.entity.syncState.pos.y
                self.entity.logicInfo.rotation = self.entity.syncState.rotation
                for n=1,#v.cmds do
                    local vv = v.cmds[n]
                    if 1 == vv.opetype then
                        self.entity.logicInfo.pos.x = self.entity.logicInfo.pos.x + HelpTools:toFixed(ENTITY_MOVE_SPEED * vv.movey / 1000)
                        self.entity.logicInfo.pos.y = self.entity.logicInfo.pos.y + HelpTools:toFixed(ENTITY_MOVE_SPEED * vv.movex / 1000)
                        self.entity.logicInfo.rotation = self.entity.logicInfo.rotation + vv.turn * ENTITY_ROTATE_SPEED
                        self.entity.vx = HelpTools:toFixed(ENTITY_MOVE_SPEED * vv.movey / 1000)
                        self.entity.vy = HelpTools:toFixed(ENTITY_MOVE_SPEED * vv.movex / 1000)
                    end
                end
                self.entity.syncState.pos = cc.p(self.entity.logicInfo.pos.x, self.entity.logicInfo.pos.y)
                self.entity.syncState.rotation = self.entity.logicInfo.rotation
                --HLog:printf(string.format("[%04d]player userid %d apply frameid %04d opecode %04d logicPos %f:%f aheadPos %f:%f", self.syncFrameId+1,self.token,v.frameid,v.opecode,self.entity.syncState.pos.x,self.entity.syncState.pos.y,self.entity.logicInfo.pos.x,self.entity.logicInfo.pos.y))
                for i=v.frameid+1,self.frameId do
                    if self.inputsPending:get(i) then
                        local premove = self.inputsPending:get(i).move
                        if premove and (premove.movex ~= 0 or premove.movey ~= 0 or premove.turn ~= 0) then
                            self.entity.logicInfo.pos.x = self.entity.logicInfo.pos.x + HelpTools:toFixed(ENTITY_MOVE_SPEED * premove.movey / 1000)
                            self.entity.logicInfo.pos.y = self.entity.logicInfo.pos.y + HelpTools:toFixed(ENTITY_MOVE_SPEED * premove.movex / 1000)
                            self.entity.logicInfo.rotation = self.entity.logicInfo.rotation + premove.turn * ENTITY_ROTATE_SPEED
                            self.entity.vx = HelpTools:toFixed(ENTITY_MOVE_SPEED * premove.movey / 1000)
                            self.entity.vy = HelpTools:toFixed(ENTITY_MOVE_SPEED * premove.movex / 1000)
                        end
                    end
                end
            else
                local otherEntity = self.entities:get(v.userid)
                if not tolua.isnull(otherEntity) and v.frameid > otherEntity.syncFrameId then
                    otherEntity.syncFrameId = v.frameid
                    for n=1,#v.cmds do
                        local vv = v.cmds[n]
                        if 1 == vv.opetype then
                            otherEntity.logicInfo.pos.x = otherEntity.logicInfo.pos.x + HelpTools:toFixed(ENTITY_MOVE_SPEED * vv.movey / 1000)
                            otherEntity.logicInfo.pos.y = otherEntity.logicInfo.pos.y + HelpTools:toFixed(ENTITY_MOVE_SPEED * vv.movex / 1000)
                            otherEntity.logicInfo.rotation = otherEntity.logicInfo.rotation + vv.turn * ENTITY_ROTATE_SPEED
                            otherEntity.vx = HelpTools:toFixed(ENTITY_MOVE_SPEED * vv.movey / 1000)
                            otherEntity.vy = HelpTools:toFixed(ENTITY_MOVE_SPEED * vv.movex / 1000)
                        elseif 2 == vv.opetype then
                            self:createBullet(v.userid,v.frameid,cc.p(vv.startposx,vv.startposy),vv)
                        end
                    end
                    --HLog:printf(string.format("userid %d frame %d opecode %d logicPos %f:%f",v.userid,otherEntity.syncFrameId,v.opecode,otherEntity.logicInfo.pos.x,otherEntity.logicInfo.pos.y))
                end
            end
        end
        self.serverFrames:remove(self.syncFrameId+1)
        self.syncFrameId = self.syncFrameId + 1
    end

    -- 执行碰撞检测
    self.collisionSystem:update(self.frameId)
    --print(string.format("predict frame %d acked frameid %d syncPos %f:%f localPos %f:%f",self.frameId,self.syncFrameId,self.entity.syncState.pos.x,self.entity.syncState.pos.y,self.entity.logicInfo.pos.x,self.entity.logicInfo.pos.y))
end

function SceneMain:onCollision(colliderA, colliderB, frameId)
    local CollisionSystem = require("src.app.collision.CollisionSystem")
    local entityA = colliderA.entity
    local entityB = colliderB.entity

    -- 子弹与玩家碰撞
    if colliderA.layer == CollisionSystem.LAYER_BULLET and colliderB.layer == CollisionSystem.LAYER_PLAYER then
        self:onBulletHitPlayer(entityA, entityB, frameId)
    elseif colliderA.layer == CollisionSystem.LAYER_PLAYER and colliderB.layer == CollisionSystem.LAYER_BULLET then
        self:onBulletHitPlayer(entityB, entityA, frameId)
    end
end

function SceneMain:onBulletHitPlayer(bullet, player, frameId)
    -- 子弹不能击中自己
    if bullet.owner == player.token then
        return
    end

    -- 标记子弹销毁
    if not bullet.destroy then
        bullet.destroy = true
        bullet:setVisible(false)
        self.collisionSystem:removeCollider(bullet)
        print(string.format("[Frame %d] Bullet %d hit Player %d", frameId, bullet.id, player.token))
    end
end

return SceneMain