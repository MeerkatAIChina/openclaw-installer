# Linux / macOS 安装脚本说明

## 一、我们的脚本说明

### 普通用户

```bash
# github 链接,注意 tag 版本
curl -fsSL https://github.com/Zhangyao719/openclaw-installer/releases/download/<tag>/install-user.sh | bash
```

你也可以手动把脚本下载下来，然后在本机终端上执行：

```bash
# 进入脚本所在的下载目录中
bash ./install-user.sh </dev/null
```

### 开发者

#### 本地开发

```bash
# 进入目录（换成自己的）
cd /mnt/e/projects/openclaw-installer/linux

# 本地执行
bash ./install-user-dev.sh </dev/null
```

**请注意：** 实测在 `WSL2` 中执行脚本**必须添加** `</dev/null`。因为使用终端（TTY）会调用 `gum`，而 `gum` 会用 `gum spin` 包一层 `npm`，在 `WSL2` 中会出现 `inappropriate ioct1 for device` 的错误，引起误判，导致环境被破坏。

#### 本地打包

```bash
# 根目录下执行
node scripts/build-release.cjs
```

会扫描 `linux/install-*-dev.sh`、`windows/install-*-dev.ps1`，生成到 `dist/`（`install-<name>.sh` / `.ps1`）。

依赖简述

- Node：跑上述命令（无需额外 `npm install`，脚本只用标准库）。
- `shfmt`：可选，但建议装（与 release 工作流一致）。

#### 卸载 OpenClaw

```bash
# 1. 先用现有 openclaw 把服务停干净（失败也无所谓，往下走）
openclaw daemon stop 2>/dev/null
openclaw daemon uninstall 2>/dev/null
openclaw gateway stop 2>/dev/null

# 2. 兜底：systemd 用户服务残留
systemctl --user stop 'openclaw*' 2>/dev/null
systemctl --user disable 'openclaw*' 2>/dev/null
rm -f ~/.config/systemd/user/openclaw*.service ~/.config/systemd/user/clawdbot*.service 2>/dev/null
systemctl --user daemon-reload 2>/dev/null

# 3. 杀掉残留进程
pkill -f 'openclaw|clawdbot' 2>/dev/null

# 4. 再卸 npm 包和文件
hash -r
npm uninstall -g openclaw 2>/dev/null
rm -f ~/.local/bin/openclaw
rm -rf ~/.local/lib/node_modules/openclaw ~/.local/lib/node_modules/.openclaw-*

# 5. 删配置 / 状态目录
rm -rf ~/.openclaw ~/.clawdbot ~/.moltbot ~/.moldbot

# 6. 验证
type -P openclaw || echo "binary: clean"
ls -la ~/.local/bin/openclaw 2>&1 | grep -q "No such file" && echo "bin link: clean"
ls ~/.openclaw 2>&1 | grep -q "No such file" && echo "config: clean"
systemctl --user list-units --all 'openclaw*' 2>/dev/null | grep -i openclaw || echo "systemd: clean"
pgrep -fa 'openclaw|clawdbot' || echo "process: clean"
```

## 二、常见问题

### WSL 中的问题归纳

1. npm 在解析/写入缓存时路径错，导致安装失败（以 `WSL` 为例）。

   ```powershell
   [2/3] Installing OpenClaw
   · Using npm registry: https://registry.npmmirror.com/
   ✓ Git already installed
   · Installing OpenClaw (latest)
   ! npm install failed for openclaw@latest
     Command: env SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm --loglevel error --silent --no-fund --no-audit install -g openclaw@latest
     Installer log: /tmp/tmp.vhlwCzF3RX
   ! npm install failed; showing last log lines
   ! npm install failed; retrying
   ! npm install failed for openclaw@latest
     Command: env SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm --loglevel error --silent --no-fund --no-audit install -g openclaw@latest
     Installer log: /tmp/tmp.PiR3b2ML5S
   ! npm install failed; showing last log lines
   ```

   这可能是 `npm` 的缓存目录指向了 `windows` 系统的 `C盘`或别的目录。可按以下步骤处理：

   ```powershell
   # step1. 输入一下命令，看当前缓存指向哪里
   npm config get cache
   npm config list -l | grep -E 'cache|prefix|tmp'
   
   # 以下是输出示例：
   zamir@LAPTOP-O7J4QF8P:~$ npm config get cache
   npm config list -l | grep -E 'cache|prefix|tmp'
   /c/Users/admin/.npm-user-cache
   ; cache = "/home/zamir/.npm" ; overridden by env
   cache-max = null
   cache-min = 0
   diff-dst-prefix = "b/"
   diff-no-prefix = false
   diff-src-prefix = "a/"
   ; prefix = "/usr" ; overridden by user
   save-prefix = "^"
   tag-version-prefix = "v"
   ; cache = "/home/zamir/.npm" ; overridden by env
   prefix = "/home/zamir/.npm-global"
   cache = "/c/Users/admin/.npm-user-cache"
   ```

   在输出示例中能看到 `/c/Users/admin/.npm-user-cache`，说明缓存确实指向了 `windows` 系统的 `C盘`。

   主要看 WSL 中的两个文件：

   ```bash
   # ~/.bashrc
   export npm_config_cache="$HOME/.npm" # 不要指向 c 盘
   [[ -d "$HOME/.npm" ]] || mkdir -p "$HOME/.npm"
   ```

   ```bash
   # ~/.npmrc
   cache=/home/zamir/.npm # cache 路径和 .bashrc 中的一致
   registry=https://registry.npmmirror.com/
   ```

## 三、扩展阅读

### OpenClaw 官方安装脚本解析

下面对应 `openclaw/install-release.sh` 中的 `main` 入口，按执行顺序拆成 9 个流程，每个流程列出主要步骤。

#### 0 前置（脚本顶部，进入 `main` 前）

- `set -euo pipefail`：失败、未定义变量、管道错误一律退出。
- `ensure_home_env`：当 `$HOME` 缺失/异常时，从 `getent` / `dscl` 重新解析当前用户家目录。
- `TMPFILES + trap cleanup_tmpfiles EXIT`：登记并在退出时清理脚本创建的所有临时文件/目录。
- `detect_downloader` / `download_file`：探测可用的下载器（`curl` 优先，`wget` 兜底），统一封装 TLS/重试参数。
- `map_legacy_env`：把旧的 `CLAWDBOT_*` 环境变量映射到 `OPENCLAW_*`，做向后兼容。

#### 1 UI 与提示

- `bootstrap_gum_temp`：临时下载并校验 `gum` 二进制，用于美化交互；失败时回退纯文本 UI。
- `print_installer_banner` + `pick_tagline` + `append_holiday_taglines`：打印产品横幅与随机/节日 tagline。
- `ui_info / ui_warn / ui_success / ui_error / ui_section / ui_stage / ui_kv / ui_panel`：统一日志与排版。
- `INSTALL_STAGE_TOTAL=3`：把核心安装划分为 3 个阶段（准备环境 / 安装本体 / 收尾），由 `ui_stage` 自动累加 `[N/3]`。

#### 2 参数解析

- `parse_args`：解析 CLI（`--install-method`、`--version`、`--beta`、`--git-dir`、`--profile`、`--workspace`、`--gateway-port`、`--no-onboard`、`--no-prompt`、`--dry-run`、`--verbose`、`--help` …）。
- `configure_verbose`：`--verbose` 时启用 `set -x`、提高 `npm` 日志级别、关闭 `--silent`。
- `validate_install_overrides`：校验 `--profile` / `--gateway-port` 入参合法性（非法直接退出）。
- 环境变量优先级：`OPENCLAW_*`（含 `OPENCLAW_TAGLINE_INDEX`、`OPENCLAW_NPM_LOGLEVEL`、`SHARP_IGNORE_GLOBAL_LIBVIPS` 等）→ CLI 入参补齐默认值。

#### 3 OS 与安装方式

- `detect_os_or_die`：判定 `OS=macos | linux`（含 WSL），不支持时打印 Windows 安装指引并退出。
- `detect_openclaw_checkout`：当前目录如果是 OpenClaw 源码 checkout（同时存在 `package.json` 中的 `"name": "openclaw"` 与 `pnpm-workspace.yaml`），记录到 `detected_checkout`。
- 若用户未显式指定 `--install-method`：
  - 探测到 checkout 且 TTY 可交互时，`choose_install_method_interactive` 让用户在 `git` / `npm` 之间二选一。
  - 否则默认 `npm`。
- `show_install_plan`：以表格形式展示本次安装计划（OS、方式、版本、git 目录、dry-run、是否 onboard…）。
- `--dry-run` 在此处直接结束，不做任何变更。

#### 4 Stage 1/3：准备环境

- `install_homebrew`：仅 macOS 下运行；缺失则远程执行 Homebrew 官方安装脚本，并 `brew shellenv` 激活到当前会话。
- `check_node` → `install_node`：要求 Node.js v22+。
  - macOS：`brew install node@22 && brew link --overwrite --force` + `ensure_macos_node22_active`。
  - Linux：`require_sudo` 取得 sudo → `install_build_tools_linux`（`apt-get` / `dnf` / `yum` / `apk` 中安装 `build-essential / cmake / python3` 等原生构建工具）→ NodeSource `setup_22.x` → 安装 `nodejs`。
- `ensure_supported_node_on_path`：把检索到的 v22+ node 路径前置到 `PATH`。
- `detect_nvm_and_warn`：若使用 NVM 且默认 Node 仍 < 22，停下来提示 `nvm install 22 / use 22 / alias default 22` 后重试。

#### 5 Stage 2/3：安装 OpenClaw 本体

##### 5.A npm 路径（默认）

1. 清理：检测到旧的 git wrapper（`~/.local/bin/openclaw`）则先移除。
2. `check_git` → 缺失时 `install_git`（npm 安装可能拉 git 依赖）。
3. `fix_npm_permissions`：Linux 下若 `npm prefix` 不可写，则切到 `~/.npm-global` 并把 `$HOME/.npm-global/bin` 写入 `~/.bashrc`、`~/.zshrc`。
4. `install_openclaw`：
   - `--beta` → `resolve_beta_version` 查询 `dist-tag beta`，否则使用 `--version` 或 `latest`。
   - `install_openclaw_npm` 实际跑 `npm install -g openclaw@<spec>`，带：
     - 失败诊断：`print_npm_failure_diagnostics` 解析 `npm ERR! code/syscall/errno`、debug 日志路径。
     - 自愈重试：缺构建工具 → `auto_install_build_tools_for_npm_failure` 重装；`ENOTEMPTY` → `cleanup_npm_openclaw_paths`；`EEXIST` → `cleanup_openclaw_bin_conflict` 后重装。
     - `latest` 失败时回退到 `openclaw@next`。
5. `ensure_openclaw_bin_link`：必要时在 npm bin 目录补建 `openclaw` 软链。
6. `install_openclaw_compat_shim`：若用户原 `PATH` 上的 node 太旧（不到 22），写一个固定指向 v22 node 的 `~/.local/bin/openclaw` shim。

##### 5.B git 路径（`--install-method git`）

1. 清理：先 `npm uninstall -g openclaw` 移除全局 npm 安装。
2. 仓库目录优先级：`detected_checkout` → `--git-dir` → `~/openclaw`；不存在时 `git clone https://github.com/openclaw/openclaw.git`。
3. `GIT_UPDATE=1`（默认）且无本地未提交改动时执行 `git pull --rebase`。
4. `cleanup_legacy_submodules`：删除遗留的 `Peekaboo` 子模块。
5. `ensure_pnpm` + `ensure_pnpm_binary_for_scripts`：准备 `pnpm`（先用现成 `pnpm`，否则 `corepack prepare pnpm@10 --activate`，最后兜底 `npm install -g pnpm@10`）。
6. `ensure_pnpm_git_prepare_allowlist`：在 `pnpm-workspace.yaml` / `package.json` 中允许构建 `@tloncorp/api`。
7. `pnpm install` → `pnpm ui:build` → `pnpm build`。
8. 写入 `~/.local/bin/openclaw` wrapper（`exec node <repo>/dist/entry.js "$@"`）。

#### 6 Stage 3/3：收尾

- `resolve_openclaw_bin`：解析当前 `OPENCLAW_BIN`（`PATH` → npm bin → nodenv rehash 兜底）。
- `warn_duplicate_openclaw_global_installs`：扫描 `npm root -g`、各 `npm` 副本、NVM/FNM/Volta 的 `lib/node_modules`、`/opt/homebrew/lib/node_modules` 等位置，发现多份 openclaw 时给出每份的版本与清理命令。
- `warn_shell_path_missing_dir`：本进程能找到 openclaw 不代表用户登录 shell 也能找到，缺少 `npm 全局 bin` 或 `~/.local/bin` 时输出修复指引。
- `refresh_gateway_service_if_loaded`：如果系统中已加载 OpenClaw gateway 守护进程，依次跑 `openclaw gateway install --force` → `openclaw gateway restart` → `openclaw gateway status --deep`，让服务指向新版二进制。

#### 7 装后流程

- 升级或 git 安装：`run_doctor`（非交互）做配置迁移；TTY 可用时再跑一次 `openclaw doctor` 与 `openclaw plugins update --all`。
- 全新安装：
  - `install_config_already_exists` 已存在配置 → 仅 `run_doctor`，跳过 onboard。
  - 否则把 stdin 接到 `/dev/tty` 后 `exec openclaw [--profile <name>] onboard [--workspace ...] [--gateway-port ...]`，让 onboarding 接管整个进程。
  - 无 TTY 时打印 `openclaw onboard` 完整命令，提示用户后续手动运行。
- `run_bootstrap_onboarding_if_needed`：若工作区残留 `BOOTSTRAP.md`，则继续运行一次 onboard 把流程走完。

#### 8 结束

- 如检测到 gateway daemon 已加载，跑一次 `openclaw daemon restart`，确保新版本生效。
- `should_open_dashboard=true`（升级 / git 安装路径）时尝试 `maybe_open_dashboard`。
- `show_footer_links`：输出 FAQ 与文档链接。

---

### 主要环境变量速查

| 变量 | 作用 |
| --- | --- |
| `OPENCLAW_INSTALL_METHOD` | `npm` / `git`，覆盖默认安装方式 |
| `OPENCLAW_VERSION` | `latest` / `next` / 具体语义化版本 |
| `OPENCLAW_BETA` | `1` 时使用 `dist-tag beta` |
| `OPENCLAW_GIT_DIR` | git 安装的 checkout 目录，默认 `~/openclaw` |
| `OPENCLAW_GIT_UPDATE` | `0` 时跳过 `git pull --rebase` |
| `OPENCLAW_PROFILE` | 隔离的 OpenClaw profile（影响 config / state / service 命名） |
| `OPENCLAW_WORKSPACE` | onboarding 使用的工作区目录 |
| `OPENCLAW_GATEWAY_PORT` | onboarding 写入的 gateway 端口 |
| `OPENCLAW_NO_ONBOARD` | `1` 时跳过 onboarding |
| `OPENCLAW_NO_PROMPT` | `1` 时禁用所有交互提示（CI 必需） |
| `OPENCLAW_DRY_RUN` | `1` 时仅打印计划，不做修改 |
| `OPENCLAW_VERBOSE` | `1` 时启用 `set -x` 与 npm verbose |
| `OPENCLAW_NPM_LOGLEVEL` | npm 日志级别，默认 `error` |
| `SHARP_IGNORE_GLOBAL_LIBVIPS` | 默认 `1`，避免 `sharp` 链接系统 libvips |
| `OPENCLAW_INSTALL_SH_NO_RUN` | `1` 时只加载函数定义、不执行 `main`（测试/复用用） |
| `OPENCLAW_GUM_VERSION` | 临时引导的 gum 版本号，默认 `0.17.0` |
