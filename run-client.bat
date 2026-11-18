@echo off
setlocal
cd /d "%~dp0"
if not exist "out\com\mmtrip\client\WebMain.class" call build.bat
echo Starting the RMI client / web gateway on http://localhost:8080 ...
java -cp "out;lib/*" com.mmtrip.client.WebMain
pause
