#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <mutex>
#include <functional>
#include "redisclient.h"
using namespace std;

typedef std::unique_ptr<RedisClient, std::function<void(RedisClient*)>> RedisClientPtr;
class RedisPool
{
public:
	static RedisPool *create(const std::string &host, const int &port, const std::string &password);
	RedisClientPtr get(int DBIndex);

	int initConnection(int count);
	void put(RedisClient *rs);
	~RedisPool();

private:
	RedisPool(const std::string &host, const int &port, const std::string &password);
	std::mutex _lock;
	std::string m_password;
	std::string m_host;
	std::vector<RedisClient*> m_pool;
	int m_port;
};
