namespace cocos2d {
	namespace plugin {

		class user_plugin;
		class plugin_manager;
		static plugin_manager* s_manager = nullptr;
		class plugin_manager {
		public:
			plugin_manager();
			virtual ~plugin_manager();
			static plugin_manager* getInstance();
			static void destroyInstance();
		public:
			user_plugin* getUserPlugin();
		private:
			user_plugin* user;
		};

	}
}