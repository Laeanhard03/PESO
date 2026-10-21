$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$envPath = Join-Path $backendRoot '.env'

if (Test-Path -LiteralPath $envPath) {
    $answer = Read-Host 'Replace backend\.env? Existing values will not be displayed (type YES to continue)'
    if ($answer -cne 'YES') {
        Write-Host 'Cancelled. No files were changed.'
        exit 0
    }
}

function Convert-SecureInputToPlainText {
    param([Parameter(Mandatory = $true)][Security.SecureString]$SecureValue)
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

$mongoSecure = $null
$geminiSecure = $null
$mongoUri = $null
$geminiKey = $null
$randomBytes = New-Object byte[] 48
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()

try {
    Write-Host ''
    Write-Host 'PESO backend secret setup. Input is hidden and values will not be printed.'
    Write-Host 'Use a newly rotated MongoDB Atlas database-user password and a new Gemini API key.'
    Write-Host ''

    $mongoSecure = Read-Host 'New MongoDB Atlas URI (hidden input)' -AsSecureString
    $geminiSecure = Read-Host 'New Gemini API key (hidden input)' -AsSecureString

    $mongoUri = (Convert-SecureInputToPlainText $mongoSecure).Trim()
    $geminiKey = (Convert-SecureInputToPlainText $geminiSecure).Trim()

    if ($mongoUri -notmatch '^mongodb(\+srv)?://' -or
        $mongoUri -match 'YOUR_CLUSTER_HOST|DB_USERNAME|<db_username>|URL_ENCODED_PASSWORD') {
        throw 'The MongoDB URI is still a placeholder or has an unsupported scheme. No credentials were saved.'
    }
    if ($geminiKey.Length -lt 20 -or $geminiKey -match 'PASTE_NEW_GEMINI_KEY_HERE|your_api_key_here') {
        throw 'The Gemini key is empty or still a placeholder. No credentials were saved.'
    }

    $rng.GetBytes($randomBytes)
    $fileLinkSecret = [Convert]::ToBase64String($randomBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')

    $lines = @(
        'PORT=3000',
        'NODE_ENV=development',
        'FIREBASE_PROJECT_ID=capstone-4th-year-peso-ai',
        'FIREBASE_SERVICE_ACCOUNT_PATH=./service-account.json',
        "MONGODB_URI=$mongoUri",
        'MONGODB_DB_NAME=peso_jobkonek',
        "GEMINI_API_KEY=$geminiKey",
        'GEMINI_MODEL=gemini-3.8-flash',
        "FILE_LINK_SECRET=$fileLinkSecret",
        'PUBLIC_API_BASE_URL=http://localhost:3000',
        'CLIENT_ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173'
    )

    Set-Content -LiteralPath $envPath -Value $lines -Encoding UTF8
    Write-Host ''
    Write-Host 'backend\.env was updated. No credential values were displayed.'
    if (-not (Test-Path -LiteralPath (Join-Path $backendRoot 'service-account.json'))) {
        Write-Host 'Next required step: add your Firebase Admin service-account JSON as backend\service-account.json.'
    }
    Write-Host 'Then run: npm run check; npm run dev; and check http://localhost:3000/api/health.'
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    if ($mongoSecure) { $mongoSecure.Dispose() }
    if ($geminiSecure) { $geminiSecure.Dispose() }
    if ($rng) { $rng.Dispose() }
    if ($randomBytes) { [Array]::Clear($randomBytes, 0, $randomBytes.Length) }
    $mongoUri = $null
    $geminiKey = $null
    $fileLinkSecret = $null
}
