# 单 URL 启动器：从 GitHub raw 拉取同仓库 windows/install.ps1 并执行（与 windows/install.ps1 的 param 保持同步）
# 用法:
#   iwr -useb https://raw.githubusercontent.com/Zhangyao719/openclaw-installer/main/install.ps1 | iex
#   & ([scriptblock]::Create((iwr -useb 'https://raw.githubusercontent.com/Zhangyao719/openclaw-installer/main/install.ps1'))) -NoOnboard
# 环境变量（可选）: OPENCLAW_INSTALLER_REPO=Owner/name ； OPENCLAW_INSTALLER_BRANCH=main

param(
    [ValidateSet("npm", "git")]
    [string]$InstallMethod = "npm",
    [string]$Tag = "latest",
    [string]$GitDir = "$env:USERPROFILE\openclaw",
    [switch]$NoOnboard,
    [switch]$NoSkills,
    [switch]$NoDashboard,
    [switch]$NoGitUpdate,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repo = if ($env:OPENCLAW_INSTALLER_REPO) { $env:OPENCLAW_INSTALLER_REPO.Trim() } else { "Zhangyao719/openclaw-installer" }
$branch = if ($env:OPENCLAW_INSTALLER_BRANCH) { $env:OPENCLAW_INSTALLER_BRANCH.Trim() } else { "main" }
$canonicalUrl = "https://raw.githubusercontent.com/$repo/$branch/windows/install.ps1"

$resp = Invoke-WebRequest -Uri $canonicalUrl -UseBasicParsing -TimeoutSec 180 -MaximumRedirection 5
& ([scriptblock]::Create($resp.Content)) @PSBoundParameters
