# 预装 Plugins 设计文档

## 概述

在现有预装 Skills 功能之后，新增预装 Plugins 步骤。插件通过 `openclaw plugins install` 原生命令安装，单次失败仅警告不中断。

## 目标文件

- `windows/install-user-dev.ps1`（交互式安装脚本）
- `windows/install-script-dev.ps1`（非交互式/脚本化安装脚本）
- `linux/install-user-dev.sh`（Linux/macOS/WSL 安装脚本）

## 设计原则

完全复用现有 Skills 的安装模式：列表定义 → 逐个安装 → 失败警告 → 汇总结果。Skills 和 Plugins 是 openclaw 的独立子系统，代码上也保持独立。

## 预装列表

```text
npm:@meerkat-ai/openclaw-mrkhub-plugin
```

列表结构为数组，方便将来扩展。

## 实现细节

### PowerShell（Windows × 2）

**1. 新增 `[switch]$SkipPlugins` 参数**（`param()` 块）

```powershell
param(
    # ... 现有参数 ...
    [switch]$SkipPlugins
)
```

**2. 新增 `Install-Plugins` 函数**（紧邻 `Install-Skills` 之后）

完全按照 `Install-Skills` 的结构：
- `$plugins` 数组定义插件标识符
- 逐个调用 `Invoke-OpenClawCommand plugins install $slug`
- `try/catch` 捕获异常，失败记录到 `$failed` 数组
- 最后汇总输出成功/失败数量

**3. 调用位置**（紧邻 `Install-Skills` 调用之后）

```powershell
# Process 5.6: 预装 Plugins
if (-not $SkipPlugins) {
    if ($isUpgrade) {
        if (Ask-YesNo -Prompt "是否安装预设 Plugins..." -Default "Y") {
            Install-Plugins
        }
    } else {
        Install-Plugins
    }
}
```

### Bash（Linux × 1）

**1. 新增 `--no-plugins` 参数**（`parse_args()` 函数中）

```bash
--no-plugins)
    NO_PLUGINS=1
    shift
    ;;
```

**2. 新增 `install_preset_plugins` 函数**（紧邻 `install_preset_skills` 之后）

完全按照 `install_preset_skills` 的结构：
- 接收 `$upgrade_install` 参数
- 升级时调用 `ask_yes_no` 询问用户
- 支持 `DRY_RUN` 模式
- openclaw 不在 PATH 时跳过
- `ui_section` / `ui_info` / `ui_warn` 输出

**3. 调用位置**（紧邻 `install_preset_skills` 调用之后）

```bash
# ---- 装后 5.5：预装 plugins ----
if [[ "${NO_PLUGINS:-}" != "1" ]]; then
    install_preset_plugins "${is_upgrade}"
fi
```

## 行为契约

| 场景 | 行为 |
|------|------|
| 全新安装 | 直接安装，不询问 |
| 升级安装 | 询问用户（"可能会覆盖当前配置"） |
| `--skip-plugins` / `--no-plugins` | 跳过 |
| 单个 plugin 安装失败 | 警告，继续下一个 |
| 全部 plugin 安装失败 | 警告汇总，不中断脚本 |
| `DRY_RUN`（仅 Linux） | 输出 "Would run: ..." |
| openclaw 不在 PATH（仅 Linux） | 警告跳过 |
