@echo off
cd /d "%~dp0"

::删除所有udf文件
for /R %%f in (*.udf) do (
    echo %%~f
	del /f /s /q %%~f
)
::删除res文件夹
if exist %~dp0\res (
	rmdir /s /q %~dp0\res
)
::删除临时文件夹
for /f "delims=" %%i in ('dir /b /ad /s /a "*.Dir"') do (
	echo %%i
	rmdir /s /q %%i
)

echo. & pause