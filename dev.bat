@echo off
echo ==========================================
echo Starting PESO JobKonek Workspace...
echo ==========================================

echo.
echo [1/3] Syncing Flutter dependencies...
:: 'call' ensures the script doesn't stop after running flutter pub get
call flutter pub get

echo.
echo [2/3] Checking React dependencies...
:: Checks if node_modules is missing. If it is, it installs them automatically.
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
flutter run