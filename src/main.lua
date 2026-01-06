require "config"
local breakSocketHandle,debugXpCall
if DEBUG > 0 then
    breakSocketHandle,debugXpCall = require("LuaDebugjit")("LocalHost", 7003)
    print(breakSocketHandle, debugXpCall)
    cc.Director:getInstance():getScheduler():scheduleScriptFunc(breakSocketHandle, 0.3, false)
    cc.Director:getInstance():setDisplayStats(CC_SHOW_FPS)
end

require "cocos.init"
cc.FileUtils:getInstance():setPopupNotify(false)
cc.exports.FPS = 60.0
cc.exports.LOGIC_FPS = 15
cc.exports.ENTITY_MOVE_SPEED = 100*0.2
cc.exports.ENTITY_ROTATE_SPEED = 10
cc.exports.BULLET_MOVE_SPEED = 100*0.2*2
cc.exports.ENTITY_RADIUS = 15
cc.exports.BULLET_RADIUS = 2.5
cc.exports.ENTITY_ORIGIN_POS = cc.p(400,400)
cc.exports.START_TIME = socket.gettime()
cc.exports.OrderedTable = require "app.tools.OrderedTable"
cc.exports.HLog = require "app.tools.Log"
cc.exports.StateMachine = require "app.tools.StateMachine"
cc.exports.EventProtocol = require "app.tools.EventProtocol"
cc.exports.SocketTCP = require "app.tools.SocketTCP"
cc.exports.SocketUDP = require "app.tools.SocketUDP"
cc.exports.Scheduler = require "app.tools.Scheduler"
cc.exports.HelpTools = require "app.tools.HelpTools"
cc.exports.ResourceManager = require "app.tools.ResourceManager"
cc.exports.QuadTree = require "app.tools.QuadTree"
require "app.common.CommonDef"

cc.load('uiloader')
cc.load('lpack')
cc.load('pb')
local buffer = read_protobuf_file_c("src/app/pbfiles/pb_common.pb")
protobuf.register(buffer)

local function main()
    cc.Director:getInstance():setAnimationInterval(1/FPS)
    cc.FileUtils:getInstance():purgeCachedEntries()
    local list = cc.FileUtils:getInstance():getSearchPaths()
    dump (list, "list")
    if CC_SHOW_FAIRYUI_SYSTEM then
        local HandlerSceneFairyGUI = require("src.app.scenes.SceneFairyGUI")
        display.runScene(HandlerSceneFairyGUI.new())
    else
        local HandlerSceneMain = require("src.app.scenes.SceneMain")
        display.runScene(HandlerSceneMain.new())
    end
end

local status, msg = xpcall(main, __G__TRACKBACK__)
if not status then
    print(msg)
end
