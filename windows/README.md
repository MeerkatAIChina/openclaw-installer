# Windows 版本安装脚本

## nodejs 安装脚本使用说明

### 简介

- 检测当前机器 Node.js 版本是否满足最低主版本要求（默认 `22`）。
- 若不满足，按顺序尝试自动安装：
  1. `winget`
  2. `choco`（Chocolatey）
  3. `scoop`
- 任一方式安装成功后即停止后续尝试。
- 全部失败时返回失败并提示手动安装。

### 参数

- `-MinMajor <int>`
  - 最低主版本要求，默认值：`22`
- `-DryRun`
  - 仅打印将执行的安装命令，不实际安装

### 运行方式

在 PowerShell 中执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "agent/scripts/node-installer.ps1"
```

指定最低版本（例如 24）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "agent/scripts/node-installer.ps1" -MinMajor 24
```

Dry Run：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "agent/scripts/node-installer.ps1" -DryRun
```

### 退出码

- `0`：Node 已满足要求，或自动安装成功
- `1`：自动安装失败（需手动安装 Node）

### 注意事项

- 脚本依赖以下任一工具进行自动安装：`winget` / `choco` / `scoop`。
- 若三者均不可用，脚本会提示手动到 [https://nodejs.org](https://nodejs.org) 安装。

## OpenClaw 安装脚本使用说明
