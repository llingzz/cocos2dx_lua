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
cc.exports.HLog = require "app.tools.Log"
cc.exports.StateMachine = require "app.tools.StateMachine"
cc.exports.EventProtocol = require "app.tools.EventProtocol"
cc.exports.SocketTCP = require "app.tools.SocketTCP"
cc.exports.SocketUDP = require "app.tools.SocketUDP"
cc.exports.Scheduler = require "app.tools.Scheduler"
cc.exports.HelpTools = require "app.tools.HelpTools"
require "app.common.CommonDef"

cc.load('uiloader')
cc.load('lpack')
cc.load('pb')
local buffer = read_protobuf_file_c("src/app/pbfiles/pb_common.pb")
protobuf.register(buffer)

local function main()
    cc.FileUtils:getInstance():purgeCachedEntries()
    local list = cc.FileUtils:getInstance():getSearchPaths()
    dump (list, "list")
    local HandlerSceneMain = require("src.app.scenes.SceneMain")
    display.runScene(HandlerSceneMain.new())
    -- local HandlerSceneFairyGUI = require("src.app.scenes.SceneFairyGUI")
    -- display.runScene(HandlerSceneFairyGUI.new())
end

local status, msg = xpcall(main, __G__TRACKBACK__)
if not status then
    print(msg)
end
