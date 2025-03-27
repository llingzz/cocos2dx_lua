#pragma once
#include "redis/hiredis.h"
#include <list>
#include <map>
#include <vector>

class RedisClient
{
public:
	RedisClient(const std::string szIP, int nPort, int nTimeOutSec = 1);
	RedisClient();
	~RedisClient();

	bool ConnectServer(const std::string  szIP, const std::string  szPw, int nPort, int nTimeOutSec = 1);
	bool ConnectServer();
	bool InitConnect(const std::string szIP, const std::string szPw, int nPort, int nTimeOutSec = 1);
	void DisConnect();

	// 格式化字符串只支持%s和%b，当命令中的字段包含有双引号、空格的时候需要用%s来代替，否则会解析失败
	std::string RedisCommand(std::string& ans, const char* pFormat, ...);
	std::string RedisCommand(const char* pFormat, ...);

	bool RedisCommand(std::list<std::string>& oResList, const char* pFormat, ...);
	bool RedisCommand(std::map<std::string, std::string>& oResMap, const char* pFormat, ...);
	void RedisCommandToVec(const char* format, std::vector<std::string>& vecHashes);
	bool SelectDB(int nDBIndex);
	void PipelineEx(std::vector<std::string> vectCommands, std::vector<std::map<std::string, std::string>>& refMap);

protected:
	redisReply* RedisvCommand(const char* pFormat, va_list pList);
	bool GetResultFromReply(const redisReply* pReply, std::string& sResult);
	bool GetResultFromReply(const redisReply* pReply, std::list<std::string>& oResList);
	bool GetResultFromReply(const redisReply* pReply, std::map<std::string, std::string>& oResMap);

protected:
	std::string m_strHostIP;
	std::string m_strPasswd;
	int m_nPort;
	int m_nTimeOutSec;
	int m_nDBIndex;
	redisContext* m_pContext;
};
