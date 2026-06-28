# ADR 0001: Do Not Redistribute OpenAI App Binaries

Status: Accepted

## Context

The Codex desktop app is distributed by OpenAI for supported platforms. This repo
is an unofficial Linux compatibility project.

## Decision

Do not commit, release, mirror, or publish the OpenAI DMG, extracted `.app`
bundle, `app.asar`, native modules, generated runtime, or generated Flatpak bundle.

The repo ships scripts, metadata, docs, tests, and local packaging helpers only.

## Consequences

- users build their own local runtime
- Homebrew can install the builder but not the app
- public Flatpak distribution needs separate legal and packaging review
- CI must avoid downloading or storing the app binary by default
