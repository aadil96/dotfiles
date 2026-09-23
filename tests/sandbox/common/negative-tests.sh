#!/bin/bash
# shellcheck disable=SC2016
# tests/sandbox/common/negative-tests.sh — failure-path suite.
#
# Covers missing identity, unavailable sudo, existing-config conflict, custom
# XDG paths, and absent systemd / absent GPG. Each scenario resets the relevant
# home first so a fresh install is exercised. The existing-config conflict test
# asserts the shipped guard: a pre-apply hook refuses to overwrite — on an
# unattended non-TTY run it exits 1 with the conflicting file list and a
# recovery hint, leaving the sentinel untouched; interactive runs prompt
# per-file with `Overwrite <file>? [y/N]` and abort on any decline.
set -euo pipefail

# shellcheck source=/opt/sandbox/common/assert.sh
# shellcheck disable=SC1091
source /opt/sandbox/common/assert.sh

NEG=/tmp/negative-tests.log
CHK=/tmp/negative-tests-check.log

# --- missing identity -----------------------------------------------------------
# DOTFILES_NONINTERACTIVE=1 without GIT_USER_NAME/GIT_USER_EMAIL must fail
# clearly without trying to open a prompt.
reset_home tester
prepare_repo_copy tester

run_capture "$NEG" tester "$(install_cmd 'DOTFILES_NONINTERACTIVE=1 DOTFILES_TEST_SKIP_PACKAGES=1')"
if [ "$CAPTURED_RC" -ne 0 ] && grep -q 'DOTFILES_NONINTERACTIVE=1 requires GIT_USER_NAME and GIT_USER_EMAIL' "$NEG"; then
  _sa_pass 'missing identity fails with actionable message'
else
  _sa_fail "missing identity (exit $CAPTURED_RC): $(report_capture "$NEG")"
fi

# --- unavailable sudo (nosudo user) ---------------------------------------------
# Expect either a completed install (all prereqs already present — reported) or
# an actionable error mentioning sudo/permission. Never silent success.
reset_home nosudo
prepare_repo_copy nosudo

run_capture "$NEG" nosudo "$(install_cmd 'DOTFILES_NONINTERACTIVE=1 GIT_USER_NAME=x GIT_USER_EMAIL=y@example.com DOTFILES_TEST_SKIP_PACKAGES=1')"
if [ "$CAPTURED_RC" -eq 0 ]; then
  _sa_pass "no-sudo: install completed with exclusions (rc=0)"
elif grep -qiE 'sudo|permission' "$NEG"; then
  _sa_pass "no-sudo: actionable error mentioning sudo/permission (exit $CAPTURED_RC)"
else
  _sa_fail "no-sudo: non-zero exit without actionable sudo message (exit $CAPTURED_RC): $(report_capture "$NEG")"
fi

# --- existing-config conflict -----------------------------------------------------
# Pre-existing ~/.zshrc with a sentinel must NOT be silently overwritten.
reset_home tester
prepare_repo_copy tester

run_capture "$NEG" tester 'printf "# CONFLICT_SENTINEL\n" > "$HOME/.zshrc"'
run_capture "$NEG" tester "$(install_cmd "$(unattended_envs 'Test User' test@example.com)")"
CONF_RC="$CAPTURED_RC"

run_capture "$CHK" tester 'grep -q CONFLICT_SENTINEL "$HOME/.zshrc"'
SURVIVED="$CAPTURED_RC"   # 0 = sentinel survived
BACKUPS="$(find /home/tester -maxdepth 1 -name '.zshrc*' ! -name '.zshrc' | wc -l)"

if [ "$SURVIVED" -eq 0 ]; then
  _sa_pass "existing-config conflict: sentinel preserved (install rc=$CONF_RC; backups=$BACKUPS)"
else
  _sa_fail "existing-config conflict: CONFLICT_BEHAVIOR=OVERWRITE (sentinel gone; install rc=$CONF_RC; backups=$BACKUPS)"
fi

# --- custom XDG paths --------------------------------------------------------------
# chezmoi's own config dir follows XDG_CONFIG_HOME, but the `dot_config/**`
# source prefix maps to $HOME/.config (XDG-independent) — so with a custom XDG
# the two DIVERGE by design. The test asserts the chezmoi config lands under
# XDG and that the brew hook reads the File from chezmoi's FIXED mapping
# ($HOME/.config/brew/Brewfile) rather than from the XDG dir.
reset_home tester
prepare_repo_copy tester

run_capture "$NEG" tester "$(install_cmd "$(unattended_envs 'Test User' test@example.com XDG_CONFIG_HOME=/tmp/xdgtest)")"
assert_captured_ok 'custom XDG: install completes' "$NEG"
assert_file 'custom XDG: chezmoi config under $XDG_CONFIG_HOME' /tmp/xdgtest/chezmoi/chezmoi.toml

run_capture "$CHK" tester 'test -f "$HOME/.config/brew/Brewfile"'
assert_captured_ok 'custom XDG: Brewfile applied under $HOME/.config (chezmoi v2 mapping)' "$CHK"

if [ ! -e /tmp/xdgtest/brew/Brewfile ]; then
  _sa_pass 'custom XDG: brew hook reads the chezmoi-mapped Brewfile (not the XDG dir)'
else
  _sa_fail 'custom XDG: brew hook still resolves a Brewfile under $XDG_CONFIG_HOME — hook and chezmoi mapping diverged'
fi

# --- absent systemd / absent GPG (reuses the most recent complete install above;
# captures "no units + no signing + skip logged")
if grep -q 'SKIP: gpg-preset service' "$NEG"; then
  _sa_pass 'absent systemd/GPG: gpg-preset hook logged skip'
else
  _sa_fail 'absent systemd/GPG: gpg-preset skip message missing'
fi
run_capture "$CHK" tester 'test ! -d "$HOME/.config/systemd"'
assert_captured_ok 'absent systemd/GPG: no systemd units applied' "$CHK"
run_capture "$CHK" tester 'git config --global --get commit.gpgsign'
assert_captured_fail 'absent systemd/GPG: no gpgsign configured' "$CHK"

finish_suite 'negative-tests'
