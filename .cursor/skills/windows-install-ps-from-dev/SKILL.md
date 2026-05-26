---
name: windows-install-ps-from-dev
description: 将 windows/install-user-dev.ps1 和 windows/install-script-dev.ps1 分别生成去注释版本 windows/install-user-windows.ps1 和 windows/install-script-windows.ps1。当需要同步或重新生成不含注释的发布脚本时使用。
disable-model-invocation: true
---

# 从 dev 脚本生成发布脚本

## 任务

将以下两个 dev 脚本分别生成对应的发布脚本，删除所有注释并清理多余空行：

| 源文件 | 目标文件 |
|--------|----------|
| `windows/install-user-dev.ps1` | `windows/install-user-windows.ps1` |
| `windows/install-script-dev.ps1` | `windows/install-script-windows.ps1` |

## 执行步骤

对每一对源/目标文件执行：

1. 读取源文件全文。
2. 对内容进行注释删除（规则见下文）。
3. 对去注释后的内容进行空行清理（规则见下文）。
4. 将结果写入目标文件（覆盖已存在文件），不得改动源文件。

## 格式化规则

- 若当前环境可用 `ms-vscode.powershell` 格式化器，优先使用该格式化器对目标文件进行格式化。
- 若不可用，则保持去注释与空行清理后的内容，不额外引入其他格式化器。

## PowerShell 注释删除规则

- **块注释**：删除 `<#` … `#>`（含跨行），整行仅有块注释时删除该行。
- **行注释**：删除从 `#` 起到行尾的内容（含前导空白），整行仅有注释时删除该行。
- **例外**：字符串字面量（单引号 `'...'`、双引号 `"..."`、here-string）内的 `#` 不视为注释，保留原样。

## 空行清理规则

- 连续 3 行及以上空行压缩为 **1 行**空行。
- 文件开头和结尾的空行删除。
- 删除注释后若某段落首尾出现多余空行，同样压缩。

## 验证

对两个目标文件各自确认：

- 文件存在，内容来自对应源文件（语义保留）。
- 文件中不含独立注释行（以 `#` 起始），不含 `<#`/`#>` 块（字符串内除外）。
- 无连续两行以上的空行。
