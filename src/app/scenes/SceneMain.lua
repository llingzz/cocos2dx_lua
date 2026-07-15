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
    self.nodeBullets = OrderedTable:new()
    self.begin = false
    self.roomid = 0
    self.isDisconnected = false
    -- 是否是观战
    self.spectate = false

    -- 服务端下发的帧数据
    self.serverFrames = OrderedTable:new()
    self.frameId = 0
    -- 客户端同步过的帧号
    self.syncFrameId = 0
    self.inputsPending = OrderedTable:new()
    -- 上次发射子弹的帧号
    self.lastFireFrameId = 0
    -- 每STATE_VERIFY_FRAME_INTERVAL帧校验一次
    self.lastVerifyFrameId = 0

    local keyBoardListener = cc.EventListenerKeyboard:create()
    keyBoardListener:registerScriptHandler(handler(self,self.onKeyEventPressed), cc.Handler.EVENT_KEYBOARD_PRESSED)
    keyBoardListener:registerScriptHandler(handler(self,self.onKeyEventReleased), cc.Handler.EVENT_KEYBOARD_RELEASED)
    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(keyBoardListener, self)

    local mouseListener = cc.EventListenerMouse:create()
    mouseListener:registerScriptHandler(handler(self,self.onMouseEventMove), cc.Handler.EVENT_MOUSE_MOVE)
    eventDispatcher:addEventListenerWithSceneGraphPriority(mouseListener, self)

    self:scheduleUpdate(handler(self,self.update))
    self.tickPing = Scheduler:scheduleGlobal(handler(self,self.ping),0.5)
    self.txLag = ccui.Text:create():setString(""):addTo(self)
    :setFontSize(30)
    :setPosition(cc.p(display.width, display.top-15))
    :setAnchorPoint(cc.p(1, 0.5))
    :setVisible(true)
    self.frameInfo = ccui.Text:create():setString("frame:0"):addTo(self)
    :setFontSize(30)
    :setPosition(cc.p(0, display.top-15))
    :setAnchorPoint(cc.p(0, 0.5))
    :setVisible(self.begin)
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
        elseif protobuf.enum_id("pb_common.protocol_code","protocol_login_reponse") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_user_login_response", INdata.data.data_str)
            protobuf.extract(dataInfo)
            cc.exports.USERID = dataInfo.userid
            self.token = dataInfo.userid
            self:ping()
            if dataInfo.ingame == 0 then
                local flag = 0
                if self.spectate then flag = 1 end
                local pData = protobuf.encode('pb_common.data_user_join_room', {
                    userid = self.token,
                    flag = flag,
                    roomid = 0
                })
                self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_join_room"),pData)
            else
                self.roomid = dataInfo.roomid
                self.syncFrameId = dataInfo.frameid
                self.frameId = self.syncFrameId
                for k,v in ipairs(dataInfo.begin.playerinfos) do
                    if not self.entities:get(v.userid) then self:createEntity(v) end
                    self.entities:get(v.userid):hide()
                    if v.userid == self.token then self.entity = self.entities:get(v.userid) end
                end
                local pData = protobuf.encode('pb_common.data_repair_frames',{
                    userid = self.token,
                    roomid = dataInfo.roomid,
                    flag = 1
                })
                self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_repair_frames"),pData)
            end
        elseif protobuf.enum_id("pb_common.protocol_code","protocol_join_room_response") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_user_join_room_response", INdata.data.data_str)
            protobuf.extract(dataInfo)
            self.roomid = dataInfo.roomid
            if 0 == dataInfo.flag then
                local pData = protobuf.encode('pb_common.data_ready', {
                    userid = self.token,
                    roomid = self.roomid,
                })
                self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_ready"),pData)
            else
                for k,v in ipairs(dataInfo.begin.playerinfos) do
                    if not self.entities:get(v.userid) then self:createEntity(v) end
                    local entity = self.entities:get(v.userid)
                    entity:hide()
                end
                local pData = protobuf.encode('pb_common.data_ready', {
                    userid = self.token,
                    roomid = self.roomid,
                })
                self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_ready"),pData)
            end
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
        elseif protobuf.enum_id("pb_common.protocol_code","protocol_repair_frames_response") == INdata.data.protocol_code then
            local dataInfo = protobuf.decode("pb_common.data_repair_frames_response", INdata.data.data_str)
            protobuf.extract(dataInfo)
            local frameid = 0
            if dataInfo.flag ~= 0 then
                self.begin = true
            end
            for i=1,#dataInfo.frames.frames do
                frameid = dataInfo.frames.frames[i].frameid
                if self.syncFrameId < frameid then
                    self.serverFrames:set(frameid,dataInfo.frames.frames[i].frames)
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
            self:fastForwardFrames()
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
            if self.spectate then
                if not self.begin then
                    self.begin = true
                    self:fastForwardFrames()
                end
                self:sendUdpData(8,protobuf.encode('pb_common.data_ope', {
                    userid = self.token,
                    frameid = 0,
                    opecode = {},
                    ackframeid = self.syncFrameId
                }),false)
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
    if not self.isDisconnected then return end
    self.isDisconnected = false
    if self.roomid ~= 0 then
        local pData = protobuf.encode('pb_common.data_repair_frames',{
            userid = self.token,
            roomid = self.roomid,
            flag = 0
        })
        self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_repair_frames"),pData)
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

function SceneMain:sendUdpData(INprotocal,INdata,INpkLoss)
    if self.isDisconnected then return true end
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
                total = total + (v.endtime-v.time)/2
                count = count + 1
            end
        end
        self.tblPong = {}
        self.txLag:setVisible(true)
        self.txLag:setString(""..math.floor(total*1000/count).."ms")
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
    end
    if cc.KeyCode.KEY_K == INkey then
        self:simulateDisconnectAndReconnect()
    end
    if cc.KeyCode.KEY_F1 == INkey then
        local pData = protobuf.encode('pb_common.data_user_login', {
            userid = 1,
            password = ""
        })
        self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_login"),pData)
    end
    if cc.KeyCode.KEY_F2 == INkey then
        local pData = protobuf.encode('pb_common.data_user_login', {
            userid = 2,
            password = ""
        })
        self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_login"),pData)
    end
    if cc.KeyCode.KEY_F3 == INkey then
        self.spectate = true
        local pData = protobuf.encode('pb_common.data_user_login', {
            userid = 3,
            password = ""
        })
        self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_login"),pData)
    end
end

function SceneMain:onKeyEventReleased(INkey,INrender)
    if self.entity then self.entity:getKeyboardEvent("onKeyEventReleased",INkey) end
end

function SceneMain:onMouseEventMove(INevent)
    if not self.begin then return end
    local posCursor = cc.p(INevent:getCursorX(),INevent:getCursorY())
    self.posCursor = posCursor
end

function SceneMain:convertOpeCode(INopeCode)
    local ahead, rotation, fire = 0, 0, 0
    if bit._and(INopeCode,0x01) > 0 then ahead = ahead + 1 end
    if bit._and(INopeCode,0x02) > 0 then ahead = ahead - 1 end
    if bit._and(INopeCode,0x04) > 0 then rotation = rotation - 1 end
    if bit._and(INopeCode,0x08) > 0 then rotation = rotation + 1 end
    local now = socket.gettime()
    if bit._and(INopeCode,0x10) > 0 and self.frameId - self.lastFireFrameId >= FIRE_BULLET_FRAME_INTERVAL then
        self.lastFireFrameId = self.frameId
        fire = 1
    end

    -- 计算炮管的角度
    local barrel_rotation = 0
    if self.posCursor then
        local posCursor = cc.pSub(self.posCursor,cc.p(self.entity:getPosition()))
        local rotation = self.entity:getRotation()
        local dir_entity = cc.p(math.sin(rotation*math.pi/180),math.cos(rotation*math.pi/180))
        local dir_cursor = cc.pNormalize(posCursor)
        local dot = dir_entity.x * dir_cursor.x + dir_entity.y * dir_cursor.y
        local cross = dir_entity.x * dir_cursor.y - dir_entity.y * dir_cursor.x
        -- math.atan2(cross, dot) 返回逆时针有符号弧度（-π ~ π）
        local rad_ccw = math.atan2(cross, dot)
        -- 顺时针角度 = 取反后归一化到 [0, 2π)
        local rad_cw = (2 * math.pi - rad_ccw) % (2 * math.pi)
        barrel_rotation = math.deg(rad_cw)
    end

    local dir = cc.p(0,0)
    if ahead ~= 0 then
        local rotation = self.entity:getRotation() % 360
        dir = cc.pMul(cc.p(math.cos(rotation*math.pi/180),math.sin(rotation*math.pi/180)),ahead)
        dir = cc.pNormalize(dir)
    end
    local resData = {}
    local ope_move = {
        movex = math.floor(dir.x*NUMBER_SCALE),
        movey = math.floor(dir.y*NUMBER_SCALE),
        turn = rotation,
        barrel_rotation = barrel_rotation
    }
    table.insert(resData,{
        opetype = 1,
        opestring = protobuf.encode('pb_common.ope_move', ope_move)
    })
    local ope_fire = {
        fire = fire
    }
    table.insert(resData,{
        opetype = 2,
        opestring = protobuf.encode('pb_common.ope_fire_bullet', ope_fire)
    })
    return ope_move, resData
end

function SceneMain:createEntity(data)
    local HandlerEntity = require "src.app.modules.map.NodeEntity"
    local originPos = cc.p(ENTITY_ORIGIN_POS.x+data.index*100,ENTITY_ORIGIN_POS.y+data.index*100)
    local entity = HandlerEntity.new(self,cc.p(math.floor(originPos.x*NUMBER_SCALE), math.floor(originPos.y*NUMBER_SCALE)))
    entity:setToken(data.userid)
    entity:setIndex(data.index)
    entity:addTo(self)
    entity:setPosition(originPos)
    self.entities:set(data.userid,entity)
end

function SceneMain:createBullet(INuserid,INframeid,INpos,INbirPos,INdata,INinitShow)
    local bulletId = INuserid*1000000+1+INframeid
    if not self.nodeBullets:get(bulletId) then
        local HandlerBullet = require "src.app.modules.map.NodeBullet"
        local bullet = HandlerBullet.new(bulletId,INuserid,INframeid,INpos,cc.p(INdata.directionx,INdata.directiony))
        bullet:setPosition(cc.p(math.floor(INbirPos.x/NUMBER_SCALE), math.floor(INbirPos.y/NUMBER_SCALE)))
        bullet:setRotation(INdata.rotation)
        bullet:addTo(self)
        self.nodeBullets:set(bulletId,bullet)
        if INinitShow ~= nil then
            bullet:setVisible(INinitShow)
        end
    end
end

function SceneMain:lerpConstantSpeed(currentPos, targetPos, speed, dt)
    if not targetPos then return currentPos,false end
    local dx = targetPos.x - currentPos.x
    local dy = targetPos.y - currentPos.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance <= 0.1 then
        return targetPos,true
    end

    local moveDistance = speed * dt
    if moveDistance >= distance then
        return targetPos,true
    end

    local ratio = moveDistance / distance
    return cc.p(currentPos.x + dx * ratio, currentPos.y + dy * ratio),false
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
            local targetPos = cc.p(math.floor(v.logicInfo.pos.x/NUMBER_SCALE), math.floor(v.logicInfo.pos.y/NUMBER_SCALE))
            local newPos = self:lerpConstantSpeed(currentPos, targetPos, ENTITY_MOVE_SPEED*LOGIC_FPS, dt)
            v:setPosition(newPos)
            local rotation = v:getRotation()
            local newRotation = HelpTools:lerp(rotation, v.logicInfo.rotation, ENTITY_ROTATE_SPEED*LOGIC_FPS*dt)
            v:setRotation(newRotation)
            v:updateNodeUI(newRotation)
            local barrel_rotation = v.barrel:getRotation()
            local newBarrelRotation = HelpTools:lerp(barrel_rotation, v.logicInfo.barrel_rotation, ENTITY_ROTATE_SPEED*LOGIC_FPS*dt)
            v.barrel:setRotation(newBarrelRotation)
        end
    end
    for k,v in self.nodeBullets:pairs() do
        if v then
            local targetPos = nil
            local currentPos = cc.p(v:getPosition())
            if not v.destroy then targetPos = v:getLogicPos(self.syncFrameId)
            else
                targetPos = v.hitPos
            end
            if targetPos then
                targetPos = cc.p(math.floor(targetPos.x/NUMBER_SCALE), math.floor(targetPos.y/NUMBER_SCALE))
            end
            local newPos,ret = self:lerpConstantSpeed(currentPos, targetPos, BULLET_MOVE_SPEED*LOGIC_FPS, dt)
            v:setPosition(newPos)
            if v.destroy and ret then
                self.nodeBullets:remove(v.id)
                v:removeFromParent()
            end
        end
    end
    self.updateTick = self.updateTick + dt
end

function SceneMain:tickLogic(dt)
    if not self.begin then return end
    if self.isDisconnected then return end

    -- 预输入
    if not self.spectate and (self.frameId < MAX_PREDICT_FRAME_COUNT or self.frameId - self.syncFrameId < MAX_PREDICT_FRAME_COUNT) then
        self.frameId = self.frameId + 1
        local opeCodes = self.entity:getOpeCode()
        local ope_move, data = self:convertOpeCode(opeCodes)
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
            self.entity.logicInfo.pos.x = self.entity.logicInfo.pos.x + ENTITY_MOVE_SPEED * ope_move.movey
            self.entity.logicInfo.pos.y = self.entity.logicInfo.pos.y + ENTITY_MOVE_SPEED * ope_move.movex
        end
    end

    while(self.serverFrames:get(self.syncFrameId+1)) do
        self:updateCollisionData()
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
                        self.entity.logicInfo.pos.x = self.entity.logicInfo.pos.x + ENTITY_MOVE_SPEED * vv.movey
                        self.entity.logicInfo.pos.y = self.entity.logicInfo.pos.y + ENTITY_MOVE_SPEED * vv.movex
                        self.entity.logicInfo.rotation = self.entity.logicInfo.rotation + vv.turn * ENTITY_ROTATE_SPEED
                        self.entity.logicInfo.barrel_rotation = vv.barrel_rotation
                    elseif 2 == vv.opetype and vv.fire == 1 then
                        local rotation = (self.entity.logicInfo.barrel_rotation + self.entity.logicInfo.rotation) % 360
                        local bdir = BulletRotationToSpeed[rotation]
                        local originPos = cc.pMul(cc.p(self.entity:getPosition()),NUMBER_SCALE)
                        originPos = cc.pAdd(cc.p(math.floor(originPos.x),math.floor(originPos.y)),cc.pMul(bdir,NUMBER_SCALE))
                        local logicPos = cc.pAdd(self.entity.logicInfo.pos,cc.pMul(bdir,NUMBER_SCALE))
                        self:createBullet(v.userid,self.syncFrameId,logicPos,originPos,{directionx = bdir.x*NUMBER_SCALE, directiony = bdir.y*NUMBER_SCALE, rotation = rotation})
                        --HLog:printf(string.format("fire at frame %05d, logic pos %d:%d dir %d:%d", self.syncFrameId, logicPos.x, logicPos.y, bdir.x, bdir.y))
                    end
                end
                self.entity.syncState.pos = cc.p(self.entity.logicInfo.pos.x, self.entity.logicInfo.pos.y)
                self.entity.syncState.rotation = self.entity.logicInfo.rotation
                --HLog:printf(string.format("[%04d]player userid %d apply frameid %04d opecode %04d logicPos %f:%f aheadPos %f:%f", self.syncFrameId+1,self.token,v.frameid,v.opecode,self.entity.syncState.pos.x,self.entity.syncState.pos.y,self.entity.logicInfo.pos.x,self.entity.logicInfo.pos.y))
                for i=v.frameid+1,self.frameId do
                    if self.inputsPending:get(i) then
                        local premove = self.inputsPending:get(i).move
                        if premove and (premove.movex ~= 0 or premove.movey ~= 0 or premove.turn ~= 0) then
                            self.entity.logicInfo.pos.x = self.entity.logicInfo.pos.x + ENTITY_MOVE_SPEED * premove.movey
                            self.entity.logicInfo.pos.y = self.entity.logicInfo.pos.y + ENTITY_MOVE_SPEED * premove.movex
                            self.entity.logicInfo.rotation = self.entity.logicInfo.rotation + premove.turn * ENTITY_ROTATE_SPEED
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
                            otherEntity.logicInfo.pos.x = otherEntity.logicInfo.pos.x + ENTITY_MOVE_SPEED * vv.movey
                            otherEntity.logicInfo.pos.y = otherEntity.logicInfo.pos.y + ENTITY_MOVE_SPEED * vv.movex
                            otherEntity.logicInfo.rotation = otherEntity.logicInfo.rotation + vv.turn * ENTITY_ROTATE_SPEED
                            otherEntity.logicInfo.barrel_rotation = vv.barrel_rotation
                        elseif 2 == vv.opetype and vv.fire == 1 then
                            local rotation = (otherEntity.logicInfo.barrel_rotation + otherEntity.logicInfo.rotation) % 360
                            local bdir = BulletRotationToSpeed[rotation]
                            local originPos = cc.pMul(cc.p(otherEntity:getPosition()),NUMBER_SCALE)
                            originPos = cc.pAdd(cc.p(math.floor(originPos.x),math.floor(originPos.y)),cc.pMul(bdir,NUMBER_SCALE))
                            local logicPos = cc.pAdd(otherEntity.logicInfo.pos,cc.pMul(bdir,NUMBER_SCALE))
                            self:createBullet(v.userid,self.syncFrameId,logicPos,originPos,{directionx = bdir.x*NUMBER_SCALE, directiony = bdir.y*NUMBER_SCALE, rotation = rotation})
                            --HLog:printf(string.format("fire at frame %05d, logic pos %d:%d dir %d:%d", self.syncFrameId, logicPos.x, logicPos.y, bdir.x, bdir.y))
                        end
                    end
                    --HLog:printf(string.format("userid %d frame %d opecode %d logicPos %f:%f",v.userid,otherEntity.syncFrameId,v.opecode,otherEntity.logicInfo.pos.x,otherEntity.logicInfo.pos.y))
                end
            end
        end
        self.serverFrames:remove(self.syncFrameId+1)
        self.syncFrameId = self.syncFrameId + 1
        self.frameInfo:setVisible(self.begin)
        self.frameInfo:setString("frame:"..self.syncFrameId)

        -- 碰撞检测
        self:checkCollision()

        -- 定期校验状态
        if not self.spectate and self.syncFrameId % STATE_VERIFY_FRAME_INTERVAL == 0 and self.syncFrameId > self.lastVerifyFrameId then
            self:sendStateVerify(self.syncFrameId)
            self.lastVerifyFrameId = self.syncFrameId
        end
    end
    --print(string.format("predict frame %d acked frameid %d syncPos %f:%f localPos %f:%f",self.frameId,self.syncFrameId,self.entity.syncState.pos.x,self.entity.syncState.pos.y,self.entity.logicInfo.pos.x,self.entity.logicInfo.pos.y))
end

-- 碰撞检测：连续检测，子弹使用相对运动，玩家固定在原点，将子弹和玩家尺寸拓展为一个
-- 拓展的矩形，将子弹抽象成一个点，等价变换为子弹运动轨迹的线段和AABB包围盒求相交的问题
-- 相交问题采用：Liang-Barsky 裁剪算法原理
function SceneMain:checkBulletPlayerCollision(player, bullet)
    -- 计算子弹相对于玩家的运动线段（起点和终点）
    local rel_start_x = bullet.prev_x - player.prev_x
    local rel_start_y = bullet.prev_y - player.prev_y
    local rel_end_x   = bullet.curr_x - player.curr_x
    local rel_end_y   = bullet.curr_y - player.curr_y

    local dx = rel_end_x - rel_start_x
    local dy = rel_end_y - rel_start_y

    -- 扩展后的矩形半宽、半高（玩家 + 子弹）
    local ext_hw = player.hw + bullet.hw
    local ext_hh = player.hh + bullet.hh
 
    -- 矩形边界（以原点为中心）
    local left   = -ext_hw
    local right  =  ext_hw
    local bottom = -ext_hh
    local top    =  ext_hh

    -- Liang-Barsky 线段裁剪，求入口参数 t_enter
    local p = { -dx, dx, -dy, dy }
    local q = { rel_start_x - left, right - rel_start_x, rel_start_y - bottom, top - rel_start_y }

    -- t_enter 和 t_exit 表示为最简分数 (num/den)，den>0
    local t_enter_num, t_enter_den = 0, 1   -- t=0
    local t_exit_num,  t_exit_den  = 1, 1   -- t=1

    for i = 1, 4 do
        local pi = p[i]
        local qi = q[i]

        if pi == 0 then
            -- 线段与边界平行，若在外侧则无碰撞
            if qi < 0 then
                return false, 0, 1, 0, 0
            end
        else
            -- 将分数 qi/pi 标准化为分母为正
            local num, den = qi, pi
            if den < 0 then
                num = -num
                den = -den
            end

            if pi < 0 then   -- 进入边，更新 t_enter = max(t_enter, num/den)
                -- 比较 num/den > t_enter_num/t_enter_den
                if num * t_enter_den > t_enter_num * den then
                    t_enter_num, t_enter_den = num, den
                end
            else             -- 离开边，更新 t_exit = min(t_exit, num/den)
                -- 比较 num/den < t_exit_num/t_exit_den
                if num * t_exit_den < t_exit_num * den then
                    t_exit_num, t_exit_den = num, den
                end
            end
        end
    end

    -- 检查有效区间：t_enter <= t_exit 且 t_exit >= 0 且 t_enter <= 1
    if t_exit_num < 0 then  -- t_exit < 0
        return false, 0, 1, 0, 0
    end
    if t_enter_num > t_enter_den then  -- t_enter > 1
        return false, 0, 1, 0, 0
    end
    -- t_enter <= t_exit ?
    if t_enter_num * t_exit_den > t_exit_num * t_enter_den then
        return false, 0, 1, 0, 0
    end

    -- 钳位到 [0, 1]
    if t_enter_num < 0 then
        t_enter_num, t_enter_den = 0, 1
    end
    if t_enter_num > t_enter_den then
        t_enter_num, t_enter_den = 1, 1
    end

    -- 计算世界坐标系碰撞点（定点数）
    -- 整数向零取整除法（确定性）
    local function idiv(a, b)
        if a >= 0 then return math.floor(a / b)
        else return -math.floor((-a) / b) end
    end
    local bullet_hit_x = bullet.prev_x + idiv(dx * t_enter_num, t_enter_den)
    local bullet_hit_y = bullet.prev_y + idiv(dy * t_enter_num, t_enter_den)
    return true, t_enter_num, t_enter_den, bullet_hit_x, bullet_hit_y
end

function SceneMain:updateCollisionData()
    for k,v in self.entities:pairs() do
        if v.token == self.token then v.preLogicX,v.preLogicY = v.syncState.pos.x,v.syncState.pos.y
        else v.preLogicX,v.preLogicY = v.logicInfo.pos.x,v.logicInfo.pos.y end
    end
    for k,v in self.nodeBullets:pairs() do
        local logicPos = v:getLogicPos(self.syncFrameId)
        v.preLogicX,v.preLogicY = logicPos.x,logicPos.y
    end
end

function SceneMain:checkCollision()
    for bulletId, v in self.nodeBullets:pairs() do
        if v and not v.destroy then
            local logicPos = v:getLogicPos(self.syncFrameId)
            if v.preLogicX > 0 and v.preLogicX < display.width*NUMBER_SCALE and v.preLogicY > 0 and v.preLogicY < display.height*NUMBER_SCALE then
                if logicPos.x < 0 or logicPos.x > display.width*NUMBER_SCALE or logicPos.y < 0 or logicPos.y > display.height*NUMBER_SCALE then
                    v.destroy = true
                    v.hitPos = cc.p(logicPos.x,logicPos.y)
                end
            end
        end
        if v and not v.destroy then
            for userid,vv in self.entities:pairs() do
                if v.owner ~= vv.token then
                    local player = {
                        prev_x= vv.preLogicX, prev_y=vv.preLogicY,
                        curr_x=vv.logicInfo.pos.x, curr_y=vv.logicInfo.pos.y,
                        hw=NUMBER_SCALE*vv.width/2, hh=NUMBER_SCALE*vv.height/2
                    }
                    if userid == self.token then
                        player.curr_x=vv.syncState.pos.x
                        player.curr_y=vv.syncState.pos.y
                    end
                    local logicPos = v:getLogicPos(self.syncFrameId)
                    local bullet = {
                        prev_x=v.preLogicX, prev_y=v.preLogicY,
                        curr_x=logicPos.x, curr_y=logicPos.y,
                        hw=NUMBER_SCALE*v.width/2, hh=NUMBER_SCALE*v.height/2
                    }
                    local ret,t1,t2,x,y = self:checkBulletPlayerCollision(player, bullet)
                    if ret then
                        v.destroy = true
                        v.hitPos = cc.p(x,y)
                        break
                    end
                end
            end
        end
    end
end

function SceneMain:simulateDisconnectAndReconnect()
    self.tcp:disconnect()
    self.tcp:close()
    self.udp:close()
    self.isDisconnected = true
    Scheduler:performWithDelayGlobal(function()
        self.tcp = SocketTCP:create()
        self.tcp:setEventProtocol(self.eventProtocol)
        self.tcp:connect("127.0.0.1",8888,true)
        self.udp = SocketUDP:create("127.0.0.1",8889,self.eventProtocol)
    end,5)
end

function SceneMain:fastForwardFrames()
    local catchUpCount = 0
    -- 快速处理所有缓存的服务端帧数据
    print(string.format("[Reconnect] Start catching up from frame %d", self.syncFrameId + 1))
    while self.serverFrames:get(self.syncFrameId + 1) do
        self:updateCollisionData()
        local frames = self.serverFrames:get(self.syncFrameId + 1)
        catchUpCount = catchUpCount + 1
        for m = 1, #frames do
            local v = frames[m]
            local entity = self.entities:get(v.userid)
            if entity and not tolua.isnull(entity) then
                -- 应用所有命令
                for n = 1, #v.cmds do
                    local cmd = v.cmds[n]
                    if 1 == cmd.opetype then
                        entity.logicInfo.pos.x = entity.logicInfo.pos.x + ENTITY_MOVE_SPEED * cmd.movey
                        entity.logicInfo.pos.y = entity.logicInfo.pos.y + ENTITY_MOVE_SPEED * cmd.movex
                        entity.logicInfo.rotation = entity.logicInfo.rotation + cmd.turn * ENTITY_ROTATE_SPEED
                        entity.logicInfo.barrel_rotation = cmd.barrel_rotation
                    elseif 2 == cmd.opetype and cmd.fire == 1 then
                        local rotation = (entity.logicInfo.barrel_rotation + entity.logicInfo.rotation) % 360
                        local bdir = BulletRotationToSpeed[rotation]
                        local originPos = cc.pMul(cc.p(entity:getPosition()),NUMBER_SCALE)
                        originPos = cc.pAdd(cc.p(math.floor(originPos.x),math.floor(originPos.y)),cc.pMul(bdir,NUMBER_SCALE))
                        local logicPos = cc.pAdd(entity.logicInfo.pos,cc.pMul(bdir,NUMBER_SCALE))
                        self:createBullet(v.userid,v.frameid,logicPos,originPos,{directionx = bdir.x*NUMBER_SCALE, directiony = bdir.y*NUMBER_SCALE, rotation = rotation},false)
                        --HLog:printf(string.format("fire at frame %05d, logic pos %d:%d dir %d:%d", v.frameid, logicPos.x, logicPos.y, bdir.x, bdir.y))
                    end
                end
                -- 同步状态
                if v.userid == self.token then
                    entity.syncState.pos = cc.p(entity.logicInfo.pos)
                    entity.syncState.rotation = entity.logicInfo.rotation
                end
            end
        end
        self.serverFrames:remove(self.syncFrameId + 1)
        self.syncFrameId = self.syncFrameId + 1
        self:checkCollision()
    end
    -- 同步本地帧号到服务端帧号
    self.frameId = self.syncFrameId
    -- 清理断线期间的本地输入缓存
    self.inputsPending:clear()
    -- 直接设置实体位置（跳过插值）
    for k, v in self.entities:pairs() do
        if v and not tolua.isnull(v) then
            v:setPosition(cc.p(math.floor(v.logicInfo.pos.x/NUMBER_SCALE), math.floor(v.logicInfo.pos.y/NUMBER_SCALE)))
            v:setRotation(v.logicInfo.rotation)
            v:updateNodeUI(v.logicInfo.rotation)
            v.barrel:setRotation(v.logicInfo.barrel_rotation)
            v:show()
        end
    end
    for k,v in self.nodeBullets:pairs() do
        if v and not tolua.isnull(v) then
            if v.destroy then
                self.nodeBullets:remove(v.id)
                v:removeFromParent()
            else
                local logicPos = v:getLogicPos(self.syncFrameId-1)
                v:setPosition(cc.p(math.floor(logicPos.x/NUMBER_SCALE), math.floor(logicPos.y/NUMBER_SCALE)))
                v:show()
            end
        end
    end
    print(string.format("[FastForward] Caught up %d frames end with lastest syncFrameId %d", catchUpCount, self.syncFrameId))
end

function SceneMain:hashString(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 0xFFFFFFFF
    end
    return hash
end

function SceneMain:calculateStateHash(frameId)
    local stateData = {}
    for k,v in self.entities:pairs() do
        if v and not tolua.isnull(v) then
            if k == self.token then
                table.insert(stateData, string.format("%d:%d,%d,%d",
                    k,
                    v.syncState.pos.x,
                    v.syncState.pos.y,
                    v.syncState.rotation
                ))
            else
                table.insert(stateData, string.format("%d:%d,%d,%d",
                    k,
                    v.logicInfo.pos.x,
                    v.logicInfo.pos.y,
                    v.logicInfo.rotation
                ))
            end
        end
    end
    for k,v in self.nodeBullets:pairs() do
        if v and not tolua.isnull(v) and not v.destroy then
            local bounds = v:getLogicPos(frameId)
            table.insert(stateData, string.format("b%d:%d,%d",
                k,
                bounds.x,
                bounds.y
            ))
        end
    end
    local stateString = table.concat(stateData, "|")
    --HLog:printf(string.format("verify hash frames %d %s",frameId,stateString))
    return self:hashString(stateString), stateString
end

function SceneMain:sendStateVerify(frameId)
    local hash, stateString = self:calculateStateHash(frameId)
    -- 发送校验请求
    local pData = protobuf.encode('pb_common.data_sync_verify', {
        frameid = frameId,
        statehash = hash,
        roomid = self.roomid,
        userid = self.token
    })
    self:sendData(protobuf.enum_id("pb_common.protocol_code","protocol_sync_verify"),pData)
    --HLog:printf(string.format("[SyncVerify] Frame %05d, Hash: %u", frameId, hash))
end

return SceneMain