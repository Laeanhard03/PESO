@echo off
setlocal
set "ROOT=%~dp0"
cd /d "%ROOT%"

echo ==========================================
echo Starting PESO JobKonek Workspace...
echo ==========================================

:: Prevents the "not a clone" error for anyone pulling this repo
git config --global --add safe.directory "*"

:: ---------------------------------------------------------
:: AUTOMATED FLUTTER PATH CONFIGURATION
:: ---------------------------------------------------------
cmd /c flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [!] 'flutter' command not found. Attempting to fix Windows PATH...
    
    set "FOUND_FLUTTER="
    
    :: 1. Scan common installation directories
    if exist "C:\src\flutter\bin\flutter.bat" set "FOUND_FLUTTER=C:\src\flutter\bin"
    if exist "C:\flutter\bin\flutter.bat" set "FOUND_FLUTTER=C:\flutter\bin"
    if exist "%USERPROFILE%\flutter\bin\flutter.bat" set "FOUND_FLUTTER=%USERPROFILE%\flutter\bin"
    
    :: 2. If it still can't find it, ask the teammate where they put it
    if not defined FOUND_FLUTTER (
        echo [ERROR] Could not automatically locate the Flutter SDK.
        set /p FOUND_FLUTTER="Please paste the full path to your Flutter 'bin' folder (e.g., C:\flutter\bin): "
    )
    
    :: 3. Update the active terminal session so the script doesn't crash today
    set "PATH=%PATH%;%FOUND_FLUTTER%"
    
    :: 4. Safely inject it into their permanent Windows User PATH for tomorrow
    echo Adding Flutter to permanent Windows Environment Variables...
    powershell -Command "[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User') + ';%FOUND_FLUTTER%', 'User')"
    
    echo [SUCCESS] Flutter PATH configured at: %FOUND_FLUTTER%
    echo.
)

:: ---------------------------------------------------------
:: WORKSPACE BOOT SEQUENCE
:: ---------------------------------------------------------
echo [1/4] Syncing Flutter dependencies...
call flutter pub get
if errorlevel 1 (
    echo.
    echo [ERROR] Flutter dependencies could not be resolved.
    pause
    exit /b 1
)

echo.
echo [2/4] Syncing React dependencies...
echo Checking for new packages like react-router-dom...
cd react_workspace
call npm install
cd ..

echo.
echo [3/4] Self-Healing: Optimizing Vite Cache...
:: This completely prevents the "Invalid Hook Call" error 
:: by deleting the confused Vite cache before it can crash.
if exist "react_workspace\node_modules\.vite" (
    echo Wiping old Vite cache to sync React instances...
    rmdir /s /q "react_workspace\node_modules\.vite"
)

echo.
echo [4/4] Launching Development Servers...
echo Starting React Vite Server in the background (Forced Sync)...
:: Using --force as an extra layer of protection
start /min "React Server" cmd /k "cd react_workspace && npm run dev -- --force"

echo Starting Flutter web app...
flutter run -d chrome

pause