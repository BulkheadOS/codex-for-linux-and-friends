# DDD Context Map

## Bounded contexts

### Upstream Metadata

Owns the official app source URLs and freshness signals. Public API:

- `lib/upstream-metadata.mjs`
- `.upstream/*.json`

It does not download or extract the app.

### Runtime Build

Owns dependency checks, DMG extraction, Electron runtime download, native module
rebuild, and local install layout. Public API:

- `bin/codex-linux install`
- `bin/codex-linux update`

It does not decide public redistribution rules.

### Compatibility Patching

Owns small, idempotent patches against extracted app contents. Public API:

- `src/patchers/codex-linux-patcher.mjs`

It should fail soft when upstream internals move.

### Packaging

Owns Homebrew formula, local Flatpak export, desktop metadata, and Discover notes.
Public API:

- `Formula/codex-for-linux.rb`
- `scripts/package-flatpak-local.sh`
- `packaging/flatpak/*`

It must not commit generated runtime artifacts.

### Support and KCS

Owns repeatable troubleshooting and decisions. Public API:

- `docs/kcs/*`
- `docs/adr/*`
- `docs/security-model.md`

## Dependency direction

```text
Support docs
    |
Packaging -> Runtime Build -> Upstream Metadata
    |              |
    |              v
    +-------> Compatibility Patching
```

Packaging can call runtime commands. Runtime build can call upstream metadata and
patching. Patching must not call packaging.
