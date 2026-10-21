$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$envPath = Join-Path $backendRoot '.env'
$envFileExisted = Test-Path -LiteralPath $envPath
$initialEnvHash = if ($envFileExisted) { (Get-FileHash -Algorithm SHA256 -LiteralPath $envPath).Hash } else { $null }
$existingValues = [ordered]@{}
$tempEnvPath = $null

if ($envFileExisted) {
    $answer = Read-Host 'Replace backend\.env? Existing values will not be displayed (type YES to continue)'
    if ($answer -cne 'YES') { Write-Host 'Cancelled. No files were changed.'; exit 0 }
    foreach ($line in [IO.File]::ReadAllLines($envPath)) {
        $cleanLine = $line.TrimStart([char]0xFEFF)
        if ([string]::IsNullOrWhiteSpace($cleanLine) -or $cleanLine.TrimStart().StartsWith('#')) { continue }
        $match = [regex]::Match($cleanLine, '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$')
        if ($match.Success) { $existingValues[$match.Groups[1].Value] = $match.Groups[2].Value }
    }
}

function Convert-SecureInputToPlainText {
    param([Parameter(Mandatory = $true)][Security.SecureString]$SecureValue)
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

$mongoSecure = $null
$mongoUri = $null
$fileLinkSecret = $null
$geminiEncryptionSecret = $null
$candidateEncryptionSecret = $null
$rng = $null
$randomBytes = $null
$encryptionBytes = $null
$decodedEncryptionBytes = $null
$values = $null
$backupPath = $null
$swapBackupPath = $null

try {
    Write-Host ''
    Write-Host 'PESO local Admin/data API setup. MongoDB input is hidden and never printed.'
    Write-Host 'Existing Gemini settings are preserved; secret values are never displayed.'
    $mongoSecure = Read-Host 'MongoDB Atlas URI for the dedicated least-privilege app user (hidden input)' -AsSecureString
    $mongoUri = (Convert-SecureInputToPlainText $mongoSecure).Trim()
    if ($mongoUri -notmatch '^mongodb(\+srv)?://' -or $mongoUri -match 'YOUR_CLUSTER_HOST|DB_USERNAME|<db_username>|URL_ENCODED_PASSWORD') {
        throw 'The MongoDB URI is still a placeholder or has an unsupported scheme. No credentials were saved.'
    }
    $uri = $null
    if (-not [Uri]::TryCreate($mongoUri, [UriKind]::Absolute, [ref]$uri) -or
        -not $uri.Host -or $uri.Scheme -notin @('mongodb','mongodb+srv')) {
        throw 'The MongoDB URI could not be parsed safely. No credentials were saved.'
    }

    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    if ($existingValues.Contains('FILE_LINK_SECRET') -and -not [string]::IsNullOrWhiteSpace([string]$existingValues['FILE_LINK_SECRET'])) {
        $fileLinkSecret = [string]$existingValues['FILE_LINK_SECRET']
    } else {
        $randomBytes = New-Object byte[] 48
        $rng.GetBytes($randomBytes)
        $fileLinkSecret = [Convert]::ToBase64String($randomBytes).TrimEnd('=').Replace('+','-').Replace('/','_')
    }

    # Never silently rotate this encryption key; existing MongoDB ciphertext depends on it.
    $candidateEncryptionSecret = [string]$existingValues['GEMINI_KEY_ENCRYPTION_SECRET']
    if (-not [string]::IsNullOrWhiteSpace($candidateEncryptionSecret)) {
        try { $decodedEncryptionBytes = [Convert]::FromBase64String($candidateEncryptionSecret) }
        catch { throw 'The existing Gemini encryption secret is invalid. Recover the verified secret backup before continuing.' }
        if ($decodedEncryptionBytes.Length -ne 32 -or [Convert]::ToBase64String($decodedEncryptionBytes) -cne $candidateEncryptionSecret) {
            throw 'The existing Gemini encryption secret is invalid. Recover the verified secret backup before continuing.'
        }
        $geminiEncryptionSecret = $candidateEncryptionSecret
    } else {
        if ($envFileExisted) {
            $answer = Read-Host 'No Gemini encryption secret exists in .env. If managed keys exist they may become unreadable. Type GENERATE NEW ENCRYPTION SECRET only if safe'
            if ($answer -cne 'GENERATE NEW ENCRYPTION SECRET') {
                throw 'Cancelled because creation of a new encryption secret was not confirmed.'
            }
        }
        $encryptionBytes = New-Object byte[] 32
        $rng.GetBytes($encryptionBytes)
        $geminiEncryptionSecret = [Convert]::ToBase64String($encryptionBytes)
    }

    # Keep all unknown values, including GEMINI_API_KEY. Remove retired SMS settings before writing the configuration. Missing host default is HOST=127.0.0.1.
    $values = [ordered]@{}
    foreach ($key in $existingValues.Keys) { $values[$key] = $existingValues[$key] }
    foreach ($key in @('SMS_AUTH_ENABLED', 'SMS_API_KEY', 'SMS_OTP_PEPPER', 'FIREBASE_SMS_PASSWORD_RESET_ENABLED', 'PASSWORD_RESET_SMS_PEPPER')) { [void]$values.Remove($key) }
    $defaults = [ordered]@{
        PORT='3000'
        HOST='127.0.0.1'
        NODE_ENV='development'
        FIREBASE_PROJECT_ID='capstone-4th-year-peso-ai'
        INITIAL_ADMIN_EMAIL='admin@example.invalid'
        PUBLIC_API_BASE_URL='http://localhost:3000'
        CLIENT_ALLOWED_ORIGINS='http://localhost:5173,http://127.0.0.1:5173'
        GEMINI_MODEL='gemini-3.8-flash'
    }
    foreach ($key in $defaults.Keys) { if (-not $values.Contains($key)) { $values[$key] = $defaults[$key] } }
    $values['MONGODB_URI'] = $mongoUri
    $values['MONGODB_DB_NAME'] = 'peso_jobkonek'
    $values['FILE_LINK_SECRET'] = $fileLinkSecret
    $values['GEMINI_KEY_ENCRYPTION_SECRET'] = $geminiEncryptionSecret
    $lines = @(
        foreach ($key in $values.Keys) {
            $value = [string]$values[$key]
            if ($value -match '[\r\n]') { throw 'An environment setting contains an invalid line break. No files were changed.' }
            "$key=$value"
        }
    )

    $currentUserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $icacls = Join-Path $env:SystemRoot 'System32\icacls.exe'

    if ($envFileExisted) {
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $envPath).Hash -cne $initialEnvHash) {
            throw 'backend\.env changed during setup. No files were changed; rerun after reviewing the change.'
        }
        if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { throw 'The local secure-backup location is unavailable. No files were changed.' }
        $backupRoot = Join-Path $env:LOCALAPPDATA 'PESOJobKonek\secure-backups'
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        $userBackupGrant = '*' + $currentUserSid + ':(OI)(CI)F'
        & $icacls $backupRoot '/inheritance:r' '/grant:r' $userBackupGrant '*S-1-5-18:(OI)(CI)F' | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not restrict the secure backup folder permissions. No environment changes were made.'
        }
        $backupAclEntries = @(Get-Acl -LiteralPath $backupRoot).Access
        foreach ($entry in $backupAclEntries) {
            $sid = $null
            try { $sid = $entry.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value } catch {}
            if ($entry.AccessControlType -eq 'Allow' -and $sid -notin @($currentUserSid,'S-1-5-18')) {
                throw 'Unexpected access remains on the secure backup folder. No environment changes were made.'
            }
        }
        $backupPath = Join-Path $backupRoot ('backend-env-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.bak')
        [IO.File]::Copy($envPath, $backupPath)
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $backupPath).Hash -cne $initialEnvHash) {
            Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
            throw 'The local environment backup could not be verified. No files were changed.'
        }
        $swapBackupPath = Join-Path $backupRoot ('backend-env-replace-' + [guid]::NewGuid().ToString('N') + '.bak')
    }

    # Write to a sibling temporary file, then atomically replace the live config.
    $tempEnvPath = $envPath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    New-Item -ItemType File -Path $tempEnvPath -Force | Out-Null
    $userFileGrant = '*' + $currentUserSid + ':F'
    & $icacls $tempEnvPath '/inheritance:r' '/grant:r' $userFileGrant '*S-1-5-18:F' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not restrict the environment temp-file permissions. No environment changes were made.'
    }
    [IO.File]::WriteAllLines($tempEnvPath,[string[]]$lines,(New-Object System.Text.UTF8Encoding($false)))
    if ($envFileExisted) {
        [IO.File]::Replace($tempEnvPath,$envPath,$swapBackupPath)
        $tempEnvPath = $null
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $swapBackupPath).Hash -cne $initialEnvHash) {
            throw 'The atomic-replace backup did not match the original environment. Preserve both backup files and recover before continuing.'
        }
    } else {
        [IO.File]::Move($tempEnvPath,$envPath)
        $tempEnvPath = $null
    }
    Write-Host ''
    Write-Host 'backend\.env was configured locally. No credential values were displayed.'
    if ($backupPath) { Write-Host 'A verified local secure backup was created.' }
    Write-Host 'The Gemini encryption secret was preserved or generated; its value was not shown.'
    Write-Host 'Start the guarded API runner and verify /api/health before opening the Admin key editor.'
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    if ($tempEnvPath -and (Test-Path -LiteralPath $tempEnvPath)) { Remove-Item -LiteralPath $tempEnvPath -Force -ErrorAction SilentlyContinue }
    if ($mongoSecure) { $mongoSecure.Dispose() }
    if ($rng) { $rng.Dispose() }
    if ($randomBytes) { [Array]::Clear($randomBytes,0,$randomBytes.Length) }
    if ($encryptionBytes) { [Array]::Clear($encryptionBytes,0,$encryptionBytes.Length) }
    if ($decodedEncryptionBytes) { [Array]::Clear($decodedEncryptionBytes,0,$decodedEncryptionBytes.Length) }
    if ($existingValues) { $existingValues.Clear() }
    if ($values) { $values.Clear() }
    $mongoUri = $null
    $fileLinkSecret = $null
    $geminiEncryptionSecret = $null
    $candidateEncryptionSecret = $null
}
