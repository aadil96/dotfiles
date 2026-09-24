# Troubleshooting

## Common issues with this dotfiles repo

### Install failed partway

- Just re-run the install one-liner; apply is idempotent and hooks skip completed work:

  ```sh
  sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply aadil96/dotfiles
  ```

- A first install can take several minutes while it downloads chezmoi, externals, and configured tools. The bootstrap may show little output while a download is in progress; allow it to finish and check network access if it stops progressing.
- If a prerequisite check failed, fix the underlying issue (missing package, unavailable sudo, no network) and re-run. The `run_once_before_00-prereqs` hook re-checks prerequisites and skips what is already satisfied.

### Existing home files stop the install (conflict guard)

- Before anything is written, the `run_before_00-conflicts` hook compares every managed target that already exists on disk with what the install would write. A differing file is a conflict: the install stops instead of silently overwriting your config.
- **Unattended** (`DOTFILES_NONINTERACTIVE=1` or non-interactive shell): the install aborts with `[portable-install] CONFLICT: refusing to overwrite N existing file(s)` followed by one line per path. Nothing was modified.
- **Interactive**: you are asked per file: `Overwrite <path>? [y/N]`. Answering `y`/`yes` proceeds (the file is then overwritten with your consent); anything else aborts.
- **Recovery**: move or back up the conflicting file(s) listed in the message (or merge your changes into the managed version), then re-run the install one-liner. Nothing is ever deleted or moved automatically; the guard only reports.
- Externals (mise, devpod, fonts, opencode config, zsh-autosuggestions) are excluded from the conflict scan — they are expected to refresh.

### Re-running a one-shot hook (run_once)

- One-shot hooks (`run_once_*`) run exactly once and skip on later applies. To force a hook to run again, reset chezmoi's script state:

  ```sh
  chezmoi state delete-bucket --bucket=scriptState
  ```

- **Warning:** this resets all script state, so it also re-triggers Tailscale enrollment (`run_onchange_after_03`). If you do not want to enroll, ensure `TAILSCALE_AUTHKEY` is unset before re-applying.

### dotdash service cannot find server.js

- Use the same `XDG_DATA_HOME` for the dashboard installer and `chezmoi apply`; the unit captures this path at apply time, defaulting to `$HOME/.local/share`.
- After moving the installation, reapply the unit, run `systemctl --user daemon-reload`, then `systemctl --user restart dotdash`.

### chezmoi apply does nothing

- Make sure you're in the correct source directory (`~/.local/share/chezmoi`)
- Run `chezmoi status` to see what would change before applying

### chezmoi warns: config file template has changed

- **Symptom:** every `chezmoi` invocation prints `chezmoi: warning: config file template has changed, run chezmoi init to regenerate config file` before its normal output.
- **Cause:** chezmoi re-renders `.chezmoi.toml.tmpl` on every run and compares it with the config template state saved at the last `chezmoi init`. The warning means the template changed since the config was last written, so `~/.config/chezmoi/chezmoi.toml` is stale and every run re-renders to something different. A common trigger: the template dropped a setting the old config still contains (for example the old `tailscale_authkey`), or `TAILSCALE_AUTHKEY` was persisted into the config by the legacy `setup` path.
- **Fix:** regenerate the config: `chezmoi init`. This re-renders `~/.config/chezmoi/chezmoi.toml` from the current template and refreshes chezmoi's saved config state. It touches no other home files and preserves saved prompt answers (`[data] name`/`email`/`gpg_signing_key`).
- **Note:** `chezmoi apply` does **not** regenerate the config file — the config is chezmoi's own, not a managed apply target. Only `chezmoi init` (or the install one-liner, which runs `init --apply`) rewrites it, so a stale config keeps warning until you run `chezmoi init`.

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

- If bootstrapping from a local clone, `./setup` still works but is the legacy path. Note that `./setup` writes any `TAILSCALE_AUTHKEY` into `$XDG_CONFIG_HOME/chezmoi/chezmoi.toml` (persisted), unlike the portable one-liner which keeps it env-only — prefer the one-liner; the next `chezmoi apply` re-render omits the key from the config; rotate the key if `./setup` was ever used with one.
- Verify `set -euo pipefail` is set in any new shell scripts you add
- If `chezmoi apply` asks `sudo` to reinstall `gpg-agent`, verify `gpgconf --list-dirs libexecdir`; `gpg-preset-passphrase` may already be installed there without being on `PATH`.

### chezmoi init fails with "not a directory"

- Ensure the source directory exists: `~/.local/share/chezmoi`
- If cloning fresh: `chezmoi init --apply https://github.com/aadil96/dotfiles.git`

### mise install fails

- Check `dot_config/mise/mise.toml` for pinned versions
- Run `mise trust` on the config file first
- Retry a failed installation per tool with `mise install <tool>` (or run `mise install` again); the mise binary lives at `~/.local/bin/mise`
- If the install is skipped entirely, check whether `DOTFILES_TEST_SKIP_PACKAGES=1` is set (test-only escape hatch, not for normal installs).

### Full sandbox lane fails after mise install

- The full Ubuntu lane installs every pinned tool once in `install-test.sh`; the negative and mock suites skip package installation because they test unrelated guard and hook behavior. Fast-lane success alone does not verify package installation.
- Each bootstrap has a 1,200-second timeout. The GitHub Actions job has a separate 75-minute limit. A completed install followed by rerun conflicts or API errors is a test failure, not an install timeout; inspect the first `FAIL:` line and the install log.
- `mise install` may add checksums and URLs for common platforms to `mise.lock`. Refresh the source lock with `mise -C dot_config/mise lock` and commit the generated metadata; this resolves lock entries without installing tools. See the [Mise lock command](https://mise.jdx.dev/cli/lock).
- If the full-lane lock assertion fails, compare `/home/tester/.config/mise/mise.lock` with `dot_config/mise/mise.lock`; the second install will stop at the conflict guard until the generated lock is committed.
- Sandbox suite scripts run as root, but installer commands run as `tester`. For lock checks, use `/home/tester` paths; `$HOME` in the suite script points to `/root`.
- For local diagnosis, run `SANDBOX_SOURCE=worktree tests/sandbox/run.sh --distro ubuntu --full`. Check the last `mise ... fetching` line and registry/network access when the bootstrap itself times out.
- GitHub API rate limits can block release lookups even after `mise install` has begun. Set `MISE_GITHUB_TOKEN` in the host environment before running the full sandbox; the runner passes it into Docker only when set. Never paste the token into command arguments or logs.

### Tool excluded during install

- Compatibility exclusions are reported, not hidden: install logs `[portable-install] EXCLUDED: <tool>: <reason>` for any tool skipped because the platform does not support it.
- Example: `vagrant` is excluded when absent from configured official repositories; third-party repos are not added automatically.
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
- Enrollment runs via the `run_onchange_after_03` hook, gated on systemd as PID 1. After fixing the auth key, re-trigger it: `chezmoi state delete-bucket --bucket=scriptState` (this also re-triggers other hooks) or change the hook file, then re-apply with `TAILSCALE_AUTHKEY` set (the key is read at runtime, never written to disk).
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
