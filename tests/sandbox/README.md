# Sandbox install verification (`tests/sandbox/`)

Disposable-container verification for the portable installer
(`sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply ...`).
All tests run inside throwaway Docker containers — **never on the host**.

## Quick start

```sh
tests/sandbox/run.sh                  # all four distros, fast lanes
tests/sandbox/run.sh --distro ubuntu  # single distro
tests/sandbox/run.sh --full           # full mise-install lane (slow)
tests/sandbox/run.sh --interactive    # also run the pty interactive suite
```

Requires a reachable Docker daemon (`docker version`). The driver:

1. Builds a read-only source copy with `git archive HEAD` (exactly the revision CI
   tests — candidate-checkout mode) and mounts `${TMP}:/repo:ro`.
2. Builds one sandbox image per distro from `tests/sandbox/<distro>/Dockerfile`.
3. Runs each in-container suite via
   `docker run --rm -v $TMP:/repo:ro dotfiles-sandbox:<distro> <suites...>`.
4. Aggregates `PASS:`/`FAIL:` lines into a per-distro summary table and exits
   non-zero on any failure.

`SANDBOX_SOURCE=worktree tests/sandbox/run.sh` archives the working tree instead
of `HEAD` (useful for pre-commit local runs of uncommitted changes; CI always
uses `HEAD`). After the feature branch merges, `aadil96/dotfiles` carries the
same code and the suite also covers the documented GitHub command
(`INSTALL_SOURCE=github`) — until then candidate-checkout is the tested path.

## Layout

```text
tests/sandbox/
  README.md
  run.sh                   # host driver (bash; only ever talks to Docker)
  macos-run.sh             # native core-path verification for the macOS CI runner
  common/
    assert.sh              # assertion + run helpers (sourced by suites)
    entrypoint.sh          # image ENTRYPOINT: runs the requested suites
    install-test.sh        # unattended install, verify, rerun/idempotency
    interactive-test.sh    # pty-driven fresh interactive install
    negative-tests.sh      # missing identity, no-sudo, conflict, XDG, no systemd
    mock-tests.sh          # service opt-in via command stubs (NO real enrollment)
  ubuntu/Dockerfile  debian/Dockerfile  fedora/Dockerfile  arch/Dockerfile
```

Every image creates (as root): `tester` (uid 1000, passwordless sudo),
`nosudo` (uid 1001, no sudo), installs `sudo curl git ca-certificates
util-linux python3` via the native package manager, sets `HOME=/home/tester`,
and runs the suites as its entrypoint. `ubuntu:24.04`, `debian:13`,
`fedora:41`, `archlinux:latest` are the base images.

## Coverage matrix

| Lane | Distro | install-test | negative | mock | interactive |
| --- | --- | :-: | :-: | :-: | :-: |
| default (fast) | ubuntu/debian/fedora/arch | ✅ | ✅ | ✅ | — |
| `--full` | all (CI: ubuntu) | ✅ full mise | ✅ | ✅ | — |
| `--interactive` | all | ✅ | ✅ | ✅ | ✅ |
| macOS runner (`macos-run.sh`) | macOS-14 | core path | — | — | — |

Verified per install (install-test.sh):

- unattended and interactive (pty) installs complete
- git `user.name`/`user.email` persist; no git signing without `GPG_KEY`
- `~/.local/bin/mise` resolves; full lane checks `mise which`
- `zsh -ic true` and `bash -ic true` start without rc-file errors
- plain containers: no systemd units, no tailscale, gpg-preset skip logged
- rerun exits 0 and `chezmoi diff --exclude=scripts` reports no managed-file differences (script targets of plain `run_before_`/`run_after_` hooks are run-but-not-materialized in chezmoi v2.72 and would otherwise show as perpetual new files)

Negative paths (negative-tests.sh):

- missing identity fails (non-zero, actionable message)
- unavailable sudo fails or completes-with-exclusions — never silent success
- pre-existing `~/.zshrc` conflict: the pre-apply guard refuses overwrite —
  unattended runs exit 1 with the file list, interactive runs prompt
  per-file `[y/N]`; the sentinel is never silently overwritten
- custom `XDG_CONFIG_HOME`: chezmoi's own config lands under the XDG dir,
  while `dot_config/**` maps to the fixed `$HOME/.config` — the brew hook reads
  the chezmoi-mapped Brewfile there (not the XDG dir)
- absent systemd/absent GPG: install completes, no units, no signing

Service opt-ins (mock-tests.sh) use PATH stubs only: fake `cat` reports systemd
as PID 1, fake `systemctl`/`sudo`/`tailscale`/`gpg` record invocations. Asserts:

- `TAILSCALE_AUTHKEY` travels in the environment — never `--authkey=` in argv
- `--ssh` / `--accept-routes` appear only when `TAILSCALE_SSH` /
  `TAILSCALE_ACCEPT_ROUTES` are set
- gpg-preset service is enabled only when the key is locally available

## Conflict behavior (shipped)

The installer ships a pre-apply guard (`run_before_00-conflicts.sh.tmpl`) that
stops instead of overwriting. On an unattended run (non-TTY or
`DOTFILES_NONINTERACTIVE=1`) that would overwrite an existing file with
different content, it exits 1, prints the conflicting file list, and leaves the
recovery hint ("Move or back up the file(s) above, then re-run the install.")
— the pre-existing files are never touched. Interactive installs prompt
per-file with `Overwrite <file>? [y/N]` and abort on any decline. The negative
test asserts the sentinel survives and the install exits non-zero.

## Notes / honest reporting

- **Missing identity message**: a fresh non-TTY run fails with
  `could not open a new TTY` (from the `promptStringOnce` saved-identity
  fallback in `.chezmoi.toml.tmpl`) rather than the explicit
  `DOTFILES_NONINTERACTIVE=1 requires GIT_USER_NAME...` message. The negative
  test accepts either (both are non-zero, non-silent failures). A follow-up
  could restructure the noninteractive branch (or pass `--no-tty` to the
  bootstrap) to always emit the explicit message.
- **Ignore patterns use target paths**: chezmoi v2.72 matches `.chezmoiignore`
  patterns against TARGET paths for `dot_`-prefixed directories — the systemd
  gate is `.config/systemd/**`, never `dot_config/systemd/**` (a source-form
  line silently ignores nothing and the units get applied). Verified
  empirically in the sandbox; template-checks guards the regression.
- **macOS**: `macos-run.sh` covers the core path on the disposable runner and
  reports `COVERAGE=macos-ok|macos-partial`. The runner (no passwordless sudo)
  cannot exercise the Homebrew-bootstrap-as-root branch.
- WSL is not covered by this harness (no disposable WSL images); it is reported
  as unverified per the plan.
- Network downloads happen inside the containers (bootstrap, package manager,
  chezmoi externals) — that is the point. Nothing from the host is mounted
  except the read-only repo copy.

## Security

- Never mounts host credentials, `~/.ssh`, `~/.config`, or the docker socket.
- The only host-to-container paths are `${TMP}:/repo:ro` plus env vars the
  driver sets (`DOTFILES_TEST_SKIP_PACKAGES`).
- Mock suite uses fake keys (`tskey-test-abc`, `FAKEFPR1234`) — no real
  Tailscale auth keys, no personal GPG material, no real enrollment.
