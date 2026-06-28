# Packaging

## Homebrew

Homebrew installs the builder/updater, not the OpenAI app:

```bash
brew tap BulkheadOS/codex-for-linux-and-friends https://github.com/BulkheadOS/codex-for-linux-and-friends
brew install --HEAD codex-for-linux
codex-linux install
```

The formula lives at [Formula/codex-for-linux.rb](../Formula/codex-for-linux.rb).

## Flatpak local bundle

Local Flatpak export packages a runtime that the user already generated on their
machine:

```bash
bash bin/codex-linux install
bash scripts/package-flatpak-local.sh
flatpak install --user dist/flatpak/codex-for-linux.flatpak
```

The output bundle can contain upstream app artifacts. Keep it private unless you
have redistribution rights.

## Discover

KDE Discover can manage installed Flatpak apps. The local path is:

1. build the local runtime
2. export the local Flatpak bundle
3. install it with `flatpak install --user`
4. manage launch/uninstall through Discover

## Flathub or public Discover distribution

Do not upload generated bundles from this repo.

A public Flatpak track needs one of:

- explicit permission to redistribute the upstream app artifacts, or
- an `extra-data` style flow with fixed size/checksum metadata and install-time
  download from the official upstream URL

That track must be reviewed separately because the current app requires native
module rebuilds and bundle patching. Public packaging should not silently perform
networked build steps at install time.
