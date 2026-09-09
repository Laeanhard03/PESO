@echo off
echo ==========================================
echo Starting PESO JobKonek Workspace...
echo ==========================================

:: ---------------------------------
:: FIX GIT SECURITY FOR FLUTTER
:: ---------------------------------
:: This prevents the "not a clone of the GitHub project" error 
:: by telling Git to trust local directories on Windows.
git config --global --add safe.directory "*"

:: ---------------------------------
:: AUTO-DETECT FLUTTER PATH
:: ---------------------------------
set "FLUTTER_CMD=flutter"
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo Flutter not found in global PATH. Scanning common directories...
    
    if exist "C:\src\flutter\bin\flutter.bat" (
        set "FLUTTER_CMD=C:\src\flutter\bin\flutter.bat"
    ) else if exist "C:\flutter\bin\flutter.bat" (
        set "FLUTTER_CMD=C:\flutter\bin\flutter.bat"
    ) else if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
        set "FLUTTER_CMD=%USERPROFILE%\flutter\bin\flutter.bat"
    ) else (
        echo.
        echo [ERROR] Could not automatically find the Flutter SDK!
        echo Please make sure Flutter is installed or add it to your Windows PATH.
        pause
        exit /b 1
    )
    echo Success! Found Flutter at: %FLUTTER_CMD%
)

echo.
echo [1/3] Syncing Flutter dependencies...
call "%FLUTTER_CMD%" pub get

echo.
echo [2/3] Checking React dependencies...
if not exist "react_workspace\node_modules\" (
    echo Node modules not found. Installing React packages...
    cd react_workspace
    call npm install
    cd ..
) else (
    echo React dependencies already installed.
)

echo.
echo [3/3] Launching Development Servers...
echo Starting React Vite Server in the background...
start /min "React Server" cmd /k "cd react_workspace && npm run dev"

echo Starting Flutter...
"%FLUTTER_CMD%" run