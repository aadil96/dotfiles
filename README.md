# dotfiles

This repository contains my personal dotfiles, managed with [chezmoi](https://www.chezmoi.io/), and designed for seamless use across local, containerized, and cloud development environments. It is structured to work out-of-the-box with:

- **chezmoi**: For dotfile management and templating
- **DevPod**: For reproducible development environments
- **VS Code Dev Containers**: For local and remote container-based development
- **GitHub Codespaces**: For cloud-based development

---

## Repository Structure

```text
├── .chezmoi.toml.tmpl         # chezmoi configuration (templated)
├── .chezmoiexternals/         # chezmoi-managed external resources (tools, fonts, configs)
├── .chezmoiscripts/           # chezmoi hook scripts (prereqs, brew, mise, services)
├── .devcontainer/             # VS Code Dev Container config (Dockerfile, devcontainer.json)
├── dot_*                      # Dotfiles (bashrc, gitconfig, tmux, wezterm, zshrc, etc.)
├── dot_config/                # XDG config files (alacritty, git, k9s, mise, nvim, starship, systemd, zellij, zsh)
├── dot_gnupg/                 # GPG config (gpg-agent.conf, gpg.conf)
├── setup                      # Legacy bootstrap script (local clone-based)
```

---

## Usage

### 1. Install

The documented entrypoint is chezmoi's one-command bootstrap:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply aadil96/dotfiles
```

This installs chezmoi, clones `aadil96/dotfiles`, and applies everything:

- System prerequisites via the native package manager (apt/dnf/pacman on Linux, Homebrew on macOS)
- Managed configuration and external resources
- Homebrew packages (macOS) or mise packages
- Optional service activation (GPG preset, Tailscale opt-in)

Interactive runs prompt for your Git `user.name` and `user.email`, plus an optional GPG key fingerprint (skipped when already provided via env or saved config). Hooks run in order: prerequisite checks/install (`run_once_before_00-prereqs`) → managed config + externals (apply) → Homebrew (`run_onchange_after_00`) → mise packages (`run_onchange_after_01`) → service activation (GPG preset `run_onchange_after_02`, Tailscale `run_once_after_03`). Binaries are detected at execution time, so freshly installed tools are found.

Prerequisites:

- Network access
- A supported OS: Ubuntu/Debian, Fedora, Arch, macOS, or WSL, on x86-64 or ARM64
- A shell, `curl`, and Git
- Privileges to install packages (sudo/root; macOS needs Command Line Tools)

Unattended/CI install:

```sh
DOTFILES_NONINTERACTIVE=1 GIT_USER_NAME="Ada Lovelace" GIT_USER_EMAIL="ada@example.com" \
  sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply aadil96/dotfiles
```

Unattended runs never prompt: missing `GIT_USER_NAME`/`GIT_USER_EMAIL` aborts with a clear error, and existing home-file conflicts stop the install instead of force-overwriting (the installer never passes `--force`).

`setup` remains available for local clone-based bootstrap and is unchanged, but the curl one-liner above is the documented entrypoint for new machines. Note that `./setup` installs Homebrew on Linux, which is no longer part of the supported toolset.

### Environment variables

| Variable | Purpose |
| --- | --- |
| `GIT_USER_NAME`, `GIT_USER_EMAIL` | Git identity; required. Env overrides saved config and interactive prompts. |
| `GPG_KEY` | GPG key fingerprint. Empty/absent means Git signing is not configured. |
| `DOTFILES_NONINTERACTIVE=1` | No prompts; missing required values abort clearly. |
| `TAILSCALE_AUTHKEY` | Tailscale enrollment, explicit opt-in. Set at install time to enroll. Runtime env only — never persisted or written to generated files. |
| `TAILSCALE_SSH=1` | Opt into remote SSH access on `tailscale up` (off by default). |
| `TAILSCALE_ACCEPT_ROUTES=1` | Opt into advertised routes on `tailscale up` (off by default). |
| `DOTFILES_TEST_SKIP_PACKAGES=1` | Test-only escape hatch: skip mise package installation (not for users). |

### Platform support & exclusions

- Supported: Ubuntu/Debian, Fedora, Arch, macOS, and WSL on x86-64 or ARM64. Native Windows is out of scope.
- System prerequisites come from the distro package manager; Homebrew is macOS-only (Brewfile formulas/casks are guarded by `if: OS.mac?`).
- zsh is installed, but the account login shell is never changed automatically.
- `vagrant` is installed from native packages where available (Arch); elsewhere it is excluded without adding third-party repos (Debian/Ubuntu/Fedora).
- Every compatibility exclusion is logged as `[portable-install] EXCLUDED: <tool>: <reason>`.
- systemd units under `dot_config/systemd/**` are installed only on Linux with a working systemd service manager (PID 1). Containers and WSL without systemd skip units and service activation but complete installation.

For failure modes and recovery, see [docs/troubleshooting.md](docs/troubleshooting.md).

### 2. chezmoi

chezmoi manages all dotfiles, templates, and external resources. It detects if you are running in a remote/container/Codespaces environment and adapts accordingly (see `.chezmoi.toml.tmpl`).

- **chezmoi apply**: Apply dotfiles to your home directory
- **chezmoi update**: Pull and apply latest changes

### 3. DevPod

DevPod is supported via `.chezmoiexternals/devpod.toml`, which ensures the DevPod binary is installed and available in your environment.

### 4. VS Code Dev Containers

- The `.devcontainer/` folder contains a `devcontainer.json` and a `Dockerfile` based on `mcr.microsoft.com/devcontainers/base:debian-13`.
- Open the repo in VS Code and "Reopen in Container" to get a fully provisioned environment with all tools and dotfiles.

### 5. GitHub Codespaces

- This repo is Codespaces-ready. Just "Open in Codespaces" on GitHub and all dotfiles, tools, and configs will be provisioned automatically.

---

## Highlights

- **Shells**: zsh (installed, login shell unchanged), bash
- **Prompt**: [starship](https://starship.rs/) with custom theme
- **Editor**: [Neovim](https://neovim.io/) (LazyVim-based), with plugins and extras
- **Terminal**: [WezTerm](https://wezfurlong.org/wezterm/), [alacritty](https://alacritty.org/)
- **Multiplexers**: tmux, zellij
- **Tools**: Managed with [mise](https://mise.jdx.dev/) (see `dot_config/mise/mise.toml`)
- **Kubernetes**: k9s with custom skin
- **Fonts**: DepartureMono (auto-installed)

---

## Customization

- All dotfiles are templated for local/remote/container/cloud detection
- Add or modify tools in `dot_config/mise/mise.toml`
- Add external resources in `.chezmoiexternals/`
- Add post-install scripts in `.chezmoiscripts/`

---

## License

These dotfiles are provided as-is for personal use and inspiration. Use at your own risk.

## Opencode config

The global opencode config lives in a separate public repo:
[aadil96/opencode-config](https://github.com/aadil96/opencode-config).
Chezmoi pulls it into `~/.config/opencode/` via `.chezmoiexternal.toml`.
To force a refresh: `chezmoi apply --refresh-externals`.
