#include "scripting/lua-bindings/manual/plugin/lua_cocos2dx_plugin_manual.h"

#include "scripting/lua-bindings/manual/tolua_fix.h"
#include "scripting/lua-bindings/manual/LuaBasicConversions.h"
#include "scripting/lua-bindings/manual/CCLuaEngine.h"

#include "plugin/libplugin/pluginmanager.h"
#include "plugin/libplugin/userplugin.h"

using namespace cocos2d::plugin;

// ---- forward declarations ----

static void _ensure_cc_table(lua_State* L);
static void _push_plugin_manager_instance(lua_State* L, plugin_manager* mgr);
static void _push_user_plugin_instance(lua_State* L, user_plugin* user);
static plugin_manager* _get_plugin_manager_ptr(lua_State* L, int idx);
static user_plugin* _get_user_plugin_ptr(lua_State* L, int idx);

// ---- helper: extract C++ pointer from wrapped table ----

static plugin_manager* _get_plugin_manager_ptr(lua_State* L, int idx)
{
    lua_pushstring(L, "_cobj");
    lua_rawget(L, idx < 0 ? idx - 1 : idx);
    plugin_manager* ptr = reinterpret_cast<plugin_manager*>(lua_touserdata(L, -1));
    lua_pop(L, 1);
    return ptr;
}

static user_plugin* _get_user_plugin_ptr(lua_State* L, int idx)
{
    lua_pushstring(L, "_cobj");
    lua_rawget(L, idx < 0 ? idx - 1 : idx);
    user_plugin* ptr = reinterpret_cast<user_plugin*>(lua_touserdata(L, -1));
    lua_pop(L, 1);
    return ptr;
}

// ---- helper: wrap C++ pointer in Lua table with metatable ----

static void _push_plugin_manager_instance(lua_State* L, plugin_manager* mgr)
{
    lua_newtable(L);
    lua_pushstring(L, "_cobj");
    lua_pushlightuserdata(L, mgr);
    lua_rawset(L, -3);

    luaL_getmetatable(L, "cc.PluginManager.instance");
    if (!lua_istable(L, -1))
    {
        lua_pop(L, 1);
        luaL_newmetatable(L, "cc.PluginManager.instance");
    }
    lua_setmetatable(L, -2);
}

static void _push_user_plugin_instance(lua_State* L, user_plugin* user)
{
    lua_newtable(L);
    lua_pushstring(L, "_cobj");
    lua_pushlightuserdata(L, user);
    lua_rawset(L, -3);

    luaL_getmetatable(L, "cc.UserPlugin.instance");
    if (!lua_istable(L, -1))
    {
        lua_pop(L, 1);
        luaL_newmetatable(L, "cc.UserPlugin.instance");
    }
    lua_setmetatable(L, -2);
}

// ---- helper: get or create cc global table ----

static void _ensure_cc_table(lua_State* L)
{
    lua_getglobal(L, "cc");
    if (!lua_istable(L, -1))
    {
        lua_pop(L, 1);
        lua_newtable(L);
        lua_setglobal(L, "cc");
        lua_getglobal(L, "cc");
    }
}

// ---- PluginManager binding functions ----

static int lua_plugin_manager_getInstance(lua_State* L)
{
    plugin_manager* mgr = plugin_manager::getInstance();
    _push_plugin_manager_instance(L, mgr);
    return 1;
}

static int lua_plugin_manager_destroyInstance(lua_State* L)
{
    plugin_manager::destroyInstance();
    return 0;
}

static int lua_plugin_manager_getUserPlugin(lua_State* L)
{
    plugin_manager* self = _get_plugin_manager_ptr(L, 1);
    if (!self)
    {
        luaL_error(L, "PluginManager:getUserPlugin() called on invalid object");
        return 0;
    }
    user_plugin* user = self->getUserPlugin();
    _push_user_plugin_instance(L, user);
    return 1;
}

// ---- UserPlugin binding functions ----

static int lua_user_plugin_set_userid(lua_State* L)
{
    user_plugin* self = _get_user_plugin_ptr(L, 1);
    if (!self)
    {
        luaL_error(L, "UserPlugin:setUserid() called on invalid object");
        return 0;
    }
    int id = static_cast<int>(luaL_checkinteger(L, 2));
    self->set_userid(id);
    return 0;
}

static int lua_user_plugin_get_userid(lua_State* L)
{
    user_plugin* self = _get_user_plugin_ptr(L, 1);
    if (!self)
    {
        luaL_error(L, "UserPlugin:getUserid() called on invalid object");
        return 0;
    }
    lua_pushinteger(L, self->get_userid());
    return 1;
}

// ---- module registration ----

TOLUA_API int register_plugin_module(lua_State* L)
{
    // -- 1. build PluginManager method table --
    lua_newtable(L);

    lua_pushstring(L, "getInstance");
    lua_pushcfunction(L, lua_plugin_manager_getInstance);
    lua_rawset(L, -3);

    lua_pushstring(L, "destroyInstance");
    lua_pushcfunction(L, lua_plugin_manager_destroyInstance);
    lua_rawset(L, -3);

    lua_pushstring(L, "getUserPlugin");
    lua_pushcfunction(L, lua_plugin_manager_getUserPlugin);
    lua_rawset(L, -3);

    // -- 2. create PluginManager instance metatable --
    luaL_newmetatable(L, "cc.PluginManager.instance");
    lua_pushvalue(L, -2);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);

    // -- 3. assign cc.PluginManager --
    _ensure_cc_table(L);
    lua_pushstring(L, "PluginManager");
    lua_pushvalue(L, -3);
    lua_rawset(L, -3);
    lua_pop(L, 2);

    // -- 4. build UserPlugin method table --
    lua_newtable(L);

    lua_pushstring(L, "setUserid");
    lua_pushcfunction(L, lua_user_plugin_set_userid);
    lua_rawset(L, -3);

    lua_pushstring(L, "getUserid");
    lua_pushcfunction(L, lua_user_plugin_get_userid);
    lua_rawset(L, -3);

    // -- 5. create UserPlugin instance metatable --
    luaL_newmetatable(L, "cc.UserPlugin.instance");
    lua_pushvalue(L, -2);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);

    // -- 6. assign cc.UserPlugin --
    _ensure_cc_table(L);
    lua_pushstring(L, "UserPlugin");
    lua_pushvalue(L, -3);
    lua_rawset(L, -3);
    lua_pop(L, 2);

    return 1;
}

/*
local mgr = cc.PluginManager:getInstance()
local user = mgr:getUserPlugin()
user:setUserid(12345)
local id = user:getUserid()
cc.PluginManager:destroyInstance()
*/