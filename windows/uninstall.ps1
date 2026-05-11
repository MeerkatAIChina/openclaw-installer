# 在 Windows 上卸载 OpenClaw（npm / 安装器场景）：停止本机 CLI 能管理的进程与服务，再卸 npm 全局包与用户目录。
# 与 Linux/macOS 的路径、systemd、launchd 无关；请勿在 PowerShell 中套用 bash 路径。

[CmdletBinding(SupportsShouldProcess = $true)]
param()

function Get-OpenClawExecutablePath {
    $cmds = @(Get-Command -Name openclaw -CommandType Application -ErrorAction SilentlyContinue)
    if ($cmds.Count -gt 0) {
        return $cmds[0].Source
    }

    $localShim = Join-Path $env:USERPROFILE '.local\bin\openclaw.cmd'
    if (Test-Path -LiteralPath $localShim) {
        return $localShim
    }

    try {
        $npm = Get-Command -Name npm.cmd -CommandType Application -ErrorAction Stop
        $prefix = (& $npm.Source config get prefix 2>$null).Trim()
        if (-not [string]::IsNullOrWhiteSpace($prefix)) {
            $candidates = @(
                (Join-Path $prefix 'openclaw.cmd'),
                (Join-Path $prefix 'bin\openclaw.cmd')
            )
            foreach ($c in $candidates) {
                if (Test-Path -LiteralPath $c) {
                    return $c
                }
            }
        }
    }
    catch {
        # ignore
    }

    $npmBin = Join-Path $env:APPDATA 'npm\openclaw.cmd'
    if (Test-Path -LiteralPath $npmBin) {
        return $npmBin
    }
    return $null
}

function Invoke-OpenClawTeardown {
    param([string]$OpenClawPath)

    if ([string]::IsNullOrWhiteSpace($OpenClawPath)) {
        return
    }

    & $OpenClawPath daemon stop 2>$null
    & $OpenClawPath daemon uninstall 2>$null
    & $OpenClawPath gateway stop 2>$null
}

function Stop-RelatedNodeChildProcesses {
    $procs = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue
    if ($null -eq $procs) {
        return
    }
    foreach ($p in @($procs)) {
        $line = [string]$p.CommandLine
        if ($line -match 'openclaw|clawdbot') {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        }
    }
}

function Uninstall-NpmGlobalOpenClaw {
    $npmCmds = @(Get-Command -Name npm.cmd -CommandType Application -ErrorAction SilentlyContinue)
    if ($npmCmds.Count -eq 0) {
        return
    }
    $npm = $npmCmds[0]
    if ($PSCmdlet.ShouldProcess('openclaw', 'npm uninstall -g')) {
        & $npm.Source uninstall -g openclaw 2>$null | Out-Null
    }
    $rootLine = & $npm.Source root -g 2>$null
    if (-not [string]::IsNullOrWhiteSpace($rootLine)) {
        $root = $rootLine.Trim()
        $pkgDir = Join-Path $root 'openclaw'
        if ($PSCmdlet.ShouldProcess($pkgDir, 'Remove npm global package dir')) {
            Remove-Item -LiteralPath $pkgDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Remove-UserOpenClawLayout {
    $paths = @(
        (Join-Path $env:USERPROFILE '.local\bin\openclaw.cmd'),
        (Join-Path $env:USERPROFILE '.openclaw'),
        (Join-Path $env:USERPROFILE '.clawdbot'),
        (Join-Path $env:USERPROFILE '.moltbot'),
        (Join-Path $env:USERPROFILE '.moldbot')
    )
    foreach ($p in $paths) {
        if (Test-Path -LiteralPath $p) {
            if ($PSCmdlet.ShouldProcess($p, 'Remove')) {
                Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    $profileRoots = Get-ChildItem -Path $env:USERPROFILE -Directory -Force -Filter '.openclaw-*' -ErrorAction SilentlyContinue
    foreach ($d in $profileRoots) {
        if ($PSCmdlet.ShouldProcess($d.FullName, 'Remove profile dir')) {
            Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$claw = Get-OpenClawExecutablePath
Invoke-OpenClawTeardown -OpenClawPath $claw
Stop-RelatedNodeChildProcesses
Uninstall-NpmGlobalOpenClaw
Remove-UserOpenClawLayout

Write-Host 'OpenClaw Windows 卸载步骤已执行（尽力而为）。请检查：Get-Command openclaw、npm list -g openclaw' -ForegroundColor Cyan
