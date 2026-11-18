@echo off
setlocal
cd /d "%~dp0"
if not exist "out\com\mmtrip\client\WebMain.class" call build.bat

echo Starting RMI server and web gateway in separate processes...
start "MyanmarTrip - RMI Server" cmd /k java -Dmht.demo=true -cp "%CD%\out;%CD%\lib\*" com.mmtrip.server.ServerMain
timeout /t 3 /nobreak >nul
start "MyanmarTrip - Web Gateway" cmd /k java -cp "%CD%\out;%CD%\lib\*" com.mmtrip.client.WebMain
timeout /t 3 /nobreak >nul
echo.
echo Close the two console windows to stop the server and the gateway.
