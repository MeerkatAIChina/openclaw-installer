---
name: tag-release
description: >
  创建带描述的 release tag。当用户让你"打 tag"、"创建 tag"、"release"、"发布版本"、
  "tag release"、"create tag" 时使用此 skill。自动读取上次 tag 以来的 commits，
  生成中文描述，按语义化版本自动递增，创建 annotated tag。
---

# Tag Release

## 触发条件

当用户说以下类似的话时触发：
- "打 tag"
- "创建一个 tag"
- "tag release"
- "发布版本"
- "打一个 release tag"

## 流程

### 1. 确定上一个 tag

```bash
git tag --sort=-v:refname | Select-Object -First 1
```

如果没有任何 tag，从 `v0.1.0` 开始。

### 2. 计算下一个版本号

解析上一个 tag 的版本号（格式 `v<major>.<minor>.<patch>`），根据本次 commit 内容决定递增级别：

- 包含 `BREAKING CHANGE` 或 type 后有 `!`（如 `feat!: xxx`）→ **major** 递增
- 包含 `feat:` 或 `feat(scope):` → **minor** 递增
- 其他（`fix:`、`chore:`、`docs:` 等或无前缀）→ **patch** 递增

> **Why:** 遵循语义化版本，让用户从版本号就能直观判断变更范围。

### 3. 获取 commits

```bash
git log <last-tag>..HEAD --oneline --no-merges
```

### 4. 生成描述

根据 commits 内容生成中文描述，格式：

```
<一句话概括本次发布的核心内容>

- <主要变更 1>
- <主要变更 2>
- ...
```

要求：
- 第一行简短概括（20 字以内）
- 用中文，专业术语（如 OSS、CI、workflow 等）保留英文
- 按重要性排序，忽略无实际意义的 chore（如 "fix typo"）
- 合并同类变更，不要逐条翻译 commit message

### 5. 创建 annotated tag

```bash
git tag -a <new-version> -m "<生成的描述>"
```

### 6. 告知用户

输出 tag 名称和描述内容。提醒用户需要 push 时说一声。

## 禁止事项

- 不要 `git push`，除非用户明确要求
- 不要让用户确认描述，直接执行
- 不要创建轻量 tag，必须用 `-a`
