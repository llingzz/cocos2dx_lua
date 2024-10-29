@ECHO OFF

FOR /f %%i IN ('dir /b *.proto') DO ( 
    IF EXIST %%i (
        ECHO %%i 
		protoc %%i -o %~dp0/%%~ni.pb
		protoc -I="%~dp0/" --cpp_out="%~dp0/" "%~dp0/%%~ni.proto"
    )
)

xcopy *.h ..\..\assistserver\assistserver\pb\ /s /e /y /i
xcopy *.cc ..\..\assistserver\assistserver\pb\ /s /e /y /i
xcopy *.pb ..\..\src\app\pbfiles\ /s /e /y /i

PAUSE