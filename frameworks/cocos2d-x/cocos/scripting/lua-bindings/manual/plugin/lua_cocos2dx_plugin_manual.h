#pragma once

#ifdef __cplusplus
extern "C" {
#endif
#include "tolua++.h"
#ifdef __cplusplus
}
#endif

#include "scripting/lua-bindings/manual/Lua-BindingsExport.h"

CC_LUA_DLL int register_plugin_module(lua_State* L);
