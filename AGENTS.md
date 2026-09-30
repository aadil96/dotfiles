# dotfiles — chezmoi-managed personal configuration

## What this repo is

Personal dotfiles for a zsh/bash + Neovim + mise setup. Managed by [chezmoi](https://chezmoi.io/). No build step — configuration files and templates only.

## Quick commands

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply aadil96/dotfiles   # Supported install entrypoint — keep working
./setup                              # Legacy Bootstrap (local clone; document, don't extend)
chezmoi apply                        # Apply all dotfiles to $HOME
chezmoi update                       # Pull latest changes and re-apply
mise exec -- chezmoi apply           # Run via mise if chezmoi not on PATH
tests/sandbox/run.sh                 # Disposable-container install verification (Docker; never on host)
```

## One-command install (invariant)

The curl one-liner above is the ONLY supported install path for new machines. `setup` is legacy and must not be the docs' default or be extended.

Any change to templates, hooks, `.chezmoiscripts/`, `.chezmoi.toml.tmpl`, `.chezmoiignore.tmpl`, shell rcs, or Brewfile/mise config MUST keep this install working. Breaking it is a merge blocker.

Invariants that must never regress:

- Unattended mode (`DOTFILES_NONINTERACTIVE=1`) never prompts and fails clearly when `GIT_USER_NAME`/`GIT_USER_EMAIL` are missing.
- Env resolution order: environment override → saved configuration → interactive prompt.
- `GPG_KEY`, `TAILSCALE_AUTHKEY` remain optional; absent means no activation. Tailscale credentials stay runtime-env-only — never persisted in config or embedded in generated scripts; never in argv (`TS_AUTHKEY` env).
- No force-overwrite: unattended installs stop on conflicting existing home files (conflict guard runs before apply); interactive installs prompt.
- Hooks keep phase order: conflict guard → prereqs → brew → mise → service activation.
- systemd units stay gated on Linux + working systemd (PID 1); containers/WSL without systemd still complete.
- `setup`, zsh login-shell, and package-manager rules unchanged.
- After any `.chezmoi.toml.tmpl` change, the on-disk config must be regenerated (`chezmoi init`) or every run warns `config file template has changed`; keep template changes deterministic (env/saved-state driven) so regeneration converges to a single render.

Before merging any change touching the above: run `tests/template-checks/check.sh` and (when Docker is available) `tests/sandbox/run.sh --distro ubuntu`; a breaking hook/config/env change without this verification is review-blocking.

## Repo structure

| Prefix                | Becomes                  | Notes                   |
| --------------------- | ------------------------ | ----------------------- |
| `dot_*`               | `$HOME/.filename`        | Chezmoi auto-symlinks   |
| `dot_config/`         | `$HOME/.config/`         | XDG config              |
| `private_dot_*`       | `$HOME/.filename`        | Never tracked in git    |
| `.chezmoiexternals/`  | External resources       | Mise, devpod, fonts     |
| `.chezmoiscripts/`    | Hook scripts             | Run by chezmoi          |
| `.devcontainer/`      | VS Code Dev Container    | -                       |

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
- GPG config in `dot_gnupg/`
- `.chezmoiignore` uses gitignore semantics only — does NOT redact secrets
- Never hardcode secrets; use `.chezmoi.toml.tmpl` env vars or prompts

## Key files to read

| Purpose | File | Notes |
| --------- | ------ | ----- |
| chezmoi config + template vars | `.chezmoi.toml.tmpl` | |
| Install contract + env vars | docs/portable-install-plan.md, README.md | One-command install invariants |
| Tool versions | `dot_config/mise/mise.toml` | |
| OpenCode config | `.opencode/ocx.jsonc` | |
| Shell config | `dot_bashrc.tmpl`, `dot_zshrc.tmpl` | |
| Bootstrap logic | `setup` | |
| Branch rules | `BRANCHING.md` | |
| GPG agent config | `dot_gnupg/gpg-agent.conf` | Allows preset passphrase |
| GPG crypto settings | `dot_gnupg/gpg.conf` | Digest/cipher preferences |
| GPG signing preset | `dot_local/bin/executable_gpg-sign-preset.tmpl` | Silent preset at login/shell start |
| GPG systemd service | `dot_config/systemd/user/gpg-sign-preset.service` | Presets passphrase at login |
| Sandbox install tests | `tests/sandbox/run.sh` | Disposable-container verification (Ubuntu/Debian/Fedora/Arch; Docker required) |

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
