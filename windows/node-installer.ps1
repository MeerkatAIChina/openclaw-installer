# Node Installer for Windows (PowerShell)

param(
    [int]$MinMajor = 22,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("info", "success", "warn", "error")]
        [string]$Level = "info"
    )
    $prefix = switch ($Level) {
        "success" { "[OK]" }
        "warn" { "[WARN]" }
        "error" { "[ERR]" }
        default { "[INFO]" }
    }
    Microsoft.PowerShell.Utility\Write-Host "$prefix $Message"
}

function Refresh-PathFromRegistry {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Get-NodeVersion {
    try {
        $version = node --version 2>$null
        if ($version) {
            return $version -replace "^v", ""
        }
    }
    catch { }
    return $null
}

function Install-NodeViaWinget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        return $false
    }
    Write-Log "Using winget..." "info"
    try {
        if ($DryRun) {
            Write-Log "[DRY RUN] winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements" "info"
            return $true
        }
        winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        Refresh-PathFromRegistry
        Write-Log "Node.js installed via winget" "success"
        return $true
    }
    catch {
        Write-Log "Winget install failed: $_" "warn"
        return $false
    }
}

function Install-NodeViaChoco {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        return $false
    }
    Write-Log "Using chocolatey..." "info"
    try {
        if ($DryRun) {
            Write-Log "[DRY RUN] choco install nodejs-lts -y" "info"
            return $true
        }
        choco install nodejs-lts -y 2>&1 | Out-Null
        Refresh-PathFromRegistry
        Write-Log "Node.js installed via chocolatey" "success"
        return $true
    }
    catch {
        Write-Log "Chocolatey install failed: $_" "warn"
        return $false
    }
}

function Install-NodeViaScoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        return $false
    }
    Write-Log "Using scoop..." "info"
    try {
        if ($DryRun) {
            Write-Log "[DRY RUN] scoop install nodejs-lts" "info"
            return $true
        }
        scoop install nodejs-lts 2>&1 | Out-Null
        Refresh-PathFromRegistry
        Write-Log "Node.js installed via scoop" "success"
        return $true
    }
    catch {
        Write-Log "Scoop install failed: $_" "warn"
        return $false
    }
}

function Install-Node {
    Write-Log "Node.js not found or version too low" "info"
    Write-Log "Installing Node.js..." "info"

    if (Install-NodeViaWinget) { return $true }
    if (Install-NodeViaChoco) { return $true }
    if (Install-NodeViaScoop) { return $true }

    Write-Log "Could not install Node.js automatically" "error"
    Write-Log "Please install Node.js $MinMajor+ manually from: https://nodejs.org" "info"
    return $false
}

function Ensure-Node {
    $nodeVersion = Get-NodeVersion
    if ($nodeVersion) {
        $major = [int](($nodeVersion -split "\.")[0])
        if ($major -ge $MinMajor) {
            Write-Log "Node.js v$nodeVersion found" "success"
            return $true
        }
        Write-Log "Node.js v$nodeVersion found, but need v$MinMajor+" "warn"
    }
    return Install-Node
}

if (Ensure-Node) {
    if (-not $DryRun) {
        $finalVersion = Get-NodeVersion
        if ($finalVersion) {
            Write-Log "Node.js ready: v$finalVersion" "success"
        }
    }
    exit 0
}

exit 1
