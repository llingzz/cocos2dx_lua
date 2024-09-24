local SceneMain = class("SceneMain", function()
    local scene = display.newScene("SceneMain")
    scene:enableNodeEvents()
    return scene
end)

function SceneMain:ctor()
    local uiloader = cc.load('uiloader')
    local layer = uiloader:load("res/modules/LayerTest.csb")
    local width = display.width
    local height = display.height
    layer:setContentSize(width, height)
    layer:enableNodeEvents()
    ccui.Helper:doLayout(layer)
    layer:addTo(self)

    self.fsm = StateMachine:new()
    self.fsm:setupState({
        initial = "idle",
        events = {
            {name = "move", from = {"idle", "jump"}, to = "walk"},
            {name = "attack", from = {"idle", "walk"}, to = "jump"},
            {name = "normal", from = {"walk", "jump"}, to = "idle"},
        },
        callbacks = {
            onenteridle = function ()
                print("onenteridle")
            end,
            onenterwalk = function ()
                print("onenterwalk")
            end,
            onenterjump = function ()
                print("onenterjump")
            end,
        },
    })
    local keyBoardListener = cc.EventListenerKeyboard:create()
    keyBoardListener:registerScriptHandler(handler(self,self.onKeyEventPressed), cc.Handler.EVENT_KEYBOARD_PRESSED)
    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(keyBoardListener, self)
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
        local ret = self.fsm:doEvent("move")
        print("press W "..tostring(ret))
    end
    if INkey == cc.KeyCode.KEY_A then
        local ret = self.fsm:doEvent("attack")
        print("press A "..tostring(ret))
    end
    if INkey == cc.KeyCode.KEY_D then
        local ret = self.fsm:doEvent("normal")
        print("press D "..tostring(ret))
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

return SceneMain