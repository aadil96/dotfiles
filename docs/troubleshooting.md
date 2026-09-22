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
- If `chezmoi apply` asks `sudo` to reinstall `gpg-agent`, verify `gpgconf --list-dirs libexecdir`; `gpg-preset-passphrase` may already be installed there without being on `PATH`.

### chezmoi init fails with "not a directory"

- Ensure the source directory exists: `~/.local/share/chezmoi`
- If cloning fresh: `chezmoi init --apply https://github.com/aadil/dotfiles.git`

### mise install fails

- Check `dot_config/mise/mise.toml` for pinned versions
- Run `mise trust` on the config file first
- Try `mise install --force` to retry failed installations

### `opencode` still launches OpenCode v1

- Stable OpenCode v2 comes from `npm:@opencode/cli`, pinned to `2.0.14`. It provides `opencode` and the compatibility command `opencode2`.
- Remove the legacy `github:anomalyco/opencode` tool entry from mise config and lockfile so v1 cannot take precedence on `PATH`.
- Apply the mise config and lockfile, run `mise install npm:@opencode/cli@2.0.14`, then open a new terminal. Verify with `mise which opencode` and `opencode --version`.
- Keep `allow_builds = ["@opencode/cli"]`; the package's postinstall script selects the platform binary.
- V2 zsh completion uses `opencode --completions zsh`; remove the old v1 yargs completion block when migrating.

### agentmemory appears to lose memories

- Do not delete `$HOME/data/state_store.db`; it contains the persistent observations and memories.
- Verify the selected version: `mise which agentmemory` should resolve to `@agentmemory/agentmemory/0.9.28`.
- Verify the service: `systemctl --user status agentmemory.service`; it should use agentmemory `0.9.28` and its pinned iii engine `0.11.2`.
- If mise falls back to `0.9.18`, update both `~/.config/mise/mise.lock` and the chezmoi source lockfile, then restart: `systemctl --user restart agentmemory.service`.
- The standalone `~/.local/bin/iii` binary is not required. Agentmemory uses `~/.agentmemory/bin/iii` at `0.11.2`.
- Confirm the service and dashboard: `curl -fsS http://localhost:3111/agentmemory/livez` and `curl -fsS http://localhost:3113/ >/dev/null`.

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
- Symptom: `mise ERROR mise version X.Y.Z is required, but you are using A.B.C` where `A.B.C < X.Y.Z`. The chezmoi external cached an older `mise-latest` artifact and overwrote a newer mise binary during apply. Fix: `chezmoi apply --refresh-externals` (forces re-download of all externals), or run `mise self-update` to let mise manage its own binary again.

### Dev Container not building

- Dockerfile uses `mcr.microsoft.com/devcontainers/base:debian-13`
- Ensure Docker is running and has network access

### Agent commits hang on GPG passphrase prompt

- **Cause**: `commit.gpgsign=true` and `gpg-agent` cache expires → `pinentry-curses` seizes the TTY agent (opencode/codex) uses. Visible as a frozen commit.
- **Fix**: Ensure the preset script ran: `~/.local/bin/gpg-sign-preset`. Run it manually to verify.
- **If keyring locked** (e.g., headless/SSH before graphical login): `secret-tool lookup service gpg-signing keygrip <grip>` will fail. Log in graphically, or unlock gnome-keyring with `gnome-keyring-daemon --unlock`.
- **Verify signing works**: after preset, run `echo test | gpg --batch --sign -u C8B994F19E7D34D9` — should succeed with no prompt. Check `git log --show-signature` for "Good signature".
