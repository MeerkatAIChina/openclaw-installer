# Requires: pwsh or PowerShell 5.1+
# Tracked *.ps1 containing non-ASCII must start with UTF-8 BOM (EF BB BF).
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$gitOut = git ls-files "*.ps1" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "git ls-files failed (run from a git checkout)"
}
$lines = @($gitOut | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($lines.Count -eq 0) {
    Write-Host "No tracked .ps1 files."
    exit 0
}

$failures = [System.Collections.Generic.List[string]]::new()

foreach ($rel in $lines) {
    $full = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $full)) {
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($full)
    $hasBom = $bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF

    $payload = $bytes
    if ($hasBom -and $bytes.Length -gt 3) {
        $payload = $bytes[3..($bytes.Length - 1)]
    }
    elseif ($hasBom -and $bytes.Length -eq 3) {
        $payload = [byte[]]@()
    }

    try {
        $text = [System.Text.Encoding]::UTF8.GetString($payload)
    }
    catch {
        [void]$failures.Add("$rel : invalid UTF-8")
        continue
    }

    if ($text -match "[^\x00-\x7F]") {
        if (-not $hasBom) {
            [void]$failures.Add("$rel : non-ASCII content requires UTF-8 BOM")
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "UTF-8 BOM check failed:" -ForegroundColor Red
    foreach ($f in $failures) {
        Write-Host "  $f"
    }
    exit 1
}

Write-Host "OK: tracked non-ASCII .ps1 files use UTF-8 BOM."
exit 0
