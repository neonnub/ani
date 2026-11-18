@echo off
setlocal
cd /d "%~dp0"
title MSTP - fetch hotel photos

echo ============================================================
echo  Fetching real, CC-licensed hotel photos
echo  Source: Wikimedia Commons + Openverse (needs internet)
echo  Only photos whose title matches the hotel AND its town are used.
echo ============================================================
echo.

python tools\fetch_hotel_photos.py --dry-run
echo.
echo ------------------------------------------------------------
echo  Above are the matches found. Press any key to download them.
echo  (Close this window to cancel.)
pause >nul

python tools\fetch_hotel_photos.py
if errorlevel 1 goto failed

echo.
echo Rebuilding the app catalogue...
call build.bat
echo.
echo Done. Restart the app to see the photos:
echo    stop.bat   then   run.bat
echo.
pause
exit /b 0

:failed
echo.
echo The fetch did not finish. Check that this computer is online,
echo then run this file again.
echo.
pause
exit /b 1
