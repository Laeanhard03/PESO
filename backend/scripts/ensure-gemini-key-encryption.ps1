param(
    [string]$EnvironmentPath,
    [switch]$ConfirmAddEncryptionSecret
)

$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($EnvironmentPath)) {
    $EnvironmentPath = Join-Path $backendRoot '.env'
}
$envPath = [IO.Path]::GetFullPath($EnvironmentPath)
if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
    throw 'The backend environment file does not exist. Run the Admin setup helper first.'
}
if (-not $ConfirmAddEncryptionSecret) {
    throw 'No changes made. Rerun with -ConfirmAddEncryptionSecret after reviewing the live configuration and key-vault approval.'
}

$initialHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $envPath).Hash
$lines = [IO.File]::ReadAllLines($envPath)
$secretLines = @($lines | Where-Object { $_ -match '^\s*GEMINI_KEY_ENCRYPTION_SECRET\s*=' })
$tempPath = $null
$backupPath = $null
$rng = $null
$secretBytes = $null
$secretValue = $null

try {
    if ($secretLines.Count -gt 1) {
        throw 'Multiple Gemini encryption secret entries exist. No changes were made; reconcile them manually without displaying their values.'
    }
    if ($secretLines.Count -eq 1) {
        $existing = [regex]::Replace($secretLines[0], '^\s*GEMINI_KEY_ENCRYPTION_SECRET\s*=', '')
        try { $decoded = [Convert]::FromBase64String($existing) }
        catch { throw 'An existing Gemini encryption secret is invalid. No changes were made; recover the verified secret backup.' }
        try {
            if ($decoded.Length -ne 32 -or [Convert]::ToBase64String($decoded) -cne $existing) {
                throw 'An existing Gemini encryption secret is invalid. No changes were made; recover the verified secret backup.'
            }
        }
        finally { [Array]::Clear($decoded, 0, $decoded.Length) }
        Write-Host 'Gemini key encryption secret is already configured and valid; no changes made.'
        return
    }

    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $secretBytes = New-Object byte[] 32
    $rng.GetBytes($secretBytes)
    $secretValue = [Convert]::ToBase64String($secretBytes)
    $newLines = @($lines) + ("GEMINI_KEY_ENCRYPTION_SECRET=" + $secretValue)

    $localAppData = [string]$env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        throw 'The secure backup location is unavailable. No files were changed.'
    }
    $backupRoot = Join-Path $localAppData 'PESOJobKonek\secure-backups'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

    # Restrict backup DACL using icacls; this avoids Set-Acl's SACL privilege requirement.
    $currentUserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $icacls = Join-Path $env:SystemRoot 'System32\icacls.exe'
    $userGrant = '*' + $currentUserSid + ':(OI)(CI)F'
    & $icacls $backupRoot '/inheritance:r' '/grant:r' $userGrant '*S-1-5-18:(OI)(CI)F' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not apply restricted permissions to the secure backup folder. No environment changes were made.'
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

    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $envPath).Hash -cne $initialHash) {
        throw 'The environment file changed while setup was being prepared. No changes made; retry after review.'
    }

    $tempPath = $envPath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    New-Item -ItemType File -Path $tempPath -Force | Out-Null
    $userFileGrant = '*' + $currentUserSid + ':F'
    & $icacls $tempPath '/inheritance:r' '/grant:r' $userFileGrant '*S-1-5-18:F' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not apply restricted permissions to the environment temp file. No changes were made.'
    }
    [IO.File]::WriteAllLines($tempPath, [string[]]$newLines, (New-Object System.Text.UTF8Encoding($false)))
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $envPath).Hash -cne $initialHash) {
        throw 'The environment file changed during setup. No changes made; retry after review.'
    }
    [IO.File]::Replace($tempPath, $envPath, $backupPath)
    $tempPath = $null
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $backupPath).Hash -cne $initialHash) {
        throw 'The secure rollback backup failed verification. Do not continue until the backed-up environment is reviewed.'
    }
    Write-Host 'Gemini key encryption secret added. Its value was not displayed.'
    Write-Host 'A verified access-restricted backup was created.'
}
finally {
    if ($tempPath -and (Test-Path -LiteralPath $tempPath)) {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }
    if ($rng) { $rng.Dispose() }
    if ($secretBytes) { [Array]::Clear($secretBytes, 0, $secretBytes.Length) }
    if ($secretValue) { $secretValue = $null }
    if ($lines) { [Array]::Clear($lines, 0, $lines.Length) }
    if ($newLines) { [Array]::Clear($newLines, 0, $newLines.Length) }
}
