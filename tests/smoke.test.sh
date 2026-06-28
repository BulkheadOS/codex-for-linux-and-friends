#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

unset CODEX_INOTIFY_PRESSURE_ALLOW_UNSAFE
unset CODEX_INOTIFY_GUARD_THRESHOLD_PERCENT
unset CODEX_LINUX_INOTIFY_USAGE_FIXTURE
unset CODEX_LINUX_INOTIFY_LIMITS_FIXTURE
export CODEX_LINUX_INOTIFY_USAGE_FIXTURE='0 0'
export CODEX_LINUX_INOTIFY_LIMITS_FIXTURE='1000 1000'

tmp_launcher_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_launcher_dir"' EXIT

help_output="$(bin/codex-linux --help)"
case "$help_output" in
  *"Codex for Linux and friends"* ) ;;
  * ) echo "help output did not include product name" >&2; exit 1 ;;
esac
case "$help_output" in
  *"codex-linux diagnostics [--json]"* ) ;;
  * ) echo "help output did not include diagnostics command" >&2; exit 1 ;;
esac

status_output="$(CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux status)"
case "$status_output" in
  *"Not installed."* ) ;;
  * ) echo "status output should report a missing install" >&2; exit 1 ;;
esac

json_output="$(CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux status --json)"
node -e 'const value = JSON.parse(process.argv[1]); if (value.installed !== false) process.exit(1)' "$json_output"

diagnostics_output="$(env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_TYPE -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION -u WAYLAND_DISPLAY CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux diagnostics)"
case "$diagnostics_output" in
  *"Install:        no"* ) ;;
  * ) echo "diagnostics should report a missing install without launching" >&2; exit 1 ;;
esac
case "$diagnostics_output" in
  *"Launch safety:  blocked - runtime is not installed"* ) ;;
  * ) echo "diagnostics should explain why launch is blocked when the runtime is missing" >&2; exit 1 ;;
esac
case "$diagnostics_output" in
  *"Appshots:     not claimed on Linux"* ) ;;
  * ) echo "diagnostics should not claim Linux Appshots support" >&2; exit 1 ;;
esac
case "$diagnostics_output" in
  *"Computer Use: not claimed on Linux"* ) ;;
  * ) echo "diagnostics should not claim Linux Computer Use support" >&2; exit 1 ;;
esac
case "$diagnostics_output" in
  *"Runtime health:"*"Processes: electron="*"Webview port: 5175 "*"Inotify: max_user_instances="* ) ;;
  * ) echo "diagnostics should include no-launch runtime health evidence" >&2; exit 1 ;;
esac

diagnostics_json="$(env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_TYPE -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION -u WAYLAND_DISPLAY CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux diagnostics --json)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.installed !== false) process.exit(1);
if (value.launchSafety.status !== "blocked") process.exit(1);
if (value.features.appshots.status !== "not-claimed-on-linux") process.exit(1);
if (value.features.computerUse.status !== "not-claimed-on-linux") process.exit(1);
if (typeof value.runtimeHealth?.processes?.electron !== "number") process.exit(1);
if (typeof value.runtimeHealth?.processes?.crashpad !== "number") process.exit(1);
if (typeof value.runtimeHealth?.processes?.webviewServer !== "number") process.exit(1);
if (value.runtimeHealth?.webviewPort?.port !== 5175) process.exit(1);
if (!["open", "closed", "unknown"].includes(value.runtimeHealth?.webviewPort?.status)) process.exit(1);
if (value.runtimeHealth?.inotify?.maxUserInstances !== null && typeof value.runtimeHealth?.inotify?.maxUserInstances !== "number") process.exit(1);
if (value.runtimeHealth?.inotify?.maxUserWatches !== null && typeof value.runtimeHealth?.inotify?.maxUserWatches !== "number") process.exit(1);
if (value.runtimeHealth?.inotify?.userInstances !== null && typeof value.runtimeHealth?.inotify?.userInstances !== "number") process.exit(1);
if (value.runtimeHealth?.inotify?.userWatches !== null && typeof value.runtimeHealth?.inotify?.userWatches !== "number") process.exit(1);
if (value.runtimeHealth?.inotify?.instanceUsagePercent !== null && typeof value.runtimeHealth?.inotify?.instanceUsagePercent !== "number") process.exit(1);
if (value.runtimeHealth?.inotify?.watchUsagePercent !== null && typeof value.runtimeHealth?.inotify?.watchUsagePercent !== "number") process.exit(1);
if (typeof value.runtimeHealth?.inotify?.codexRelatedFdCount !== "number") process.exit(1);
if (!["ok", "warning", "blocked", "override-active", "unknown"].includes(value.runtimeHealth?.inotify?.pressure?.status)) process.exit(1);
if (value.runtimeHealth?.inotify?.pressure?.guardThresholdPercent !== 90) process.exit(1);
if (typeof value.runtimeHealth?.inotify?.pressure?.override !== "boolean") process.exit(1);
if (value.runtimeHealth?.inotify?.pressure?.status !== "ok") process.exit(1);
' "$diagnostics_json"

watch_override_json="$(env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_TYPE -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION -u WAYLAND_DISPLAY CODEX_LINUX_RECURSIVE_WATCH=1 CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux diagnostics --json)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.fileWatching.status !== "override-active") process.exit(1);
if (!value.fileWatching.detail.includes("CODEX_LINUX_RECURSIVE_WATCH=1")) process.exit(1);
' "$watch_override_json"

custom_port_json="$(env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_TYPE -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION -u WAYLAND_DISPLAY CODEX_WEBVIEW_PORT=5176 CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux diagnostics --json)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.runtimeHealth.webviewPort.port !== 5176) process.exit(1);
if (!["open", "closed", "unknown"].includes(value.runtimeHealth.webviewPort.status)) process.exit(1);
' "$custom_port_json"

high_inotify_json="$(env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_TYPE -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION -u WAYLAND_DISPLAY CODEX_LINUX_INOTIFY_USAGE_FIXTURE='91 660' CODEX_LINUX_INOTIFY_LIMITS_FIXTURE='100 1000' CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux diagnostics --json)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.runtimeHealth.inotify.userInstances !== 91) process.exit(1);
if (value.runtimeHealth.inotify.userWatches !== 660) process.exit(1);
if (value.runtimeHealth.inotify.instanceUsagePercent !== 91) process.exit(1);
if (value.runtimeHealth.inotify.watchUsagePercent !== 66) process.exit(1);
if (value.runtimeHealth.inotify.pressure.status !== "blocked") process.exit(1);
if (value.runtimeHealth.inotify.pressure.override !== false) process.exit(1);
' "$high_inotify_json"

near_threshold_inotify_json="$(env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_TYPE -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION -u WAYLAND_DISPLAY CODEX_LINUX_INOTIFY_USAGE_FIXTURE='899 0' CODEX_LINUX_INOTIFY_LIMITS_FIXTURE='1000 1000' CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux diagnostics --json)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.runtimeHealth.inotify.instanceUsagePercent !== 89) process.exit(1);
if (value.runtimeHealth.inotify.pressure.status === "blocked") process.exit(1);
' "$near_threshold_inotify_json"

exact_threshold_inotify_json="$(env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_TYPE -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION -u WAYLAND_DISPLAY CODEX_LINUX_INOTIFY_USAGE_FIXTURE='900 0' CODEX_LINUX_INOTIFY_LIMITS_FIXTURE='1000 1000' CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux diagnostics --json)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.runtimeHealth.inotify.instanceUsagePercent !== 90) process.exit(1);
if (value.runtimeHealth.inotify.pressure.status !== "blocked") process.exit(1);
' "$exact_threshold_inotify_json"

partial_unknown_inotify_json="$(env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_TYPE -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION -u WAYLAND_DISPLAY CODEX_LINUX_INOTIFY_USAGE_FIXTURE='0 10' CODEX_LINUX_INOTIFY_LIMITS_FIXTURE='unknown 1000' CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux diagnostics --json)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.runtimeHealth.inotify.instanceUsagePercent !== null) process.exit(1);
if (value.runtimeHealth.inotify.watchUsagePercent !== 1) process.exit(1);
if (value.runtimeHealth.inotify.pressure.status !== "warning") process.exit(1);
' "$partial_unknown_inotify_json"

leading_zero_threshold_json="$(env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_TYPE -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION -u WAYLAND_DISPLAY CODEX_INOTIFY_GUARD_THRESHOLD_PERCENT=090 CODEX_LINUX_INOTIFY_USAGE_FIXTURE='90 0' CODEX_LINUX_INOTIFY_LIMITS_FIXTURE='100 1000' CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux diagnostics --json)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.runtimeHealth.inotify.pressure.guardThresholdPercent !== 90) process.exit(1);
if (value.runtimeHealth.inotify.pressure.status !== "blocked") process.exit(1);
' "$leading_zero_threshold_json"

override_inotify_json="$(env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_TYPE -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION -u WAYLAND_DISPLAY CODEX_INOTIFY_PRESSURE_ALLOW_UNSAFE=1 CODEX_LINUX_INOTIFY_USAGE_FIXTURE='91 660' CODEX_LINUX_INOTIFY_LIMITS_FIXTURE='100 1000' CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux diagnostics --json)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.runtimeHealth.inotify.pressure.status !== "override-active") process.exit(1);
if (value.runtimeHealth.inotify.pressure.override !== true) process.exit(1);
' "$override_inotify_json"

missing_kde_override_json="$(
  env \
  CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" \
  CODEX_KDE_WAYLAND_ALLOW_UNSAFE=1 \
  KDE_FULL_SESSION=true \
  KDE_SESSION_VERSION=6 \
  XDG_SESSION_TYPE=wayland \
  XDG_CURRENT_DESKTOP=KDE \
  XDG_SESSION_DESKTOP=KDE \
  DESKTOP_SESSION=plasma \
  bin/codex-linux diagnostics --json
)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.installed !== false) process.exit(1);
if (value.session !== "KDE Wayland") process.exit(1);
if (value.launchSafety.status !== "blocked") process.exit(1);
if (!value.launchSafety.detail.includes("not installed")) process.exit(1);
' "$missing_kde_override_json"

if grep -q 'exec "$SCRIPT_DIR/electron"' bin/codex-linux; then
  echo "launcher must not exec electron after starting the webview server; cleanup trap would be skipped" >&2
  exit 1
fi

if ! grep -q 'exec python3 -m http.server "$WEBVIEW_PORT"' bin/codex-linux; then
  echo "webview server must exec python so the cleanup trap owns the server PID" >&2
  exit 1
fi

if ! grep -q 'ELECTRON_PID="$!"' bin/codex-linux; then
  echo "launcher must track Electron's child PID for signal cleanup" >&2
  exit 1
fi

if ! grep -q 'for cmd in curl node npm npx python3 unzip make setsid sha256sum' bin/codex-linux; then
  echo "doctor must require setsid and sha256sum for process isolation and Electron checksum verification" >&2
  exit 1
fi

if ! grep -q 'setsid "$SCRIPT_DIR/electron"' bin/codex-linux; then
  echo "launcher must start Electron in its own process group" >&2
  exit 1
fi

if ! grep -q 'kill -TERM -- "-$pid"' bin/codex-linux; then
  echo "launcher must terminate Electron's process group on signal cleanup" >&2
  exit 1
fi

if grep -q '\${extra_flags\[@\]+"' bin/codex-linux; then
  echo "launcher must not pass a blank argv item when no extra flags are configured" >&2
  exit 1
fi

if ! grep -q 'wait "$ELECTRON_PID"' bin/codex-linux; then
  echo "launcher must wait on the tracked Electron PID instead of running it in the foreground" >&2
  exit 1
fi

if ! grep -q 'trap cleanup_launcher EXIT' bin/codex-linux; then
  echo "launcher must clean up Electron and webview server on normal exit" >&2
  exit 1
fi

if ! grep -q 'WEBVIEW_SERVER_STARTED=0' bin/codex-linux ||
   ! grep -q 'WEBVIEW_SERVER_STARTED=1' bin/codex-linux ||
   ! grep -q '\${WEBVIEW_SERVER_STARTED:-0}" != "1"' bin/codex-linux; then
  echo "launcher must only stop webview servers it started" >&2
  exit 1
fi

if ! grep -q 'stop_crashpad_handlers' bin/codex-linux; then
  echo "launcher must clean up Codex crashpad handlers that Electron leaves orphaned" >&2
  exit 1
fi

if ! grep -q '"$SCRIPT_DIR/chrome_crashpad_handler"' bin/codex-linux; then
  echo "crashpad cleanup must be scoped to the installed Codex runtime" >&2
  exit 1
fi

if ! grep -q "trap 'handle_launcher_signal 130' INT" bin/codex-linux; then
  echo "launcher must handle SIGINT by cleaning up child processes" >&2
  exit 1
fi

if grep -q 'trap stop_webview_server EXIT INT TERM' bin/codex-linux; then
  echo "webview-only signal trap would leave foreground Electron running" >&2
  exit 1
fi

if ! grep -q 'CODEX_KDE_WAYLAND_ALLOW_UNSAFE' bin/codex-linux ||
   ! grep -q 'CODEX_KWIN_ALLOW_UNSAFE' bin/codex-linux ||
   ! grep -q 'block_kde_wayland_launch' bin/codex-linux; then
  echo "launcher must guard KDE Wayland behind an explicit unsafe override" >&2
  exit 1
fi

if ! grep -q 'Unsafe maintainer-only KDE Wayland crash-guard override' bin/codex-linux; then
  echo "launcher help must label the KDE Wayland override as unsafe maintainer-only testing" >&2
  exit 1
fi

if ! grep -q 'CODEX_INOTIFY_PRESSURE_ALLOW_UNSAFE' bin/codex-linux ||
   ! grep -q 'CODEX_INOTIFY_GUARD_THRESHOLD_PERCENT' bin/codex-linux ||
   ! grep -q 'block_inotify_pressure_launch' bin/codex-linux; then
  echo "launcher must guard high inotify pressure behind an explicit unsafe override" >&2
  exit 1
fi

if ! grep -q 'Use a non-KDE Wayland session or an X11 session for normal use' bin/codex-linux; then
  echo "KDE Wayland guard must give desktop-launch users a safe next action" >&2
  exit 1
fi

if ! grep -q 'CODEX_WEBVIEW_PORT=5176 codex-linux launch' bin/codex-linux; then
  echo "webview startup failure must print a recovery command" >&2
  exit 1
fi

if grep -q 'extra_flags+=("--wayland-text-input-version=3")' bin/codex-linux && \
   ! grep -q 'CODEX_WAYLAND_TEXT_INPUT:-0' bin/codex-linux; then
  echo "Wayland text-input v3 must remain opt-in until physical keyboard focus is reliable" >&2
  exit 1
fi

if grep -q 'exec >>"$LAUNCHER_LOG_FILE"' bin/codex-linux; then
  echo "launcher must not persist raw Electron stdout/stderr by default" >&2
  exit 1
fi

if ! grep -q 'CODEX_LINUX_CXX' bin/codex-linux; then
  echo "native rebuild should allow an explicit C++ compiler override" >&2
  exit 1
fi

if ! grep -q 'npm_config_cxx="$native_cxx"' bin/codex-linux; then
  echo "native rebuild should pass the selected C++ compiler into node-gyp" >&2
  exit 1
fi

if grep -q 'for cmd in curl node npm npx python3 unzip make g++' bin/codex-linux; then
  echo "doctor should not require g++ before honoring CODEX_LINUX_CXX" >&2
  exit 1
fi

if grep -q 'Refused to start webview server' bin/codex-linux; then
  echo "launcher should not fail just because another Codex compatibility launcher owns the webview port" >&2
  exit 1
fi

if ! grep -q 'readlink -f "$resolved"' bin/codex-linux; then
  echo "compiler overrides resolved from PATH should become absolute before native rebuild" >&2
  exit 1
fi

if ! grep -q 'unset ELECTRON_RUN_AS_NODE' bin/codex-linux; then
  echo "launcher must clear ELECTRON_RUN_AS_NODE before starting Electron" >&2
  exit 1
fi

if ! grep -q 'SHASUMS256.txt' bin/codex-linux ||
   ! grep -q 'sha256sum "$electron_zip"' bin/codex-linux ||
   ! grep -q 'Electron runtime checksum mismatch' bin/codex-linux; then
  echo "installer must verify Electron runtime ZIPs against published SHA256 checksums" >&2
  exit 1
fi

node - "$tmp_launcher_dir/start.sh" <<'NODE'
const fs = require("fs");
const source = fs.readFileSync("bin/codex-linux", "utf8");
const marker = "  cat >\"$INSTALL_DIR/start.sh\" <<'EOF'\n";
const start = source.indexOf(marker);
if (start < 0) {
  throw new Error("could not find generated launcher heredoc");
}
const bodyStart = start + marker.length;
const end = source.indexOf("\nEOF\n", bodyStart);
if (end < 0) {
  throw new Error("could not find generated launcher heredoc end");
}
fs.writeFileSync(process.argv[2], source.slice(bodyStart, end + 1));
NODE

chmod +x "$tmp_launcher_dir/start.sh"
cat >"$tmp_launcher_dir/electron" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${0}.args"
EOF
chmod +x "$tmp_launcher_dir/electron"
mkdir -p "$tmp_launcher_dir/home" "$tmp_launcher_dir/state" "$tmp_launcher_dir/cache"

diagnostics_legacy_dir="$tmp_launcher_dir/diagnostics-legacy-runtime"
mkdir -p "$diagnostics_legacy_dir"
cat >"$diagnostics_legacy_dir/metadata.json" <<'EOF'
{
  "appVersion": "98.0.0-test",
  "electronVersion": "41.0.0-test"
}
EOF
cat >"$diagnostics_legacy_dir/start.sh" <<'EOF'
#!/usr/bin/env bash
echo "legacy launcher ran" >&2
exit 99
EOF
chmod +x "$diagnostics_legacy_dir/start.sh"

legacy_diagnostics="$(
  env \
  CODEX_LINUX_INSTALL_DIR="$diagnostics_legacy_dir" \
  KDE_FULL_SESSION=true \
  KDE_SESSION_VERSION=6 \
  XDG_SESSION_TYPE=wayland \
  XDG_CURRENT_DESKTOP=KDE \
  XDG_SESSION_DESKTOP=KDE \
  DESKTOP_SESSION=plasma \
  bin/codex-linux diagnostics
)"
case "$legacy_diagnostics" in
  *"Launch safety:  blocked - installed runtime launcher lacks the KDE Wayland crash guard"* ) ;;
  * ) echo "diagnostics should flag installed KDE Wayland runtimes that lack the crash guard" >&2; exit 1 ;;
esac

if legacy_launch_output="$(
  env \
  CODEX_LINUX_INSTALL_DIR="$diagnostics_legacy_dir" \
  KDE_FULL_SESSION=true \
  KDE_SESSION_VERSION=6 \
  XDG_SESSION_TYPE=wayland \
  XDG_CURRENT_DESKTOP=KDE \
  XDG_SESSION_DESKTOP=KDE \
  DESKTOP_SESSION=plasma \
  bin/codex-linux launch 2>&1
)"; then
  echo "codex-linux launch must refuse legacy runtimes on KDE Wayland" >&2
  exit 1
fi
case "$legacy_launch_output" in
  *"lacks the KWin crash guard"* ) ;;
  * ) echo "legacy runtime launch refusal should explain the missing KWin guard" >&2; exit 1 ;;
esac
case "$legacy_launch_output" in
  *"legacy launcher ran"* ) echo "legacy runtime launcher must not execute on KDE Wayland" >&2; exit 1 ;;
esac

inotify_guard_dir="$tmp_launcher_dir/inotify-guard-runtime"
mkdir -p "$inotify_guard_dir"
cat >"$inotify_guard_dir/metadata.json" <<'EOF'
{
  "appVersion": "99.0.0-test",
  "electronVersion": "42.1.0-test"
}
EOF
cat >"$inotify_guard_dir/start.sh" <<'EOF'
#!/usr/bin/env bash
echo "inotify guard test launcher ran" >&2
exit 23
EOF
chmod +x "$inotify_guard_dir/start.sh"

if inotify_guard_output="$(
  env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_TYPE -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION -u WAYLAND_DISPLAY \
  CODEX_LINUX_INSTALL_DIR="$inotify_guard_dir" \
  CODEX_LINUX_INOTIFY_USAGE_FIXTURE='90 100' \
  CODEX_LINUX_INOTIFY_LIMITS_FIXTURE='100 1000' \
  bin/codex-linux launch 2>&1
)"; then
  echo "codex-linux launch must refuse high inotify pressure before running the installed launcher" >&2
  exit 1
fi
case "$inotify_guard_output" in
  *"refused to launch because inotify usage is already at or above 90%"* ) ;;
  * ) echo "inotify pressure guard did not print the expected refusal message" >&2; exit 1 ;;
esac
case "$inotify_guard_output" in
  *"inotify guard test launcher ran"* ) echo "inotify pressure guard must stop before installed launcher execution" >&2; exit 1 ;;
esac

inotify_override_output="$(
  env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_TYPE -u XDG_CURRENT_DESKTOP -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION -u WAYLAND_DISPLAY \
  CODEX_LINUX_INSTALL_DIR="$inotify_guard_dir" \
  CODEX_INOTIFY_PRESSURE_ALLOW_UNSAFE=1 \
  CODEX_LINUX_INOTIFY_USAGE_FIXTURE='90 100' \
  CODEX_LINUX_INOTIFY_LIMITS_FIXTURE='100 1000' \
  bin/codex-linux launch 2>&1 || true
)"
case "$inotify_override_output" in
  *"inotify guard test launcher ran"* ) ;;
  * )
  echo "inotify pressure unsafe override should allow the installed launcher to run" >&2
  exit 1
  ;;
esac

diagnostics_install_dir="$tmp_launcher_dir/diagnostics-runtime"
mkdir -p "$diagnostics_install_dir"
cat >"$diagnostics_install_dir/metadata.json" <<'EOF'
{
  "appVersion": "99.0.0-test",
  "electronVersion": "42.1.0-test"
}
EOF
cat >"$diagnostics_install_dir/start.sh" <<'EOF'
#!/usr/bin/env bash
# CODEX_KDE_WAYLAND_ALLOW_UNSAFE
block_kde_wayland_launch() { :; }
echo "diagnostics test launcher should not run" >&2
exit 99
EOF
chmod +x "$diagnostics_install_dir/start.sh"

kde_diagnostics="$(
  env \
  CODEX_LINUX_INSTALL_DIR="$diagnostics_install_dir" \
  KDE_FULL_SESSION=true \
  KDE_SESSION_VERSION=6 \
  XDG_SESSION_TYPE=wayland \
  XDG_CURRENT_DESKTOP=KDE \
  XDG_SESSION_DESKTOP=KDE \
  DESKTOP_SESSION=plasma \
  bin/codex-linux diagnostics
)"
case "$kde_diagnostics" in
  *"Install:        yes"* ) ;;
  * ) echo "diagnostics should detect the installed runtime" >&2; exit 1 ;;
esac
case "$kde_diagnostics" in
  *"Session:        KDE Wayland"* ) ;;
  * ) echo "diagnostics should identify KDE Wayland sessions" >&2; exit 1 ;;
esac
case "$kde_diagnostics" in
  *"Launch safety:  blocked - KDE Wayland crash guard prevents launch to avoid a KWin restart"* ) ;;
  * ) echo "diagnostics should explain the KDE Wayland crash guard" >&2; exit 1 ;;
esac

kde_diagnostics_json="$(
  env \
  CODEX_LINUX_INSTALL_DIR="$diagnostics_install_dir" \
  KDE_FULL_SESSION=true \
  KDE_SESSION_VERSION=6 \
  XDG_SESSION_TYPE=wayland \
  XDG_CURRENT_DESKTOP=KDE \
  XDG_SESSION_DESKTOP=KDE \
  DESKTOP_SESSION=plasma \
  bin/codex-linux diagnostics --json
)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.installed !== true) process.exit(1);
if (value.session !== "KDE Wayland") process.exit(1);
if (value.launchSafety.status !== "blocked") process.exit(1);
if (value.features.automations.status !== "blocked") process.exit(1);
' "$kde_diagnostics_json"

kde_override_diagnostics_json="$(
  env \
  CODEX_LINUX_INSTALL_DIR="$diagnostics_install_dir" \
  CODEX_KWIN_ALLOW_UNSAFE=1 \
  KDE_FULL_SESSION=true \
  KDE_SESSION_VERSION=6 \
  XDG_SESSION_TYPE=wayland \
  XDG_CURRENT_DESKTOP=KDE \
  XDG_SESSION_DESKTOP=KDE \
  DESKTOP_SESSION=plasma \
  bin/codex-linux diagnostics --json
)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.installed !== true) process.exit(1);
if (value.launchSafety.status !== "unsafe-override") process.exit(1);
if (value.features.automations.status !== "unsafe-override") process.exit(1);
' "$kde_override_diagnostics_json"

kde_override_high_inotify_json="$(
  env \
  CODEX_LINUX_INSTALL_DIR="$diagnostics_install_dir" \
  CODEX_KWIN_ALLOW_UNSAFE=1 \
  CODEX_LINUX_INOTIFY_USAGE_FIXTURE='90 0' \
  CODEX_LINUX_INOTIFY_LIMITS_FIXTURE='100 1000' \
  KDE_FULL_SESSION=true \
  KDE_SESSION_VERSION=6 \
  XDG_SESSION_TYPE=wayland \
  XDG_CURRENT_DESKTOP=KDE \
  XDG_SESSION_DESKTOP=KDE \
  DESKTOP_SESSION=plasma \
  bin/codex-linux diagnostics --json
)"
node -e '
const value = JSON.parse(process.argv[1]);
if (value.installed !== true) process.exit(1);
if (value.session !== "KDE Wayland") process.exit(1);
if (value.runtimeHealth.inotify.pressure.status !== "blocked") process.exit(1);
if (value.launchSafety.status !== "blocked") process.exit(1);
if (!value.launchSafety.detail.includes("inotify usage")) process.exit(1);
if (value.features.automations.status !== "blocked") process.exit(1);
' "$kde_override_high_inotify_json"

rm -f "$tmp_launcher_dir/electron.args"
if guard_output="$(
  env \
  HOME="$tmp_launcher_dir/home" \
  XDG_STATE_HOME="$tmp_launcher_dir/state" \
  XDG_CACHE_HOME="$tmp_launcher_dir/cache" \
  CODEX_CLI_PATH=/bin/true \
  KDE_FULL_SESSION=true \
  KDE_SESSION_VERSION=6 \
  XDG_SESSION_TYPE=wayland \
  XDG_CURRENT_DESKTOP=KDE \
  XDG_SESSION_DESKTOP=KDE \
  DESKTOP_SESSION=plasma \
  "$tmp_launcher_dir/start.sh" 2>&1
)"; then
  echo "launcher must refuse KDE Wayland without the unsafe override" >&2
  exit 1
fi
case "$guard_output" in
  *"refused to launch on KDE Wayland"* ) ;;
  * ) echo "KDE Wayland guard did not print the expected refusal message" >&2; exit 1 ;;
esac
if [ -f "$tmp_launcher_dir/electron.args" ]; then
  echo "KDE Wayland guard must stop before Electron starts" >&2
  exit 1
fi

rm -f "$tmp_launcher_dir/electron.args"
if inotify_launcher_output="$(
  env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION \
  HOME="$tmp_launcher_dir/home" \
  XDG_STATE_HOME="$tmp_launcher_dir/state" \
  XDG_CACHE_HOME="$tmp_launcher_dir/cache" \
  CODEX_CLI_PATH=/bin/true \
  CODEX_LINUX_INOTIFY_USAGE_FIXTURE='90 100' \
  CODEX_LINUX_INOTIFY_LIMITS_FIXTURE='100 1000' \
  XDG_SESSION_TYPE=wayland \
  XDG_CURRENT_DESKTOP=GNOME \
  "$tmp_launcher_dir/start.sh" 2>&1
)"; then
  echo "generated launcher must refuse high inotify pressure before Electron starts" >&2
  exit 1
fi
case "$inotify_launcher_output" in
  *"refused to launch because inotify usage is already at or above 90%"* ) ;;
  * ) echo "generated inotify pressure guard did not print the expected refusal message" >&2; exit 1 ;;
esac
if [ -f "$tmp_launcher_dir/electron.args" ]; then
  echo "generated inotify pressure guard must stop before Electron starts" >&2
  exit 1
fi

rm -f "$tmp_launcher_dir/electron.args"
env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION \
HOME="$tmp_launcher_dir/home" \
XDG_STATE_HOME="$tmp_launcher_dir/state" \
XDG_CACHE_HOME="$tmp_launcher_dir/cache" \
CODEX_CLI_PATH=/bin/true \
CODEX_INOTIFY_PRESSURE_ALLOW_UNSAFE=1 \
CODEX_LINUX_INOTIFY_USAGE_FIXTURE='90 100' \
CODEX_LINUX_INOTIFY_LIMITS_FIXTURE='100 1000' \
XDG_SESSION_TYPE=wayland \
XDG_CURRENT_DESKTOP=GNOME \
"$tmp_launcher_dir/start.sh"
if [ ! -f "$tmp_launcher_dir/electron.args" ]; then
  echo "generated launcher inotify unsafe override should allow Electron to start" >&2
  exit 1
fi

rm -f "$tmp_launcher_dir/electron.args"
env -u KDE_FULL_SESSION -u KDE_SESSION_VERSION -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION \
HOME="$tmp_launcher_dir/home" \
XDG_STATE_HOME="$tmp_launcher_dir/state" \
XDG_CACHE_HOME="$tmp_launcher_dir/cache" \
CODEX_CLI_PATH=/bin/true \
XDG_SESSION_TYPE=wayland \
XDG_CURRENT_DESKTOP=GNOME \
"$tmp_launcher_dir/start.sh"
if ! grep -q -- '--ozone-platform=x11' "$tmp_launcher_dir/electron.args"; then
  echo "non-KDE Wayland sessions should keep the XWayland-compatible default" >&2
  exit 1
fi

rm -f "$tmp_launcher_dir/electron.args"
env \
HOME="$tmp_launcher_dir/home" \
XDG_STATE_HOME="$tmp_launcher_dir/state" \
XDG_CACHE_HOME="$tmp_launcher_dir/cache" \
CODEX_CLI_PATH=/bin/true \
KDE_FULL_SESSION=true \
KDE_SESSION_VERSION=6 \
CODEX_KDE_WAYLAND_ALLOW_UNSAFE=1 \
XDG_SESSION_TYPE=wayland \
XDG_CURRENT_DESKTOP=KDE \
XDG_SESSION_DESKTOP=KDE \
DESKTOP_SESSION=plasma \
"$tmp_launcher_dir/start.sh"
if ! grep -q -- '--ozone-platform=wayland' "$tmp_launcher_dir/electron.args"; then
  echo "KDE Wayland unsafe override should default to native Wayland" >&2
  exit 1
fi
if ! grep -q -- '--wayland-text-input-version=3' "$tmp_launcher_dir/electron.args"; then
  echo "KDE Wayland unsafe override should include native text-input support" >&2
  exit 1
fi

rm -f "$tmp_launcher_dir/electron.args"
env \
HOME="$tmp_launcher_dir/home" \
XDG_STATE_HOME="$tmp_launcher_dir/state" \
XDG_CACHE_HOME="$tmp_launcher_dir/cache" \
CODEX_CLI_PATH=/bin/true \
KDE_FULL_SESSION=true \
KDE_SESSION_VERSION=6 \
CODEX_KDE_WAYLAND_ALLOW_UNSAFE=1 \
CODEX_OZONE_PLATFORM=x11 \
XDG_SESSION_TYPE=wayland \
XDG_CURRENT_DESKTOP=KDE \
XDG_SESSION_DESKTOP=KDE \
DESKTOP_SESSION=plasma \
"$tmp_launcher_dir/start.sh"
if grep -q -- '--ozone-platform=x11' "$tmp_launcher_dir/electron.args"; then
  echo "KDE Wayland unsafe override must not allow the crash-prone XWayland path" >&2
  exit 1
fi
if ! grep -q -- '--ozone-platform=wayland' "$tmp_launcher_dir/electron.args"; then
  echo "KDE Wayland unsafe override should force native Wayland even if CODEX_OZONE_PLATFORM=x11" >&2
  exit 1
fi

crashpad_test_dir="$tmp_launcher_dir/crashpad-test"
mkdir -p "$crashpad_test_dir"
cat >"$crashpad_test_dir/start.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LAUNCHER_LOG_FILE="$LOG_DIR/launcher.log"
ELECTRON_PID=""
ELECTRON_HAS_PROCESS_GROUP=0
ELECTRON_PROCESS_GROUP_ID=""
CRASHPAD_BASELINE_PIDS=""
mkdir -p "$LOG_DIR"

launcher_log() { :; }

stop_electron() {
  local pid="$ELECTRON_PID"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    if [ "${ELECTRON_HAS_PROCESS_GROUP:-0}" = "1" ]; then
      ELECTRON_PROCESS_GROUP_ID="$pid"
      kill -TERM -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    else
      kill "$pid" 2>/dev/null || true
    fi
    wait "$pid" 2>/dev/null || true
  fi
  ELECTRON_PID=""
  ELECTRON_HAS_PROCESS_GROUP=0
}

snapshot_crashpad_handlers() {
  local pid
  local pgid
  local cmd

  CRASHPAD_BASELINE_PIDS=""
  while read -r pid pgid cmd; do
    case "$cmd" in
      "$SCRIPT_DIR/chrome_crashpad_handler"|"$SCRIPT_DIR/chrome_crashpad_handler "*)
        CRASHPAD_BASELINE_PIDS="${CRASHPAD_BASELINE_PIDS}${CRASHPAD_BASELINE_PIDS:+ }$pid"
        ;;
    esac
  done < <(ps -eo pid=,pgid=,args=)
}

crashpad_pid_was_preexisting() {
  local target="$1"
  local existing
  for existing in $CRASHPAD_BASELINE_PIDS; do
    [ "$existing" = "$target" ] && return 0
  done
  return 1
}

stop_crashpad_handlers() {
  local pid
  local pgid
  local cmd

  ps -eo pid=,pgid=,args= | while read -r pid pgid cmd; do
    case "$cmd" in
      "$SCRIPT_DIR/chrome_crashpad_handler"|"$SCRIPT_DIR/chrome_crashpad_handler "*)
        if [ -n "${ELECTRON_PROCESS_GROUP_ID:-}" ] && [ "$pgid" != "$ELECTRON_PROCESS_GROUP_ID" ]; then
          continue
        fi
        if [ -z "${ELECTRON_PROCESS_GROUP_ID:-}" ] && crashpad_pid_was_preexisting "$pid"; then
          continue
        fi
        kill "$pid" 2>/dev/null || true
        ;;
    esac
  done
}

cleanup_launcher() {
  stop_electron
  stop_crashpad_handlers
}

trap cleanup_launcher EXIT
snapshot_crashpad_handlers
setsid "$SCRIPT_DIR/electron" "$@" &
ELECTRON_PID="$!"
ELECTRON_HAS_PROCESS_GROUP=1
ELECTRON_PROCESS_GROUP_ID="$ELECTRON_PID"
wait "$ELECTRON_PID" || true
ELECTRON_PID=""
ELECTRON_HAS_PROCESS_GROUP=0
EOF
chmod +x "$crashpad_test_dir/start.sh"
cat >"$crashpad_test_dir/electron" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash -c 'exec -a "$0/chrome_crashpad_handler" sleep 30' "$SCRIPT_DIR" &
echo "$!" >"$SCRIPT_DIR/crashpad.$$.pid"
sleep 30
EOF
chmod +x "$crashpad_test_dir/electron"

"$crashpad_test_dir/start.sh" &
launcher_one="$!"
for _ in $(seq 1 50); do
  [ -f "$crashpad_test_dir"/crashpad.*.pid ] && break
  sleep 0.1
done
"$crashpad_test_dir/start.sh" &
launcher_two="$!"
sleep 0.5
crashpad_before="$(pgrep -f "$crashpad_test_dir/chrome_crashpad_handler" | wc -l | tr -d ' ')"
kill "$launcher_one" 2>/dev/null || true
wait "$launcher_one" 2>/dev/null || true
sleep 0.5
crashpad_after_one="$(pgrep -f "$crashpad_test_dir/chrome_crashpad_handler" | wc -l | tr -d ' ')"
kill "$launcher_two" 2>/dev/null || true
wait "$launcher_two" 2>/dev/null || true
if [ "$crashpad_before" -lt 2 ]; then
  echo "crashpad ownership test did not create two fake crashpad handlers" >&2
  exit 1
fi
if [ "$crashpad_after_one" -lt 1 ]; then
  echo "terminating one launcher must not kill another launcher's crashpad handler" >&2
  exit 1
fi

if ! grep -q -- '--startup-background: #1e1e1e' bin/codex-linux; then
  echo "installer should apply the known Linux webview startup-background patch" >&2
  exit 1
fi

if ! grep -q 'MimeType=x-scheme-handler/codex;' templates/codex-for-linux.desktop.in; then
  echo "desktop launcher should register codex: deep links like the working community launcher" >&2
  exit 1
fi

if ! grep -q 'Exec=__EXEC__ %u' templates/codex-for-linux.desktop.in; then
  echo "desktop launcher Exec must accept the codex: URL it registers" >&2
  exit 1
fi

if ! grep -q 'update-desktop-database "$(dirname "$DESKTOP_FILE_PATH")"' bin/codex-linux; then
  echo "desktop install should refresh the desktop MIME database when available" >&2
  exit 1
fi

if ! grep -q 'xdg-mime default "$(basename "$DESKTOP_FILE_PATH")" x-scheme-handler/codex' bin/codex-linux; then
  echo "desktop install should register codex: links to the installed launcher when xdg-mime is available" >&2
  exit 1
fi

if ! grep -q -- '--filesystem=home' packaging/flatpak/com.bulkheados.CodexForLinux.yml; then
  echo "Flatpak manifest permission check could not find the home filesystem grant" >&2
  exit 1
fi

if ! grep -q 'home-directory access' README.md ||
   ! grep -q 'home-directory access' docs/packaging.md ||
   ! grep -q 'home-directory access' packaging/flatpak/com.bulkheados.CodexForLinux.metainfo.xml ||
   ! grep -q 'home-directory access' scripts/package-flatpak-local.sh; then
  echo "Flatpak home access must be warned about in README, packaging docs, metadata, and package output" >&2
  exit 1
fi

for template in \
  .github/ISSUE_TEMPLATE/bug_report.yml \
  .github/ISSUE_TEMPLATE/crash_report.yml \
  .github/ISSUE_TEMPLATE/feature_compatibility.yml
do
  if ! grep -q 'diagnostics --json' "$template"; then
    echo "$template must ask for no-launch diagnostics evidence" >&2
    exit 1
  fi
done

node --input-type=module <<'NODE'
import fs from "node:fs";
import { parse } from "yaml";

const allowedTypes = new Set(["checkboxes", "dropdown", "input", "markdown", "textarea"]);
const files = fs.readdirSync(".github/ISSUE_TEMPLATE")
  .filter((name) => name.endsWith(".yml"))
  .map((name) => `.github/ISSUE_TEMPLATE/${name}`);

for (const file of files) {
  const data = parse(fs.readFileSync(file, "utf8"));

  if (file.endsWith("/config.yml")) {
    if (data.blank_issues_enabled !== false) {
      throw new Error(`${file}: blank issues must be disabled`);
    }
    if (!Array.isArray(data.contact_links)) {
      throw new Error(`${file}: contact_links must be an array`);
    }
    continue;
  }

  for (const key of ["name", "description", "title", "labels", "body"]) {
    if (!(key in data)) {
      throw new Error(`${file}: missing ${key}`);
    }
  }
  if (!Array.isArray(data.body)) {
    throw new Error(`${file}: body must be an array`);
  }

  const ids = new Set();
  data.body.forEach((item, index) => {
    if (!allowedTypes.has(item.type)) {
      throw new Error(`${file}: invalid body type ${JSON.stringify(item.type)}`);
    }
    if (!item.attributes || typeof item.attributes !== "object") {
      throw new Error(`${file}: item ${index} missing attributes`);
    }
    if (item.type !== "markdown") {
      if (!item.id) {
        throw new Error(`${file}: non-markdown item ${index} missing id`);
      }
      if (ids.has(item.id)) {
        throw new Error(`${file}: duplicate id ${item.id}`);
      }
      ids.add(item.id);
      if (!item.attributes.label) {
        throw new Error(`${file}: item ${item.id} missing label`);
      }
    }
    if (["checkboxes", "dropdown"].includes(item.type)) {
      if (!Array.isArray(item.attributes.options) || item.attributes.options.length === 0) {
        throw new Error(`${file}: item ${item.id || index} missing options`);
      }
    }
    if (item.validations && typeof item.validations !== "object") {
      throw new Error(`${file}: validations must be a map`);
    }
  });
}
NODE

for term in tokens cookies "private prompts" "generated app files" "personal data"; do
  if ! grep -Rqi "$term" .github/ISSUE_TEMPLATE/*.yml CONTRIBUTING.md; then
    echo "public issue intake must warn about $term" >&2
    exit 1
  fi
done

if ! grep -Rqi 'DMGs' .github/ISSUE_TEMPLATE/*.yml CONTRIBUTING.md ||
   ! grep -Rqi 'app.asar' .github/ISSUE_TEMPLATE/*.yml CONTRIBUTING.md ||
   ! grep -Rqi 'screenshots' .github/ISSUE_TEMPLATE/*.yml CONTRIBUTING.md; then
  echo "public issue intake must warn about generated app bundles and screenshots with personal data" >&2
  exit 1
fi

if ! grep -q 'full coredumps' .github/ISSUE_TEMPLATE/crash_report.yml; then
  echo "crash issue template must forbid full coredump attachments" >&2
  exit 1
fi

if ! grep -q 'High memory usage' .github/ISSUE_TEMPLATE/crash_report.yml ||
   ! grep -q 'High inotify instance/watch usage' .github/ISSUE_TEMPLATE/crash_report.yml ||
   ! grep -q 'Process or inotify evidence' .github/ISSUE_TEMPLATE/crash_report.yml; then
  echo "crash issue template must capture memory, inotify, and process-leak evidence" >&2
  exit 1
fi

if ! grep -q 'blank_issues_enabled: false' .github/ISSUE_TEMPLATE/config.yml; then
  echo "GitHub issues should use structured templates for public safety" >&2
  exit 1
fi
