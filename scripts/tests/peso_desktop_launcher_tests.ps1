$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modulePath = Join-Path $root 'scripts\peso_desktop_launcher_core.psm1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    Write-Error "RED: expected missing launcher module at $modulePath"
    exit 1
}

Import-Module $modulePath -Force

$script:checks = 0
function Assert-True([bool]$condition, [string]$message) {
    $script:checks++
    if (-not $condition) { throw "FAIL: $message" }
}
function Assert-False([bool]$condition, [string]$message) {
    Assert-True (-not $condition) $message
}

$projectRoot = [System.IO.Path]::GetFullPath($root).TrimEnd('\')
$runner = Join-Path $projectRoot 'scripts\run_peso_desktop_service.ps1'
$viteLine = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $runner + '" -Service vite -ProjectRoot "' + $projectRoot + '" -Port 5173'
$flutterLine = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $runner + '" -Service flutter -ProjectRoot "' + $projectRoot + '" -Port 5237'
$apiLine = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $runner + '" -Service api -ProjectRoot "' + $projectRoot + '" -Port 3000'
$edgeProfile = Join-Path $env:LOCALAPPDATA 'PESOJobKonek\edge-profile'
$edgeLine = '"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --user-data-dir="' + $edgeProfile + '" --app=http://127.0.0.1:5237'

Assert-True (Test-PesoCommandLineIdentity $viteLine $projectRoot 'vite' 5173) 'accepts the exact Vite runner identity'
Assert-True (Test-PesoCommandLineIdentity $flutterLine $projectRoot 'flutter' 5237) 'accepts the exact Flutter runner identity'
Assert-True (Test-PesoCommandLineIdentity $apiLine $projectRoot 'api' 3000) 'accepts the exact MongoDB API runner identity'
Assert-False (Test-PesoCommandLineIdentity $apiLine $projectRoot 'api' 3001) 'rejects the wrong API port'
Assert-False (Test-PesoCommandLineIdentity $apiLine $projectRoot 'vite' 3000) 'rejects the API command line for the wrong service'
Assert-True (Test-PesoCommandLineIdentity $edgeLine $projectRoot 'edge' 5237) 'accepts the expected Edge app URL'
Assert-False (Test-PesoCommandLineIdentity $viteLine ($projectRoot + '\another-project') 'vite' 5173) 'rejects a foreign project root'
Assert-False (Test-PesoCommandLineIdentity $viteLine $projectRoot 'vite' 5174) 'rejects the wrong Vite port'
Assert-False (Test-PesoCommandLineIdentity $viteLine $projectRoot 'flutter' 5173) 'rejects a service-kind mismatch'
Assert-False (Test-PesoCommandLineIdentity '"msedge.exe" --app=http://127.0.0.1:5237' $projectRoot 'edge' 5237) 'rejects an app on the default/shared Edge profile'
Assert-False (Test-PesoCommandLineIdentity ('"msedge.exe" --user-data-dir="' + $edgeProfile + '" --app=https://example.com') $projectRoot 'edge' 5237) 'rejects an app URL mismatch'

$freePort = 64000
while ($freePort -lt 65000 -and (Get-PesoListenerOwner $freePort)) { $freePort++ }
Assert-True ($freePort -lt 65000) 'found a test port without a listener'
Assert-True ($null -eq (Get-PesoListenerOwner $freePort)) 'returns null for a port with no listener'
Assert-False (Test-PesoEndpoint ("http://127.0.0.1:" + $freePort + "/") 1) 'returns false when a local endpoint is not responding'

$tempBackend = Join-Path $env:TEMP ('peso-backend-test-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tempBackend | Out-Null
    $relativePath = Join-Path $tempBackend 'test-account.json'
    Set-Content -LiteralPath $relativePath -Value '{}' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $tempBackend '.env') -Value 'FIREBASE_SERVICE_ACCOUNT_PATH=test-account.json' -Encoding UTF8
    $oldPath = $env:FIREBASE_SERVICE_ACCOUNT_PATH
    $oldGooglePath = $env:GOOGLE_APPLICATION_CREDENTIALS
    $env:FIREBASE_SERVICE_ACCOUNT_PATH = ''
    $env:GOOGLE_APPLICATION_CREDENTIALS = ''
    Assert-True ((Get-PesoBackendCredentialPath -BackendRoot $tempBackend) -eq $relativePath) 'resolves a relative account-file path from .env'
    Remove-Item -LiteralPath (Join-Path $tempBackend '.env') -Force
    Assert-True ((Get-PesoBackendCredentialPath -BackendRoot $tempBackend) -eq '') 'does not report an absent account file'
    $env:FIREBASE_SERVICE_ACCOUNT_PATH = $oldPath
    $env:GOOGLE_APPLICATION_CREDENTIALS = $oldGooglePath
}
finally {
    $env:FIREBASE_SERVICE_ACCOUNT_PATH = $oldPath
    $env:GOOGLE_APPLICATION_CREDENTIALS = $oldGooglePath
    Remove-Item -LiteralPath $tempBackend -Recurse -Force -ErrorAction SilentlyContinue
}

$tempState = Join-Path $env:TEMP ('peso-launcher-test-' + [guid]::NewGuid().ToString('N') + '.json')
try {
    $state = @{
        projectRoot = $projectRoot
        services = @{
            vite = @{
                pid = $PID
                projectRoot = $projectRoot
                service = 'vite'
                port = 5173
                runnerPath = $runner
                startedAtUtc = [DateTime]::UtcNow.ToString('o')
            }
        }
    }
    $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $tempState -Encoding UTF8
    Assert-False (Test-PesoRecordedProcess $PID $projectRoot 'vite' 5173 $tempState) 'does not trust a PID whose current command line is not the exact runner'
    Assert-False (Test-PesoRecordedProcess 2147483646 $projectRoot 'vite' 5173 $tempState) 'rejects a nonexistent/stale PID'
    Assert-False (Test-PesoRecordedProcess $PID ($projectRoot + '\foreign') 'vite' 5173 $tempState) 'rejects saved state for another root'
}
finally {
    Remove-Item -LiteralPath $tempState -Force -ErrorAction SilentlyContinue
}
Write-Output "PASS: $script:checks launcher-core assertions"
