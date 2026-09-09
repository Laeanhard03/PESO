@echo off
setlocal
set "ROOT=%~dp0"
cd /d "%ROOT%"

echo ==========================================
echo Starting PESO JobKonek Workspace...
echo ==========================================

<<<<<<< Updated upstream
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
echo [1/3] Syncing Flutter dependencies...
call flutter pub get
=======
:: ---------------------------------
:: FLUTTER SDK
:: ---------------------------------
set "FLUTTER_CMD=C:\flutter\bin\flutter.bat"

if not exist "%FLUTTER_CMD%" (
    echo.
    echo [ERROR] Flutter SDK not found at:
    echo %FLUTTER_CMD%
    pause
    exit /b 1
)

echo Flutter found at: %FLUTTER_CMD%

echo.
echo [1/3] Syncing Flutter dependencies...
call "%FLUTTER_CMD%" pub get
if errorlevel 1 (
    echo.
    echo [ERROR] Flutter dependencies could not be resolved.
    pause
    exit /b 1
)
>>>>>>> Stashed changes

echo.
echo [2/3] Checking React dependencies...
if not exist "react_workspace\node_modules\" (
    echo Node modules not found. Installing React packages...
    cd /d "%ROOT%react_workspace"
    call npm install
    if errorlevel 1 (
        echo.
        echo [ERROR] React dependencies could not be installed.
        pause
        exit /b 1
    )
    cd /d "%ROOT%"
) else (
    echo React dependencies already installed.
)

echo.
echo [3/3] Launching Development Servers...
echo Starting React Vite Server in the background...
start "PESO React" /D "%ROOT%react_workspace" cmd /k npm run dev

<<<<<<< Updated upstream
echo Starting Flutter...
flutter run
=======
echo Starting Flutter web app...
call "%FLUTTER_CMD%" run -d chrome

pause
>>>>>>> Stashed changes
