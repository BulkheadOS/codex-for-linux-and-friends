# Accessibility and UX Notes

This repository owns the Linux compatibility surface around the upstream Codex
desktop app. It does not own the upstream app UI, account gating, or OpenAI
feature flags.

On KDE Wayland, GUI accessibility testing is currently blocked by the crash guard
because earlier launches caused KWin coredumps. Until a safe launch path is
verified, do not claim Linux WCAG conformance for the inherited upstream UI.

## Controlled surfaces

The accessibility and UX bar applies to the files and behavior this repository
controls:

- `codex-linux` command output
- `codex-linux diagnostics` and `codex-linux diagnostics --json`
- launcher refusal messages
- generated desktop entries and MIME handler metadata
- Flatpak and Discover metadata
- Homebrew/source install instructions
- KCS support notes
- GitHub issue forms

## WCAG 2.2 intent

For controlled surfaces, target WCAG 2.2 intent:

- Perceivable: important status is available as text, not color alone.
- Operable: every supported path has a shell command, desktop entry, or explicit
  recovery command.
- Understandable: failure messages state what happened, why it matters, and what
  to run next.
- Robust: diagnostics are also available as structured JSON for tools, support,
  and assistive workflows.

This is a target for the compatibility wrapper. It is not a claim that the
upstream Codex app UI has been audited on Linux.

## ADHD and AuDHD support

The project should reduce cognitive load by default:

- stable command names
- one diagnostic command before risky actions
- short sections with copyable commands
- no surprise background updater
- no hidden launch after a safety check fails
- explicit warnings before unsafe maintainer overrides
- count-only diagnostics instead of broad logs or personal data

The intended user outcome is confidence and capability: the user should know
whether the app can launch, what is blocked, and the safest next action.

## Product principles

The public promise should stay narrow and useful: local Linux compatibility
tooling for Kubuntu, SteamOS, and nearby desktops. Do not turn unsupported
upstream features into marketing claims.

Relevant working principles:

- Make users capable before trying to impress them.
- Reverse risk by keeping installs user-level, local, explicit, and removable.
- Prefer boring, reversible systems over clever launchers that surprise the
  desktop session.
- State feature gaps plainly so users do not waste time looking for UI that is
  blocked, upstream-gated, or not claimed on Linux.

## Privacy boundary

Public reports should not include tokens, cookies, private prompts, raw
credentials, generated runtime files, DMGs, extracted app bundles, `app.asar`,
full coredumps, or screenshots with personal data.

`codex-linux diagnostics --json` is designed to provide no-launch evidence using
counts and status fields. It should not require broad process listings, raw app
logs, or account-sensitive screenshots.

## Current QA status

Feature rows mirror the dated source review in
[Feature parity notes](feature-parity.md). Refresh that source review before
changing Appshots, Computer Use, Automations, or inherited upstream UI claims.

| Area | Status | Evidence |
|---|---|---|
| KDE Wayland launch | Blocked by design | Crash guard exits before Electron to avoid KWin restart risk. |
| Inotify pressure | Guarded | Diagnostics reports instance/watch usage and launch guard status. |
| Appshots | Not claimed on Linux | Official docs currently describe Appshots as macOS-only. |
| Computer Use | Not claimed on Linux | Official docs currently describe Computer Use as macOS/Windows-only. |
| Automations | Blocked on guarded KDE Wayland | Automations need the local app running; the crash guard prevents that session path. |
| Upstream app UI | Inherited and unverified | GUI testing is unsafe on the current KDE Wayland host. |
