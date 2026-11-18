@echo off
setlocal
cd /d "%~dp0"

if not exist "lib\postgresql-42.7.4.jar" call tools\fetch-deps.bat
if errorlevel 1 (
  echo Dependency download failed.
  pause
  exit /b 1
)

echo [1/2] Compiling sources...
if not exist out mkdir out
del sources.txt >nul 2>&1
for /r "src" %%f in (*.java) do (
  set "srcfile=%%f"
  setlocal EnableDelayedExpansion
  echo "!srcfile:\=/!"
  endlocal
)>>sources.txt
javac -encoding UTF-8 -cp "lib/*" -d out @sources.txt
if errorlevel 1 (
  echo.
  echo Build failed. Check that a JDK 17+ is installed and on PATH.
  pause
  exit /b 1
)
del sources.txt >nul 2>&1
echo [2/2] Build complete - classes are in out\
