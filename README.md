# Codex for Linux and friends

Unofficial local Linux compatibility tooling for the OpenAI Codex desktop app.

This project makes the Codex desktop app usable on Kubuntu, SteamOS, Arch-style
systems, and nearby Linux desktops by building a private, user-level runtime from
the official upstream app.

## Status and scope

This project is not supported, endorsed, reviewed, or maintained by OpenAI.

It is unofficial, experimental, and subject to breaking at any time. OpenAI can
change the Codex app bundle, update feed, native modules, login flow, or desktop
behavior without notice.

This repository ships only MIT-licensed compatibility tooling. It does not
redistribute the OpenAI Codex app, a DMG, an extracted app bundle, `app.asar`,
credentials, tokens, or user data.

## What this repository provides

`codex-linux` is a local builder, launcher, updater, and diagnostics wrapper. It:

1. checks local dependencies
2. downloads the current official Codex App DMG, unless you pass `--dmg`
3. extracts the app bundle locally
4. rebuilds native modules for Linux/Electron
5. applies Linux compatibility patches
6. downloads a matching Electron Linux runtime
7. creates a private user-level runtime and desktop launcher
8. updates only when explicitly requested

The default path is local, user-owned, and reversible. There is no background
updater service.

## Requirements

Kubuntu, Ubuntu, Linux Mint:

```bash
sudo apt install coreutils curl unzip p7zip-full python3 build-essential desktop-file-utils
```

SteamOS, Arch, Manjaro:

```bash
sudo pacman -S --needed coreutils curl unzip p7zip python base-devel desktop-file-utils
```

You also need Node.js 20+ with `npm` and `npx`, plus an installed Codex CLI:

```bash
npm i -g @openai/codex
```

If your shell or Node toolchain points native builds at a missing compiler, set
the compiler explicitly:

```bash
CODEX_LINUX_CC=/usr/bin/gcc CODEX_LINUX_CXX=/usr/bin/g++ bash bin/codex-linux install
```

## Quick start from source

```bash
git clone https://github.com/BulkheadOS/codex-for-linux-and-friends.git
cd codex-for-linux-and-friends
bash bin/codex-linux doctor
bash bin/codex-linux install
bash bin/codex-linux launch
```

Use a DMG you already downloaded:

```bash
bash bin/codex-linux install --dmg /path/to/Codex.dmg
```

## Homebrew on Linux

```bash
brew tap BulkheadOS/codex-for-linux-and-friends https://github.com/BulkheadOS/codex-for-linux-and-friends
brew install --HEAD codex-for-linux
codex-linux install
```

The Homebrew formula installs the builder/updater only. It still builds your
private runtime locally from the official upstream app.

## Local Flatpak and Discover path

This repo supports a local Flatpak path for Discover-friendly desktop management:

```bash
bash bin/codex-linux install
bash scripts/package-flatpak-local.sh
flatpak install --user dist/flatpak/codex-for-linux.flatpak
```

KDE Discover can manage the installed Flatpak after it is installed.

Do not upload the generated bundle unless you have the rights to redistribute the
upstream app contents. The local Flatpak currently grants home-directory access
so Codex can open the projects you choose. Treat the generated bundle as a
private local install, not a public redistributable artifact.

Flathub or public Discover distribution needs a stricter `extra-data` packaging
track and clear redistribution approval. See [packaging notes](docs/packaging.md).

## Day-to-day commands

Start the app:

```bash
bash bin/codex-linux launch
```

Update the local runtime after upstream changes:

```bash
bash bin/codex-linux update
```

Check launch safety and feature availability without starting the app:

```bash
bash bin/codex-linux diagnostics
bash bin/codex-linux diagnostics --json
```

Run the public-safety check before publishing changes:

```bash
npm test
npm run qa:public
```

Refresh official OpenAI feature-support evidence before changing public claims:

```bash
npm run verify:openai-features -- --json
```

## Feature support expectations

This compatibility layer targets the core desktop shell, CLI handoff, webview
rendering, `codex:` links, explicit updates, and user-level desktop integration.

Some upstream features are deliberately not marketed as Linux-supported here. The
feature table in [Feature parity notes](docs/feature-parity.md) is the source of
truth for current claims. In particular, Appshots, Computer Use, Automations,
remote/mobile host setup, Chronicle, and inherited upstream UI behavior should
only be claimed after current source checks and live verification support the
claim.

On guarded KDE Wayland sessions, the launcher may refuse to start before Electron
opens because prior testing found a compositor-impacting KWin crash risk. Use
diagnostics first on those systems.

## Safety and privacy model

The public promise stays narrow:

- no OpenAI app binaries are committed
- no local config, tokens, or credentials are committed
- generated runtime files live under user data/cache directories
- logs stay local under the user's cache/state directories
- raw app stdout/stderr is not persisted by this wrapper by default
- install is user-level by default
- update is explicit: `codex-linux update`
- no background updater service is installed

See [Security model](docs/security-model.md) for trust boundaries,
redistribution limits, and public-packaging constraints.

## Documentation map

Start with [docs/README.md](docs/README.md) for the documentation index.

Key reference pages:

- [DDD context map](docs/ddd/context-map.md)
- [KCS support notes](docs/kcs/codex-linux-operations.md)
- [Security model](docs/security-model.md)
- [Feature parity notes](docs/feature-parity.md)
- [Packaging notes](docs/packaging.md)
- [Accessibility and UX notes](docs/accessibility-ux.md)
- [Goal evidence matrix](docs/goal-evidence.md)
- [Contributing](CONTRIBUTING.md)

## Project discipline

The repo uses:

- DDD-style bounded contexts for packaging, upstream detection, runtime build,
  compatibility patching, and support docs
- KCS notes for repeatable support and troubleshooting
- ADRs for non-obvious technical decisions
- Conventional Commits
- MIT license for this compatibility tooling only

Before opening a PR, run:

```bash
npm test
bash bin/codex-linux doctor
bash scripts/qa-public-safety.sh
```

## Prior art

This project was informed by community experiments around running the Codex macOS
app on Linux, including:

- `forsetius/codex-app-mint`
- `fvaha/New-Codex-App-Manjaro-Arch-Port`

See [NOTICE.md](NOTICE.md). This repository avoids copying unlicensed code and
keeps the default path local, user-level, and explicit.
