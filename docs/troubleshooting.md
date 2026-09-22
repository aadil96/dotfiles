# Troubleshooting

## Common issues with this dotfiles repo

### Install failed partway

- Just re-run the install one-liner; apply is idempotent and hooks skip completed work:

  ```sh
  sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply aadil96/dotfiles
  ```

- If a prerequisite check failed, fix the underlying issue (missing package, unavailable sudo, no network) and re-run. The `run_once_before_00-prereqs` hook re-checks prerequisites and skips what is already satisfied.

### Re-running a one-shot hook (run_once)

- One-shot hooks (`run_once_*`) run exactly once and skip on later applies. To force a hook to run again, reset chezmoi's script state:

  ```sh
  chezmoi state delete-bucket --bucket=scriptState
  ```

- **Warning:** this resets all `run_once` tracking, so it also re-triggers Tailscale enrollment (`run_once_after_03`). If you do not want to enroll, ensure `TAILSCALE_AUTHKEY` is unset before re-applying.

### dotdash service cannot find server.js

- Use the same `XDG_DATA_HOME` for the dashboard installer and `chezmoi apply`; the unit captures this path at apply time, defaulting to `$HOME/.local/share`.
- After moving the installation, reapply the unit, run `systemctl --user daemon-reload`, then `systemctl --user restart dotdash`.

### chezmoi apply does nothing

- Make sure you're in the correct source directory (`~/.local/share/chezmoi`)
- Run `chezmoi status` to see what would change before applying

### Template variables missing

- Check `.chezmoi.toml.tmpl` for available variables
- Use `{{ if ... }}{{ end }}` guards to handle missing values gracefully

### Private files not appearing

- The `private_` prefix controls target file permissions (installed as 0600); it does **not** exclude files from Git.
- Whether a `private_*` file is tracked by Git is decided by `.gitignore` / `.chezmoiignore` patterns, not by the prefix. This repo's `.gitignore` lists `private_*`, so such files are kept out of Git.
- If a secret file is missing locally, the `.gitignore` pattern or the file itself changed — check `git status` (tracked status) and `chezmoi status` (installed status) before assuming the file was skipped.
- Long-term: do not rely on the `private_` prefix for secret management; keep secrets out of the repo entirely.

### Shell scripts failing on new machine

- Run the install one-liner first — it bootstraps chezmoi and applies all dotfiles:

  ```sh
  sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply aadil96/dotfiles
  ```

- If bootstrapping from a local clone, `./setup` still works but is the legacy path.
- Verify `set -euo pipefail` is set in any new shell scripts you add
- If `chezmoi apply` asks `sudo` to reinstall `gpg-agent`, verify `gpgconf --list-dirs libexecdir`; `gpg-preset-passphrase` may already be installed there without being on `PATH`.

### chezmoi init fails with "not a directory"

- Ensure the source directory exists: `~/.local/share/chezmoi`
- If cloning fresh: `chezmoi init --apply https://github.com/aadil96/dotfiles.git`

### mise install fails

- Check `dot_config/mise/mise.toml` for pinned versions
- Run `mise trust` on the config file first
- Retry a failed installation with `<mise-bin> install --force`; the mise binary lives at `~/.local/bin/mise`
- If the install is skipped entirely, check whether `DOTFILES_TEST_SKIP_PACKAGES=1` is set (test-only escape hatch, not for normal installs).

### Tool excluded during install

- Compatibility exclusions are reported, not hidden: install logs `[portable-install] EXCLUDED: <tool>: <reason>` for any tool skipped because the platform does not support it.
- Example: `vagrant` comes from native packages where available (Arch); on Debian/Ubuntu/Fedora it is excluded because third-party repos are not added automatically.
- Re-run the installer and inspect the log output if you expect a tool and do not see it.

### systemd units not installed (container/WSL)

- systemd units under `dot_config/systemd/**` are only installed when Linux has a working systemd service manager (`.chezmoiignore.tmpl` checks that PID 1 is systemd).
- Containers and WSL without systemd skip systemd units and service activation but still complete installation.
- Check with `ps -p 1 -o comm=`; if it is not `systemd`, units are intentionally skipped.

### Git signing not enabled

- Git signing is only enabled when a key is explicitly configured (`GPG_KEY` or saved config) and locally present.
- The gpg-preset systemd service only enables when `gpg --list-secret-keys` finds the configured key; otherwise the service is skipped.
- Set `GPG_KEY` at install time (or in saved config) and ensure the secret key exists locally, then re-apply.

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

- Homebrew is macOS-only in the portable install; the Brewfile formulas/casks are guarded by `if: OS.mac?` and do not run on Linux.
- Run `brew bundle --file ~/.config/brew/Brewfile`
- The brew hook (`run_onchange_after_00`) triggers on Brewfile changes

### Tailscale not connecting

- Tailscale enrollment is explicit opt-in: set `TAILSCALE_AUTHKEY` at install time to enroll. It is a runtime env var only — never persisted or written to generated files.
- Without `TAILSCALE_AUTHKEY`, the Tailscale binary is not installed and no enrollment happens.
- `TAILSCALE_SSH=1` and `TAILSCALE_ACCEPT_ROUTES=1` opt into remote SSH access / advertised routes on `tailscale up`; both are off by default.
- Enrollment runs via the `run_once_after_03` hook. After fixing the auth key, re-trigger it: `chezmoi state delete-bucket --bucket=scriptState` (this also re-triggers other `run_once` hooks).
- Nightly enrollments are intentionally not automatic — do not set remote SSH or accepted-routes flags unless you want them.

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