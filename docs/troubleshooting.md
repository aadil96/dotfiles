# Troubleshooting

## Common issues with this dotfiles repo

### chezmoi apply does nothing

- Make sure you're in the correct source directory (`~/.local/share/chezmoi`)
- Run `chezmoi status` to see what would change before applying

### Template variables missing

- Check `.chezmoi.toml.tmpl` for available variables
- Use `{{ if ... }}{{ end }}` guards to handle missing values gracefully

### Private files not appearing

- Files prefixed `private_` are excluded from git — they only exist locally
- Do NOT copy `private_*` files to other machines

### Shell scripts failing on new machine

- Run `./setup` first — it bootstraps chezmoi and applies all dotfiles
- Verify `set -euo pipefail` is set in any new shell scripts you add

### chezmoi init fails with "not a directory"

- Ensure the source directory exists: `~/.local/share/chezmoi`
- If cloning fresh: `chezmoi init --apply https://github.com/aadil/dotfiles.git`

### mise install fails

- Check `dot_config/mise/mise.toml` for pinned versions
- Run `mise trust` on the config file first
- Try `mise install --force` to retry failed installations

### Brewfile not applying

- Run `brew bundle --file ~/.config/brew/Brewfile`
- The chezmoiscript `run_onchange_after_install_brew.sh.tmpl` triggers on Brewfile changes

### Tailscale not connecting

- `.chezmoiscripts/run_once_after_install_tailscale.sh.tmpl` handles install + auth
- If no auth key set, run manually: `tailscale up --authkey=<key> --accept-routes --ssh`
- Run once only — delete chezmoi state to re-trigger

### CI failures (ShellCheck)

- ShellCheck runs on all `*.sh` files in PRs
- Fix shellcheck warnings before merging

### markdownlint failures

- Config in `.markdownlint.yaml`
- Run locally: `markdownlint '**/*.md' --ignore .opencode/node_modules`

### chezmoi external resources not refreshing

- Run `chezmoi apply --refresh-externals` to force refresh
- External resources defined in `.chezmoiexternal.toml`

### Dev Container not building

- Dockerfile uses `mcr.microsoft.com/devcontainers/base:debian-13`
- Ensure Docker is running and has network access
