param(
    [switch]$Elevated
)

$ErrorActionPreference = "Stop"

$NodeVersion = "24.15.0"
$NodePublisher = "Node.js Foundation"
$NodeZipUrl = "https://registry.npmmirror.com/-/binary/node/v24.15.0/node-v24.15.0-win-x64.zip"
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
    # 非管理员时通过 UAC 重新拉起当前脚本
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$PSCommandPath`"",
        "-Elevated"
    )
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs | Out-Null
    } catch {
        throw "需要管理员权限。你取消了 UAC 或提权失败。"
    }
}

function Send-EnvironmentChangeBroadcast {
    # 广播环境变量变更，避免用户重启后才生效
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

function Add-PathEntryIfMissing {
    param(
        [ValidateSet("Machine", "User")]
        [string]$Scope,
        [Parameter(Mandatory = $true)]
        [string]$Entry
    )

    $current = [Environment]::GetEnvironmentVariable("Path", $Scope)
    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($current)) {
        $parts = $current -split ";" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    # 归一化比较，保证 PATH 追加是幂等的
    $normalized = $parts | ForEach-Object { $_.TrimEnd("\").ToLowerInvariant() }
    $target = $Entry.TrimEnd("\")
    if ($normalized -notcontains $target.ToLowerInvariant()) {
        $parts += $Entry
        [Environment]::SetEnvironmentVariable("Path", ($parts -join ";"), $Scope)
    }
}

if (-not (Test-IsAdmin)) {
    Start-ElevatedSelf
    exit 0
}

$tempRoot = Join-Path $env:TEMP ("node-installer-" + [guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $tempRoot "node.zip"
$extractDir = Join-Path $tempRoot "extract"

try {
    # 下载并解压固定版本的官方 zip 包
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

    Invoke-WebRequest -Uri $NodeZipUrl -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $rootEntries = Get-ChildItem -Path $extractDir
    if ($rootEntries.Count -ne 1 -or -not $rootEntries[0].PSIsContainer) {
        throw "ZIP 内容格式不符合预期。"
    }

    $packageRoot = $rootEntries[0].FullName

    # 目标目录统一重建，避免残留旧文件
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Copy-Item -Path (Join-Path $packageRoot "*") -Destination $InstallDir -Recurse -Force

    # 将安装/卸载脚本副本落到本机，卸载不依赖仓库目录
    New-Item -ItemType Directory -Path $InstallerDir -Force | Out-Null
    Copy-Item -Path (Join-Path $PSScriptRoot "node-installer.ps1") -Destination (Join-Path $InstallerDir "node-installer.ps1") -Force
    Copy-Item -Path (Join-Path $PSScriptRoot "node-uninstaller.ps1") -Destination (Join-Path $InstallerDir "node-uninstaller.ps1") -Force

    $uninstallScriptPath = Join-Path $InstallerDir "node-uninstaller.ps1"
    $uninstallCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$uninstallScriptPath`""

    # 写入卸载信息，展示在“应用和功能”中
    New-Item -Path $UninstallRegKey -Force | Out-Null
    New-ItemProperty -Path $UninstallRegKey -Name "DisplayName" -Value "Node.js" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallRegKey -Name "DisplayVersion" -Value $NodeVersion -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallRegKey -Name "Publisher" -Value $NodePublisher -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallRegKey -Name "InstallLocation" -Value $InstallDir -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallRegKey -Name "UninstallString" -Value $uninstallCmd -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallRegKey -Name "QuietUninstallString" -Value "$uninstallCmd -Quiet" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $UninstallRegKey -Name "NoModify" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $UninstallRegKey -Name "NoRepair" -Value 1 -PropertyType DWord -Force | Out-Null

    # 写入 Node 安装信息，便于外部工具识别
    New-Item -Path $NodeRegKey -Force | Out-Null
    New-ItemProperty -Path $NodeRegKey -Name "InstallPath" -Value $InstallDir -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $NodeRegKey -Name "Version" -Value $NodeVersion -PropertyType String -Force | Out-Null

    # 机器级添加 node 路径；用户级添加 npm 全局命令路径
    Add-PathEntryIfMissing -Scope Machine -Entry $InstallDir
    Add-PathEntryIfMissing -Scope User -Entry (Join-Path $env:APPDATA "npm")
    Send-EnvironmentChangeBroadcast

    if (-not (Test-Path (Join-Path $InstallDir "node.exe"))) {
        throw "安装完成后未找到 node.exe。"
    }

    Write-Output "Node.js v$NodeVersion 安装完成。"
} finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
