#!/bin/bash
# tests/sandbox/macos-run.sh — macOS install-test equivalent, run natively on a
# disposable GitHub-hosted macOS runner (the runner IS the disposable env; no
# container). Kept to install-test.sh's core path, with honest partial coverage:
#
#   * runs as the runner user (no passwordless sudo) with
#     DOTFILES_TEST_SKIP_PACKAGES=1 (fast lane) and `container=true` (the runner
#     is a CI environment) so the config's remote detection disables autoCommit;
#   * accepts either a completed install or an actionable sudo/permission error
#     (macOS prereqs/Homebrew bootstrap need sudo), reporting which path; any
#     OTHER failure is a hard FAIL;
#   * verifies git identity, mise binary, clean zsh/bash startup, no systemd
#     units, no git signing, and a rerun with no managed-file differences.
#
# Prints COVERAGE=macos-ok | macos-partial for honest reporting.
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "COVERAGE=unverified (not macOS)"
  exit 0
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="$(mktemp -d)"
LOG="$(mktemp)"
CHK="$(mktemp)"
trap 'rm -rf "$SOURCE" "$LOG" "$CHK"' EXIT

git -C "$REPO_ROOT" archive HEAD | tar -x -C "$SOURCE"
chmod 755 "$SOURCE"

fail() { echo "FAIL: $*"; exit 1; }

# bootstrap path resolution: get.chezmoi.io installs to ~/bin or ~/.local/bin
chezmoi_bin() {
  local c
  c="$(command -v chezmoi 2>/dev/null || true)"
  [ -n "$c" ] && { printf '%s' "$c"; return; }
  for p in "$HOME/bin/chezmoi" "$HOME/.local/bin/chezmoi"; do
    [ -x "$p" ] && { printf '%s' "$p"; return; }
  done
}

# --- install (rc 0, or actionable sudo/permission error) ---------------------------
set +e
DOTFILES_NONINTERACTIVE=1 GIT_USER_NAME="CI Test" GIT_USER_EMAIL="ci@example.com" \
DOTFILES_TEST_SKIP_PACKAGES=1 container=true \
  sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply --source "$SOURCE" >"$LOG" 2>&1
RC=$?
set -e
echo "install exit=$RC"

COVERAGE="macos-partial"
if [ "$RC" -ne 0 ]; then
  if grep -qiE 'sudo|permission' "$LOG"; then
    echo "note: install reached the sudo-missing branch (expected on runners):"
    grep -iE 'sudo|permission' "$LOG" | tail -4
  else
    echo "--- install log (tail) ---"; tail -40 "$LOG"
    fail "install failed without an actionable sudo/permission error (exit $RC)"
  fi
else
  COVERAGE="macos-ok"
fi

# --- core verification (mirrors install-test.sh) -------------------------------------
CHEZ="$(chezmoi_bin)" || true
[ -n "${CHEZ:-}" ] || fail "chezmoi binary not found after bootstrap"

git config --global user.name 2>/dev/null | grep -qx 'CI Test' || fail "git user.name not applied"
git config --global user.email 2>/dev/null | grep -qx 'ci@example.com' || fail "git user.email not applied"

[ -x "$HOME/.local/bin/mise" ] || fail "mise binary missing at ~/.local/bin/mise"

set +e
zsh -ic true >"$CHK" 2>&1; ZRC=$?
bash -ic true >"$CHK" 2>&1; BRC=$?
set -e
[ "$ZRC" -eq 0 ] || fail "zsh -ic true failed (exit $ZRC)"
[ "$BRC" -eq 0 ] || fail "bash -ic true failed (exit $BRC)"

[ ! -d "$HOME/.config/systemd" ] || fail "systemd units present (should never apply on macOS)"

set +e
git config --global --get commit.gpgsign >/dev/null 2>&1; GPRC=$?
set -e
[ "$GPRC" -ne 0 ] || fail "gpgsign unexpectedly configured (no GPG_KEY)"

# --- rerun (idempotency) --------------------------------------------------------------
set +e
DOTFILES_NONINTERACTIVE=1 GIT_USER_NAME="CI Test" GIT_USER_EMAIL="ci@example.com" \
DOTFILES_TEST_SKIP_PACKAGES=1 container=true \
  sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply --source "$SOURCE" >"$LOG" 2>&1
RRC=$?
set -e
if [ "$RRC" -eq 0 ] || grep -qiE 'sudo|permission' "$LOG"; then
  echo "rerun ok (exit=$RRC)"
else
  echo "--- rerun log (tail) ---"; tail -30 "$LOG"
  fail "rerun failed without actionable sudo/permission error (exit $RRC)"
fi

DIFF_OUT="$("$CHEZ" diff 2>/dev/null)" || true
[ -z "$DIFF_OUT" ] || fail "chezmoi diff reports managed-file differences after rerun"

echo "PASS: macos core install verification"
echo "COVERAGE=$COVERAGE"
exit 0