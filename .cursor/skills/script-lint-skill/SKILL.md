# Script Lint Skill

目标：统一检查 shell 与 PowerShell 脚本质量并返回可执行修复建议。

## 执行步骤

1. 收集脚本文件：
   - Shell: `**/*.sh`
   - PowerShell: `**/*.ps1`
2. 对 Shell 执行：
   - `shellcheck <files>`
   - `shfmt -d <files>`
   - 如脚本目标是 POSIX，再执行：`checkbashisms <files>`
3. 对 PowerShell 执行：
   - `Invoke-ScriptAnalyzer -Path . -Recurse`
4. 输出：
   - 按文件列出错误/警告
   - 给出最小修复建议，不做无关重构

## 约束

- 只修复本次检查报错直接相关内容。
- 不引入新依赖与抽象层。
- 用户未要求时不自动提交。
