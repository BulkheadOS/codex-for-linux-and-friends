# Security Model

## Goal

Make the compatibility layer useful without becoming a binary mirror, credential
collector, or privileged installer.

## Non-goals

- redistributing the OpenAI Codex app
- bypassing OpenAI authentication
- modifying OpenAI service behavior
- installing system services
- collecting telemetry
- storing API keys

## Trust boundaries

| Boundary | Owner | Rule |
|---|---|---|
| Official DMG URL | OpenAI | Fetch as upstream input only |
| Generated runtime | Local user | Keep private and user-owned |
| Compatibility scripts | This repo | MIT licensed, reviewed, tested |
| Codex credentials | OpenAI/user environment | Never read or copy directly |
| Packaging exports | Local user | Do not redistribute without rights |

## Local runtime trust

The generated runtime runs the upstream Electron app through a local
compatibility launcher. The launcher currently passes Electron `--no-sandbox`
and `--disable-gpu-sandbox` because this is a local compatibility path for a
proprietary app bundle, not a public sandboxed redistribution.

The local Flatpak manifest also grants home-directory access so Codex can open
the project paths the user selects. That is a deliberate local-trust tradeoff.
Any public Discover/Flathub track must use a separate reviewed manifest with
narrower filesystem permissions or a portal/per-path access design.

## Update safety

`codex-linux update` compares upstream URL, ETag, Last-Modified, and Content-Length
for the official Codex App DMG. If those change, it rebuilds the local runtime.
This is a freshness signal, not a cryptographic guarantee for the DMG.

The downloaded Electron Linux runtime is verified against Electron's published
`SHASUMS256.txt` before extraction.

The previous runtime remains in place until the replacement runtime is fully built
and moved into place.

Launcher diagnostics stay local. Raw app stdout/stderr is not persisted by this
wrapper by default.

Flatpak public distribution needs fixed checksums or an approved `extra-data`
flow for every upstream artifact, including the Codex App input. The local
Flatpak exporter is for personal install only.
