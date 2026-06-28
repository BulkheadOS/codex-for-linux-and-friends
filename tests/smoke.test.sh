#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

tmp_launcher_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_launcher_dir"' EXIT

help_output="$(bin/codex-linux --help)"
case "$help_output" in
  *"Codex for Linux and friends"* ) ;;
  * ) echo "help output did not include product name" >&2; exit 1 ;;
esac

status_output="$(CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux status)"
case "$status_output" in
  *"Not installed."* ) ;;
  * ) echo "status output should report a missing install" >&2; exit 1 ;;
esac

json_output="$(CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux status --json)"
node -e 'const value = JSON.parse(process.argv[1]); if (value.installed !== false) process.exit(1)' "$json_output"

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
