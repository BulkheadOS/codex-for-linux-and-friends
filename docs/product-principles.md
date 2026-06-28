# Product Principles

This is a compatibility project, not a growth funnel.

## Make the user capable

Every command should leave the user knowing the next step. Error messages should
name the missing tool, the likely package name, and the command to retry.

## Lower cognitive load

- one main command: `codex-linux`
- explicit verbs: `doctor`, `install`, `update`, `launch`, `status`, `uninstall`
- no background updater
- no surprise global installs
- status is available in plain text and JSON

## Respect neurodivergent users

- stable command names
- predictable output
- no hidden state beyond documented XDG data/cache/state directories
- short sections in docs
- direct warnings before risky packaging choices

## Value before polish

The first value unit is "the app launches from a desktop entry." Packaging polish
is useful only if it preserves that path and does not create redistribution risk.

## Public work standard

Assume users will copy commands literally. Keep examples safe, reversible where
possible, and clear about what is local versus redistributable.

## Feature honesty

Meet or exceed existing Linux ports on the parts we can own: install, update,
launch, native modules, desktop integration, and safe diagnostics. Mark upstream
features as unsupported or best-effort when they depend on macOS, Windows, account
flags, or GUI state this project cannot verify.
