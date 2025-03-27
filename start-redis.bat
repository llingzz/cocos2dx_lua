@echo off
cd D:
cd %~dp0/assistserver/redis/
redis-server.exe ./redis.windows.conf
echo. & pause