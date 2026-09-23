#!/bin/bash
# tests/template-checks/check.sh — CI-safe, offline template rendering checks.
# No Docker, no network (the CI job installs chezmoi beforehand).
#
# Requires chezmoi v2.x on PATH (bootstrap: sh -c "$(curl -fsLS https://get.chezmoi.io)").
#
# Flow:
#   0. `chezmoi init --source <repo>` under a throwaway HOME with
#      DOTFILES_NONINTERACTIVE=1 — the real init-template/config render must
#      succeed (this is where missing identity would fail clearly);
#   1. render every *.tmpl with `chezmoi execute-template --source <repo>`
#      (config data available, includes resolve from the repo) — must succeed;
#   2. render again WITHOUT DOTFILES_NONINTERACTIVE in a per-file FRESH HOME
#      with stdin closed and `timeout 30` — must EXIT rather than hang
#      (chezmoi promptStringOnce on a non-TTY is expected to fail fast /
#      return silently; a hang is a hard failure);
#   3. bash -n every rendered .sh output and every dot_bashrc.tmpl /
#      dot_zshrc.tmpl render.
# Also asserts .chezmoiignore.tmpl renders, and (optional nicety) runs
# shellcheck -S error over the rendered hook scripts when shellcheck exists.
#
# Prints `Verdict: PASS` or `Verdict: FAIL` with the failing file list.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

command -v chezmoi >/dev/null 2>&1 || { echo "FATAL: chezmoi not on PATH"; exit 1; }
CHEZ="$(command -v chezmoi)"

TH="$(mktemp -d)"
trap 'rm -rf "$TH"' EXIT

# Shared throwaway HOME for step 0 + pass-1 renders — the real user HOME is
# never touched.
export HOME="$TH/home"
mkdir -p "$HOME"
export XDG_CONFIG_HOME="$TH/home/.config" \
       XDG_DATA_HOME="$TH/home/.local/share" \
       XDG_STATE_HOME="$TH/home/.local/state" \
       XDG_CACHE_HOME="$TH/home/.cache"

RENDER_DIR="$TH/rendered"
SHELL_DIR="$TH/rendered-shell"
mkdir -p "$RENDER_DIR" "$SHELL_DIR"

FAILED_FILES=()

# --- step 0: init-template / config render ---------------------------------------
set +e
( cd "$REPO" && DOTFILES_NONINTERACTIVE=1 GIT_USER_NAME=T GIT_USER_EMAIL=t@e \
    DOTFILES_TEST_SKIP_PACKAGES=1 timeout 30 "$CHEZ" init --source "$REPO" >"$TH/init.log" 2>&1 )
INIT_RC=$?
set -e
if [ "$INIT_RC" -ne 0 ]; then
  echo "Verdict: FAIL"
  echo "  - chezmoi init (config generation) failed: $(tail -2 "$TH/init.log" | tr '\n' ' ')"
  exit 1
fi
[ -f "$XDG_CONFIG_HOME/chezmoi/chezmoi.toml" ] || {
  echo "Verdict: FAIL"
  echo "  - chezmoi init completed but config missing at \$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"
  exit 1
}

# render_pass1 <tmpl-file> — noninteractive render with saved config; sets RC1
render_pass1() {
  local f="$1" out="$2"
  set +e
  ( cd "$REPO" && DOTFILES_NONINTERACTIVE=1 GIT_USER_NAME=T GIT_USER_EMAIL=t@e \
      DOTFILES_TEST_SKIP_PACKAGES=1 timeout 30 "$CHEZ" execute-template --source "$REPO" <"$f" >"$out" 2>"$out.err" )
  RC1=$?
  set -e
}

# render_pass2 <tmpl-file> <fresh-home> — interactive-ish, stdin closed,
# timeout-guarded; must not hang (timeout exit code 124). Sets RC2.
render_pass2() {
  local f="$1" p2home="$2"
  set +e
  ( cd "$REPO" && HOME="$p2home" XDG_CONFIG_HOME="$p2home/.config" \
      XDG_DATA_HOME="$p2home/.local/share" XDG_STATE_HOME="$p2home/.local/state" \
      XDG_CACHE_HOME="$p2home/.cache" \
      GIT_USER_NAME=T GIT_USER_EMAIL=t@e timeout 30 "$CHEZ" execute-template --init --source "$REPO" </dev/null >/dev/null 2>&1 )
  RC2=$?
  set -e
}

mapfile -t TMPLS < <(cd "$REPO" && find . -name '*.tmpl' -not -path './node_modules/*' -not -path './.git/*' | sort)

for f in "${TMPLS[@]}"; do
  rel="${f#./}"
  out="$RENDER_DIR/$rel"
  mkdir -p "$(dirname "$out")"

  # .chezmoi.toml.tmpl is the init template: already rendered by step 0
  # (execute-template lacks promptStringOnce, an init-only function).
  if [ "$rel" = ".chezmoi.toml.tmpl" ]; then
    p2home="$TH/p2/chezmoi_toml_tmpl"
    mkdir -p "$p2home"
    render_pass2 "$f" "$p2home"
    if [ "$RC2" -eq 124 ]; then
      FAILED_FILES+=("$rel (prompt hung on non-TTY; killed by timeout 30)")
    fi
    continue
  fi

  # pass 1: render with saved config data
  render_pass1 "$f" "$out"
  if [ "$RC1" -ne 0 ]; then
    FAILED_FILES+=("$rel (render exit $RC1: $(tail -1 "$out.err" 2>/dev/null))")
    continue
  fi

  # pass 2: no hang on non-TTY prompt (fresh HOME per file so no saved prompt state)
  p2home="$TH/p2/$(printf '%s' "$rel" | tr '/.' '__')"
  mkdir -p "$p2home"
  render_pass2 "$f" "$p2home"
  if [ "$RC2" -eq 124 ]; then
    FAILED_FILES+=("$rel (prompt hung on non-TTY; killed by timeout 30)")
    continue
  fi

  case "$rel" in
    *.sh.tmpl | dot_bashrc.tmpl | dot_zshrc.tmpl | dot_local/bin/executable_gpg-sign-preset.tmpl)
      if ! bash -n "$out" 2>"$out.syn"; then
        FAILED_FILES+=("$rel (bash -n failed: $(tail -1 "$out.syn" 2>/dev/null))")
        continue
      fi
      # shellcheck pass is scoped to rendered HOOK scripts (.sh.tmpl): rc files
      # are shebang-less by design and would trip SC2148.
      case "$rel" in
        *.sh.tmpl) cp "$out" "$SHELL_DIR/$(printf '%s' "$rel" | tr '/.' '__').sh" ;;
      esac
      ;;
  esac
done

# explicit .chezmoiignore.tmpl render assertion
if [ ! -s "$RENDER_DIR/.chezmoiignore.tmpl" ]; then
  FAILED_FILES+=(".chezmoiignore.tmpl render missing/empty")
fi

# REGRESSION GUARD: ignore patterns for dot_-prefixed directories are matched
# by chezmoi (v2.72+) against TARGET paths — .config/systemd/** — never source
# paths (dot_config/systemd/** silently ignores nothing, which let systemd
# units apply in the sandbox). The source must contain the target-form line; a
# systemd host renders the gate closed (line absent) by design, and a
# non-systemd host must render the line verbatim.
if ! grep -q '\.config/systemd/\*\*' "$REPO/.chezmoiignore.tmpl"; then
  FAILED_FILES+=(".chezmoiignore.tmpl missing .config/systemd/** gate")
fi
if grep -q 'dot_config/systemd/\*\*' "$REPO/.chezmoiignore.tmpl"; then
  FAILED_FILES+=(".chezmoiignore.tmpl contains source-form gate dot_config/systemd/** — target form .config/systemd/** required")
fi
if ! grep -q 'systemd' /proc/1/comm 2>/dev/null; then
  if ! grep -q '^\.config/systemd/\*\*$' "$RENDER_DIR/.chezmoiignore.tmpl"; then
    FAILED_FILES+=(".chezmoiignore.tmpl render missing .config/systemd/** gate on non-systemd host")
  fi
fi

# optional nicety: shellcheck rendered hooks (error level only) when available
if command -v shellcheck >/dev/null 2>&1 && ls "$SHELL_DIR"/*.sh >/dev/null 2>&1; then
  set +e
  shellcheck -S error "$SHELL_DIR"/*.sh
  SCR=$?
  set -e
  if [ "$SCR" -ne 0 ]; then
    echo "note: rendered-hook shellcheck found errors (warn-only; see above)"
  fi
fi

if [ "${#FAILED_FILES[@]}" -eq 0 ]; then
  echo "Rendered ${#TMPLS[@]} templates (two passes each)."
  echo "Verdict: PASS"
  exit 0
fi

echo "Verdict: FAIL"
for f in "${FAILED_FILES[@]}"; do
  echo "  - $f"
done
exit 1