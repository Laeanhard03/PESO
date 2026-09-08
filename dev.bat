@echo off
echo Starting React Vite Server...

:: Opens a new minimized terminal window just for React
start /min "React Server" cmd /k "cd react_workspace && npm run dev"

echo Starting Flutter...
:: Running 'flutter run' without flags will prompt you to select a device
flutter run