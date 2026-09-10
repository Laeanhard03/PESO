@echo off
setlocal
set "ROOT=%~dp0"
cd /d "%ROOT%"

echo ==========================================
echo Starting PESO JobKonek Workspace...
echo ==========================================

:: Prevents the "not a clone" error
git config --global --add safe.directory "*"

cmd /c flutter --version >nul 2>&1
if %errorlevel% equ 0 goto FLUTTER_READY

echo.
echo [!] 'flutter' command not found. Attempting to fix Windows PATH...
set "FOUND_FLUTTER="

if exist "C:\src\flutter\bin\flutter.bat" set "FOUND_FLUTTER=C:\src\flutter\bin"
if exist "C:\flutter\bin\flutter.bat" set "FOUND_FLUTTER=C:\flutter\bin"
if exist "%USERPROFILE%\flutter\bin\flutter.bat" set "FOUND_FLUTTER=%USERPROFILE%\flutter\bin"

if defined FOUND_FLUTTER goto APPLY_PATH

echo [ERROR] Could not automatically locate the Flutter SDK.
set /p FOUND_FLUTTER="Please paste the full path to your Flutter 'bin' folder: "

:APPLY_PATH
set "FOUND_FLUTTER=%FOUND_FLUTTER:"=%"
set "PATH=%PATH%;%FOUND_FLUTTER%"
echo Adding Flutter to permanent Windows Environment Variables...
powershell -Command "[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User') + ';%FOUND_FLUTTER%', 'User')"
echo [SUCCESS] Flutter PATH configured.
echo.

:FLUTTER_READY
echo [1/4] Syncing Flutter dependencies...
call flutter pub get

echo.
echo [2/4] Syncing React dependencies...
cd react_workspace
call npm install
cd ..

echo.
echo [3/4] Optimizing Vite Cache...
if exist "react_workspace\node_modules\.vite" (
    rmdir /s /q "react_workspace\node_modules\.vite"
)

echo.
echo [4/4] Launching React Server...
start /min "React Server" cmd /k "cd react_workspace && npm run dev -- --force"

echo Workspace ready! VS Code will now attach Flutter...