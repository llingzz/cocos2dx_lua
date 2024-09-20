@ECHO OFF

FOR /f %%i IN ('dir /b *.proto') DO ( 
    IF EXIST %%i (
        ECHO %%i 
		protoc %%i -o %~dp0/%%~ni.pb
		protoc -I="%~dp0/" --cpp_out="%~dp0/" "%~dp0/%%~ni.proto"
    )
)

PAUSE