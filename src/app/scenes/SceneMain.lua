local SceneMain = class("SceneMain", function()
    local scene = display.newScene("SceneMain")
    scene:enableNodeEvents()
    return scene
end)

function SceneMain:ctor()
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
    cc.Director:getInstance():setDisplayStats(CC_SHOW_FPS)
    self.eventProtocol = EventProtocol:new()
    self.eventProtocol:addEventListener(SocketTCP.EVENT_DATA, handler(self,self.onEventData), "TCP_DATA")
    self.tcp = SocketTCP:create()
    self.tcp:setEventProtocol(self.eventProtocol)
    self.tcp:connect("127.0.0.1",8888,true)
end

function SceneMain:onExit()
end

function SceneMain:onEventData(INdata)
    dump(INdata)
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
        local pData = protobuf.encode('ServerModule.SERVER_TIME_REQ', {
            nUserID = 606224,
        })
        local dataInfo = protobuf.decode("ServerModule.SERVER_TIME_REQ", pData)
        protobuf.extract(dataInfo)
        dump(dataInfo)
        self.tcp:send(pData)
    end
end

function SceneMain:onEnterTransitionFinish()
end

return SceneMain