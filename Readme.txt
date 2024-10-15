项目创建
1. cd cocos2d-x-3.1.x/tools/cocos2d-console/bin
2. cocos new cocos2dx_lua -p com.lling.org -l lua -d xxx/xxx

添加LuaDebugjit.lua在vscode中开启调试，插件选用luaide，调试目录cocos2dx_lua/src
注意：调试时请删除simulator\win32/resource文件夹，否则无法正常进入断点

pbc支持
1. https://github.com/cloudwu/pbc下载源码，解压放入frameworks\cocos2d-x\external下
2. libcocos2d筛选器external下新建pbc目录，添加pbc源码src目录下的文件和pbc.h
3. libcocos2d导出为dll，对pbc.h修改：
1)#include "platform/CCPlatformMacros.h"
2)所有接口前缀添加CC_DLL
4. libluacocos2d筛选器manual下新建pbc目录，添加pbc源码binding\lua目录下的文件pbc-lua.c，稍作修改如下：
#include "scripting/lua-bindings/manual/pbc/pbc-lua.h"

#if defined(WIN32) && !defined(__cplusplus)
#define inline __inline
#endif

...
#include "external/pbc-master/pbc.h"
...
5. 新建pbc-lua.h/lua_cocos2dx_pbc_manual.h/lua_cocos2dx_pbc_manual.cpp进行lua绑定，内容如下：
[pbc-lua.h]
#pragma once
#ifdef __cplusplus
extern "C" {
#endif
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
extern "C" {
#endif
    int luaopen_protobuf_c(lua_State* L);
#ifdef __cplusplus
}
#endif

[lua_cocos2dx_pbc_manual.h]
#pragma once

#ifdef __cplusplus
extern "C" {
#endif
#include "tolua++.h"
#ifdef __cplusplus
}
#endif

TOLUA_API int  register_pbc_module(lua_State* L);

[lua_cocos2dx_pbc_manual.cpp]
#include "scripting/lua-bindings/manual/pbc/lua_cocos2dx_pbc_manual.h"

#include "platform/CCPlatformConfig.h"
#include "base/ccConfig.h"
#include "scripting/lua-bindings/manual/tolua_fix.h"
#include "scripting/lua-bindings/manual/LuaBasicConversions.h"
#include "scripting/lua-bindings/manual/CCLuaEngine.h"

#include "scripting/lua-bindings/manual/pbc/pbc-lua.h"

#include "cocos/platform/CCFileUtils.h"

int read_protobuf_file(lua_State* L) {
    const char* buff = luaL_checkstring(L, -1);
    Data data = cocos2d::FileUtils::getInstance()->getDataFromFile(buff);
    lua_pushlstring(L, (const char*)data.getBytes(), data.getSize());
    return 1;
}

TOLUA_API int register_pbc_module(lua_State* L)
{
    lua_getglobal(L, "_G");
    if (lua_istable(L, -1))//stack:...,_G,
    {
        lua_register(L, "read_protobuf_file_c", read_protobuf_file);
        luaopen_protobuf_c(L);
    }
    lua_pop(L, 1);
    return 1;
}
6. 在lua_module_register.cpp对pbc模块进行注册
#include "scripting/lua-bindings/manual/pbc/lua_cocos2dx_pbc_manual.h"
int lua_module_register(lua_State* L){
...
register_pbc_module(L);
...
}
7. 重新编译引擎，在lua脚本层使用示例如下：
cc.load('pb')
local buffer = read_protobuf_file_c("src/app/pbfiles/ServerModuleProto.pb")
protobuf.register(buffer)
local pData = protobuf.encode('Module.MESSAGE1', {
	n1 = 1,
})
local dataInfo = protobuf.decode("Module.MESSAGE1", pData)
protobuf.extract(dataInfo)

fairy-gui支持
1.https://github.com/fairygui/FairyGUI-cocos2dx获取源码
2.将libfairygui下文件加放入到D:\Work\Client\Cocos2dx\cocos2dx_lua\frameworks\cocos2d-x\cocos\editor-support\下
3.调整libfairygui.vcxproj
  <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="PropertySheets">
    <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
    <Import Project="..\..\..\..\..\cocos\2d\cocos2dx.props" />
    <Import Project="..\..\..\..\..\cocos\2d\cocos2d_headers.props" />
  </ImportGroup>
  <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="PropertySheets">
    <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
    <Import Project="..\..\..\..\..\cocos\2d\cocos2dx.props" />
    <Import Project="..\..\..\..\..\cocos\2d\cocos2d_headers.props" />
  </ImportGroup>
4.解决方案属性页\项目依赖项勾选libfairygui
5.CLabel.h修改virtual void updateBMFontScale();
6.注释GLoaer3D.cpp中onChangeSpine方法
7.项目引入c++目录libfairygui\Classes
8.添加链接附加依赖项libfairygui.lib
9.编译即可，测试可使用fairygui-cocos2dx自带测试用例，需要稍作修改，这里不再赘述