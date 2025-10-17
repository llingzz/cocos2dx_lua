@echo off
cd D:
cd %~dp0
rmdir /s /q %~dp0\log
rmdir /s /q %~dp0\simulator\win32\Resources
rmdir /s /q %~dp0\assistserver\Debug
rmdir /s /q %~dp0\assistserver\assistserver\Debug
rmdir /s /q %~dp0\assistserver\vcpkg_installed
rmdir /s /q %~dp0\assistserver\.vs
rmdir /s /q %~dp0\frameworks\cocos2d-x\cocos\2d\Debug.win32
rmdir /s /q %~dp0\frameworks\cocos2d-x\cocos\editor-support\spine\proj.win32\Debug.win32
rmdir /s /q %~dp0\frameworks\cocos2d-x\cocos\scripting\lua-bindings\proj.win32\Debug.win32
rmdir /s /q %~dp0\frameworks\cocos2d-x\external\recast\proj.win32\Debug.win32
rmdir /s /q %~dp0\frameworks\cocos2d-x\tools\simulator\libsimulator\proj.win32\Debug.win32
rmdir /s /q %~dp0\frameworks\runtime-src\proj.win32\.vs
rmdir /s /q %~dp0\frameworks\runtime-src\proj.win32\Debug.win32
rmdir /s /q %~dp0\frameworks\cocos2d-x\cocos\editor-support\FairyGUI-cocos2dx-master\libfairygui\proj.win32\Debug.win32
echo. & pause