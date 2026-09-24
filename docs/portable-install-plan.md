# One-command portable dotfiles install

Status: agreed implementation plan; implementation and sandbox tests pending.
Date: 2026-09-22.

## Summary

Use [chezmoi's native bootstrap](https://www.chezmoi.io/) as the supported entrypoint:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply aadil96/dotfiles
```

Install the full compatible toolset across Ubuntu/Debian, Fedora, Arch, macOS,
and WSL. Support interactive and unattended installation. Keep `setup`
unchanged; document its replacement.

## Implementation

- Make `.chezmoi.toml.tmpl` safe on empty machines: resolve environment
  overrides, then saved configuration, then interactive prompts. Missing
  required values in unattended mode fail clearly. SSH/container detection
  controls compatibility, not whether prompts are allowed.
- Preserve `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GPG_KEY`, and
  `TAILSCALE_AUTHKEY`. Add `DOTFILES_NONINTERACTIVE=1`; absent GPG/Tailscale
  settings mean no activation. Avoid persisting Tailscale credentials or
  embedding them in generated scripts.
- Order hooks explicitly: prerequisite checks/install → managed configuration
  and externals → Brew/mise packages → optional service activation. Detect
  newly installed binaries at execution time.
- Use native Linux package managers for system prerequisites and Homebrew on
  macOS. Guard Brew formulas/casks, external downloads, and mise tools by
  supported platform and architecture. Retain existing versions wherever
  supported; report every compatibility exclusion.
- Install compiler/system dependencies required by existing source-built
  tools. Missing privileges or package failures produce actionable errors,
  not false success.
- Gate systemd files and service activation on Linux and a working service
  manager. Containers and WSL without systemd must still complete installation.
- Enable Git signing only with an explicitly configured, locally available
  secret key. Guard shell GPG integration when tools are absent. Tailscale
  enrollment remains explicit opt-in; do not automatically enable remote SSH
  access or accepted routes.
- Fix Bash/zsh initialization for supported Brew locations and mise
  activation. Install zsh without changing the account's login shell
  automatically.
- Preserve existing home-file conflicts: interactive installs prompt;
  unattended installs stop rather than force overwrites.
- Update README and troubleshooting instructions, including prerequisites,
  unattended examples, compatibility exclusions, recovery, and accurate
  `private_` behavior: it controls file permissions, not Git exclusion.

## Sandboxed verification

Docker was available locally during planning. Run installation tests only in
disposable environments.

- Add a repeatable harness using Ubuntu, Debian, Fedora, and Arch containers,
  disposable non-root users, and isolated home/XDG directories. Mount source
  read-only; copy it inside each container. Never expose host credentials,
  home directories, or Docker socket.
- Exercise the actual installer and hooks with network downloads. Test the
  candidate checkout before publication; test the documented GitHub command
  once that revision is published.
- Test fresh interactive installation through a pseudo-terminal and
  unattended installation through environment variables.
- Run installation twice; verify tools resolve, Bash/zsh start cleanly,
  configured identity persists, and no unintended managed-file differences
  remain.
- Cover missing identity, unavailable sudo, existing configuration, file
  conflicts, custom XDG paths, unavailable systemd, absent GPG keys, and failed
  downloads.
- Use command stubs for service opt-in tests; never enroll a real Tailscale
  node or import personal keys.
- Replace placeholder CI tests with template/rendered-shell checks and
  sandbox install tests. Validate macOS in disposable macOS runners and WSL
  in an actual disposable WSL environment. Report unavailable platform
  coverage as unverified.

## Acceptance and defaults

- One command installs all applicable packages and configuration; reruns
  complete safely.
- Network access, a supported OS/architecture, shell, curl, Git, and necessary
  installation privileges are prerequisites.
- Target x86-64 and ARM64; distinguish actual execution coverage from
  template-only checks.
- Native Windows, account logins, private-key transfer, and unrelated service
  provisioning remain outside scope.
- Implement on a feature branch. No host-wide apply during development.
  Completion requires sandbox evidence, with failures and unsupported
  combinations listed explicitly.
