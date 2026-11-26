# Security Policy

## Scope

This repo manages personal dotfiles and configuration. It does NOT run production services.

## Key rules

- **Never commit secrets.** Use `private_*` prefix for any file containing credentials.
- `.chezmoiignore` uses gitignore semantics only — it does NOT redact secrets from tracking.
- GPG configuration lives in `private_dot_gnupg/`. Those files are tracked because they contain no secrets. `private_` does not stop chezmoi from applying them; it makes the installed `~/.gnupg` mode 0700.
- If a file should never leave this machine, prefix it `private_`.
- Template variables like `github_token` in `.chezmoi.toml.tmpl` must remain empty strings in version control. Set via environment variables or chezmoi's `promptStringOnce`.
- `gemini_api_key` is the same kind of secret: the template source never contains a key. `GEMINI_API_KEY` or `promptStringOnce` fills it locally. `private_dot_aicommits.tmpl` is tracked only because it has no key; `private_` makes the installed `~/.aicommits` mode 0600. `.config/gh/hosts.yml` is ignored because it holds the gh auth token.

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
