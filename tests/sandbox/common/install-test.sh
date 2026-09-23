#!/bin/bash
# tests/sandbox/common/install-test.sh — primary in-container suite.
#
# Exercises the real portable installer end to end as the disposable `tester`
# user (uid 1000, passwordless sudo):
#   1. unattended install via the documented bootstrap one-liner in
#      candidate-checkout mode (--source /home/tester/dotfiles — exactly the
#      revision CI tests, i.e. `git archive HEAD`),
#   2. verification: git identity, mise binary/tools, clean zsh/bash startup,
#      no systemd units in a plain container, no tailscale, no git signing,
#   3. rerun (idempotency): second install exits 0 and `chezmoi diff --exit-code`
#      reports no managed-file differences.
# DOTFILES_TEST_SKIP_PACKAGES=1 (fast lane) skips the mise install; the FULL lane
# (--full, DOTFILES_TEST_SKIP_PACKAGES=0) additionally checks `mise which`.
set -euo pipefail

source /opt/sandbox/common/assert.sh

INSTALL_LOG=/tmp/install-test-install.log
CHK=/tmp/install-test-check.log

# --- fresh environment + writable candidate-checkout source -------------------
reset_home tester
prepare_repo_copy tester

# --- 1. unattended install -----------------------------------------------------
run_capture "$INSTALL_LOG" tester "$(install_cmd "$(unattended_envs 'Test User' test@example.com)")"
assert_captured_ok 'unattended install' "$INSTALL_LOG"

# --- 2. verification ------------------------------------------------------------

# git identity
run_capture "$CHK" tester 'git config --global user.name'
assert_captured_ok 'git identity: user.name present' "$CHK"
assert_eq 'git identity: user.name value' 'Test User' "$(cat "$CHK")"
run_capture "$CHK" tester 'git config --global user.email'
assert_captured_ok 'git identity: user.email present' "$CHK"
assert_eq 'git identity: user.email value' 'test@example.com' "$(cat "$CHK")"

# no git signing configured (GPG_KEY unset)
run_capture "$CHK" tester 'git config --global --get commit.gpgsign'
assert_captured_fail 'git identity: no gpgsign configured' "$CHK"

# mise binary landed (chezmoi external) even in the fast lane
run_capture "$CHK" tester '[ -x "$HOME/.local/bin/mise" ]'
assert_captured_ok 'mise binary present at ~/.local/bin/mise' "$CHK"

# full lane: mise tools resolve
if [ "${DOTFILES_TEST_SKIP_PACKAGES:-}" != "1" ]; then
  run_capture "$CHK" tester 'export PATH="$HOME/.local/bin:$PATH"; mise which bat'
  assert_captured_ok 'full lane: mise which bat resolves' "$CHK"
  run_capture "$CHK" tester 'export PATH="$HOME/.local/bin:$PATH"; mise which fd'
  assert_captured_ok 'full lane: mise which fd resolves' "$CHK"
  run_capture "$CHK" tester 'export PATH="$HOME/.local/bin:$PATH"; mise which fzf'
  assert_captured_ok 'full lane: mise which fzf resolves' "$CHK"
fi

# clean shell startup (benign warnings tolerated; ERROR lines are not)
run_capture "$CHK" tester 'zsh -ic true'
if [ "$CAPTURED_RC" -eq 0 ] && ! grep -qiE 'ERROR|command not found|no such file or directory' "$CHK"; then
  _sa_pass 'zsh starts cleanly (no rc-file errors)'
else
  _sa_fail "zsh startup (exit $CAPTURED_RC): $(report_capture "$CHK")"
fi
run_capture "$CHK" tester 'bash -ic true'
if [ "$CAPTURED_RC" -eq 0 ] && ! grep -qiE 'ERROR|command not found|no such file or directory' "$CHK"; then
  _sa_pass 'bash starts cleanly (no rc-file errors)'
else
  _sa_fail "bash startup (exit $CAPTURED_RC): $(report_capture "$CHK")"
fi

# no systemd unit files in a plain container (no systemd PID 1)
run_capture "$CHK" tester 'test ! -d "$HOME/.config/systemd"'
assert_captured_ok 'no systemd units applied (plain container)' "$CHK"

# tailscale never installed without TAILSCALE_AUTHKEY
run_capture "$CHK" tester '! command -v tailscale'
assert_captured_ok 'tailscale not installed (no opt-in key)' "$CHK"

# gpg-preset hook logged a skip (no signing key configured in this container)
if grep -q 'SKIP: gpg-preset service' "$INSTALL_LOG"; then
  _sa_pass 'gpg-preset hook logged a skip'
else
  _sa_fail 'gpg-preset hook skip message missing from install log'
fi

# --- 3. rerun (idempotency) ------------------------------------------------------
run_capture "$INSTALL_LOG" tester "$(install_cmd "$(unattended_envs 'Test User' test@example.com)")"
assert_captured_ok 'rerun: second install completes' "$INSTALL_LOG"

# rerun: no managed-file differences — `chezmoi diff --exit-code` was removed in
# chezmoi v2.72.2, so compare rendered diff output against empty instead.
run_capture "$CHK" tester 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; out="$(chezmoi diff)"; [ -z "$out" ]'
assert_captured_ok 'rerun: no managed-file differences' "$CHK"

run_capture "$CHK" tester 'git config --global user.name'
assert_captured_ok 'rerun: git identity still present' "$CHK"

finish_suite 'install-test'