#include<string>
#include "redisclient.h"
#include "./redis/hiredis.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

RedisClient::RedisClient(const std::string szIP, int nPort, int nTimeOutSec) :m_nDBIndex(0)
{
	m_strHostIP = szIP;
	m_nPort = nPort;
	m_nTimeOutSec = nTimeOutSec;
	m_pContext = nullptr;
}

RedisClient::RedisClient() :m_nDBIndex(0)
{
	m_nPort = 0;
	m_nTimeOutSec = 0;
	m_pContext = nullptr;
}

RedisClient::~RedisClient()
{
	if (m_pContext) {
		DisConnect();
	}
}

bool RedisClient::ConnectServer(const std::string szIP, const std::string szPw, int nPort, int nTimeOutSec)
{
	if (InitConnect(szIP, szPw, nPort, nTimeOutSec)) {
		return ConnectServer();
	}
	return false;
}

bool RedisClient::InitConnect(const std::string  szIP, std::string szPw, int nPort, int nTimeOutSec)
{
	m_strHostIP = szIP;
	m_strPasswd = szPw;
	m_nPort = nPort;
	m_nTimeOutSec = nTimeOutSec;
	return true;
}

bool RedisClient::ConnectServer()
{
	if (m_strHostIP.size() <= 0) {
		return false;
	}
	struct timeval t = { m_nTimeOutSec, 0 };
	m_pContext = redisConnectWithTimeout(m_strHostIP.c_str(), m_nPort, t);
	if (!m_pContext) {
		return false;
	}
	if (m_pContext && m_pContext->err) {
		return false;
	}
	if (m_strPasswd.size() > 0) {
		std::string ret;
		RedisCommand(ret, "AUTH %s", m_strPasswd.c_str());
		if (ret != "OK") {
			return false;
		}
	}
	if (m_nDBIndex != 0) {
		int nTempDb = m_nDBIndex;
		m_nDBIndex = 0;
		this->SelectDB(nTempDb);
	}
	return true;
}

void RedisClient::DisConnect()
{
	if (m_pContext) {
		redisFree(m_pContext);
		m_pContext = nullptr;
	}
}

std::string RedisClient::RedisCommand(std::string& ans, const char* pFormat, ...)
{
	if (!pFormat) {
		return std::to_string(REDIS_REPLY_ERROR);
	}

	va_list pList;
	va_start(pList, pFormat);

	std::string sRet = std::to_string(REDIS_REPLY_ERROR);
	redisReply* pReply = RedisvCommand(pFormat, pList);
	if (pReply) {
		GetResultFromReply(pReply, ans);
		sRet = std::to_string(pReply->type);
		freeReplyObject(pReply);
	}

	va_end(pList);
	return sRet;
}

std::string RedisClient::RedisCommand(const char* pFormat, ...)
{
	if (!pFormat) {
		return std::to_string(REDIS_REPLY_ERROR);
	}

	va_list pList;
	va_start(pList, pFormat);

	std::string sRet = std::to_string(REDIS_REPLY_ERROR);
	redisReply* pReply = RedisvCommand(pFormat, pList);
	if (pReply) {
		GetResultFromReply(pReply, sRet);
		sRet = std::to_string(pReply->type);
		freeReplyObject(pReply);
	}

	va_end(pList);
	return sRet;
}

bool RedisClient::RedisCommand(std::list<std::string>& oResList, const char* pFormat, ...)
{
	if (!pFormat) {
		return false;
	}

	va_list pList;
	va_start(pList, pFormat);

	bool bRet = false;
	redisReply* pReply = RedisvCommand(pFormat, pList);
	if (pReply) {
		bRet = GetResultFromReply(pReply, oResList);
		freeReplyObject(pReply);
	}

	va_end(pList);
	return bRet;
}

bool RedisClient::RedisCommand(std::map<std::string, std::string>& oResMap, const char* pFormat, ...)
{
	if (!pFormat) {
		return false;
	}

	va_list pList;
	va_start(pList, pFormat);

	bool bRet = false;
	redisReply* pReply = RedisvCommand(pFormat, pList);
	if (pReply) {
		bRet = GetResultFromReply(pReply, oResMap);
		freeReplyObject(pReply);
	}

	va_end(pList);
	return bRet;
}

redisReply* RedisClient::RedisvCommand(const char* pFormat, va_list pList)
{
	redisReply* pReply = (redisReply*)redisvCommand(m_pContext, pFormat, pList);
	if (m_pContext->err != REDIS_OK) {
		DisConnect();
		if (!ConnectServer()) {
			return nullptr;
		}
		pReply = (redisReply*)redisvCommand(m_pContext, pFormat, pList);
	}
	if (m_pContext->err != REDIS_OK) {
		return nullptr;
	}
	return pReply;
}

bool RedisClient::GetResultFromReply(const redisReply* pReply, std::string& sResult)
{
	if (!pReply) {
		return false;
	}
	switch (pReply->type)
	{
	case REDIS_REPLY_STRING:
	case REDIS_REPLY_STATUS:
	case REDIS_REPLY_ERROR:
	{
		sResult = pReply->str;
		break;
	}
	case REDIS_REPLY_NIL:
	{
		sResult = "";
		break;
	}
	case REDIS_REPLY_INTEGER:
	{
		char szBuf[32] = { 0 };
		_snprintf_s(szBuf, 32, "%lld", pReply->integer);
		sResult = szBuf;
		break;
	}
	default:
		return false;
	}
	return true;
}

bool RedisClient::GetResultFromReply(const redisReply* pReply, std::list<std::string>& oResList)
{
	if (!pReply) {
		return false;
	}

	if (REDIS_REPLY_ARRAY != pReply->type) {
		return false;
	}

	for (size_t i = 0; i < pReply->elements; ++i) {
		std::string sRes;
		bool bRet = GetResultFromReply(pReply->element[i], sRes);
		if (bRet) {
			oResList.push_back(sRes);
		}
		else {
			oResList.push_back("");
		}
	}

	return true;
}

bool RedisClient::GetResultFromReply(const redisReply* pReply, std::map<std::string, std::string>& oResMap)
{
	if (!pReply) {
		return false;
	}

	if (REDIS_REPLY_ARRAY != pReply->type) {
		return false;
	}

	std::string sKey = "";
	for (size_t i = 0; i < pReply->elements; ++i) {
		if (0 == i % 2) {
			bool bRet = GetResultFromReply(pReply->element[i], sKey);
			if (!bRet) {
				++i;
				continue;
			}
		}
		else {
			std::string sValue;
			bool bRet = GetResultFromReply(pReply->element[i], sValue);
			if (!bRet) {
				continue;
			}
			oResMap.insert(std::make_pair(sKey, sValue));
		}
	}
	return true;
}

void RedisClient::RedisCommandToVec(const char* format, std::vector<std::string>& vecHashes)
{
	redisReply* reply = (redisReply*)redisCommand(m_pContext, format);
	if (m_pContext->err != REDIS_OK) {
		DisConnect();
		if (!ConnectServer()) {
			return;
		}
		reply = (redisReply*)redisCommand(m_pContext, format);
	}
	if (m_pContext->err != REDIS_OK) {
		return;
	}
	if (!reply) {
		return;
	}
	if (reply->type != REDIS_REPLY_ARRAY) {
		freeReplyObject(reply);
		return;
	}

	int i;
	int nCount = reply->elements;
	for (i = 0; i < nCount; ++i) {
		redisReply* childReply = reply->element[i];
		if (childReply->type == REDIS_REPLY_STRING) {
			vecHashes.push_back(childReply->str);
		}
		else {
			vecHashes.push_back("");
		}
	}
	freeReplyObject(reply);
	return;
}

bool RedisClient::SelectDB(int nDBIndex)
{
	if (nDBIndex == m_nDBIndex) {
		return true;
	}
	std::string sRet;
	std::string strIndex = std::to_string(nDBIndex);
	RedisCommand(sRet, "select %s", strIndex.c_str());
	if (sRet == "OK") {
		m_nDBIndex = nDBIndex;
		return true;
	}
	return false;
}

void RedisClient::PipelineEx(std::vector<std::string> vectCommands, std::vector<std::map<std::string, std::string>>& refMap)
{
	if (m_pContext->err != REDIS_OK) {
		DisConnect();
		if (!ConnectServer()) {
			return;
		}
	}

	for (int i = 0; i < vectCommands.size(); i++) {
		redisAppendCommand(m_pContext, vectCommands[i].c_str());
	}

	for (int i = 0; i < vectCommands.size(); i++) {
		redisReply* reply;
		if (REDIS_OK != redisGetReply(m_pContext, (void**)&reply)) {
			std::map<std::string, std::string> tMap;
			tMap.insert(std::make_pair("error", "1"));
			refMap.emplace_back(std::move(tMap));
			continue;
		}
		if (!reply) {
			std::map<std::string, std::string> tMap;
			tMap.insert(std::make_pair("error", "1"));
			refMap.emplace_back(std::move(tMap));
			continue;
		}
		if (reply->type == REDIS_REPLY_ARRAY) {
			std::map<std::string, std::string> tMap;
			if (reply->elements == 0){
				tMap["error"] = "1";
			}
			else{
				for (auto j = 0; j < reply->elements; j += 2) {
					redisReply* keyReply = (reply->element)[j];
					redisReply* valReply = (reply->element)[j + 1];
					if (!keyReply || !valReply) {
						tMap["error"] = "1";
						break;
					}
					else {
						tMap["error"] = "0";
						std::string strKey = (REDIS_REPLY_INTEGER == keyReply->type) ? std::to_string(keyReply->integer) : std::string(keyReply->str);
						std::string strVal = (REDIS_REPLY_INTEGER == valReply->type) ? std::to_string(valReply->integer) : std::string(valReply->str);
						tMap.insert(std::make_pair(std::move(strKey), std::move(strVal)));
					}
				}
			}
			refMap.emplace_back(std::move(tMap));
		}
		else {
			std::map<std::string, std::string> tMap;
			tMap.insert(std::make_pair("error", "1"));
			refMap.emplace_back(std::move(tMap));
		}
		freeReplyObject(reply);
	}
}
