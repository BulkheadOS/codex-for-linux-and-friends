# Goal Evidence Matrix

This matrix tracks what the public repository can prove now, what it deliberately
does not claim, and what still needs live verification outside this repository.

Date of this evidence pass: 2026-06-29.

## Evidence classes

- `Proven`: current repo files, commands, or live probes directly verify the
  requirement.
- `Guarded`: the safe behavior is to refuse or avoid an unsafe path.
- `External observed`: a live service outside this repository was probed during
  this pass, but the result is not repo-proven and can drift.
- `Incomplete`: the requirement is not proven yet.

## Repository scope

| Requirement | Status | Evidence |
|---|---|---|
| Work only in the Codex Linux app repo | Proven for this evidence pass | This matrix and related checks are scoped to `BulkheadOS/codex-for-linux-and-friends`; Pobal-os is outside this repo and is not used as evidence here. |
| Public unofficial posture | Proven | `README.md` states the project is not supported, endorsed, reviewed, or maintained by OpenAI. |
| MIT tooling only, no OpenAI binary redistribution | Proven | `README.md`, `LICENSE`, ADR 0001, and `scripts/qa-public-safety.sh` enforce no committed DMGs, extracted app bundles, generated runtimes, `app.asar`, credentials, tokens, or user data. |
| DDD and KCS discipline | Proven | `docs/ddd/context-map.md`, `docs/kcs/codex-linux-operations.md`, ADRs, and README project discipline section are present. |
| Homebrew, Flatpak, and Discover path | Proven | `Formula/codex-for-linux.rb`, `packaging/flatpak/*`, `scripts/package-flatpak-local.sh`, `docs/packaging.md`, and README install sections document the packaging paths and redistribution limits. |
| Keep current with upstream Codex app releases | Proven for explicit rebuild path | `codex-linux update` compares upstream URL, ETag, Last-Modified, and Content-Length, then rebuilds the local runtime. It is explicit, not a background updater. |

## Runtime safety

| Requirement | Status | Evidence |
|---|---|---|
| Avoid KWin hard crashes on KDE Wayland | Guarded | Installed launcher and `codex-linux launch` exit before Electron on KDE Wayland unless an unsafe maintainer override is set. |
| Avoid process leaks | Proven by no-launch diagnostics | `codex-linux diagnostics --json` reports `electron=0`, `crashpad=0`, `webviewServer=0`, and webview port `5175` closed on the guarded host. |
| Capture memory-leak evidence safely | Proven for no-launch diagnostics | `codex-linux diagnostics --json` reports aggregate Codex-related `runtimeHealth.memory` counts and RSS totals without publishing raw process command lines, local paths, or project names. |
| Avoid high file-watch pressure failures | Proven | Diagnostics reports inotify instance/watch usage and the launcher refuses when usage reaches the configured guard threshold. |
| No GUI launch during unsafe QA | Guarded | Current KDE Wayland host is a no-launch test environment because earlier launches caused KWin coredumps. |

## Accessibility and UX

| Requirement | Status | Evidence |
|---|---|---|
| ADHD and AuDHD friendly wrapper surface | Proven for controlled surfaces | `docs/product-principles.md` and `docs/accessibility-ux.md` require stable command names, one diagnostics path, short docs, no surprise background work, and explicit next actions. |
| WCAG 2.2 or higher | Guarded | `docs/accessibility-ux.md` targets WCAG 2.2 intent only for controlled wrapper surfaces. It explicitly does not claim audited Linux WCAG conformance for the inherited upstream app UI. |
| A11y public intake | Proven | `.github/ISSUE_TEMPLATE/accessibility_report.yml` captures keyboard/focus, screen reader, contrast, motion/timing, cognitive load, ADHD/AuDHD, and docs/support-flow issues with diagnostics and privacy warnings. |
| Upstream app UI accessibility | Incomplete | GUI testing is blocked on this KDE Wayland host until a safe launch path exists. |

## Upstream Codex app features

Reproducible official-docs check:

```bash
npm run verify:openai-features -- --json
```

The check reads only `developers.openai.com` pages, does not launch the app, and
fails closed if official docs no longer support the current Linux feature
claims.

| Requirement | Status | Evidence |
|---|---|---|
| Appshots | Incomplete / not claimed on Linux | `npm run verify:openai-features -- --json` reports `appshots.status=not-claimed-on-linux` from official docs currently describing Appshots as macOS-only. |
| Computer Use | Incomplete / not claimed on Linux | `npm run verify:openai-features -- --json` reports `computer-use.status=not-claimed-on-linux` from official docs currently describing Computer Use as macOS/Windows-only. |
| Automations | Guarded on KDE Wayland; incomplete elsewhere | `npm run verify:openai-features -- --json` reports `automations.status=requires-local-running-app`; local diagnostics show the crash guard blocks the current KDE Wayland session. |
| Remote/mobile host setup | Incomplete / not claimed on Linux | `npm run verify:openai-features -- --json` reports `remote-mobile-hosts.status=not-claimed-on-linux` from official docs currently describing Codex App hosts on macOS and Windows. |
| Chronicle | Incomplete / not claimed on Linux | `npm run verify:openai-features -- --json` reports `chronicle.status=not-claimed-on-linux` from official docs currently describing Chronicle as macOS-only with macOS Screen Recording and Accessibility permissions. |
| Other inherited app features | Incomplete unless live-tested | Features that depend on account flags, remote state, or GUI sign-in need a safe desktop session before this repo can claim them. |

## Fediverse profile evidence

These checks are external to this repo and can drift. They are recorded only as
dated observations because ElectricTown and Coolock Village profile visibility
was checked during this pass without syncing personal data into the Codex Linux
repository.

External observations are not repo-proven. Re-run the probes before making a
current public claim.

Reproducible check:

```bash
npm run verify:fediverse -- --json
npm run verify:fediverse -- --strict-mastodon --json
npm run verify:fediverse:mastodon-org -- --json
```

The default check exits nonzero only when direct WebFinger, actor, or icon checks
fail. `--strict-mastodon` also fails on remote Mastodon cache mismatches, which
is the expected current result until Coolock's remote cached `acct` matches
`coolockvillage@coolockvillage.ie`.

The `verify:fediverse:mastodon-org` check is the strict gate for the requested
`mastodon.org` path. It must exit `0` before this repository can claim that the
profiles are visible from that specific third-party Mastodon surface.

| Profile | Status | Evidence |
|---|---|---|
| `@coolockvillage@coolockvillage.ie` WebFinger | External observed | `npm run verify:fediverse -- --json` reported `webfinger.status=pass`, subject `acct:coolockvillage@coolockvillage.ie`, and ActivityPub actor/profile-page links during this pass. |
| `@coolockvillage@coolockvillage.ie` actor/icon | External observed | `npm run verify:fediverse -- --json` reported organization actor data with name `Coolock Village`, summary, inbox/outbox, public key, icon URL `https://coolockvillage.ie/images/coolock_village_logo.png`, and `icon.status=pass` during this pass. |
| `@electrictown@electrictown.ie` WebFinger | External observed | `npm run verify:fediverse -- --json` reported `webfinger.status=pass`, subject `acct:electrictown@electrictown.ie`, and ActivityPub actor/profile-page links during this pass. |
| `@electrictown@electrictown.ie` actor/icon | External observed | `npm run verify:fediverse -- --json` reported organization actor data with name `ElectricTown`, summary, inbox/outbox, public key, icon URL `https://electrictown.ie/icon-512.png`, and `icon.status=pass` during this pass. |
| `@electrictown@electrictown.ie` Mastodon instance search | External observed | Unauthenticated `mastodon.social` search without remote resolution returned an account with matching `acct`, display name `ElectricTown`, enriched fields, and cached avatar/header URLs during this pass. |
| `@coolockvillage@coolockvillage.ie` Mastodon instance search | Incomplete | `npm run verify:fediverse -- --strict-mastodon --json` failed as expected because unauthenticated `mastodon.social` search returned a visible Coolock Village account with enriched fields and cached avatar/header URLs, but the cached `acct` was `Dublin@coolockvillage.ie`; exact handle consistency is not proven. |
| `mastodon.org` direct verification | Incomplete | `npm run verify:fediverse:mastodon-org -- --json` and direct `curl` probes to `mastodon.org` failed with a TLS internal-error alert in this environment, so the requested `mastodon.org` UI/search path was not captured. |
| Search from a third-party Mastodon UI | Incomplete | WebFinger, actor documents, and `mastodon.social` search were observed to expose federation surfaces, but a browser-visible search from the requested `mastodon.org` UI has not been captured in this repository. |

## Completion rule

Do not mark the full goal complete until:

1. `codex-linux diagnostics --json` reports `session-clear` on the target host,
   or a documented launch guard is intentionally accepted as the correct
   target-host behavior.
2. GUI feature checks are run from a desktop session that does not crash KWin.
3. Appshots, Computer Use, Automations, and upstream app UI claims are updated
   only with live evidence and dated source review.
4. Fediverse profile search is verified from the requested third-party Mastodon
   UI, and remote Mastodon caches show the expected handles and profile icons.
5. No generated runtime, DMG, app bundle, `app.asar`, token, cookie, private
   prompt, full coredump, or personal screenshot is committed.
