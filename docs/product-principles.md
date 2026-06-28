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
- visible guardrails before actions that can restart the desktop session
- copyable commands that do not require users to mentally reconstruct state

## Value before polish

The first value unit is "the app launches from a desktop entry." Packaging polish
is useful only if it preserves that path and does not create redistribution risk.

## Accessibility bar

The upstream app UI is not owned by this repository, but the local compatibility
surface is. For the files we do control:

- desktop entries must expose standard names, categories, icons, and registered
  URL handlers
- command output should be readable without color, animation, or timing-sensitive
  cues
- docs should use short headings, concrete commands, and recovery steps
- risky states should fail closed with plain-language messages
- metadata for Flatpak/Discover should state the unofficial and experimental
  status without requiring users to inspect source code
- compatibility claims should meet WCAG 2.2 intent where this repo controls the
  user surface: perceivable text, operable command paths, understandable status,
  and predictable behavior

This project should be ADHD and AuDHD friendly by default: fewer choices per
step, stable labels, no surprise background work, and explicit next actions.

## Capability over churn

Make users more capable, not merely more impressed. A good change reduces the
time from "I have the upstream app" to "I understand what works on Linux, what is
unsafe, and what to do next."

Borrowed product lenses we use without pretending this is a sales funnel:

- clear promise: local Linux compatibility tooling, not official OpenAI support
- risk reversal: no app binary redistribution, user-level install, explicit
  update, and private generated runtime
- user capability: teach the failure mode and recovery command in every KCS note
- leadership restraint: prefer boring, reversible systems over clever launchers
  that surprise the user's desktop session

## Public work standard

Assume users will copy commands literally. Keep examples safe, reversible where
possible, and clear about what is local versus redistributable.

## Feature honesty

Meet or exceed existing Linux ports on the parts we can own: install, update,
launch, native modules, desktop integration, and safe diagnostics. Mark upstream
features as unsupported or best-effort when they depend on macOS, Windows, account
flags, or GUI state this project cannot verify.
