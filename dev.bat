@echo off
setlocal
set "ROOT=%~dp0"
cd /d "%ROOT%"

echo ==========================================
echo Starting PESO JobKonek Workspace...
echo ==========================================

:: --------------------------------------------
:: ASSET GENERATION (SAFE FOR GITHUB)
:: --------------------------------------------
echo [0/5] Verifying Security Assets...
if not exist ".env" (
    echo   - .env not found. Creating default placeholder...
    echo GEMINI_API_KEY=your_api_key_here_do_not_commit> .env
    echo   [!] Please open .env and replace the placeholder with your actual key.
) else (
    echo   - Existing .env file found and active.
)

if not exist "lib\peso_logic" mkdir "lib\peso_logic"
if not exist "lib\peso_logic\secrets.json" (
    echo   - secrets.json not found. Creating default empty JSON...
    echo {> lib\peso_logic\secrets.json
    echo   "gemini_api_key": "",>> lib\peso_logic\secrets.json
    echo   "warning": "This key is encrypted. Safe to commit to GitHub.">> lib\peso_logic\secrets.json
    echo }>> lib\peso_logic\secrets.json
)
:: --------------------------------------------

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
set /p FOUND_FLUTTER="Please paste the full path to your Flutter 'bin' folder: "

:APPLY_PATH
set "FOUND_FLUTTER=%FOUND_FLUTTER:"=%"
set "PATH=%PATH%;%FOUND_FLUTTER%"
powershell -Command "[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User') + ';%FOUND_FLUTTER%', 'User')"
echo [SUCCESS] Flutter PATH configured.

:FLUTTER_READY
echo.
echo [1/5] Syncing Flutter dependencies...
call flutter pub get

echo.
echo [2/5] Syncing React dependencies...
if exist "react_workspace\node_modules" goto SKIP_NPM
cd react_workspace
call npm install
cd ..
goto REACT_DEPS_DONE

:SKIP_NPM
echo   - node_modules found. Skipping npm install to save time...
:REACT_DEPS_DONE


echo.
echo [3/5] Checking React Server status...
netstat -ano | find "LISTENING" | find ":5173" >nul 2>&1
if %errorlevel% equ 0 goto REACT_RUNNING

echo   - No running server detected. Cleaning Vite cache...
if exist "react_workspace\node_modules\.vite" rmdir /s /q "react_workspace\node_modules\.vite"
echo   - Launching React Server...
start /min "React Server" cmd /k "cd react_workspace && npm run dev"
goto REACT_DONE

:REACT_RUNNING
echo   - React Server is already running on port 5173. Reusing instance...
:REACT_DONE


echo.
echo [4/5] Checking PESO File Watcher status...
tasklist /V /FI "WINDOWTITLE eq PESO File Watcher*" | find "PESO File Watcher" >nul 2>&1
if %errorlevel% equ 0 goto WATCHER_RUNNING

echo   - Spawning Smart Background Watcher...
echo $title = "PESO File Watcher" > watcher.ps1
echo [Console]::Title = $title >> watcher.ps1
echo $global:HasNewFile = $false >> watcher.ps1
echo $watcher = New-Object System.IO.FileSystemWatcher >> watcher.ps1
echo $watcher.Path = "%ROOT%\lib" >> watcher.ps1
echo $watcher.Filter = "*.dart" >> watcher.ps1
echo $watcher.IncludeSubdirectories = $true >> watcher.ps1
echo $watcher.EnableRaisingEvents = $true >> watcher.ps1

echo $createdAction = { >> watcher.ps1
echo     $global:HasNewFile = $true >> watcher.ps1
echo     Write-Host "[!] New file detected! Flag raised. Waiting for your next Ctrl+S..." -ForegroundColor Yellow >> watcher.ps1
echo } >> watcher.ps1

echo $changedAction = { >> watcher.ps1
echo     if ($global:HasNewFile) { >> watcher.ps1
echo         $global:HasNewFile = $false >> watcher.ps1
echo         Write-Host "[*] Ctrl+S detected with a pending new file! Firing Ctrl+Shift+F5..." -ForegroundColor Green >> watcher.ps1
echo         $wshell = New-Object -ComObject wscript.shell >> watcher.ps1
echo         if ($wshell.AppActivate("Visual Studio Code")) { >> watcher.ps1
echo             Start-Sleep -Milliseconds 300 >> watcher.ps1
echo             $wshell.SendKeys("^+{F5}") >> watcher.ps1
echo         } >> watcher.ps1
echo     } >> watcher.ps1
echo } >> watcher.ps1

echo Register-ObjectEvent $watcher "Created" -Action $createdAction ^| Out-Null >> watcher.ps1
echo Register-ObjectEvent $watcher "Changed" -Action $changedAction ^| Out-Null >> watcher.ps1
echo Write-Host "PESO Watcher Active. Monitoring /lib for new files." -ForegroundColor Cyan >> watcher.ps1
echo Write-Host "This window will auto-close if you exit VS Code." -ForegroundColor Gray >> watcher.ps1

echo while ($true) { >> watcher.ps1
echo     if (-not (Get-Process Code -ErrorAction SilentlyContinue)) { >> watcher.ps1
echo         Write-Host "VS Code closed. Terminating watcher..." -ForegroundColor Red >> watcher.ps1
echo         Start-Sleep -Seconds 1 >> watcher.ps1
echo         exit >> watcher.ps1
echo     } >> watcher.ps1
echo     Start-Sleep -Seconds 2 >> watcher.ps1
echo } >> watcher.ps1

start "PESO File Watcher" powershell -NoProfile -ExecutionPolicy Bypass -File watcher.ps1
goto WATCHER_DONE

:WATCHER_RUNNING
echo   - File Watcher is already active. Reusing instance...
:WATCHER_DONE

echo.
echo [5/5] Workspace ready! VS Code will now attach Flutter...