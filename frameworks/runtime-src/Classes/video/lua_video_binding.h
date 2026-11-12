#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"

#ifdef __cplusplus
}

extern "C" {
#endif

/** 把 cc.VideoNode 注册进已有的 "cc" 模块表。返回 1 表示成功。 */
int register_all_video(lua_State* L);

#ifdef __cplusplus
}
#endif
