# zsh-autosuggestions chezmoi Integration

**Date:** 2026-05-14
**Status:** Draft

---

## Problem

The user's zsh configuration conditionally sources `zsh-autosuggestions` (lines 105-107 of `dot_zshrc.tmpl`) and `zsh-syntax-highlighting` (lines 110-112), but neither plugin is provisioned automatically. On new machines, these plugins must be cloned manually to `~/.zsh/zsh-autosuggestions/` and `~/.zsh/zsh-syntax-highlighting/`.

Two concrete issues:

1. **Missing automation**: No chezmoi external resource provisions these repositories. New machine bootstraps require manual `git clone` steps outside of `chezmoi apply`.

2. **Relative source path**: The `source` commands use `.zsh/` (relative to `$HOME` when zsh runs, but fragile — depends on working directory). Should use `$HOME/.zsh/` for explicitness and robustness.

---

## Design

### 1. Create `.chezmoiexternals/zsh-autosuggestions.toml`

Add a new chezmoi external definition using `type = "git-repo"` to clone the repository on `chezmoi apply`. This follows the existing pattern in `.chezmoiexternals/` (e.g., `devpod.toml`, `departuremono.toml`), though no existing file currently uses the `git-repo` type.

```toml
[".zsh/zsh-autosuggestions"]
type = "git-repo"
url = "https://github.com/zsh-users/zsh-autosuggestions.git"
refreshPeriod = "168h"
```

- **`refreshPeriod = "168h"`**: Weekly refresh keeps the plugin up to date without hammering GitHub on every `chezmoi apply`.
- **Target path `".zsh/zsh-autosuggestions"`**: chezmoi resolves relative paths inside externals against `$HOME`, matching where the existing config expects the plugin.

### 2. Fix relative path in `dot_zshrc.tmpl`

Change the two conditional source blocks from using a relative `.zsh/` prefix to an explicit `$HOME/.zsh/` prefix:

| Line | Current | Fixed |
| ------- | ---------------------------------------------------------------- | ------------------------------------------------------------------ |
| 105-106 | `.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh` | `$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh` |
| 110-111 | `.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh` | `$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh` |

This makes the source paths independent of the working directory at shell startup.

### 3. Add Linear MCP to `dot_config/opencode/opencode.jsonc`

The running `~/.config/opencode/opencode.jsonc` has a Linear MCP server block that is missing from the chezmoi-managed version. Add it to the `"mcp"` section after the existing `"gh_grep"` entry:

```json
"linear": {
    "type": "remote",
    "url": "https://mcp.linear.app/mcp",
    "headers": {
        "Authorization": "Bearer ${LINEAR_API_KEY}"
    },
    "enabled": true
}
```

- The `headers` block references an environment variable `LINEAR_API_KEY` — the token must be available in the shell environment when OpenCode launches.
- This is a remote MCP server; no local installation required.

---

## Files Affected

| Action | File | Purpose |
| ------ | ------------------------------------------- | -------------------------------------- |
| CREATE | `.chezmoiexternals/zsh-autosuggestions.toml` | Provision zsh-autosuggestions via git repo |
| EDIT | `dot_zshrc.tmpl` | Fix relative `$HOME/.zsh/` paths (2 changes) |
| EDIT | `dot_config/opencode/opencode.jsonc` | Add missing Linear MCP server config |

---

## Risks and Considerations

- **`git-repo` type**: This is the first use of `type = "git-repo"` in this repo's externals. chezmoi handles shallow clones for this type, which is efficient for plugin-like dependencies.
- **Environment variable dependency**: The Linear MCP `headers.Authorization` field requires `LINEAR_API_KEY` to be set. If it's absent at OpenCode startup, the MCP server will fail to authenticate. Document this as a setup prerequisite rather than embedding a token.
- **No syntax-highlighting external**: The spec only adds an external for `zsh-autosuggestions`. If desired, a second `.chezmoiexternals` file for `zsh-syntax-highlighting` could be added in a follow-up, but the path fix applies regardless.

---

## Verification

After implementation:

1. **`chezmoi status`** — confirms all files are tracked and changes are staged.
2. **`chezmoi diff`** — shows exact before/after for the two edited files.
3. **`chezmoi execute-template < dot_zshrc.tmpl`** — validates the template renders correctly with the new paths.
