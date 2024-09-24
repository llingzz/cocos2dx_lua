
#ifndef __LUA_LPACK_H_
#define __LUA_LPACK_H_


#if __cplusplus
extern "C" {
#endif

#include "lauxlib.h"
int luaopen_pack(lua_State *L);
void register_lpack_module(lua_State *L);

#if __cplusplus
}
#endif
#endif
