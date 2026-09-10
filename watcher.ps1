$title = "PESO File Watcher" 
[Console]::Title = $title 
$global:HasNewFile = $false 
$watcher = New-Object System.IO.FileSystemWatcher 
$watcher.Path = "C:\Users\Admin\Desktop\PESOPROTOTYPE\\lib" 
$watcher.Filter = "*.dart" 
$watcher.IncludeSubdirectories = $true 
$watcher.EnableRaisingEvents = $true 
$createdAction = { 
    $global:HasNewFile = $true 
    Write-Host "[!] New file detected! Flag raised. Waiting for your next Ctrl+S..." -ForegroundColor Yellow 
} 
$changedAction = { 
    if ($global:HasNewFile) { 
        $global:HasNewFile = $false 
        Write-Host "[*] Ctrl+S detected with a pending new file! Firing Ctrl+Shift+F5..." -ForegroundColor Green 
        $wshell = New-Object -ComObject wscript.shell 
        if ($wshell.AppActivate("Visual Studio Code")) { 
            Start-Sleep -Milliseconds 300 
            $wshell.SendKeys("^+{F5}") 
        } 
    } 
} 
Register-ObjectEvent $watcher "Created" -Action $createdAction | Out-Null 
Register-ObjectEvent $watcher "Changed" -Action $changedAction | Out-Null 
Write-Host "PESO Watcher Active. Monitoring /lib for new files." -ForegroundColor Cyan 
Write-Host "This window will auto-close if you exit VS Code." -ForegroundColor Gray 
while ($true) { 
    if (-not (Get-Process Code -ErrorAction SilentlyContinue)) { 
        Write-Host "VS Code closed. Terminating watcher..." -ForegroundColor Red 
        Start-Sleep -Seconds 1 
        exit 
    } 
    Start-Sleep -Seconds 2 
} 
