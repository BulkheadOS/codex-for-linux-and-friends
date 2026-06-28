# Security Policy

## Supported scope

This repository supports the compatibility tooling in this repo. It does not
support or audit the proprietary upstream Codex app.

## Reporting

Open a GitHub security advisory or private issue with:

- affected command or file
- operating system and architecture
- reproduction steps
- expected behavior
- actual behavior
- whether generated files, logs, or personal data are involved

Do not paste tokens, credentials, cookies, private prompts, or raw account data.

## Security design

- no app binary redistribution
- no credentials stored by this project
- user-level install by default
- no root requirement for the generated runtime
- no background updater service
- local launcher diagnostics only by default
- raw app stdout/stderr is not persisted by this wrapper
- explicit `install`, `update`, `launch`, and `uninstall` commands

## Generated files

Generated runtime directories and local Flatpak bundles may contain upstream app
artifacts. Treat them as private local files unless you have redistribution rights.
