# Documentation Index

This directory holds the deeper reference material for Codex for Linux and
friends. The root [README](../README.md) is the public landing page and quick
start; this page routes readers to the right supporting document.

## Recommended reading paths

### New users

1. [Root README](../README.md) for scope, requirements, and install paths
2. [Feature parity notes](feature-parity.md) to understand which upstream Codex
   app features are targeted, inherited, blocked, or not claimed on Linux
3. [Security model](security-model.md) before relying on the local runtime or
   local Flatpak output

### Troubleshooting and support

1. Run `bash bin/codex-linux diagnostics`
2. Read [KCS: Codex for Linux Operations](kcs/codex-linux-operations.md)
3. Use the issue templates and include diagnostics output instead of raw logs,
   generated runtimes, DMGs, extracted app bundles, tokens, screenshots with
   personal data, or coredumps

### Maintainers and contributors

1. [Contributing](../CONTRIBUTING.md) for the development loop and PR checklist
2. [DDD context map](ddd/context-map.md) before changing cross-boundary behavior
3. [ADR directory](adr/) before changing non-obvious technical decisions
4. [Goal evidence matrix](goal-evidence.md) before updating public claims
5. [Accessibility and UX notes](accessibility-ux.md) before changing command
   output, diagnostics, launch refusal messages, issue forms, or packaging text

### Packaging reviewers

1. [Packaging notes](packaging.md) for Homebrew, local Flatpak, Discover, and
   public distribution constraints
2. [Security model](security-model.md) for trust boundaries and redistribution
   limits
3. [Goal evidence matrix](goal-evidence.md) for what the repository can prove now

## Documentation ownership

| Area | Primary docs | Notes |
|---|---|---|
| User install and daily use | [Root README](../README.md) | Keep the landing page short, actionable, and honest about scope. |
| Troubleshooting | [KCS operations](kcs/codex-linux-operations.md) | Add repeatable fixes with symptom, cause, fix, and verification. |
| Architecture boundaries | [DDD context map](ddd/context-map.md) | Keep packaging, runtime build, upstream metadata, and patching boundaries clear. |
| Security and privacy | [Security model](security-model.md) | Do not broaden public claims without evidence and review. |
| Feature claims | [Feature parity notes](feature-parity.md), [Goal evidence matrix](goal-evidence.md) | Refresh source checks before changing public feature language. |
| Packaging | [Packaging notes](packaging.md) | Local bundles are private unless redistribution rights or an approved `extra-data` path exists. |
| Accessibility and UX | [Accessibility and UX notes](accessibility-ux.md) | Controlled wrapper surfaces should stay text-first, predictable, and low-friction. |

## Change checklist

When a change affects install, launch, update, packaging, or support behavior:

- update the root README if the public quick-start path changes
- update KCS notes when the change creates repeatable support knowledge
- update the feature parity notes before changing Linux feature claims
- add or update an ADR for non-obvious technical decisions
- run `npm test` and `bash scripts/qa-public-safety.sh`
- avoid committing generated runtimes, DMGs, extracted app bundles, `app.asar`,
  credentials, tokens, logs, private prompts, coredumps, or screenshots with
  personal data
