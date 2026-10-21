@echo off
setlocal
set "SCRIPT=%~dp0scripts\launch_peso_desktop.ps1"
if not exist "%SCRIPT%" (
  echo PESO JobKonek launcher script was not found:
  echo %SCRIPT%
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" (
  echo.
  echo PESO launcher stopped safely. Review the message above and the logs under %%LOCALAPPDATA%%\PESOJobKonek\logs.
  pause
)
exit /b %RESULT%
