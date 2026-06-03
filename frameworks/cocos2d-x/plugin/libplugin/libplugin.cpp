// libplugin.cpp : 定义静态库的函数。
//

#include "pch.h"
#include "framework.h"
#include "userplugin.h"
#include "pluginmanager.h"

namespace cocos2d {
	namespace plugin {
		user_plugin::user_plugin() :
			uid(0) {

		}
		user_plugin::~user_plugin() {

		}
		void user_plugin::set_userid(int id) {
			uid = id;
		}
		int user_plugin::get_userid() {
			return uid;
		}

		plugin_manager* plugin_manager::getInstance() {
			if (nullptr == s_manager) {
				s_manager = new plugin_manager();
			}
			return s_manager;
		}
		void plugin_manager::destroyInstance() {
			if (s_manager) {
				delete s_manager;
				s_manager = nullptr;
			}
		}
		plugin_manager::plugin_manager() :
			user(nullptr) {

		}
		plugin_manager::~plugin_manager() {

		}
		user_plugin* plugin_manager::getUserPlugin() {
			if (!user) {
				user = new user_plugin();
			}
			return user;
		}
	}
}

// TODO: 这是一个库函数示例
void fnlibplugin()
{
}
