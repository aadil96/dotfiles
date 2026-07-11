# Security Policy

## Scope

This repo manages personal dotfiles and configuration. It does NOT run production services.

## Key rules

- **Never commit secrets.** Use `private_*` prefix for any file containing credentials.
- `.chezmoiignore` uses gitignore semantics only — it does NOT redact secrets from tracking.
- GPG configuration lives in `private_dot_gnupg/` (not tracked in git by convention — chezmoi ignores `private_*`).
- If a file should never leave this machine, prefix it `private_`.
- Template variables like `github_token` in `.chezmoi.toml.tmpl` must remain empty strings in version control. Set via environment variables or chezmoi's `promptStringOnce`.

## External dependencies

- **chezmoi** — dotfile manager. Installed via setup script or existing package manager.
- **mise** — tool version manager. Tools pinned in `dot_config/mise/mise.toml`.
- **Homebrew** — package manager for macOS/Linux. Brewfile referenced from chezmoiscripts.

## CI security

- GitHub Actions CI runs ShellCheck + markdownlint only
- No secrets deployed in CI
- No production access from CI

## Reporting

Personal repo — issues/PRs for concerns. Not a supported product.
