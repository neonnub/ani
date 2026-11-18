@echo off
setlocal
cd /d "%~dp0"
if not exist "out\com\mmtrip\server\ServerMain.class" call build.bat
echo Starting the RMI server (registry port 1099)...
java -Dmht.demo=true -cp "out;lib/*" com.mmtrip.server.ServerMain
pause
