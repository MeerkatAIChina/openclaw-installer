---
name: tag-release
description: >
  创建带描述的 release tag。当用户让我"打 tag"、"创建 tag"、"release"、"发布版本"、
  "tag release"、"create tag" 时使用此 skill。自动读取上次 tag 以来的 commits，
  生成中文描述，按语义化版本自动递增，创建 annotated tag。支持正式版本和预发布版本（beta/rc）。
---

# Tag Release

## 触发条件

当用户说以下类似的话时触发：
- "打 tag"
- "创建一个 tag"
- "tag release"
- "发布版本"
- "打一个 release tag"
- "打个 beta 版本"
- "发布预发布版本"

## 流程

### 1. 确定版本类型

询问用户（或根据上下文判断）要创建的版本类型：

| 类型 | 说明 | 示例 |
|------|------|------|
| 正式版本 | 按语义化版本递增 | v1.2.3 |
| Beta 预发布 | 在正式版本前加 `-beta.N` | v1.2.3-beta.1 |
| RC 候选版本 | 在正式版本前加 `-rc.N` | v1.2.3-rc.1 |

### 2. 确定上一个 tag

```bash
git tag --sort=-v:refname | Select-Object -First 1
```

如果没有任何 tag，从 `v0.1.0` 开始。

### 3. 计算下一个版本号

解析上一个 tag 的版本号（格式 `v<major>.<minor>.<patch>` 或 `v<major>.<minor>.<patch>-<prerelease>`）：

**正式版本**：
- 包含 `BREAKING CHANGE` 或 type 后有 `!`（如 `feat!: xxx`）→ **major** 递增
- 包含 `feat:` 或 `feat(scope):` → **minor** 递增
- 其他（`fix:`、`chore:`、`docs:` 等或无前缀）→ **patch** 递增

**预发布版本**：
- 如果当前已有同版本的预发布（如 `v1.2.3-beta.1` 存在），则递增后缀 `v1.2.3-beta.2`
- 否则基于下一个正式版本创建第一个预发布 `v1.2.3-beta.1`

> **Why:** 遵循语义化版本，让用户从版本号就能直观判断变更范围。

### 4. 获取 commits

```bash
git log <last-tag>..HEAD --oneline --no-merges
```

### 5. 生成描述

根据 commits 内容生成中文描述，格式：

```
<一句话概括本次发布的核心内容>

- <主要变更 1>
- <主要变更 2>
- ...
```

要求：
- 第一行：简短概括（20 字以内），**不要包含版本号**
- 版本号会由 release 标题自动显示
- 用中文，专业术语（如 OSS、CI、workflow 等）保留英文
- 按重要性排序，忽略无实际意义的 chore（如 "fix typo"）
- 合并同类变更，不要逐条翻译 commit message
- 预发布版本在描述开头注明 **【预发布版本】**

### 6. 创建 annotated tag

```bash
git tag -a <new-version> -m "<生成的描述>"
```

### 7. 告知用户

输出 tag 名称和描述内容。提醒用户需要 push 时说一声。

示例输出：
```
已创建 tag: v0.3.0-beta.1

描述：
新增阿里云 OSS 同步发布功能

- 构建产物添加平台后缀（-linux/-windows）
- Release 自动同步到阿里云 OSS
- 支持 Pre-release 自动标记

运行 `git push origin v0.3.0-beta.1` 推送到远程并触发 release。
```

## 禁止事项

- 不要 `git push`，除非用户明确要求
- 不要让用户确认描述，直接执行
- 不要创建轻量 tag，必须用 `-a`
