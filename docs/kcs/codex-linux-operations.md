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

Fix:

```bash
rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/codex-for-linux/webview.pid"
CODEX_WEBVIEW_PORT=5176 bash bin/codex-linux launch
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
