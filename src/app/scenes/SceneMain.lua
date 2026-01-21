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
    self.entities = OrderedTable:new()
    self.begin = false
    self.roomid = 0

    -- 服务端下发的帧数据
    self.serverFrames = OrderedTable:new()
    self.frameId = 0
    -- 客户端同步过的帧号
    self.syncFrameId = 0
    self.inputsPending = OrderedTable:new()
    self.syncStates = nil
    self.lastestPos = nil

    self.otherFrameid = 0
    self.otherPos = nil

    self.bullets = OrderedTable:new()
    self.nodeBullets = OrderedTable:new()

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
    if self.tickPhysicWorld then
        Scheduler:unscheduleGlobal(self.tickPhysicWorld)
        self.tickPhysicWorld = nil
    end
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
    if self.entity then self.entity:getKeyboardEvent("onKeyEventPressed",INkey) end
end

function SceneMain:onKeyEventReleased(INkey,INrender)
    if self.entity then self.entity:getKeyboardEvent("onKeyEventReleased",INkey) end
end

function SceneMain:convertOpeCode(INopeCode,INpack)
    local ahead, rotation, fire = 0, 0, false
    if bit._and(INopeCode,0x01) > 0 then ahead = ahead + 1 end
    if bit._and(INopeCode,0x02) > 0 then ahead = ahead - 1 end
    if bit._and(INopeCode,0x04) > 0 then rotation = rotation - 1 end
    if bit._and(INopeCode,0x08) > 0 then rotation = rotation + 1 end
    if bit._and(INopeCode,0x10) > 0 then fire = true end
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
    local ope_fire_bullet = nil
    if fire then
        local curPos = cc.p(self.entity:getPosition())
        local rotation = self.entity:getRotation() % 360
        local bdir = cc.p(math.sin(rotation*math.pi/180),math.cos(rotation*math.pi/180))
        bdir = cc.pNormalize(bdir)
        ope_fire_bullet = {
            startposx = HelpTools:toFixed(curPos.x),
            startposy = HelpTools:toFixed(curPos.y),
            directionx = HelpTools:toFixed(bdir.x*1000),
            directiony = HelpTools:toFixed(bdir.y*1000),
            rotation = rotation
        }
    end
    local resData = {}
    if INpack then
        if ope_move then
            table.insert(resData,{
                opetype = 1,
                opestring = protobuf.encode('pb_common.ope_move', ope_move)
            })
        end
        if ope_fire_bullet then
            table.insert(resData,{
                opetype = 2,
                opestring = protobuf.encode('pb_common.ope_fire_bullet', ope_fire_bullet)
            })
        end
    end
    return ope_move,ope_fire_bullet,resData
end

function SceneMain:createEntity(data)
    local HandlerEntity = require "src.app.modules.map.NodeEntity"
    local entity = HandlerEntity.new(self)
    entity:setToken(data.userid)
    entity:setIndex(data.index)
    entity:addTo(self)
    local originPos = cc.p(ENTITY_ORIGIN_POS.x+data.index*100,ENTITY_ORIGIN_POS.y+data.index*100)
    entity:setPosition(originPos)
    self.entities:set(data.userid,entity)
    if data.userid ~= self.token and not self.otherPos then
        self.otherPos = {
            pos = originPos,
            rotation = 0
        }
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
            if k == self.token then
                if self.lastestPos then
                    local currentPos = cc.p(v:getPosition())
                    local newPos = self:lerpConstantSpeed(currentPos, self.lastestPos.pos, ENTITY_MOVE_SPEED*LOGIC_FPS, dt)
                    v:setPosition(newPos)
                    local rotation = v:getRotation()
                    local newRotation = HelpTools:lerp(rotation, self.lastestPos.rotation, ENTITY_ROTATE_SPEED*LOGIC_FPS*dt)
                    v:setRotation(newRotation)
                end
            else
                if self.otherPos then
                    local currentPos = cc.p(v:getPosition())
                    local newPos = self:lerpConstantSpeed(currentPos, self.otherPos.pos, ENTITY_MOVE_SPEED*LOGIC_FPS, dt)
                    v:setPosition(newPos)
                    local rotation = v:getRotation()
                    local newRotation = HelpTools:lerp(rotation, self.otherPos.rotation, ENTITY_ROTATE_SPEED*LOGIC_FPS*dt)
                    v:setRotation(newRotation)
                end
            end
        end
    end
    for k,v in self.bullets:pairs() do
        if not self.nodeBullets:get(v.id) and v.active then
            local bullet = display.newSprite("res/bullet.png")
            bullet:addTo(self)
            bullet:setPosition(cc.p(v.startpos))
            bullet:setRotation(v.rotation)
            self.nodeBullets:set(v.id,bullet)
        end
        local bullet = self.nodeBullets:get(v.id)
        if bullet then
            local currentPos = cc.p(bullet:getPosition())
            local newPos = self:lerpConstantSpeed(currentPos, v.targetpos, BULLET_MOVE_SPEED*LOGIC_FPS, dt)
            bullet:setPosition(newPos)
            local dis = cc.pGetDistance(newPos,v.targetpos)
            if dis < 10 and v.destroy then
                bullet:removeFromParent()
                self.nodeBullets:remove(v.id)
                self.bullets:remove(v.id)
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
    if not self.lastestPos then
        self.lastestPos = {
            pos = cc.p(self.entity:getPosition()),
            rotation = 0,
        }
    end
    if not self.syncStates then
        self.syncStates = {
            pos = cc.p(ENTITY_ORIGIN_POS.x+self.entity.index*100,ENTITY_ORIGIN_POS.y+self.entity.index*100),
            rotation = 0,
        }
    end

    self.frameId = self.frameId + 1
    local opeCodes = self.entity:getOpeCode()
    local ope_move,ope_fire_bullet,data = self:convertOpeCode(opeCodes,true)
    local ret = self:sendUdpData(8,protobuf.encode('pb_common.data_ope', {
        userid = self.token,
        frameid = self.frameId,
        opecode = data,
        ackframeid = self.syncFrameId
    }),false)
    --if ret then HLog:printf(string.format("player packet loss frameid:%d opeCode:%d",self.frameId,opeCodes)) end
    if not self.inputsPending:get(self.frameId) then self.inputsPending:set(self.frameId,{}) end
    self.inputsPending:set(self.frameId,{
        move=ope_move,
        fire=ope_fire_bullet
    })
    if ope_fire_bullet then
        local bulletId = self.token*1000000+self.frameId
        if not self.bullets:get(bulletId) then
            local bullet = {
                id = bulletId,
                owner = self.token,
                frameid = self.frameId,
                startpos = cc.p(self.entity:getPosition()),
                targetpos = cc.p(ope_fire_bullet.startposx,ope_fire_bullet.startposy),
                direction = cc.p(ope_fire_bullet.directionx/1000,ope_fire_bullet.directiony/1000),
                rotation  = ope_fire_bullet.rotation,
                active = true,
                syncPos = cc.p(self.entity:getPosition())
            }
            self.bullets:set(bulletId,bullet)
            --HLog:printf(string.format("[bullet][%d][%06d] id:%d begin targetpos:%f,%f",bulletId,self.frameId,self.token,bullet.targetpos.x,bullet.targetpos.y))
        end
    end
    if ope_move.turn ~= 0 then
        self.lastestPos.rotation = self.lastestPos.rotation + ope_move.turn * ENTITY_ROTATE_SPEED
    end
    if ope_move.movex ~= 0 or ope_move.movey ~= 0 then
        self.lastestPos.pos.x = self.lastestPos.pos.x + HelpTools:toFixed(ENTITY_MOVE_SPEED * ope_move.movey / 1000)
        self.lastestPos.pos.y = self.lastestPos.pos.y + HelpTools:toFixed(ENTITY_MOVE_SPEED * ope_move.movex / 1000)
    end

    while(self.serverFrames:get(self.syncFrameId+1)) do
        local frames = self.serverFrames:get(self.syncFrameId+1)
        --if 0 == #frames then HLog:printf(string.format("frames empty frameid:%d",self.syncFrameId+1)) end
        for m=1,#frames do
            local v = frames[m]
            if v.userid == self.token then
                self.lastestPos.pos.x = self.syncStates.pos.x
                self.lastestPos.pos.y = self.syncStates.pos.y
                self.lastestPos.rotation = self.syncStates.rotation
                for n=1,#v.cmds do
                    local vv = v.cmds[n]
                    if 1 == vv.opetype then
                        self.lastestPos.pos.x = self.lastestPos.pos.x + HelpTools:toFixed(ENTITY_MOVE_SPEED * vv.movey / 1000)
                        self.lastestPos.pos.y = self.lastestPos.pos.y + HelpTools:toFixed(ENTITY_MOVE_SPEED * vv.movex / 1000)
                        self.lastestPos.rotation = self.lastestPos.rotation + vv.turn * ENTITY_ROTATE_SPEED
                    end
                end

                for bk,bv in self.bullets:pairs() do
                    if bv.owner == self.token and v.frameid > bv.frameid then
                        bv.lasttargetpos = cc.p(bv.targetpos.x,bv.targetpos.y)
                        bv.targetpos.x = bv.syncPos.x
                        bv.targetpos.y = bv.syncPos.y
                        for i=bv.frameid+1,v.frameid do
                            bv.targetpos.x = bv.targetpos.x + HelpTools:toFixed(bv.direction.x*BULLET_MOVE_SPEED)
                            bv.targetpos.y = bv.targetpos.y + HelpTools:toFixed(bv.direction.y*BULLET_MOVE_SPEED)
                            bv.frameid = i
                            --HLog:printf(string.format("[bullet][%d][%06d] id:%d targetpos:%f,%f",bv.id,bv.frameid,self.token,bv.targetpos.x,bv.targetpos.y))
                        end
                        bv.syncPos.x = bv.targetpos.x
                        bv.syncPos.y = bv.targetpos.y
                    end
                end

                self.syncStates.pos = cc.p(self.lastestPos.pos.x, self.lastestPos.pos.y)
                self.syncStates.rotation = self.lastestPos.rotation
                --HLog:printf(string.format("[%04d]player userid %d apply frameid %04d opecode %04d logicPos %f:%f aheadPos %f:%f", self.syncFrameId+1,self.token,v.frameid,v.opecode,self.syncStates.x,self.syncStates.y,self.lastestPos.x,self.lastestPos.y))
                for i=v.frameid+1,self.frameId do
                    if self.inputsPending:get(i) then
                        local premove = self.inputsPending:get(i).move
                        if premove and (premove.movex ~= 0 or premove.movey ~= 0 or premove.turn ~= 0) then
                            self.lastestPos.pos.x = self.lastestPos.pos.x + HelpTools:toFixed(ENTITY_MOVE_SPEED * premove.movey / 1000)
                            self.lastestPos.pos.y = self.lastestPos.pos.y + HelpTools:toFixed(ENTITY_MOVE_SPEED * premove.movex / 1000)
                            self.lastestPos.rotation = self.lastestPos.rotation + premove.turn * ENTITY_ROTATE_SPEED
                        end
                    end
                    for kk,vv in self.bullets:pairs() do
                        if vv.owner == self.token and not vv.destroy then
                            vv.lasttargetpos = cc.p(vv.targetpos.x,vv.targetpos.y)
                            vv.targetpos.x = vv.targetpos.x + HelpTools:toFixed(vv.direction.x*BULLET_MOVE_SPEED)
                            vv.targetpos.y = vv.targetpos.y + HelpTools:toFixed(vv.direction.y*BULLET_MOVE_SPEED)
                            --HLog:printf(string.format("[bullet][%d][%06d] id:%d predict targetpos:%f,%f",vv.id,i,self.token,vv.targetpos.x,vv.targetpos.y))
                        end
                    end
                end
            else
                if v.frameid > self.otherFrameid then
                    self.otherFrameid = v.frameid
                    for n=1,#v.cmds do
                        local vv = v.cmds[n]
                        if 1 == vv.opetype then
                            self.otherPos.pos.x = self.otherPos.pos.x + HelpTools:toFixed(ENTITY_MOVE_SPEED * vv.movey / 1000)
                            self.otherPos.pos.y = self.otherPos.pos.y + HelpTools:toFixed(ENTITY_MOVE_SPEED * vv.movex / 1000)
                            self.otherPos.rotation = self.otherPos.rotation + vv.turn * ENTITY_ROTATE_SPEED
                        elseif 2 == vv.opetype then
                            local bulletId = v.userid*1000000+v.frameid
                            if not self.bullets:get(bulletId) then
                                local bullet = {
                                    id = v.userid*1000000+v.frameid,
                                    owner = v.userid,
                                    frameid = v.frameid,
                                    startpos = cc.p(vv.startposx,vv.startposy),
                                    targetpos = cc.p(vv.startposx,vv.startposy),
                                    lasttargetpos = cc.p(vv.startposx,vv.startposy),
                                    direction = cc.p(vv.directionx/1000,vv.directiony/1000),
                                    rotation  = vv.rotation
                                }
                                self.bullets:set(bulletId,bullet)
                                --HLog:printf(string.format("[bullet][%d][%06d] id:%d begin targetpos:%f,%f",bullet.id,v.frameid,self.token,bullet.targetpos.x,bullet.targetpos.y))
                            end
                        end
                    end
                    --HLog:printf(string.format("userid %d frame %d opecode %d logicPos %f:%f",v.userid,self.otherFrameid,v.opecode,self.otherPos.x,self.otherPos.y))
                    for kk,vv in self.bullets:pairs() do
                        if vv.owner ~= self.token and vv.frameid < self.otherFrameid and not vv.destroy then
                            for i=vv.frameid+1,self.otherFrameid do
                                vv.lasttargetpos = cc.p(vv.targetpos.x,vv.targetpos.y)
                                vv.active = true
                                vv.targetpos.x = vv.targetpos.x + HelpTools:toFixed(vv.direction.x*BULLET_MOVE_SPEED)
                                vv.targetpos.y = vv.targetpos.y + HelpTools:toFixed(vv.direction.y*BULLET_MOVE_SPEED)
                                vv.frameid = i
                                --HLog:printf(string.format("[bullet][%d][%06d] id:%d targetpos:%f,%f",vv.id,vv.frameid,self.token,vv.targetpos.x,vv.targetpos.y))
                            end
                        end
                    end
                end
            end
        end
        self.serverFrames:remove(self.syncFrameId+1)
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