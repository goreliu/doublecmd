@echo off
setlocal

set LAZBUILD=C:\Users\goreliu\scoop\apps\lazarus\current\lazbuild.exe

if not exist "%LAZBUILD%" (
  echo lazbuild not found: %LAZBUILD%
  exit /b 1
)

"%LAZBUILD%" --build-all "%~dp0src\anycmd.lpi"
exit /b %ERRORLEVEL%
