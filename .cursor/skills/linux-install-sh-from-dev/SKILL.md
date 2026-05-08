---
name: linux-install-sh-from-dev
description: 将 linux/ 目录下 install-***-dev.sh 批量生成对应去注释发布脚本 install-***.sh。需要同步或重新生成 Linux 发布安装脚本时使用。
disable-model-invocation: true
---

# 从 dev shell 脚本生成发布脚本

## 任务

扫描 `linux/` 目录下所有 `install-*-dev.sh`，并逐个生成对应目标文件：

- 源文件：`linux/install-<name>-dev.sh`
- 目标文件：`linux/install-<name>.sh`

生成时删除注释并清理多余空行。

## 执行步骤

对每个匹配到的源文件执行：

1. 读取源文件全文。
2. 按规则删除 shell 注释。
3. 按规则压缩空行。
4. 将结果写入对应目标文件（覆盖已存在文件），不得改动源文件。
5. 若 `mkhl.shfmt` 插件可用，对目标文件执行格式化。

## Shell 注释删除规则

- 删除整行注释：去掉前导空白后以 `#` 开头的整行删掉（不包含 shebang）。
- **不删除行尾 `#...` 注释**：双引号 / command substitution（如 `"$("···"#hex"···)")`）与 heredoc 正文中的 `#` 极易被误判，会破坏语法或内容。
- 保留 shebang 行（`#!/usr/bin/env bash` 或 `#!/bin/bash`）。

## 换行规则

- 目标 `.sh` 必须只使用 **LF**（`\n`），不得混入 CR（`\r`）。

## 空行清理规则

- 连续 3 行及以上空行压缩为 1 行空行。
- 删除文件开头和结尾空行。
- 删除注释后产生的多余空行同样压缩。

## 格式化规则

- 优先使用 `mkhl.shfmt` 插件格式化目标 `.sh` 文件（如果可用）。
- 若插件不可用，则跳过该步骤，不阻断文件生成。

## 验证

对每个目标文件确认：

- 文件已生成，内容来自对应源文件。
- 文件不含独立注释行（shebang 除外）。
- 不出现连续三行及以上的空行块。
- 若 `mkhl.shfmt` 可用，目标文件已完成格式化。
