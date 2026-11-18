@echo off
setlocal
cd /d "%~dp0"
if not exist "out\com\mmtrip\client\WebMain.class" call build.bat

echo Starting everything in one process (embedded RMI registry + web UI).
echo The browser opens automatically; the exact URL is printed below.
java -Dmht.demo=true -cp "out;lib/*" com.mmtrip.client.WebMain --embedded
pause
