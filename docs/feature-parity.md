# Feature Parity Notes

This project aims to make the official Codex desktop app usable on Linux without
redistributing OpenAI app binaries or pretending unsupported operating-system
features are supported.

Sources checked on 2026-06-28:

- Codex app quickstart: https://developers.openai.com/codex/quickstart
- Appshots: https://developers.openai.com/codex/appshots
- Computer Use: https://developers.openai.com/codex/app/computer-use
- Automations: https://developers.openai.com/codex/app/automations
- In-app browser: https://developers.openai.com/codex/app/browser
- Remote connections: https://developers.openai.com/codex/remote-connections
- Chronicle: https://developers.openai.com/codex/memories/chronicle

Reproducible source check:

```bash
npm run verify:openai-features -- --json
```

OpenAI's public quickstart currently lists the Codex app as available for macOS
and Windows, with Linux behind a notification path. This repository is
therefore a compatibility project, not a supported OpenAI Linux distribution.

## Current target

Meet or exceed the existing community Linux ports for the core desktop path:

```text
official DMG -> local extraction -> Linux native module rebuild
             -> Linux compatibility patching -> matching Electron runtime
             -> user-level desktop entry -> explicit update command
```

## Feature table

| Feature | Linux compatibility status | Notes |
|---|---|---|
| Core desktop shell | Targeted | Built from the official DMG and a matching Linux Electron runtime. |
| CLI handoff | Targeted | Launcher resolves an installed `codex` CLI without storing credentials. |
| Webview rendering | Targeted | Uses the same local webview port convention as prior community ports. |
| `codex:` deep links | Targeted | Desktop entries register `x-scheme-handler/codex`, refresh the MIME database, and set the user-level handler when supported. |
| Automations | Blocked on guarded KDE Wayland; best-effort elsewhere | Official docs require the local app to run at the scheduled time and access the chosen project path. The current KDE Wayland crash guard intentionally prevents launch on affected sessions, so automations are not usable there until a safe launch path is verified. Account gating remains upstream. |
| Appshots | Not claimed on Linux | Official docs describe Appshots as available in the Codex app on macOS. |
| Computer Use | Not claimed on Linux | Official docs describe Computer Use as available on macOS and Windows in supported regions. |
| In-app browser | Best-effort inherited | Official docs describe an in-app browser plugin. If the upstream Electron app enables it without OS APIs, this wrapper should not block it. |
| Remote/mobile host setup | Not claimed on Linux | Official docs describe Codex App hosts on macOS and Windows. |
| Chronicle | Not claimed on Linux | Official docs describe Chronicle as macOS-only and dependent on macOS Screen Recording and Accessibility permissions. |
| Other upstream UI | Best-effort inherited | If the feature is implemented in the upstream Electron app and is not gated by OS APIs, this wrapper should not block it. |

## Verification standard

A feature is marked `Targeted` only when this repository can install, launch, and
test the Linux path locally without copying personal data or app binaries into git.

A feature is marked `Best-effort inherited` when the wrapper should preserve the
upstream app behavior but the feature depends on OpenAI account state, remote
feature flags, or local GUI sign-in that this repository cannot safely automate.

A feature is marked `Blocked on guarded KDE Wayland` when upstream support may
exist but the local launcher correctly refuses to start on this desktop class
because prior launches caused KWin coredumps.

A feature is marked `Not claimed on Linux` when official docs currently describe
the feature as macOS-only or macOS/Windows-only. Do not market those features as
working on Linux until live verification proves they work in the port.

Run `bash bin/codex-linux diagnostics` for a host-specific check. It does not
start Electron, and it reports Appshots, Computer Use, Automations, KDE Wayland
launch safety, and Linux file-watch posture in one place.

Run `npm run verify:openai-features -- --json` before changing this table. That
command reads only official OpenAI developer docs, does not launch the app, and
fails closed if the docs no longer support the current Linux feature claims.

## User-experience bar

- Keep commands predictable and reversible.
- Prefer explicit status and diagnostics over hidden background services.
- Avoid persisting raw app logs by default.
- Do not require users to understand Electron internals to launch or update.
- Document gaps plainly so users do not waste time hunting for unsupported UI.
