# Codex for Linux and friends

Unofficial local Linux compatibility tooling for the OpenAI Codex desktop app.

I built this to make the Codex app usable on Kubuntu and SteamOS, then shaped it
so other Linux desktop users can try the same path without copying private files
around by hand.

## Not official

This project is not supported, endorsed, reviewed, or maintained by OpenAI.

It is unofficial, experimental, and subject to breaking at any time. OpenAI can
change the Codex app bundle, update feed, native modules, login flow, or desktop
behavior without notice. This repository ships only MIT-licensed compatibility
tooling. It does not redistribute the OpenAI Codex app, a DMG, an extracted app
bundle, `app.asar`, credentials, tokens, or user data.

## What it does

`codex-linux`:

1. checks local dependencies
2. downloads the current official Codex App DMG, unless you pass `--dmg`
3. extracts the app bundle locally
4. rebuilds native modules for Linux/Electron
5. applies Linux compatibility patches
6. downloads a matching Electron Linux runtime
7. creates a private user-level runtime and desktop launcher
8. updates by comparing upstream URL, ETag, Last-Modified, and Content-Length

## Install from source

```bash
git clone https://github.com/BulkheadOS/codex-for-linux-and-friends.git
cd codex-for-linux-and-friends
bash bin/codex-linux doctor
bash bin/codex-linux install
```

Start it:

```bash
bash bin/codex-linux launch
```

Update it:

```bash
bash bin/codex-linux update
```

Use a DMG you already downloaded:

```bash
bash bin/codex-linux install --dmg /path/to/Codex.dmg
```

## Install with Homebrew on Linux

```bash
brew tap BulkheadOS/codex-for-linux-and-friends https://github.com/BulkheadOS/codex-for-linux-and-friends
brew install --HEAD codex-for-linux
codex-linux install
```

The Homebrew formula installs the builder/updater only. It still builds your
private runtime locally from the official upstream app.

## Flatpak and Discover

This repo supports a local Flatpak path for Discover-friendly desktop management:

```bash
bash bin/codex-linux install
bash scripts/package-flatpak-local.sh
flatpak install --user dist/flatpak/codex-for-linux.flatpak
```

KDE Discover can manage the installed Flatpak after it is installed. Do not upload
the generated bundle unless you have the rights to redistribute the upstream app
contents.

Flathub or public Discover distribution needs a stricter `extra-data` packaging
track and clear redistribution approval. See [packaging notes](docs/packaging.md).

## Requirements

Kubuntu, Ubuntu, Linux Mint:

```bash
sudo apt install curl unzip p7zip-full python3 build-essential desktop-file-utils
```

SteamOS, Arch, Manjaro:

```bash
sudo pacman -S --needed curl unzip p7zip python base-devel desktop-file-utils
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

## Public safety model

- no OpenAI app binaries are committed
- no local config, tokens, or credentials are committed
- generated runtime files live under user data/cache directories
- logs stay local under the user's cache/state directories
- raw app stdout/stderr is not persisted by this wrapper by default
- install is user-level by default
- no background updater service is installed
- update is explicit: `codex-linux update`

Run the public-safety check before publishing changes:

```bash
npm test
```

## Project discipline

The repo uses:

- DDD-style bounded contexts for packaging, upstream detection, runtime build, and docs
- KCS notes for repeatable support and troubleshooting
- ADRs for non-obvious technical decisions
- Conventional Commits
- MIT license for this compatibility tooling only

Start with:

- [DDD context map](docs/ddd/context-map.md)
- [KCS support notes](docs/kcs/codex-linux-operations.md)
- [Security model](docs/security-model.md)
- [Feature parity notes](docs/feature-parity.md)
- [Contributing](CONTRIBUTING.md)

## Prior art

This project was informed by community experiments around running the Codex macOS
app on Linux, including:

- `forsetius/codex-app-mint`
- `fvaha/New-Codex-App-Manjaro-Arch-Port`

See [NOTICE.md](NOTICE.md). This repository avoids copying unlicensed code and
keeps the default path local, user-level, and explicit.
