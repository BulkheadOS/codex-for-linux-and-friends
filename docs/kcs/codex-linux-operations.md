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

Cause: the desktop entry must both register `x-scheme-handler/codex` and pass
the clicked URL through its `Exec` line with `%u`. The desktop MIME database
also has to be refreshed after installing or updating the launcher, and another
Codex compatibility launcher may still own the scheme.

Fix: reinstall the desktop entry and refresh the desktop database:

```bash
bash bin/codex-linux install
update-desktop-database "${XDG_DATA_HOME:-$HOME/.local/share}/applications" 2>/dev/null || true
xdg-mime default codex-for-linux.desktop x-scheme-handler/codex
```

Verification:

```bash
xdg-mime query default x-scheme-handler/codex
rg '^Exec=.*%u' "${XDG_DATA_HOME:-$HOME/.local/share}/applications/codex-for-linux.desktop"
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

## Article: scheduled automations do not run

Symptom: a Codex automation is scheduled, but nothing happens at the expected
time.

Cause: official Codex automation docs require the local app to be running and
able to access the selected project path. On KDE Wayland, this compatibility
launcher may refuse to start because the unsafe XWayland path has caused KWin
coredumps. In that guarded state, automations cannot run from this app instance.

Fix: first verify whether the launcher is blocked by the KWin guard. Do not
disable the guard on a normal desktop session just to test a schedule. Use a
known-safe desktop session, a disposable test session, or wait for a verified
safe launch path.

Verification:

```bash
XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE CODEX_CLI_PATH=/bin/true ~/.local/share/codex-for-linux/runtime/start.sh
```

If the command refuses to launch with the KWin crash-guard message, automations
are blocked by design on that session.

## Article: generated Flatpak bundle contains upstream app files

Symptom: `dist/flatpak/codex-for-linux.flatpak` exists after local packaging.

Cause: local Flatpak export packages the generated runtime.

Fix: keep the bundle private. Do not upload it unless you have redistribution rights.

Verification:

```bash
bash scripts/qa-public-safety.sh
```

## Article: KDE/KWin crashes or the desktop session restarts when the app opens

Symptom: opening Codex for Linux on KDE Plasma Wayland kills or restarts KWin,
Plasma, and other desktop processes.

Cause: the KDE Wayland compositor can crash when this Electron runtime is
started through the XWayland path. The observed crash log showed KWin receiving
an XCB `BadWindow` error for the `SHAPE` input extension immediately before the
KWin coredump. Treat this as a compositor-impacting crash risk, not as a normal
application crash.

Fix: reinstall or update to a launcher with the KDE Wayland crash guard. The
guard refuses to launch on KDE Wayland by default and writes the reason to the
launcher log. Do not use an older generated `start.sh` on KDE Wayland.

Maintainer-only testing can override the guard after saving work or moving to a
throwaway session:

```bash
CODEX_KDE_WAYLAND_ALLOW_UNSAFE=1 CODEX_OZONE_PLATFORM=wayland CODEX_WAYLAND_TEXT_INPUT=1 codex-linux launch
```

`CODEX_KWIN_ALLOW_UNSAFE=1` is accepted as a shorter alias.
The normal unsafe override still forces native Wayland; it does not permit
`CODEX_OZONE_PLATFORM=x11` on KDE Wayland.

Verification:

```bash
XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE CODEX_CLI_PATH=/bin/true ~/.local/share/codex-for-linux/runtime/start.sh
```

The command must refuse to launch and print the crash-guard message. It must not
start Electron.

## Article: composer has no caret and physical keyboard does not type

Symptom: the app opens and mouse clicks work, but the composer does not show a
caret and physical keyboard input does not appear.

Cause: forcing native Wayland flags can break text focus on some Linux desktop
environments. Non-KDE Wayland sessions still use the XWayland-compatible
Chromium path by default, matching the working community launchers. KDE Wayland
is guarded separately because the XWayland path has been observed to crash KWin.

Fix: reinstall or update to a launcher that defaults to
`CODEX_OZONE_PLATFORM=x11` on non-KDE Wayland sessions and patches Linux primary
windows onto the default titlebar path. Do not use the XWayland keyboard-focus
workaround on KDE Wayland unless the KWin crash guard has been deliberately
overridden for maintainer testing. To test native Wayland manually on a
controlled session:

```bash
CODEX_KDE_WAYLAND_ALLOW_UNSAFE=1 CODEX_OZONE_PLATFORM=wayland CODEX_WAYLAND_TEXT_INPUT=1 codex-linux launch
```

Verification:

```bash
ps -eo pid,cmd | rg 'electron .*--ozone-platform=x11'
```

Then click the composer and confirm a caret appears before typing. Skip this
runtime verification on KDE Wayland unless the crash guard is intentionally
overridden in a disposable session.

## Article: app exits but helper processes stay behind

Symptom: port 5175 remains busy after the app exits, or a Codex
`chrome_crashpad_handler` process remains after Electron is gone.

Cause: old launchers recorded a wrapper subshell PID for the local webview
server, or relied on a webview-only trap while Electron ran in the foreground.
Cleanup could miss either the child `python3 -m http.server` process or the
foreground Electron process. Electron can also leave its crashpad helper
orphaned when the launcher is terminated externally.

Fix: reinstall or update to a launcher that starts the webview server with
`exec`, starts Electron in its own process group, tracks Electron's PID, and
cleans up the Electron process group, Codex crashpad handlers, and webview
servers it started on exit. It must leave an already-running webview listener
alone so one app instance cannot tear down another instance's helper. Close
stale helpers from older builds after confirming they belong to Codex for
Linux:

```bash
ps -eo pid,cmd | rg 'codex-for-linux|python3 -m http.server 5175|chrome_crashpad_handler'
kill <pid>
```

Verification:

```bash
ps -eo pid,cmd | rg 'codex-for-linux|http.server 5175|chrome_crashpad_handler' || true
```

## Article: local webview server fails to start

Symptom: launch fails with `Failed to start local webview server on
127.0.0.1:5175`.

Cause: the default local webview port is unavailable, the webview directory is
missing, or the helper process failed before the port became reachable.

Fix: check the port owner and either close the stale process or choose another
port for this launch:

```bash
ss -ltnp 'sport = :5175'
CODEX_WEBVIEW_PORT=5176 codex-linux launch
```

Verification:

```bash
CODEX_WEBVIEW_PORT=5176 codex-linux launch
```

## Article: desktop warns that too many applications want to monitor files

Symptom: VS Code or the desktop environment warns that too many applications are
monitoring file changes. The warning may mention high inotify instance or watch
usage while Codex for Linux is open.

Cause: upstream recursive project watching is cheap on macOS, but on Linux it
can become many inotify watches for large workspaces. Monorepos with
`node_modules`, build output, caches, and package-level dependencies can consume
most of the default `fs.inotify.max_user_watches` limit.

Fix: rebuild with a patcher version that disables recursive `fs.watch` on Linux
by default. This keeps small `.git` metadata watchers but avoids recursively
watching every project path. If a user explicitly wants upstream recursive
watching and has raised their inotify limits, launch with:

```bash
CODEX_LINUX_RECURSIVE_WATCH=1 codex-linux launch
```

Verification:

```bash
sysctl fs.inotify.max_user_instances fs.inotify.max_user_watches
```

Then compare the app process watch count before and after restarting Codex for
Linux.

## Article: Linux editors are listed but detection logs `Unknown open target`

Symptom: the app logs `Failed to detect open target` with
`Unknown open target "vscode"` or another Linux editor target.

Cause: the main process and the `open-in` worker maintain separate target
registries. Linux targets must be patched into both places; patching only the
main bundle leaves worker-side `get-target-command` unable to resolve them.

Fix: rebuild with a patcher version that updates `.vite/build/worker.js` as
well as the main bundle.

Verification:

```bash
npm test
bash bin/codex-linux install
```

## Article: startup logs `MaxListenersExceededWarning` for `WebContents`

Symptom: startup logs
`Possible EventEmitter memory leak detected. 11 destroyed listeners added to [WebContents]`.

Cause: the desktop app registers more than ten expected cleanup listeners on
registered app `WebContents` during startup. On Linux this can trip Node's
default listener warning even when the listener count is bounded.

Fix: rebuild with a patcher version that raises finite listener limits on
registered app `WebContents` only. Existing `0` unlimited listener limits must
stay unlimited.

Verification:

```bash
npm test
bash bin/codex-linux install
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
