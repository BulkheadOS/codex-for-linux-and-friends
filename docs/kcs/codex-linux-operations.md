# KCS: Codex for Linux Operations

## Article: install fails before download

Symptom: `codex-linux doctor` reports missing commands.

Cause: the host is missing extraction, build, Node, or desktop-entry tooling.

Fix:

```bash
bash bin/codex-linux doctor
```

Install the packages printed by the command, then retry.

Verification:

```bash
bash bin/codex-linux doctor
```

## Article: upstream changed

Symptom: `codex-linux update` rebuilds the runtime.

Cause: upstream URL, ETag, Last-Modified, or Content-Length changed.

Fix: let the rebuild finish. The previous runtime remains in place until the new
runtime is ready. If patching fails, open an issue with the app version, Electron
version, failing command, and launcher diagnostics. Do not include tokens.

Verification:

```bash
bash bin/codex-linux status
```

## Article: `codex:` links do not open the app

Symptom: browser or terminal links using the `codex:` scheme do not open Codex
for Linux.

Cause: the desktop MIME database was not refreshed after installing or updating
the launcher, or another Codex compatibility launcher still owns the scheme.

Fix: reinstall the desktop entry and refresh the desktop database:

```bash
bash bin/codex-linux install
update-desktop-database "${XDG_DATA_HOME:-$HOME/.local/share}/applications" 2>/dev/null || true
xdg-mime default codex-for-linux.desktop x-scheme-handler/codex
```

Verification:

```bash
xdg-mime query default x-scheme-handler/codex
```

## Article: native rebuild looks for a missing compiler

Symptom: install fails while rebuilding `better-sqlite3` or `node-pty`; the log
mentions a compiler such as `g++-11: No such file or directory`.

Cause: `node-gyp` generated a native build using a compiler name that is not
installed on the host.

Fix: use the compiler installed by the system build tools, or provide explicit
compiler paths:

```bash
CODEX_LINUX_CC=/usr/bin/gcc CODEX_LINUX_CXX=/usr/bin/g++ bash bin/codex-linux install
```

Verification:

```bash
bash bin/codex-linux status
```

## Article: Appshots or Computer Use are missing on Linux

Symptom: the app launches, but Appshots or Computer Use controls are missing or
do not work on Linux.

Cause: the compatibility layer runs the desktop app shell on Linux, but official
Codex docs currently describe Appshots as macOS-only and Computer Use as
macOS/Windows-only.

Fix: do not treat this as an install failure. Use the core app, CLI, browser, and
automation paths that are available in your account. Track upstream docs and only
claim Linux support for these features after live verification.

Verification:

```bash
bash bin/codex-linux status
```

## Article: generated Flatpak bundle contains upstream app files

Symptom: `dist/flatpak/codex-for-linux.flatpak` exists after local packaging.

Cause: local Flatpak export packages the generated runtime.

Fix: keep the bundle private. Do not upload it unless you have redistribution rights.

Verification:

```bash
bash scripts/qa-public-safety.sh
```

## Article: app exits but webview server stays behind

Symptom: port 5175 remains busy after the app exits.

Cause: launcher process was killed in a way that skipped cleanup, or another
process is using the same port.

Fix: recent launchers continue when the port is already in use, because older
community launchers also bind this port. If the UI looks stale or mismatched,
close the older launcher and clear the stale pid file:

```bash
rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/codex-for-linux/webview.pid"
bash bin/codex-linux launch
```

Verification:

```bash
python3 - <<'PY'
import socket
s = socket.socket()
print(s.connect_ex(("127.0.0.1", 5175)))
s.close()
PY
```

## Article: use a local DMG offline

Symptom: upstream metadata lookup is unavailable, but a local DMG already exists.

Cause: the user is offline or the upstream HEAD request is temporarily failing.

Fix:

```bash
bash bin/codex-linux install --dmg /path/to/Codex.dmg
```

Verification:

```bash
bash bin/codex-linux status
```
