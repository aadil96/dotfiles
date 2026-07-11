# Tmux Cheatsheet

> Generated from [chezmoi-managed tmux config](../dot_tmux.conf.tmpl).

---

## What is tmux?

**tmux** is a **terminal multiplexer** — it runs inside your terminal and lets you manage multiple windows and panes in a single terminal window. Think of it as a window manager for the command line.

### Getting Started

1. Open your terminal
2. Type `tmux` and press Enter
3. You're now inside a tmux session. You'll see a green status bar at the bottom.
4. Try splitting the screen: press `C-a` (Ctrl + a, release both), then press `%` (Shift + 5)
5. Move between the two panes: press `C-a`, release, then press `l`
6. To leave tmux: press `C-a`, release, then press `d` (detach)
7. To come back: type `tmux attach` in your terminal

### How Keybindings Work

All tmux commands start with the **prefix key** — think of it like "waking up" tmux to listen for a command. This config uses `C-a` as the prefix.

**The golden rule: you NEVER hold the prefix while pressing the command key.**

| Notation | What to do |
| ------------ | -------------------------------------------------------------- |
| `C-a` | Press and hold **Ctrl**, tap **a**, then release **both** keys |
| `C-a` `k` | Press `C-a` (Ctrl+a), **release both**, then press **k** |
| `C-a` `C-k` | Press `C-a` (Ctrl+a), **release both**, then press **Ctrl+k** |

Some bindings use the `-r` (repeat) flag. This means you only press the prefix **once**, then you can tap the command key multiple times in a row without re-pressing the prefix.

> **⚠️ These keybindings only work inside a tmux session.** If you're in a regular terminal, they won't do anything.

### Common Beginner Pitfalls

| Symptom | What's wrong |
| --------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Text appears in your terminal instead of the command working | You forgot to press the prefix first. Press `C-a` **before** the command key. |
| I pressed `5` instead of `Shift+5` to get `%` | The `%` symbol requires **Shift + 5**, not just `5`. The same goes for any symbol key — `$`, `"`, `&`, `?`, `{`, `}` etc. Always check if the keybinding uses a shifted character. |
| Nothing happens when you type a keybinding | Try pressing `C-a` more deliberately — release Ctrl before pressing the next key. The two keystrokes are separate, not a chord. |
| Keys don't work at all | You might not be inside a tmux session. Check for the green status bar at the bottom of your terminal. |

---

## Keybinding Notation

Throughout this cheatsheet, keybindings are written like `C-a k`. This always means:

1. Press **Ctrl + a** together, then release both
2. Then press **k** (or whatever the command key is)

> **Note on symbol keys:** Some keybindings use symbols that require Shift:
>
> - `%` = press **Shift + 5**
> - `"` = press **Shift + '**
> - `&` = press **Shift + 7**
> - `$` = press **Shift + 4**
> - `?` = press **Shift + /**
> - `{` = press **Shift + [**
> - `}` = press **Shift + ]**

---

## Prefix

The **prefix key** is how you tell tmux you're about to give it a command.

| Action | Key |
| ---------------------------- | ------------ |
| Send prefix to tmux | `C-a` |
| Send literal `C-a` to the app inside tmux | `C-a` `a` |
| Default prefix (disabled) | ~~`C-b`~~ |

> **Tip:** Wait for the tmux status bar to flash before typing the rest of your command. If nothing happens, you might have missed the prefix.

---

## Session Management

A **session** is a full tmux workspace. You can have multiple sessions running at once.

| Action | Command |
| ---------------------------- | ---------------------- |
| Create a new named session | `tmux new -s <name>` |
| Detach from current session | `C-a` `d` |
| List all sessions | `tmux ls` |
| Attach to a session | `tmux attach -t <name>` |
| Kill a session | `tmux kill-session -t <name>` |
| Rename current session | `C-a` `$` |
| Select a session interactively | `C-a` `s` |

---

## Window Management

**Windows** are like tabs inside a session. Numbering starts at **1** (not the default 0).

| Action | Key |
| --------------------- | ---------------- |
| Create new window | `C-a` `c` |
| Next window | `C-a` `n` |
| Previous window | `C-a` `p` |
| Select window by number | `C-a` `<number>` (e.g. `C-a` `1`) |
| Rename current window | `C-a` `,` |
| Close current window | `C-a` `&` |
| List all windows | `C-a` `w` |

---

## Pane Management

**Panes** split a single window into multiple regions. Navigation uses **Vim-style hjkl** keys.

### Splitting

| Action | Key |
| ------------------------------ | ---------- |
| Split horizontally (top/bottom) | `C-a` `"` |
| Split vertically (left/right) | `C-a` `%` |

### Navigation (Vim hjkl) — repeatable

| Action | Key |
| ---------------- | ---------- |
| Move pane up | `C-a` `k` |
| Move pane down | `C-a` `j` |
| Move pane left | `C-a` `h` |
| Move pane right | `C-a` `l` |
| Toggle to last pane | `C-a` `;` |

> **Tip:** Because these bindings use `-r` (repeat), you only need to press the prefix once, then you can tap `k`/`j`/`h`/`l` repeatedly to move across multiple panes. `C-a ;` (semicolon) jumps back to the previously focused pane — super useful when switching between two panes.

### Resizing — repeatable

| Action | Key |
| ---------------- | ------------ |
| Resize pane up | `C-a` `C-k` |
| Resize pane down | `C-a` `C-j` |
| Resize pane left | `C-a` `C-h` |
| Resize pane right | `C-a` `C-l` |

Each resize moves the pane border by **5 lines**. Because these also use `-r`, press `C-a`, release, then tap `C-k` / `C-j` / `C-h` / `C-l` repeatedly to keep resizing.

### Other Pane Actions

| Action | Key |
| --------------------- | ----------- |
| Close current pane | `C-a` `x` |
| Toggle pane zoom (fullscreen) | `C-a` `z` |
| Swap pane with next | `C-a` `{` / `}` |
| Show & select pane by number | `C-a` `q` then type the number (e.g., `1`, `2`, `3`) |

> **Tip:** `C-a q` shows numbers on all panes. Type a number while they're visible to jump to that pane. Panes are numbered starting at 1 (`pane-base-index` 1).

---

## Copy Mode

Copy mode lets you scroll through pane history and yank text. Uses **Vi keybindings**.

| Action | Key |
| ----------------- | ------------ |
| Enter copy mode | `C-a` `[` |
| Exit copy mode | `Enter` or `q` |
| Move up | `k` |
| Move down | `j` |
| Move left | `h` |
| Move right | `l` |
| Scroll up half page | `C-u` |
| Scroll down half page | `C-d` |
| Scroll up full page | `C-b` |
| Scroll down full page | `C-f` |
| Move to start of line | `0` |
| Move to end of line | `$` |
| Search forward | `/` |
| Search backward | `?` |
| Next match | `n` |
| Previous match | `N` |
| Start selection | `Space` (or `v`) |
| Start line selection | `V` |
| Yank selection | `Enter` (or `y`) |
| Paste yanked text | `C-a` `]` |

> Once inside copy mode, navigation keys (`k`, `j`, `h`, `l`, etc.) are pressed directly — no prefix needed. You only need the prefix (`C-a`) to enter (`[`) and paste (`]`).

---

## Configuration Details

Key settings from `~/.tmux.conf`:

| Setting | Value | Purpose |
| ------------------- | ------------------------ | ------------------------------------ |
| `default-terminal` | `tmux-256color` | Truecolor-capable terminal type |
| `terminal-overrides` | `,xterm-256color:RGB` | Enable truecolor for xterm |
| `terminal-overrides` | `,alacritty:Tc` | Enable truecolor for Alacritty |
| `prefix` | `C-a` | Easier reach than default `C-b` |
| `mouse` | `on` | Click to select panes, resize, scroll |
| `history-limit` | `50000` | 50k lines of scrollback per pane |
| `escape-time` | `0` | Instant escape — no delay for Vim/Neovim |
| `base-index` | `1` | Window numbering starts at 1 |
| `pane-base-index` | `1` | Pane numbering starts at 1 |
| `mode-keys` | `vi` | Vi-style navigation in copy mode |
| `status-interval` | `60` | Status bar refreshes every 60s |
| `status-left` | `#[fg=green]#S` | Session name in green |
| `status-right` | `#[fg=yellow]%H:%M` | Current time in yellow |

### Truecolor Support

This config enables **truecolor (24-bit color)** for modern terminals:

- **Alacritty**: Native support via the `Tc` capability override
- **xterm-256color** terminals: Enabled via the `RGB` capability override

Without these overrides, terminals that report as `xterm-256color` will not render truecolor correctly inside tmux.

### Escape Time

```tmux
set -sg escape-time 0
```

Setting `escape-time` to `0` eliminates the 500ms default delay when pressing `Esc` in Vim/Neovim. This makes modeswitching (insert → normal) feel instant.

### Scrollback History

```tmux
set -g history-limit 50000
```

Each pane retains **50,000 lines** of scrollback — useful for long build outputs, logs, or terminal sessions.

### Mouse Support

```tmux
set -g mouse on
```

With mouse mode on you can:

- Click panes to focus them
- Drag pane borders to resize
- Scroll the pane history with your mouse wheel/trackpad
- Click window names in the status bar to switch

---

## Quick Reference Table

| What you want | Keys |
| --------------------- | ------------------- |
| **Prefix** | `C-a` |
| **Send C-a to app** | `C-a` `a` |
| **Reload config** | `C-a` `r` |
| **New window** | `C-a` `c` |
| **Close window** | `C-a` `&` (Shift+7) |
| **Next/prev window** | `C-a` `n` / `C-a` `p` |
| **Select window #** | `C-a` `1`…`9` |
| **Rename window** | `C-a` `,` |
| **Split horizontal** | `C-a` `"` (Shift+') |
| **Split vertical** | `C-a` `%` (Shift+5) |
| **Navigate pane up** | `C-a` `k` |
| **Navigate pane down** | `C-a` `j` |
| **Navigate pane left** | `C-a` `h` |
| **Navigate pane right** | `C-a` `l` |
| **Toggle last pane** | `C-a` `;` |
| **Resize pane up** | `C-a` `C-k` |
| **Resize pane down** | `C-a` `C-j` |
| **Resize pane left** | `C-a` `C-h` |
| **Resize pane right** | `C-a` `C-l` |
| **Close pane** | `C-a` `x` |
| **Toggle zoom pane** | `C-a` `z` |
| **Enter copy mode** | `C-a` `[` |
| **Paste yanked text** | `C-a` `]` |
| **Detach session** | `C-a` `d` |
| **List sessions** | `C-a` `s` |
| **Rename session** | `C-a` `$` (Shift+4) |
| **Reload config** | `C-a` `r` |
| **Show time** | `C-a` `t` |

---

> **Pro tip:** Run `C-a` `?` (Shift+/) inside tmux to see all available keybindings at any time.
