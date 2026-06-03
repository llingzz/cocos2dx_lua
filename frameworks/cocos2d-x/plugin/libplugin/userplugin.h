namespace cocos2d {
	namespace plugin {
		class user_plugin
		{
		public:
			user_plugin();
			virtual ~user_plugin();
		public:
			void set_userid(int id);
			int get_userid();
		private:
			int uid;
		};
	}
}
