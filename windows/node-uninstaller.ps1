param(
    [switch]$Elevated,
    [switch]$FromTemp,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:ProgramFiles "nodejs"
$InstallerDir = Join-Path $InstallDir "installer"
$UninstallRegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OpenClawNodeJs"
$NodeRegKey = "HKLM:\SOFTWARE\Node.js"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-ElevatedSelf {
    param(
        [switch]$FromTempFlag,
        [switch]$QuietFlag
    )

    # 非管理员时通过 UAC 重新拉起当前脚本
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$PSCommandPath`"",
        "-Elevated"
    )
    if ($FromTempFlag) { $args += "-FromTemp" }
    if ($QuietFlag) { $args += "-Quiet" }

    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs | Out-Null
    } catch {
        throw "需要管理员权限。你取消了 UAC 或提权失败。"
    }
}

function Send-EnvironmentChangeBroadcast {
    # 广播环境变量变更，避免终端继续使用旧 PATH 缓存
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class NativeMethods {
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint Msg,
        UIntPtr wParam,
        string lParam,
        uint fuFlags,
        uint uTimeout,
        out UIntPtr lpdwResult);
}
"@
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x001A
    $SMTO_ABORTIFHUNG = 0x0002
    $result = [UIntPtr]::Zero
    [void][NativeMethods]::SendMessageTimeout(
        $HWND_BROADCAST,
        $WM_SETTINGCHANGE,
        [UIntPtr]::Zero,
        "Environment",
        $SMTO_ABORTIFHUNG,
        5000,
        [ref]$result
    )
}

function Remove-PathEntryIfExists {
    param(
        [ValidateSet("Machine", "User")]
        [string]$Scope,
        [Parameter(Mandatory = $true)]
        [string]$Entry
    )

    $current = [Environment]::GetEnvironmentVariable("Path", $Scope)
    if ([string]::IsNullOrWhiteSpace($current)) {
        return
    }

    # 归一化比较，确保删除 PATH 项时不受大小写和尾斜杠影响
    $entryNormalized = $Entry.TrimEnd("\").ToLowerInvariant()
    $parts = $current -split ";" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $filtered = @()
    foreach ($part in $parts) {
        if ($part.TrimEnd("\").ToLowerInvariant() -ne $entryNormalized) {
            $filtered += $part
        }
    }

    [Environment]::SetEnvironmentVariable("Path", ($filtered -join ";"), $Scope)
}

if (-not $FromTemp -and $PSCommandPath.StartsWith($InstallDir, [System.StringComparison]::OrdinalIgnoreCase)) {
    # 先复制到临时目录执行，避免“运行中的脚本无法删除自身目录”
    $tempScript = Join-Path $env:TEMP ("node-uninstaller-" + [guid]::NewGuid().ToString("N") + ".ps1")
    Copy-Item -Path $PSCommandPath -Destination $tempScript -Force
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$tempScript`"",
        "-FromTemp"
    )
    if ($Quiet) { $args += "-Quiet" }
    Start-Process -FilePath "powershell.exe" -ArgumentList $args | Out-Null
    exit 0
}

if (-not (Test-IsAdmin)) {
    Start-ElevatedSelf -FromTempFlag:$FromTemp -QuietFlag:$Quiet
    exit 0
}

try {
    # 先清 PATH 和注册表，再删除安装目录
    Remove-PathEntryIfExists -Scope Machine -Entry $InstallDir
    Remove-PathEntryIfExists -Scope User -Entry (Join-Path $env:APPDATA "npm")
    Send-EnvironmentChangeBroadcast

    if (Test-Path $UninstallRegKey) {
        Remove-Item -Path $UninstallRegKey -Recurse -Force
    }
    if (Test-Path $NodeRegKey) {
        Remove-Item -Path $NodeRegKey -Recurse -Force
    }

    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force
    }

    if (-not $Quiet) {
        Write-Output "Node.js 已卸载完成。"
    }
} finally {
    if ($FromTemp -and (Test-Path $PSCommandPath)) {
        Remove-Item -Path $PSCommandPath -Force -ErrorAction SilentlyContinue
    }
}
