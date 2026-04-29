# Cross Platform Check Skill

目标：验证脚本在 Linux/macOS/Windows 场景下的兼容性风险。

## 检查清单

1. Shebang 与解释器依赖是否明确（`sh`/`bash`/`pwsh`）。
2. 是否使用了平台特定命令或参数（GNU vs BSD 差异）。
3. 路径分隔符、换行、编码是否可跨平台。
4. Shell 脚本是否含 Bashism（当目标是 POSIX 时）。
5. PowerShell 是否依赖仅 Windows 可用模块或 cmdlet。

## 输出格式

- 按严重级别：`blocker` / `warning` / `note`
- 每条包含：问题、影响平台、最小修复动作

## 约束

- 不做大规模重构。
- 优先给出最小变更修复。
