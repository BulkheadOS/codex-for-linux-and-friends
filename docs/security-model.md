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

## Update safety

`codex-linux update` compares upstream URL, ETag, Last-Modified, and Content-Length.
If those change, it rebuilds the local runtime. This is a freshness signal, not a
cryptographic guarantee.

The previous runtime remains in place until the replacement runtime is fully built
and moved into place.

Launcher diagnostics stay local. Raw app stdout/stderr is not persisted by this
wrapper by default.

Flatpak public distribution needs fixed checksums or an approved `extra-data` flow.
The local Flatpak exporter is for personal install only.
