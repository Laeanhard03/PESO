$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$projectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $scriptRoot)).TrimEnd('\')
$runnerPath = Join-Path $scriptRoot 'run_peso_desktop_service.ps1'
$coreModule = Join-Path $scriptRoot 'peso_desktop_launcher_core.psm1'
$stateDirectory = Join-Path $env:LOCALAPPDATA 'PESOJobKonek'
$statePath = Join-Path $stateDirectory 'launcher-state.json'
$edgeProfileDirectory = Join-Path $stateDirectory 'edge-profile'
$logDirectory = Join-Path $stateDirectory 'logs'
$servicePorts = @{ api = 3000; vite = 5173; flutter = 5237 }

Import-Module $coreModule -Force
$serviceUrls = @{ api = 'http://127.0.0.1:3000/api/health'; vite = 'http://127.0.0.1:5173/'; flutter = 'http://127.0.0.1:5237/' }
$readinessTimeoutSeconds = 150

function Read-LauncherState {
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { throw 'State file is empty.' }
        return ($raw | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        throw "Launcher state exists but cannot be read safely; no process will be reused or started. Inspect '$statePath'. $($_.Exception.Message)"
    }
}

function Get-ServiceMap {
    param($State)
    $map = @{}
    if ($null -ne $State -and $null -ne $State.services) {
        foreach ($property in $State.services.PSObject.Properties) {
            if ($property.Name -in @('api', 'vite', 'flutter')) { $map[$property.Name] = $property.Value }
        }
    }
    return $map
}

function Save-LauncherState {
    param([Parameter(Mandatory)][hashtable]$Services)
    $serviceObject = [ordered]@{}
    foreach ($serviceName in @('api', 'vite', 'flutter')) {
        if ($Services.ContainsKey($serviceName) -and $null -ne $Services[$serviceName]) {
            $entry = $Services[$serviceName]
            $serviceObject[$serviceName] = [pscustomobject]@{
                pid = [int]$entry.pid
                projectRoot = [string]$entry.projectRoot
                service = [string]$entry.service
                port = [int]$entry.port
                runnerPath = [string]$entry.runnerPath
                logPath = [string]$entry.logPath
                startedAtUtc = [string]$entry.startedAtUtc
            }
        }
    }
    $state = [pscustomobject]@{
        schemaVersion = 1
        projectRoot = $projectRoot
        updatedAtUtc = [DateTime]::UtcNow.ToString('o')
        services = [pscustomobject]$serviceObject
    }
    $temporaryPath = $statePath + '.tmp'
    $json = $state | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($temporaryPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryPath -Destination $statePath -Force
}

function Test-RecordedRunner {
    param([Parameter(Mandatory)][string]$Service, [hashtable]$Services)
    if (-not $Services.ContainsKey($Service) -or $null -eq $Services[$Service]) { return $false }
    $entry = $Services[$Service]
    return (Test-PesoRecordedProcess -ProcessId ([int]$entry.pid) -ProjectRoot $projectRoot -Service $Service -Port $servicePorts[$Service] -StatePath $statePath)
}

function Start-ServiceRunner {
    param([Parameter(Mandatory)][string]$Service, [hashtable]$Services)
    $port = $servicePorts[$Service]
    $logPath = Join-Path $logDirectory ($Service + '.log')
    $errorLogPath = Join-Path $logDirectory ($Service + '.err.log')
    $powershellExe = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershellExe -PathType Leaf)) {
        throw "Windows PowerShell was not found at '$powershellExe'."
    }
    $quote = [string][char]34
    $argumentList = '-NoProfile -ExecutionPolicy Bypass -File ' + $quote + $runnerPath + $quote + ' -Service ' + $Service + ' -ProjectRoot ' + $quote + $projectRoot + $quote + ' -Port ' + $port
    $process = Start-Process -FilePath $powershellExe -ArgumentList $argumentList -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput $logPath -RedirectStandardError $errorLogPath -PassThru

    $Services[$Service] = [pscustomobject]@{
        pid = [int]$process.Id
        projectRoot = $projectRoot
        service = $Service
        port = $port
        runnerPath = $runnerPath
        logPath = $logPath
        startedAtUtc = [DateTime]::UtcNow.ToString('o')
    }
    Save-LauncherState -Services $Services
    Write-Host "Started PESO $Service runner PID $($process.Id) on loopback port $port."
}


function Test-PesoApiConfigured {
    $backendRoot = Join-Path $projectRoot 'backend'
    if (-not (Test-Path -LiteralPath (Join-Path $backendRoot '.env') -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $backendRoot 'server.js') -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $backendRoot 'node_modules\express\package.json') -PathType Leaf)) {
        return $false
    }

    # The current backend verifies Firebase ID tokens without Admin SDK credentials.
    return [bool](Get-Command node -ErrorAction SilentlyContinue)
}

function Test-PesoApiReady {
    try {
        $response = Invoke-WebRequest -Uri ([uri]$serviceUrls.api) -TimeoutSec 3 -UseBasicParsing
        if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 300) { return $false }
        $health = $response.Content | ConvertFrom-Json -ErrorAction Stop
        return ([bool]$health.ok -and [bool]$health.mongoDbConnected -and [bool]$health.firebaseTokenVerificationReady)
    } catch {
        return $false
    }
}

function Assert-PortPreflight {
    param(
        [hashtable]$Services,
        [Parameter(Mandatory)][string[]]$ServiceNames
    )
    foreach ($serviceName in $ServiceNames) {
        $port = $servicePorts[$serviceName]
        $owners = @(Get-PesoListenerOwner -Port $port)
        if ($owners.Count -gt 0) {
            if (-not (Test-PesoListenerOwnership -Service $serviceName -ProjectRoot $projectRoot -Port $port -StatePath $statePath)) {
                $details = ($owners | ForEach-Object {
                    'PID ' + $_.ProcessId + ' (' + $(if ($_.MetadataAvailable) { $_.ExecutablePath } else { 'process metadata unavailable' }) + ')'
                }) -join '; '
                throw "Port $port is already used by an unverified process ($details). Nothing was stopped; close that exact process yourself or review the port owner before continuing."
            }
            Write-Host "Verified existing PESO $serviceName listener on 127.0.0.1:$port."
        } elseif (Test-RecordedRunner -Service $serviceName -Services $Services) {
            Write-Host "Found the exact PESO $serviceName runner still starting (PID $($Services[$serviceName].pid)); will wait without duplicating it."
        }
    }
}

function Ensure-ServiceStarted {
    param([Parameter(Mandatory)][string]$Service, [hashtable]$Services)
    $owners = @(Get-PesoListenerOwner -Port $servicePorts[$Service])
    if ($owners.Count -gt 0) { return }
    if (Test-RecordedRunner -Service $Service -Services $Services) { return }
    Start-ServiceRunner -Service $Service -Services $Services
}

function Wait-ServiceReady {
    param([Parameter(Mandatory)][string]$Service, [hashtable]$Services)
    $deadline = [DateTime]::UtcNow.AddSeconds($readinessTimeoutSeconds)
    $lastMessageAt = [DateTime]::MinValue
    while ([DateTime]::UtcNow -lt $deadline) {
        $owners = @(Get-PesoListenerOwner -Port $servicePorts[$Service])
        if ($owners.Count -gt 0) {
            if (-not (Test-PesoListenerOwnership -Service $Service -ProjectRoot $projectRoot -Port $servicePorts[$Service] -StatePath $statePath)) {
                throw "Port $($servicePorts[$Service]) became owned by an unverified process while $Service was starting. Nothing was stopped."
            }
            $serviceReady = if ($Service -eq 'api') {
                Test-PesoApiReady
            } else {
                Test-PesoEndpoint -Uri ([uri]$serviceUrls[$Service]) -TimeoutSeconds 2
            }
            if ($serviceReady) {
                Write-Host "READY: $Service passed its local readiness check at $($serviceUrls[$Service])"
                return
            }
            if ($Service -eq 'api' -and
                (Test-PesoEndpoint -Uri ([uri]$serviceUrls.api) -TimeoutSeconds 2) -and
                ([DateTime]::UtcNow - $deadline.AddSeconds(-$readinessTimeoutSeconds)).TotalSeconds -gt 25) {
                throw "The MongoDB API responds but its dependencies are not ready. Check the API logs under '$logDirectory'. Secret values are not printed."
            }
        } elseif (-not (Test-RecordedRunner -Service $Service -Services $Services)) {
            $logPath = if ($Services.ContainsKey($Service)) { $Services[$Service].logPath } else { '' }
            throw "The exact PESO $Service runner exited before its listener became ready. Check '$logPath' and its paired .err.log. No unrelated process was stopped."
        }

        if (([DateTime]::UtcNow - $lastMessageAt).TotalSeconds -ge 15) {
            Write-Host "Waiting for PESO $Service on 127.0.0.1:$($servicePorts[$Service])..."
            $lastMessageAt = [DateTime]::UtcNow
        }
        Start-Sleep -Seconds 1
    }
    $logPath = if ($Services.ContainsKey($Service)) { $Services[$Service].logPath } else { '' }
    throw "Timed out waiting for PESO $Service at $($serviceUrls[$Service]). No Edge app window was opened. Check '$logPath' and its paired .err.log."
}

function Resolve-EdgePath {
    $command = Get-Command msedge.exe -ErrorAction SilentlyContinue
    if ($null -ne $command -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) { return $command.Source }
    $programFilesX86Item = Get-Item -LiteralPath 'Env:ProgramFiles(x86)' -ErrorAction SilentlyContinue
    $programFilesX86 = if ($null -ne $programFilesX86Item) { [string]$programFilesX86Item.Value } else { '' }
    $candidates = @(
        $(if ($programFilesX86) { Join-Path $programFilesX86 'Microsoft\Edge\Application\msedge.exe' }),
        $(if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe' }),
        $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe' })
    )
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace([string]$candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    return $null
}

function Open-EdgeApp {
    $edgePath = Resolve-EdgePath
    if ([string]::IsNullOrWhiteSpace($edgePath)) {
        throw 'Microsoft Edge was not found; both local services are ready, but the app window was not opened.'
    }
    $edgeProcesses = @(Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" -ErrorAction SilentlyContinue)
    foreach ($edgeProcess in $edgeProcesses) {
        if (Test-PesoCommandLineIdentity -CommandLine ([string]$edgeProcess.CommandLine) -ProjectRoot $projectRoot -Service edge -Port 5237) {
            Write-Host "Reusing the already-open PESO JobKonek app window (verified Edge PID $($edgeProcess.ProcessId))."
            return
        }
    }
    New-Item -ItemType Directory -Path $edgeProfileDirectory -Force | Out-Null
    $edgeArguments = @('--user-data-dir=' + [string][char]34 + $edgeProfileDirectory + [string][char]34, '--app=http://127.0.0.1:5237')
    Start-Process -FilePath $edgePath -ArgumentList $edgeArguments | Out-Null
    Write-Host 'Opened the PESO JobKonek Edge app window.'
}

try {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -PathType Leaf)) {
        throw "Expected Flutter project file was not found beneath '$projectRoot'."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'react_workspace\package.json') -PathType Leaf)) {
        throw "Expected React workspace package.json was not found beneath '$projectRoot'."
    }
    if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
        throw "The PESO service runner is missing: '$runnerPath'."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'react_workspace\node_modules\.bin\vite.cmd') -PathType Leaf)) {
        throw 'The local Vite install is missing. This launcher does not run npm install.'
    }
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw 'Flutter was not found on PATH. Ensure Flutter is installed and available in the user PATH.'
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw 'npm was not found on PATH. Ensure Node.js/npm is installed and available in the user PATH.'
    }

    New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $state = Read-LauncherState
    if ($null -ne $state -and [System.IO.Path]::GetFullPath([string]$state.projectRoot).TrimEnd('\') -ne $projectRoot) {
        throw "Launcher state belongs to another project root ($($state.projectRoot)); it was preserved and no process was started. Review '$statePath'."
    }
    $services = Get-ServiceMap -State $state
    $activeServiceNames = @('vite', 'flutter')
    $apiConfigured = Test-PesoApiConfigured
    if ($apiConfigured) { $activeServiceNames += 'api' }

    # Inspect every enabled port first; foreign listeners are never auto-killed.
    Assert-PortPreflight -Services $services -ServiceNames $activeServiceNames
    foreach ($serviceName in $activeServiceNames) {
        Ensure-ServiceStarted -Service $serviceName -Services $services
    }
    foreach ($serviceName in $activeServiceNames) {
        Wait-ServiceReady -Service $serviceName -Services $services
    }
    Open-EdgeApp

    Write-Host ''
    Write-Host 'PESO JobKonek is ready.'
    Write-Host 'Flutter Web: http://127.0.0.1:5237/'
    Write-Host 'React NSRP/resume: http://127.0.0.1:5173/ and /resume'
    if ($apiConfigured) {
        Write-Host 'MongoDB API health: http://127.0.0.1:3000/api/health'
    } else {
        Write-Warning 'MongoDB API not started: backend/.env, local API dependencies, and a Firebase Admin credential file are required. Complete backend/MONGODB_BACKEND_SETUP.md to enable profile/onboarding/artifact API features. No credential files were modified.'
    }
    Write-Host "Safe launch metadata: $statePath"
    Write-Host "Service logs: $logDirectory"
} catch {
    Write-Error ("PESO desktop launcher stopped safely: " + $_.Exception.Message)
    exit 1
}
