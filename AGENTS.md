# dotfiles — chezmoi-managed personal configuration

## What this repo is

Personal dotfiles for a zsh/bash + Neovim + mise setup. Managed by [chezmoi](https://chezmoi.io/). No build step — configuration files and templates only.

## Quick commands

```sh
./setup                              # Bootstrap: install chezmoi, apply dotfiles
chezmoi apply                        # Apply all dotfiles to $HOME
chezmoi update                       # Pull latest changes and re-apply
mise exec -- chezmoi apply           # Run via mise if chezmoi not on PATH
```

## Repo structure

| Prefix | Becomes | Notes |
|--------|---------|-------|
| `dot_*` | `$HOME/.filename` | Chezmoi auto-symlinks |
| `dot_config/` | `$HOME/.config/` | XDG config |
| `private_dot_*` | `$HOME/.filename` | Never tracked in git |
| `.chezmoiexternals/` | External resources | Mise, devpod, fonts |
| `.chezmoiscripts/` | Hook scripts | Run by chezmoi |
| `.devcontainer/` | VS Code Dev Container | - |

## Templates

- `.tmpl` extension = chezmoi Go template
- Supports `{{ .chezmoi.os }}`, `{{ lookPath "cmd" }}`
- Use `{{ if ... }}{{ end }}` guards for missing vars
- Template vars defined in `.chezmoi.toml.tmpl`

## Shell script standards

- Shebang: `#!/bin/bash` or `#!/usr/bin/env bash`
- Required: `set -euo pipefail`
- No bare `cd` — use `cd ... || exit` or pushd/popd

## Security

- `private_*` prefix = never commit to git
- GPG config in `private_dot_gnupg/` (not tracked)
- `.chezmoiignore` uses gitignore semantics only — does NOT redact secrets
- Never hardcode secrets; use `.chezmoi.toml.tmpl` env vars or prompts

## Key files to read

| Purpose | File |
|---------|------|
| chezmoi config + template vars | `.chezmoi.toml.tmpl` |
| Tool versions | `dot_config/mise/mise.toml` |
| OpenCode config | `.opencode/ocx.jsonc` |
| Shell config | `dot_bashrc.tmpl`, `dot_zshrc.tmpl` |
| Bootstrap logic | `setup` |
| Branch rules | `BRANCHING.md` |

## Git safety

- `main`/`master` protected — no direct commits/pushes/merges/rebases
- Feature branches for all changes: `feat/`, `fix/`, `chore/`
- See `BRANCHING.md` for full rules

## Documentation

- Update docs when behavior changes
- Add failure modes to `docs/troubleshooting.md`
- Don't create new docs unless genuinely useful

## Forbidden

- `make`, `npm install`, or any build command
- Editing `setup` (must stay runnable on any vanilla Linux/macOS)
- Hardcoded paths (use `$HOME`, `$XDG_CONFIG_HOME`, or chezmoi vars)
- Force push, rebase to protected branches, destructive git ops
