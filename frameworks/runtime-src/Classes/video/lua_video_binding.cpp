#include "lua_video_binding.h"

#include "VideoNode.h"

#include "cocos2d.h"
#include "scripting/lua-bindings/manual/CCLuaEngine.h"
#include "scripting/lua-bindings/manual/CCLuaStack.h"
#include "scripting/lua-bindings/manual/tolua_fix.h"

USING_NS_CC;

namespace
{

VideoNode* videoNodeFromStack(lua_State* L)
{
    return static_cast<VideoNode*>(tolua_tousertype(L, 1, nullptr));
}

int lua_video_create(lua_State* L)
{
    // 兼容 cc.VideoNode:create(path)（第 1 个参数是类表）与 cc.VideoNode.create(path)
    const int pathIndex = lua_isstring(L, 1) ? 1 : 2;

    size_t length = 0;
    const char* path = luaL_checklstring(L, pathIndex, &length);

    VideoNode* node = VideoNode::create(std::string(path, length));
    if (!node)
    {
        lua_pushnil(L);
        return 1;
    }

    toluafix_pushusertype_ccobject(L, node->_ID, &node->_luaID, static_cast<void*>(node), "cc.VideoNode");
    return 1;
}

int lua_video_play(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    if (self)
        self->play();
    return 0;
}

int lua_video_pause(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    if (self)
        self->pause();
    return 0;
}

int lua_video_resume(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    if (self)
        self->resume();
    return 0;
}

int lua_video_stop(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    if (self)
        self->stop();
    return 0;
}

int lua_video_seek(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    if (!self)
        return 0;

    const float seconds = static_cast<float>(luaL_checknumber(L, 2));
    self->seek(seconds);
    return 0;
}

int lua_video_setLoop(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    if (!self)
        return 0;

    self->setLoop(lua_toboolean(L, 2) != 0);
    return 0;
}

int lua_video_isPlaying(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushboolean(L, self && self->isPlaying());
    return 1;
}

int lua_video_getDuration(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getDuration() : 0.0);
    return 1;
}

int lua_video_getCurrentTime(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getCurrentTime() : 0.0);
    return 1;
}

int lua_video_getDecodedFrames(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getDecodedFrames() : 0);
    return 1;
}

int lua_video_getRenderedFrames(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getRenderedFrames() : 0);
    return 1;
}

int lua_video_getSendErrors(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getSendErrors() : 0);
    return 1;
}

int lua_video_getUpdateCount(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getUpdateCount() : 0);
    return 1;
}

int lua_video_getUploadMs(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getUploadMs() : 0.0);
    return 1;
}

int lua_video_getPushedFrames(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getPushedFrames() : 0);
    return 1;
}

int lua_video_getDroppedFrames(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getDroppedFrames() : 0);
    return 1;
}

int lua_video_getEmptyPolls(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getEmptyPolls() : 0);
    return 1;
}

int lua_video_getAudioDrops(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getAudioDrops() : 0);
    return 1;
}

int lua_video_getAudioWriteFailures(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getAudioWriteFailures() : 0);
    return 1;
}

int lua_video_getAudioUnderruns(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getAudioUnderruns() : 0);
    return 1;
}

int lua_video_getVideoWidth(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getVideoWidth() : 0.0);
    return 1;
}

int lua_video_getVideoHeight(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    lua_pushnumber(L, self ? self->getVideoHeight() : 0.0);
    return 1;
}

int lua_video_setVolume(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    if (!self)
        return 0;

    self->setVolume(static_cast<float>(luaL_checknumber(L, 2)));
    return 0;
}

int lua_video_addEventListener(lua_State* L)
{
    VideoNode* self = videoNodeFromStack(L);
    if (!self)
        return 0;

    tolua_Error error;
    if (!toluafix_isfunction(L, 2, "LUA_FUNCTION", 0, &error))
    {
        tolua_error(L, "#ferror in function 'addEventListener'.", &error);
        return 0;
    }

    const LUA_FUNCTION handler = toluafix_ref_function(L, 2, 0);
    self->setEventCallback([self, handler](int event) {
        LuaStack* stack = LuaEngine::getInstance()->getLuaStack();
        stack->pushObject(self, "cc.VideoNode");
        stack->pushInt(event);
        stack->executeFunctionByHandler(handler, 2);
    });
    return 0;
}

}  // namespace

int register_all_video(lua_State* L)
{
    if (!L)
        return 0;

    // 本引擎的 tolua 被改造过：tolua_module / tolua_beginmodule 需要父表在栈上，
    // 各 register_xxx_module 都是先把 _G 压栈再注册。
    lua_getglobal(L, "_G");
    if (!lua_istable(L, -1))
    {
        lua_pop(L, 1);
        return 0;
    }

    tolua_open(L);
    tolua_module(L, "cc", 0);
    tolua_beginmodule(L, "cc");
    tolua_usertype(L, "cc.VideoNode");
    tolua_cclass(L, "VideoNode", "cc.VideoNode", "cc.Node", nullptr);
    tolua_beginmodule(L, "VideoNode");
    tolua_function(L, "create", lua_video_create);
    tolua_function(L, "play", lua_video_play);
    tolua_function(L, "pause", lua_video_pause);
    tolua_function(L, "resume", lua_video_resume);
    tolua_function(L, "stop", lua_video_stop);
    tolua_function(L, "seek", lua_video_seek);
    tolua_function(L, "setLoop", lua_video_setLoop);
    tolua_function(L, "isPlaying", lua_video_isPlaying);
    tolua_function(L, "getDuration", lua_video_getDuration);
    tolua_function(L, "getCurrentTime", lua_video_getCurrentTime);
    tolua_function(L, "getDecodedFrames", lua_video_getDecodedFrames);
    tolua_function(L, "getRenderedFrames", lua_video_getRenderedFrames);
    tolua_function(L, "getSendErrors", lua_video_getSendErrors);
    tolua_function(L, "getUpdateCount", lua_video_getUpdateCount);
    tolua_function(L, "getUploadMs", lua_video_getUploadMs);
    tolua_function(L, "getPushedFrames", lua_video_getPushedFrames);
    tolua_function(L, "getDroppedFrames", lua_video_getDroppedFrames);
    tolua_function(L, "getEmptyPolls", lua_video_getEmptyPolls);
    tolua_function(L, "getAudioDrops", lua_video_getAudioDrops);
    tolua_function(L, "getAudioWriteFailures", lua_video_getAudioWriteFailures);
    tolua_function(L, "getAudioUnderruns", lua_video_getAudioUnderruns);
    tolua_function(L, "getVideoWidth", lua_video_getVideoWidth);
    tolua_function(L, "getVideoHeight", lua_video_getVideoHeight);
    tolua_function(L, "setVolume", lua_video_setVolume);
    tolua_function(L, "addEventListener", lua_video_addEventListener);
    tolua_endmodule(L);
    tolua_endmodule(L);

    lua_pop(L, 1);   // 弹出 _G

    return 1;
}
