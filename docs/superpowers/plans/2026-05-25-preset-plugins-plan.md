# 预装 Plugins 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在三个安装脚本中新增 `openclaw plugins install` 预装步骤，位于 skills 安装之后。

**Architecture:** 完全复用现有 `Install-Skills` / `install_preset_skills` 的模式——独立函数 + 列表定义 + 逐个安装 + 失败仅警告。每个脚本新增独立函数和 skip 参数。

**Tech Stack:** PowerShell 5.1+, Bash 4+, Pester (测试)

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `windows/tests/Install-Plugins.Tests.ps1` | **新建** — Pester 测试，验证 Install-Plugins 函数行为 |
| `windows/install-user-dev.ps1` | **修改** — 新增 `Install-Plugins` 函数 + `$SkipPlugins` 参数 + 调用点 |
| `windows/install-script-dev.ps1` | **修改** — 同上（与 user 版完全一致） |
| `linux/install-user-dev.sh` | **修改** — 新增 `install_preset_plugins` 函数 + `--no-plugins` 参数 + 调用点 |

---

### Task 1: 编写 Pester 测试（TDD 第一步）

**Files:**
- Create: `windows/tests/Install-Plugins.Tests.ps1`

- [ ] **Step 1: 创建测试文件**

```powershell
# windows/tests/Install-Plugins.Tests.ps1
Describe "Install-Plugins" {
    BeforeAll {
        # 获取脚本目录以便载入 install-user-dev.ps1
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
        $scriptPath = Join-Path $repoRoot "windows/install-user-dev.ps1"

        # Mock Invoke-OpenClawCommand，避免真正调用 openclaw
        Mock Invoke-OpenClawCommand { return $true } -Verifiable

        # Mock Get-OpenClawCommandPath 返回一个假路径
        Mock Get-OpenClawCommandPath { return "openclaw" }

        # 载入脚本（dot-source），但跳过 Main 执行
        # 脚本末尾会调用 Main，我们需要阻止
        Mock Main { return $true }

        . $scriptPath *> $null
    }

    Context "函数存在性" {
        It "Install-Plugins 函数已定义" {
            { Get-Command Install-Plugins -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context "默认插件列表" {
        It "包含 @meerkat-ai/openclaw-mrkhub-plugin" {
            # 通过调用 Install-Plugins 并检查 mock 调用来验证
            Install-Plugins

            $calls = (Get-MockedCommand Invoke-OpenClawCommand).Calls
            $calls.Count | Should -BeGreaterThan 0
            $pluginInstalled = $calls.Args | Where-Object {
                $_ -join ' ' -match 'npm:@meerkat-ai/openclaw-mrkhub-plugin'
            }
            $pluginInstalled | Should -Not -BeNullOrEmpty
        }
    }

    Context "单个插件安装失败不中断" {
        It "失败后继续安装后续插件并报告失败数量" {
            Mock Invoke-OpenClawCommand {
                $global:LASTEXITCODE = 1
            }

            Install-Plugins

            $calls = (Get-MockedCommand Invoke-OpenClawCommand).Calls
            $calls.Count | Should -BeGreaterThan 0
        }
    }

    Context "全部安装成功" {
        It "退出码为 0 时输出成功信息" {
            Mock Invoke-OpenClawCommand {
                $global:LASTEXITCODE = 0
            }

            Install-Plugins

            $calls = (Get-MockedCommand Invoke-OpenClawCommand).Calls
            $calls.Count | Should -BeGreaterThan 0
        }
    }
}
```

- [ ] **Step 2: 运行测试，确认全部 FAIL**

```powershell
# 先从 install-user-dev.ps1 中提取 Install-Plugins 相关逻辑来测试
# 因为函数尚不存在，此测试会失败
Invoke-Pester -Script (Join-Path $PSScriptRoot "../windows/tests/Install-Plugins.Tests.ps1") -Output Detailed
```

预期：所有测试 FAIL，`Install-Plugins` 函数不存在

- [ ] **Step 3: 提交测试**

```bash
git add windows/tests/Install-Plugins.Tests.ps1
git commit -m "test: add Pester tests for Install-Plugins function"
```

---

### Task 2: 实现 install-user-dev.ps1 的 Install-Plugins

**Files:**
- Modify: `windows/install-user-dev.ps1`

- [ ] **Step 1: 在 param() 块中新增 `$SkipPlugins` 参数**

在 `windows/install-user-dev.ps1:25` 的 `[switch]$DryRun` 之后添加：

```powershell
    [switch]$DryRun,
    [switch]$SkipPlugins
)
```

- [ ] **Step 2: 在 Install-Skills 函数之后新增 Install-Plugins 函数**

在 `windows/install-user-dev.ps1:1096`（`Install-Skills` 函数的结束 `}`）之后插入：

```powershell

# 装后：预装常用 plugins（逐个 openclaw plugins install；单次失败仅警告）。
function Install-Plugins {
    $plugins = @(
        'npm:@meerkat-ai/openclaw-mrkhub-plugin'
    )

    $failed = @()

    Write-Host "[*] Installing Plugins..." -ForegroundColor Yellow
    foreach ($slug in $plugins) {
        Write-Host "  Installing $slug..." -ForegroundColor Gray
        try {
            Invoke-OpenClawCommand plugins install $slug
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[!] Failed to install plugin '$slug' (exit code $LASTEXITCODE)" -ForegroundColor Yellow
                $failed += $slug
            }
        }
        catch {
            Write-Host "[!] Failed to install plugin '$slug': $($_.Exception.Message)" -ForegroundColor Yellow
            $failed += $slug
        }
    }

    if ($failed.Count -eq 0) {
        Write-Host "[OK] All $($plugins.Count) plugins installed" -ForegroundColor Green
    }
    else {
        Write-Host "[!] $($plugins.Count - $failed.Count)/$($plugins.Count) plugins installed; failed: $($failed -join ', ')" -ForegroundColor Yellow
    }
}
```

- [ ] **Step 3: 更新文件头注释中的流程总览**

将 `windows/install-user-dev.ps1:15`：

```
# 5 装后       — 5.1 doctor 迁移；5.2 网关服务刷新；5.3 onboard 向导；5.4 启动 hooks； 5.5 预装 Skills（全新安装）；
```

修改为：

```
# 5 装后       — 5.1 doctor 迁移；5.2 网关服务刷新；5.3 onboard 向导；5.4 启动 hooks； 5.5 预装 Skills；5.6 预装 Plugins（全新安装）；
```

- [ ] **Step 4: 在 Install-Skills 调用之后新增 Install-Plugins 调用**

在 `windows/install-user-dev.ps1` 中原 `Install-Skills` 调用块之后（原 L1289-1296 之后，`return $true` 之前），找到：

```powershell
    else {
        Write-Host ""
        Write-Host "即将开始预安装常用 Skills..." -ForegroundColor Cyan
        Install-Skills
    }

    return $true
```

在其后插入：

```powershell

    # Process 5.6: 预装 Plugins
    if (-not $SkipPlugins) {
        if ($isUpgrade) {
            Write-Host ""
            if (Ask-YesNo -Prompt "是否安装预设 Plugins（注意：可能会覆盖当前配置）？" -Default "Y") {
                Write-Host "即将开始预安装常用 Plugins..." -ForegroundColor Cyan
                Install-Plugins
            }
        }
        else {
            Write-Host ""
            Write-Host "即将开始预安装常用 Plugins..." -ForegroundColor Cyan
            Install-Plugins
        }
    }
```

- [ ] **Step 5: 运行 Pester 测试验证 PASS**

```powershell
Invoke-Pester -Script windows/tests/Install-Plugins.Tests.ps1 -Output Detailed
```

预期：所有测试 PASS

- [ ] **Step 6: 运行 PSScriptAnalyzer**

```powershell
Invoke-ScriptAnalyzer -Path windows/install-user-dev.ps1 -Severity Error,ParseError
```

预期：无错误输出

- [ ] **Step 7: 提交**

```bash
git add windows/install-user-dev.ps1
git commit -m "feat: add Install-Plugins function to install-user-dev.ps1"
```

---

### Task 3: 实现 install-script-dev.ps1 的 Install-Plugins

**Files:**
- Modify: `windows/install-script-dev.ps1`

> 此任务与 Task 2 完全独立，可并行执行。

- [ ] **Step 1: 在 param() 块中新增 `$SkipPlugins` 参数**

在 `windows/install-script-dev.ps1:29` 的 `[string]$ApiKey` 之后添加：

```powershell
    [string]$ApiKey,
    [switch]$SkipPlugins
)
```

- [ ] **Step 2: 在 Install-Skills 函数之后新增 Install-Plugins 函数**

在 `windows/install-script-dev.ps1:916`（`Install-Skills` 函数的结束 `}`）之后插入：

```powershell

# 装后：预装常用 plugins（逐个 openclaw plugins install；单次失败仅警告）。
function Install-Plugins {
    $plugins = @(
        'npm:@meerkat-ai/openclaw-mrkhub-plugin'
    )

    $failed = @()

    Write-Host "[*] Installing Plugins..." -ForegroundColor Yellow
    foreach ($slug in $plugins) {
        Write-Host "  Installing $slug..." -ForegroundColor Gray
        try {
            Invoke-OpenClawCommand plugins install $slug
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[!] Failed to install plugin '$slug' (exit code $LASTEXITCODE)" -ForegroundColor Yellow
                $failed += $slug
            }
        }
        catch {
            Write-Host "[!] Failed to install plugin '$slug': $($_.Exception.Message)" -ForegroundColor Yellow
            $failed += $slug
        }
    }

    if ($failed.Count -eq 0) {
        Write-Host "[OK] All $($plugins.Count) plugins installed" -ForegroundColor Green
    }
    else {
        Write-Host "[!] $($plugins.Count - $failed.Count)/$($plugins.Count) plugins installed; failed: $($failed -join ', ')" -ForegroundColor Yellow
    }
}
```

- [ ] **Step 3: 更新文件头注释中的流程总览**

将 `windows/install-script-dev.ps1:15`：

```
# 5 装后       — 5.1 doctor 迁移；5.2 网关服务刷新；5.3 onboard 向导；5.4 预装 Skills（全新安装）；
```

修改为：

```
# 5 装后       — 5.1 doctor 迁移；5.2 网关服务刷新；5.3 onboard 向导；5.4 预装 Skills；5.5 预装 Plugins（全新安装）；
```

- [ ] **Step 4: 在 Install-Skills 调用之后新增 Install-Plugins 调用**

在 `windows/install-script-dev.ps1` 中原 `Install-Skills` 调用之后。找到：

```powershell
    # Process 5.4: 预装 Skills
    if (-not $isUpgrade) {
        Write-Host ""
        Write-Host "即将开始预安装常用 Skills..." -ForegroundColor Cyan
        Install-Skills
    }

    return $true
```

替换为：

```powershell
    # Process 5.4: 预装 Skills
    if (-not $isUpgrade) {
        Write-Host ""
        Write-Host "即将开始预安装常用 Skills..." -ForegroundColor Cyan
        Install-Skills
    }

    # Process 5.5: 预装 Plugins
    if (-not $SkipPlugins) {
        if ($isUpgrade) {
            Write-Host ""
            if (Ask-YesNo -Prompt "是否安装预设 Plugins（注意：可能会覆盖当前配置）？" -Default "Y") {
                Write-Host "即将开始预安装常用 Plugins..." -ForegroundColor Cyan
                Install-Plugins
            }
        }
        else {
            Write-Host ""
            Write-Host "即将开始预安装常用 Plugins..." -ForegroundColor Cyan
            Install-Plugins
        }
    }

    return $true
```

- [ ] **Step 5: 运行 PSScriptAnalyzer**

```powershell
Invoke-ScriptAnalyzer -Path windows/install-script-dev.ps1 -Severity Error,ParseError
```

预期：无错误输出

- [ ] **Step 6: 提交**

```bash
git add windows/install-script-dev.ps1
git commit -m "feat: add Install-Plugins function to install-script-dev.ps1"
```

---

### Task 4: 实现 install-user-dev.sh 的 install_preset_plugins

**Files:**
- Modify: `linux/install-user-dev.sh`

> 此任务与 Task 2、3 完全独立，可并行执行。

- [ ] **Step 1: 在 parse_args() 中新增 `--no-plugins` 参数**

在 `linux/install-user-dev.sh` 的 `parse_args()` 函数中（`--no-git-update` 之后，约 L1208），添加：

```bash
        --no-plugins)
            NO_PLUGINS=1
            shift
            ;;
```

- [ ] **Step 2: 在 install_preset_skills 函数之后新增 install_preset_plugins 函数**

在 `linux/install-user-dev.sh:2787`（`install_preset_skills` 函数的结束 `}`）之后插入：

```bash

# 装后：预装常用 plugins（逐个 openclaw plugins install；单次失败仅警告）。
install_preset_plugins() {
    local upgrade_install="${1:-false}"

    if [[ "${upgrade_install}" == "true" ]]; then
        if ! ask_yes_no "Install bundled Plugins? (Warning: this may overwrite your current configuration)" "N"; then
            return 0
        fi
    fi

    local -a plugin_slugs=(
        "npm:@meerkat-ai/openclaw-mrkhub-plugin"
    )

    if [[ "${DRY_RUN:-}" == "1" ]]; then
        ui_section "Preset plugins (dry-run)"
        local s=""
        for s in "${plugin_slugs[@]}"; do
            ui_info "Would run: openclaw plugins install ${s}"
        done
        return 0
    fi

    local claw="${OPENCLAW_BIN:-}"
    if [[ -z "$claw" ]]; then
        claw="$(resolve_openclaw_bin || true)"
    fi
    if [[ -z "$claw" ]]; then
        ui_warn "openclaw not on PATH; skipping preset plugins"
        return 0
    fi

    ui_section "Installing preset plugins"

    local ok=0
    local fail=0
    local -a failed_slugs=()
    local s=""
    for s in "${plugin_slugs[@]}"; do
        if "$claw" plugins install "$s"; then
            ok=$((ok + 1))
            ui_info "Plugin installed: ${s}"
        else
            fail=$((fail + 1))
            failed_slugs+=("$s")
            ui_warn "Failed to install plugin: ${s}"
        fi
    done
    if ((fail == 0)); then
        ui_success "Preset plugins: ${ok}/${#plugin_slugs[@]} installed"
    else
        ui_warn "Preset plugins: ${ok} ok, ${fail} failed — ${failed_slugs[*]}"
    fi
}
```

- [ ] **Step 3: 在 install_preset_skills 调用之后新增 install_preset_plugins 调用**

在 `linux/install-user-dev.sh` 中，找到（原 L3540-3541）：

```bash
    # ---- 装后 5：预装 skills ----
    install_preset_skills "${is_upgrade}"
```

在其后追加：

```bash

    # ---- 装后 5.5：预装 plugins ----
    if [[ "${NO_PLUGINS:-}" != "1" ]]; then
        install_preset_plugins "${is_upgrade}"
    fi
```

- [ ] **Step 4: 更新 install-user-dev.sh 文件头注释**

在 `linux/install-user-dev.sh` 顶部的流程注释中添加 plugins 步骤。找到类似的行（约 L18）：

```
# 8 结束       — preset hooks(enable_hooks)、preset skills(install_preset_skills)、gateway daemon 检测重启、dashboard、带 token URL 浏览器、show_footer_links
```

修改为：

```
# 8 结束       — preset hooks(enable_hooks)、preset skills(install_preset_skills)、preset plugins(install_preset_plugins)、gateway daemon 检测重启、dashboard、带 token URL 浏览器、show_footer_links
```

- [ ] **Step 5: 运行 shellcheck**

```bash
shellcheck linux/install-user-dev.sh
```

预期：无新增错误

- [ ] **Step 6: 运行 bash 语法检查**

```bash
bash -n linux/install-user-dev.sh
```

预期：无输出（语法正确）

- [ ] **Step 7: 提交**

```bash
git add linux/install-user-dev.sh
git commit -m "feat: add install_preset_plugins function to install-user-dev.sh"
```

---

### Task 5: 运行所有 CI 检查

**依赖:** Task 2, 3, 4 全部完成

- [ ] **Step 1: 运行 PowerShell PSScriptAnalyzer（两个脚本）**

```powershell
Invoke-ScriptAnalyzer -Path windows/install-user-dev.ps1 -Severity Error,ParseError
Invoke-ScriptAnalyzer -Path windows/install-script-dev.ps1 -Severity Error,ParseError
```

预期：两者均无错误

- [ ] **Step 2: 运行 Pester 测试**

```powershell
Invoke-Pester -Script windows/tests/Install-Plugins.Tests.ps1 -Output Detailed
```

预期：所有测试 PASS

- [ ] **Step 3: 运行 shellcheck**

```bash
shellcheck linux/install-user-dev.sh
```

预期：无新增错误

- [ ] **Step 4: 运行 shfmt 检查**

```bash
shfmt -d -i 4 linux/install-user-dev.sh
```

预期：无格式差异

- [ ] **Step 5: 运行 UTF-8 BOM 检查**

```bash
pwsh -NoProfile -File ./scripts/check-ps1-utf8-bom.ps1
```

预期：通过

---

### Task 6: 构建 dist 并验证

**依赖:** Task 5 通过

- [ ] **Step 1: 构建 release**

```bash
node scripts/build-release.cjs
```

- [ ] **Step 2: 验证 dist 中 PowerShell 脚本可解析**

```bash
pwsh -NoProfile -File scripts/verify-dist-ps1-parse.ps1
```

预期：所有 dist/*.ps1 输出 OK

- [ ] **Step 3: 验证 dist 中 Bash 脚本语法正确**

```bash
bash -n dist/*.sh
```

预期：无输出（语法正确）

- [ ] **Step 4: 确认 dist 脚本中包含 plugin 安装逻辑**

```bash
grep -l "plugins install" dist/*
```

预期：dist 中三个脚本均匹配

- [ ] **Step 5: 提交 dist 验证结果（如有变更）**

只有 dist/ 中有变更时才提交。

---

## 并行执行策略

```
Task 1: Pester 测试 (TDD)
    │
    ▼
┌─── Task 2: install-user-dev.ps1 ──────┐
├─── Task 3: install-script-dev.ps1 ─────┤  ← 三路并行
└─── Task 4: install-user-dev.sh ────────┘
    │
    ▼
Task 5: CI 检查
    │
    ▼
Task 6: 构建验证
```

Task 2、3、4 修改的文件互不依赖，可由三个子代理并行执行。
