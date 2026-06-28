# Contributing

This repo is intentionally public-facing. Assume every change will be read by
Linux users, OpenAI users, packaging reviewers, and security-minded contributors.

## Rules

- Use Conventional Commits.
- Keep one logical change per commit.
- Do not commit generated runtimes, DMGs, extracted app bundles, `app.asar`,
  `node_modules`, logs, screenshots with personal data, or credentials.
- Update docs and KCS notes when behavior, install steps, packaging, or support
  knowledge changes.
- Add or update ADRs for non-obvious technical decisions.
- Prefer user-level installs and explicit commands over background services.
- Keep error messages actionable: what failed, why it matters, and what to run next.

## Development loop

```bash
npm test
```

Before opening a PR, also run:

```bash
bash bin/codex-linux doctor
bash scripts/qa-public-safety.sh
```

## DDD boundaries

Respect the bounded contexts in [docs/ddd/context-map.md](docs/ddd/context-map.md):

- upstream metadata detection
- local runtime build
- compatibility patching
- packaging/export
- support/docs

Do not make packaging code reach into patcher internals unless a public script or
documented file is the intended boundary.

## Support notes

When you learn something repeatable, update [docs/kcs/codex-linux-operations.md](docs/kcs/codex-linux-operations.md).

Use the GitHub issue forms for public reports:

- Bug report: install, update, launcher, packaging, or desktop integration bugs
- Crash or process leak: KWin crashes, Electron crashes, memory growth, orphaned
  helpers, or high inotify usage
- Feature compatibility: Appshots, Computer Use, Automations, browser, deep
  links, Flatpak, Discover, or Homebrew behavior

Ask reporters for `bash bin/codex-linux diagnostics --json` before requesting
logs. Do not ask for full coredumps, generated runtimes, DMGs, extracted app
bundles, `app.asar`, cookies, tokens, private prompts, or screenshots containing
personal data.

Good KCS entries include:

- symptom
- environment
- cause
- fix
- verification command
- whether the issue is upstream, local, or unknown

## Review checklist

- Does this avoid redistributing OpenAI-owned app bits?
- Does this avoid collecting or exposing user data?
- Does this keep install/update explicit?
- Does this work on Kubuntu-style Debian systems?
- Does this work on SteamOS/Arch-style systems?
- Does the user see a clear next step when something fails?
- Does `npm test` pass?
