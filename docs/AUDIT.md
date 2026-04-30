# Audit Log

## 2026-04-30

### 任务
- 实现 Node 脚本安装与卸载能力（PowerShell 版本）。
- 将 Node 相关脚本调整到 `windows/` 目录并处理 README 覆盖。
- 补充关键逻辑的简明注释。

### 变更文件
- `windows/node-installer.ps1`
- `windows/node-uninstaller.ps1`
- `windows/README.md`

### 审计检查项
- 权限模型：安装/卸载均支持自动提权（UAC）。
- 安装资源：固定下载 `v24.15.0` 官方 zip 镜像地址。
- 安装路径：固定 `C:\Program Files\nodejs`（每机器安装）。
- 卸载入口：注册表 `DisplayName=Node.js`，写入 `DisplayVersion=24.15.0`。
- 可维护性：在提权、PATH 幂等、环境变量广播、卸载自复制执行等关键点补充注释。

### 风险与备注
- 当前未执行真实安装/卸载端到端运行验证（避免污染本机 Node 环境）。
- 后续每次任务完成后，按日期继续追加本文件。
