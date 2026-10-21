param(
    [Parameter(Mandatory)][ValidateSet('vite', 'flutter', 'api')][string]$Service,
    [Parameter(Mandatory)][string]$ProjectRoot,
    [Parameter(Mandatory)][ValidateRange(1, 65535)][int]$Port
)

$ErrorActionPreference = 'Stop'
$expectedPorts = @{ api = 3000; vite = 5173; flutter = 5237 }
if ($Port -ne $expectedPorts[$Service]) {
    throw "Service '$Service' is restricted to port $($expectedPorts[$Service])."
}
if ($ProjectRoot -ne [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')) {
    throw 'ProjectRoot must be a normalized absolute path.'
}
if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'pubspec.yaml') -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'react_workspace\package.json') -PathType Leaf)) {
    throw 'The expected PESO Flutter and React project files were not found in ProjectRoot.'
}

if ($Service -eq 'vite') {
    $viteCommand = Join-Path $ProjectRoot 'react_workspace\node_modules\.bin\vite.cmd'
    if (-not (Test-Path -LiteralPath $viteCommand -PathType Leaf)) {
        throw "Vite is not installed at the expected local path: $viteCommand. The launcher does not install packages."
    }
    $npm = Get-Command npm -ErrorAction Stop
    Push-Location (Join-Path $ProjectRoot 'react_workspace')
    try {
        & $npm.Source run dev -- --host 127.0.0.1 --port 5173 --strictPort
        if ($LASTEXITCODE -ne 0) { throw "Vite exited with code $LASTEXITCODE." }
    } finally {
        Pop-Location
    }
} elseif ($Service -eq 'flutter') {
    $flutter = Get-Command flutter -ErrorAction Stop
    Push-Location $ProjectRoot
    try {
        & $flutter.Source run -d web-server --web-hostname 127.0.0.1 --web-port 5237 --release
        if ($LASTEXITCODE -ne 0) { throw "Flutter Web server exited with code $LASTEXITCODE." }
    } finally {
        Pop-Location
    }
} else {
    $backendRoot = Join-Path $ProjectRoot 'backend'
    $backendEnv = Join-Path $backendRoot '.env'
    $backendServer = Join-Path $backendRoot 'server.js'
    if (-not (Test-Path -LiteralPath $backendEnv -PathType Leaf)) {
        throw 'The MongoDB API is not configured: backend/.env is missing. The launcher never creates or reads secrets.'
    }
    if (-not (Test-Path -LiteralPath $backendServer -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $backendRoot 'node_modules\express\package.json') -PathType Leaf)) {
        throw 'The backend source or its local Express dependencies are missing. Install dependencies from backend/ before starting the API.'
    }

    # The active backend verifies Firebase ID tokens using Google public signing certificates.

    $node = Get-Command node -ErrorAction Stop
    $env:PORT = '3000'
    $env:HOST = '127.0.0.1'
    Push-Location $backendRoot
    try {
        & $node.Source server.js
        if ($LASTEXITCODE -ne 0) { throw "MongoDB API exited with code $LASTEXITCODE." }
    } finally {
        Pop-Location
    }
}
