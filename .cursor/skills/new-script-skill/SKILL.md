# New Script Skill

目标：快速生成安全、可维护的脚本骨架（sh/bash/ps1）。

## 输入

- 脚本类型：`sh` / `bash` / `ps1`
- 脚本路径
- 必填参数列表
- 主流程描述（1-3 条）

## 输出规范

- `sh`:
  - `#!/usr/bin/env sh`
  - `set -eu`
  - 参数校验与 usage
  - `trap` 清理（若使用临时资源）
- `bash`:
  - `#!/usr/bin/env bash`
  - `set -euo pipefail`
  - 参数校验与 usage
  - 函数化结构，函数内默认 `local`
- `ps1`:
  - `[CmdletBinding()]`
  - `param(...)`
  - 参数验证
  - 明确错误输出与退出码

## 约束

- 只生成最小可运行骨架。
- 不生成测试、文档、示例数据。
