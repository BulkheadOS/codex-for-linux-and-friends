# ADR 0002: Update by Explicit Rebuild

Status: Accepted

## Context

The upstream app can change without notice. A background updater would be opaque
and could fail while the user is not watching.

## Decision

Use explicit updates:

```bash
codex-linux update
```

The updater compares official upstream metadata and rebuilds the local runtime
when the source changes.

## Consequences

- no daemon or startup agent
- easier troubleshooting
- users control when bandwidth and rebuild time are spent
- updates depend on upstream headers and are not a cryptographic integrity proof
