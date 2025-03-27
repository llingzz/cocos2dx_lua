#include "redispool.h"
#include <memory>
#include <functional>

RedisPool * RedisPool::create(const std::string &host, const int &port, const std::string &password)
{
	return new RedisPool(host, port, password);
}

RedisClientPtr RedisPool::get(int DBIndex)
{
	RedisClient* rs = nullptr; {
		std::lock_guard<std::mutex> lk(_lock);
		if (!m_pool.empty()) {
			rs = m_pool.back();
			m_pool.pop_back();
		}
	}
	if (rs == nullptr) {
		rs = new RedisClient;
		rs->InitConnect(m_host, m_password, m_port);
		if (!rs->ConnectServer()) {
			delete rs;
			rs = nullptr;
		}
	}
	std::function<void(RedisClient*)> f = std::bind(&RedisPool::put, this, std::placeholders::_1);
	RedisClientPtr urs(rs, f);
	urs->SelectDB(DBIndex);
	return urs;
}


void RedisPool::put(RedisClient *rs)
{
	std::lock_guard<std::mutex> lk(_lock);
	m_pool.push_back(rs);
}


int RedisPool::initConnection(int count)
{
	int nSuccessCount(0);
	for (int i = 0; i < count; i++) {
		RedisClient* rs = new RedisClient;
		rs->InitConnect(m_host, m_password, m_port);
		if (rs->ConnectServer()) {
			m_pool.push_back(rs);
			nSuccessCount++;
		}
		else {
			delete rs;
		}
	}
	return nSuccessCount;
}

RedisPool::RedisPool(const std::string& host, const int& port, const std::string& password)
	:m_host(host), m_port(port), m_password(password)
{

}

RedisPool::~RedisPool()
{
	std::lock_guard<std::mutex> lk(_lock);
	for (RedisClient* rs : m_pool) {
		delete rs;
	}
}