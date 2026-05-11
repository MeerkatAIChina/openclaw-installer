#!/usr/bin/env bash
# 卸载 OpenClaw（macOS / Linux / WSL）：尽力清理 CLI、用户级守护与用户目录。
# 不保证覆盖全部历史安装路径；请先停止使用相关会话后再执行。

set +e

resolve_openclaw_bin() {
    if command -v openclaw >/dev/null 2>&1; then
        command -v openclaw
        return 0
    fi
    local p
    for p in "${HOME}/.local/bin/openclaw" "${HOME}/.npm-global/bin/openclaw"; do
        if [[ -x "$p" ]]; then
            printf '%s' "$p"
            return 0
        fi
    done
    if command -v npm >/dev/null 2>&1; then
        local prefix
        prefix="$(npm config get prefix 2>/dev/null | tr -d '\r')"
        if [[ -n "$prefix" && -x "${prefix}/bin/openclaw" ]]; then
            printf '%s' "${prefix}/bin/openclaw"
            return 0
        fi
    fi
    return 1
}

run_claw_if_found() {
    local claw
    if ! claw="$(resolve_openclaw_bin)"; then
        return 0
    fi
    "$claw" daemon stop 2>/dev/null || true
    "$claw" daemon uninstall 2>/dev/null || true
    "$claw" gateway stop 2>/dev/null || true
}

cleanup_systemd_user_units() {
    [[ "$(uname -s)" == "Linux" ]] || return 0
    local f name
    shopt -s nullglob
    for f in "${HOME}/.config/systemd/user"/openclaw*.service "${HOME}/.config/systemd/user"/clawdbot*.service; do
        [[ -e "$f" ]] || continue
        name="$(basename "$f")"
        systemctl --user stop "$name" 2>/dev/null || true
        systemctl --user disable "$name" 2>/dev/null || true
    done
    rm -f "${HOME}/.config/systemd/user"/openclaw*.service "${HOME}/.config/systemd/user"/clawdbot*.service 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    shopt -u nullglob
}

cleanup_launchd_user_agents() {
    [[ "$(uname -s)" == "Darwin" ]] || return 0
    local f uid
    uid="$(id -u)"
    shopt -s nullglob
    for f in "${HOME}/Library/LaunchAgents"/*openclaw* "${HOME}/Library/LaunchAgents"/*clawdbot* \
        "${HOME}/Library/LaunchAgents"/*OpenClaw*; do
        [[ -e "$f" ]] || continue
        launchctl bootout "gui/${uid}" "$f" 2>/dev/null || launchctl unload -w "$f" 2>/dev/null || true
        rm -f "$f"
    done
    shopt -u nullglob
}

cleanup_npm_global_artifacts() {
    command -v npm >/dev/null 2>&1 || return 0
    npm uninstall -g openclaw 2>/dev/null || true
    local root
    root="$(npm root -g 2>/dev/null | tr -d '\r')"
    if [[ -n "$root" ]]; then
        rm -rf "${root}/openclaw" "${root}/.openclaw-"* 2>/dev/null || true
    fi
    rm -rf "${HOME}/.local/lib/node_modules/openclaw" "${HOME}/.local/lib/node_modules/.openclaw-"* 2>/dev/null || true
}

main() {
    run_claw_if_found
    cleanup_systemd_user_units
    cleanup_launchd_user_agents
    pkill -f 'openclaw|clawdbot' 2>/dev/null || true
    hash -r 2>/dev/null || true
    cleanup_npm_global_artifacts
    rm -f "${HOME}/.local/bin/openclaw" 2>/dev/null || true
    rm -rf "${HOME}/.openclaw" "${HOME}/.clawdbot" "${HOME}/.moltbot" "${HOME}/.moldbot" 2>/dev/null || true
    shopt -s nullglob
    for d in "${HOME}/.openclaw-"*; do
        [[ -e "$d" ]] || continue
        rm -rf "$d"
    done
    shopt -u nullglob
    printf 'OpenClaw 卸载步骤已执行（尽力而为）。请检查：command -v openclaw、npm list -g openclaw\n'
}

main "$@"
