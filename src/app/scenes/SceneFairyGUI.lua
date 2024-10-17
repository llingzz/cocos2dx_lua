local SceneFairyGUI = class("SceneFairyGUI", function()
    local scene = display.newScene("SceneFairyGUI")
    scene:enableNodeEvents()
    return scene
end)

function SceneFairyGUI:ctor()
    local groot = fgui.GRoot:create(self)
    groot:retain()
    fgui.UIPackage:addPackage("fairy-gui/UI/MainMenu")
    local view = fgui.UIPackage:createObject("MainMenu", "Main")
    groot:addChild(view)
    -- TODO
end

return SceneFairyGUI