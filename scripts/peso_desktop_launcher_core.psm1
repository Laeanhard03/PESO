Set-StrictMode -Version Latest

function Get-PesoNormalizedRoot {
    param([Parameter(Mandatory)][string]$Path)
    try {
        return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    } catch {
        return ''
    }
}

function Test-PesoCommandLineIdentity {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$CommandLine,
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][ValidateSet('flutter', 'vite', 'api', 'edge')][string]$Service,
        [Parameter(Mandatory)][ValidateRange(1, 65535)][int]$Port
    )

    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $false }
    if ($Service -eq 'edge') {
        if ($Port -ne 5237) { return $false }
        $profileRoot = Join-Path $env:LOCALAPPDATA 'PESOJobKonek\edge-profile'
        $profilePattern = '(?i)--user-data-dir=["'']?' + [regex]::Escape($profileRoot) + '["'']?(?:\s|$)'
        return ($CommandLine -match '(?i)msedge\.exe') -and
            ($CommandLine -match $profilePattern) -and
            ($CommandLine -match '(?i)--app=https?://127\.0\.0\.1:5237/?(?:\s|$)')
    }

    $root = Get-PesoNormalizedRoot $ProjectRoot
    if ([string]::IsNullOrWhiteSpace($root)) { return $false }
    $runner = Join-Path $root 'scripts\run_peso_desktop_service.ps1'
    $escapedRoot = [regex]::Escape($root)
    $escapedRunner = [regex]::Escape($runner)
    $lower = $CommandLine.ToLowerInvariant()
    $servicePattern = '(?i)-Service\s+["'']?' + [regex]::Escape($Service) + '["'']?(?:\s|$)'
    $portPattern = '(?i)-Port\s+["'']?' + $Port + '["'']?(?:\s|$)'
    $rootPattern = '(?i)-ProjectRoot\s+["'']?' + $escapedRoot + '["'']?(?:\s|$)'
    return ($lower -match $escapedRunner.ToLowerInvariant()) -and
        ($CommandLine -match $rootPattern) -and
        ($CommandLine -match $servicePattern) -and
        ($CommandLine -match $portPattern)
}

function Test-PesoEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [ValidateRange(1, 30)][int]$TimeoutSeconds = 2
    )

    if ($Uri.Scheme -ne 'http' -or $Uri.Host -notin @('127.0.0.1', 'localhost', '::1')) {
        return $false
    }

    $request = $null
    $response = $null
    try {
        $request = [System.Net.HttpWebRequest]::Create($Uri)
        $request.Method = 'GET'
        $request.AllowAutoRedirect = $false
        $request.Timeout = $TimeoutSeconds * 1000
        $request.ReadWriteTimeout = $TimeoutSeconds * 1000
        $response = [System.Net.HttpWebResponse]$request.GetResponse()
        return ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 300)
    } catch {
        return $false
    } finally {
        if ($null -ne $response) { $response.Close() }
        if ($null -ne $request) { $request.Abort() }
    }
}

function Get-PesoListenerOwner {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateRange(1, 65535)][int]$Port)

    $connections = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    if ($connections.Count -eq 0) { return }

    $owners = @()
    foreach ($connection in $connections) {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($connection.OwningProcess)" -ErrorAction SilentlyContinue
        $owners += [pscustomobject]@{
            Port = $Port
            ProcessId = [int]$connection.OwningProcess
            LocalAddress = [string]$connection.LocalAddress
            ExecutablePath = if ($null -ne $process) { [string]$process.ExecutablePath } else { '' }
            CommandLine = if ($null -ne $process) { [string]$process.CommandLine } else { '' }
            ParentProcessId = if ($null -ne $process) { [int]$process.ParentProcessId } else { 0 }
            MetadataAvailable = ($null -ne $process -and -not [string]::IsNullOrWhiteSpace([string]$process.CommandLine))
        }
    }
    return $owners
}


function Get-PesoBackendCredentialPath {
    param([Parameter(Mandatory)][string]$BackendRoot)

    $root = [System.IO.Path]::GetFullPath($BackendRoot)
    $firebaseSetting = [string]$env:FIREBASE_SERVICE_ACCOUNT_PATH
    $googleSetting = [string]$env:GOOGLE_APPLICATION_CREDENTIALS
    $envFile = Join-Path $root '.env'

    if (Test-Path -LiteralPath $envFile -PathType Leaf) {
        foreach ($line in (Get-Content -LiteralPath $envFile -ErrorAction SilentlyContinue)) {
            if ([string]::IsNullOrWhiteSpace($firebaseSetting) -and
                $line -match '^\s*FIREBASE_SERVICE_ACCOUNT_PATH\s*=\s*(.*?)\s*$') {
                $firebaseSetting = $Matches[1].Trim().Trim('"').Trim("'")
            }
            if ([string]::IsNullOrWhiteSpace($googleSetting) -and
                $line -match '^\s*GOOGLE_APPLICATION_CREDENTIALS\s*=\s*(.*?)\s*$') {
                $googleSetting = $Matches[1].Trim().Trim('"').Trim("'")
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($firebaseSetting)) {
        $firebaseFile = if ([System.IO.Path]::IsPathRooted($firebaseSetting)) {
            $firebaseSetting
        } else {
            Join-Path $root $firebaseSetting
        }
        if (Test-Path -LiteralPath $firebaseFile -PathType Leaf) { return $firebaseFile }
    } else {
        $defaultFile = Join-Path $root 'service-account.json'
        if (Test-Path -LiteralPath $defaultFile -PathType Leaf) { return $defaultFile }
    }

    if (-not [string]::IsNullOrWhiteSpace($googleSetting)) {
        $googleFile = if ([System.IO.Path]::IsPathRooted($googleSetting)) {
            $googleSetting
        } else {
            Join-Path $root $googleSetting
        }
        if (Test-Path -LiteralPath $googleFile -PathType Leaf) { return $googleFile }
    }
    return ''
}


function Get-PesoProcessAncestorIds {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateRange(1, 2147483647)][int]$ProcessId)

    $ids = [System.Collections.Generic.List[int]]::new()
    $seen = [System.Collections.Generic.HashSet[int]]::new()
    $currentId = $ProcessId

    for ($depth = 0; $depth -lt 16 -and $currentId -gt 0; $depth++) {
        if (-not $seen.Add($currentId)) { break }
        $ids.Add($currentId)
        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$currentId" -ErrorAction SilentlyContinue
        if ($null -eq $process) { break }
        $currentId = [int]$process.ParentProcessId
    }
    return $ids.ToArray()
}

function Read-PesoLauncherState {
    param([Parameter(Mandatory)][string]$StatePath)
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        return $null
    }
}

function Test-PesoRecordedProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateRange(1, 2147483647)][int]$ProcessId,
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][ValidateSet('flutter', 'vite', 'api')][string]$Service,
        [Parameter(Mandatory)][ValidateRange(1, 65535)][int]$Port,
        [Parameter(Mandatory)][string]$StatePath
    )

    $root = Get-PesoNormalizedRoot $ProjectRoot
    if ([string]::IsNullOrWhiteSpace($root)) { return $false }
    $state = Read-PesoLauncherState $StatePath
    if ($null -eq $state) { return $false }
    if ((Get-PesoNormalizedRoot ([string]$state.projectRoot)) -ne $root) { return $false }

    $entry = $state.services.$Service
    if ($null -eq $entry) { return $false }
    if ([int]$entry.pid -ne $ProcessId -or [int]$entry.port -ne $Port) { return $false }
    if ([string]$entry.service -ne $Service) { return $false }
    if ((Get-PesoNormalizedRoot ([string]$entry.projectRoot)) -ne $root) { return $false }
    $expectedRunner = Join-Path $root 'scripts\run_peso_desktop_service.ps1'
    if ((Get-PesoNormalizedRoot ([string]$entry.runnerPath)) -ne (Get-PesoNormalizedRoot $expectedRunner)) { return $false }

    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
    if ($null -eq $process) { return $false }
    return (Test-PesoCommandLineIdentity ([string]$process.CommandLine) $root $Service $Port)
}

function Test-PesoListenerOwnership {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('flutter', 'vite', 'api')][string]$Service,
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][ValidateRange(1, 65535)][int]$Port,
        [Parameter(Mandatory)][string]$StatePath
    )

    $owners = @(Get-PesoListenerOwner $Port)
    if ($owners.Count -eq 0) { return $false }
    $state = Read-PesoLauncherState $StatePath
    if ($null -eq $state) { return $false }
    $entry = $state.services.$Service
    if ($null -eq $entry) { return $false }
    if (-not (Test-PesoRecordedProcess ([int]$entry.pid) $ProjectRoot $Service $Port $StatePath)) { return $false }

    foreach ($owner in $owners) {
        if (-not $owner.MetadataAvailable) { return $false }
        $ancestors = @(Get-PesoProcessAncestorIds ([int]$owner.ProcessId))
        if ($ancestors -notcontains ([int]$entry.pid)) { return $false }
    }
    return $true
}

Export-ModuleMember -Function Test-PesoCommandLineIdentity, Test-PesoEndpoint, Get-PesoListenerOwner, Get-PesoBackendCredentialPath, Test-PesoRecordedProcess, Test-PesoListenerOwnership
