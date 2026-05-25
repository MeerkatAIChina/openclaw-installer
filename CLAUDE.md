# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **OpenClaw Installer** — a cross-platform one-click installer for OpenClaw, forked from the official install scripts and customized for Chinese users. It supports Windows (PowerShell), Linux, macOS, and WSL (Bash).

Key customizations over the official scripts:
- Sets npm registry to Taobao mirror for faster domestic downloads.
- Pre-configures popular model providers (MoonShot, Zhipu, MiniMax, OpenAI) with simplified auth setup.
- Uses non-interactive `openclaw onboard` to avoid TTY half-state hangs when called from scripts.
- Pre-installs a curated set of skills (see `README.md` for the list).
- Enables hooks automatically post-install.

## Build & Release

The project has **no `package.json`**; Node.js is only used for the build script.

### Common commands

```bash
# Build release artifacts into dist/ (required before releasing)
node scripts/build-release.cjs

# Check UTF-8 BOM on non-ASCII .ps1 files (must pass in CI)
pwsh -NoProfile -File ./scripts/check-ps1-utf8-bom.ps1

# Verify shell script syntax after build
bash -n dist/*.sh

# Verify PowerShell parses after build
pwsh -NoProfile -File scripts/verify-dist-ps1-parse.ps1
```

### CI checks (from `.github/workflows/script-quality.yml`)

- **Shell**: `shellcheck`, `shfmt -i 4`, `checkbashisms` on tracked `*.sh` (excluding `linux/openclaw/**`).
- **PowerShell**: `PSScriptAnalyzer` (`-Severity Error,ParseError`) on all `*.ps1`.
- **Pester**: runs `*.Tests.ps1` under `windows/tests/` on Windows runner (directory currently empty).

### Release flow

1. Tag with `v*` → GitHub Actions runs `node scripts/build-release.cjs`, verifies both shell and PowerShell dist scripts, then creates a GitHub Release uploading `dist/*`.
2. `dist/` is gitignored; release assets are the only distribution channel.

## Directory Structure

| Path | Purpose |
|------|---------|
| `linux/` | Bash install scripts for Linux/macOS/WSL. |
| `windows/` | PowerShell install scripts for Windows. |
| `scripts/` | Build and validation tools (Node.js + PowerShell). |
| `dist/` | Build output directory (gitignored). |
| `docs/` | Design docs, onboard research, auth provider reference. |
| `linux/openclaw/` | Official OpenClaw bash scripts (reference only). |
| `windows/openclaw/` | Official OpenClaw PowerShell scripts (reference only). |

### Key files

- `linux/install-user-dev.sh` — Main interactive install script (dev source).
- `windows/install-user-dev.ps1` — Main interactive install script for users (dev source).
- `windows/install-script-dev.ps1` — Non-interactive/scriptable install for servers (dev source).
- `linux/uninstall.sh` / `windows/uninstall.ps1` — Uninstall scripts.
- `scripts/build-release.cjs` — Strips comments, compresses blank lines, formats, and outputs `dist/`.
- `scripts/strip-ps1-for-release.ps1` — PowerShell-specific release stripping (preserves parseability, adds UTF-8 BOM).

## Architecture Notes

### Dual-track source → dist build

The repo keeps **development sources** (`*-dev.sh` / `*-dev.ps1`) with full comments, verbose formatting, and dev-only logic. `build-release.cjs` produces the minimal `dist/` scripts for end users:

- **Bash**: strips whole-line comments (respects heredocs), normalizes to LF, compresses 3+ consecutive blank lines to one, then runs `shfmt -w -i 4 -bn -ci`.
- **PowerShell**: delegates to `scripts/strip-ps1-for-release.ps1`, which parses the AST to remove comments, compresses blank lines, ensures trailing newline, and writes UTF-8 with BOM.

### WSL caveat

When running bash scripts in WSL2 locally, always append `</dev/null`:

```bash
bash ./install-user-dev.sh </dev/null
```

Without this, `gum` (used for UI) triggers `inappropriate ioctl for device` and can corrupt the environment.

### TTY / onboard trap

When PowerShell calls `openclaw onboard`, stdout is piped (`isTTY = false`) but stdin remains a TTY (`isTTY = true`). OpenClaw enters a broken half-interactive mode and hangs. All install scripts pass `--non-interactive` to avoid this.

### Windows incremental-modification rule

`windows/install*.ps1` files are derived from the official OpenClaw install script. When modifying them:
- Work one module at a time in script order (`0 前置` → `1 Node.js` → `2 Git` → `3 安装本体` → `4 收尾`).
- Comment out all later modules while working on the current one; uncomment only after validation.
- **Do not delete original code** without explicit user approval.

## Coding Standards

### Bash (`*.sh`)

- Shebang: `#!/usr/bin/env bash` when using Bash features; `#!/usr/bin/env sh` for POSIX-only.
- Start with `set -euo pipefail`.
- Quote all variable expansions: `"${var}"`.
- No `eval`; all errors go to `stderr` (`>&2`).
- Use `trap` for temp-file cleanup; use `local` in functions.
- Prefer `printf` over `echo -e`; use `command -v` instead of `which`.
- `shfmt` indent: **4 spaces**.

### PowerShell (`*.ps1`)

- No `Invoke-Expression`; no hardcoded credentials.
- Functions use `Verb-Noun` with `[CmdletBinding()]` and `param()`.
- Prefer explicit named parameters; implement `ShouldProcess` for state-changing commands.
- **4 spaces**, no tabs; avoid backtick line continuations.
- **Encoding**: any `.ps1` containing non-ASCII characters **must be UTF-8 with BOM**. Scripts with only ASCII may be plain UTF-8. CI enforces this via `scripts/check-ps1-utf8-bom.ps1`.

## Environment Variables

Install scripts read `OPENCLAW_*` variables (e.g., `OPENCLAW_INSTALL_METHOD`, `OPENCLAW_VERSION`, `OPENCLAW_GIT_DIR`, `OPENCLAW_NO_ONBOARD`, `OPENCLAW_DRY_RUN`, `OPENCLAW_VERBOSE`). See `linux/README.md` "主要环境变量速查" for the full list.
