# ADR 0003: Local Flatpak First

Status: Accepted

## Context

Users asked for Flatpak, Discover, and Brew paths. The generated runtime may
contain proprietary upstream app artifacts.

## Decision

Support a local Flatpak exporter and Homebrew builder install first. Do not publish
generated Flatpak bundles from this repo.

## Consequences

- Discover can manage the app after local Flatpak install
- the repo remains safe to publish
- Flathub requires a future `extra-data` or approved redistribution design
