#!/bin/bash
# tests/sandbox/common/assert.sh — tiny assertion + environment helpers shared by
# every in-container suite. Source this file, do not execute it.
#
# Contract:
#   * Each helper prints exactly one `PASS: <name>` or `FAIL: <name> <detail>`
#     line on stdout — the driver (tests/sandbox/run.sh) parses those lines.
#   * finish_suite <name> prints a `SUMMARY: ...` line and exits non-zero if any
#     assertion failed.
#   * All probing runs are executed as unprivileged users via `su -`; nothing in
#     this file ever touches the host.
set -euo pipefail

_SA_PASS=0
_SA_FAIL=0

_sa_pass() { _SA_PASS=$((_SA_PASS + 1)); printf 'PASS: %s\n' "$*"; }
_sa_fail() { _SA_FAIL=$((_SA_FAIL + 1)); printf 'FAIL: %s\n' "$*"; }

# --- core assertions ---------------------------------------------------------

# assert_cmd <name> <cmd...> — pass if the command exits 0
assert_cmd() {
  local name="$1"; shift
  local out rc
  set +e
  out=$("$@" 2>&1); rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    _sa_pass "$name"
  else
    _sa_fail "$name (exit $rc): $(printf '%s' "$out" | tail -4 | tr '\n' ' ')"
  fi
}

# assert_fail <name> <cmd...> — pass if the command exits non-zero
assert_fail() {
  local name="$1"; shift
  local out rc
  set +e
  out=$("$@" 2>&1); rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    _sa_pass "$name"
  else
    _sa_fail "$name (expected non-zero exit, got 0): $(printf '%s' "$out" | tail -4 | tr '\n' ' ')"
  fi
}

# assert_eq <name> <expected> <actual>
assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    _sa_pass "$name"
  else
    _sa_fail "$name (expected [$expected], got [$actual])"
  fi
}

# assert_contains <name> <needle> <haystack>
assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) _sa_pass "$name" ;;
    *) _sa_fail "$name (missing [$needle])" ;;
  esac
}

# assert_not_contains <name> <needle> <haystack>
assert_not_contains() {
  local name="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) _sa_fail "$name (unexpected [$needle])" ;;
    *) _sa_pass "$name" ;;
  esac
}

# assert_file <name> <path>
assert_file() {
  local name="$1" path="$2"
  if [ -e "$path" ]; then _sa_pass "$name"; else _sa_fail "$name (missing: $path)"; fi
}

# assert_no_file <name> <path>
assert_no_file() {
  local name="$1" path="$2"
  if [ -e "$path" ]; then _sa_fail "$name (unexpected: $path)"; else _sa_pass "$name"; fi
}

# finish_suite <suite-name>
finish_suite() {
  local suite="${1:-suite}"
  printf 'SUMMARY: %s: %d passed, %d failed\n' "$suite" "$_SA_PASS" "$_SA_FAIL"
  if [ "$_SA_FAIL" -ne 0 ]; then
    printf 'RESULT: %s: FAIL\n' "$suite"
    exit 1
  fi
  printf 'RESULT: %s: PASS\n' "$suite"
  exit 0
}

# --- environment / run helpers -----------------------------------------------

# run_user <user> <cmd...> — execute a shell command line as the named user via a
# login shell (fresh environment; HOME is the user's home). Fails hard under
# `set -e`; for probing failures use run_capture instead.
run_user() {
  local user="$1"; shift
  su - "$user" -c "$*"
}

# run_capture <outfile> <user> <cmd...> — run as user, capture combined output to
# outfile, set CAPTURED_RC. Never aborts the suite.
run_capture() {
  local outfile="$1" user="$2"; shift 2
  local cmd="$*"
  set +e
  su - "$user" -c "$cmd" >"$outfile" 2>&1
  CAPTURED_RC=$?
  set -e
}

CAPTURED_RC=0

# report_capture <outfile> — one-line trailing summary of a captured log
report_capture() { tail -8 "$1" 2>/dev/null | tr '\n' ' '; }

# assert_captured_ok <name> <outfile> — asserts the previous run_capture exited 0
assert_captured_ok() {
  local name="$1" out="$2"
  if [ "${CAPTURED_RC:-1}" -eq 0 ]; then
    _sa_pass "$name"
  else
    _sa_fail "$name (exit ${CAPTURED_RC:-1}): $(report_capture "$out")"
  fi
}

# assert_captured_fail <name> <outfile> — asserts the previous run_capture exited non-zero
assert_captured_fail() {
  local name="$1" out="$2"
  if [ "${CAPTURED_RC:-0}" -ne 0 ]; then
    _sa_pass "$name"
  else
    _sa_fail "$name (expected non-zero exit, got 0)"
  fi
}

# --- home / repo fixtures ----------------------------------------------------

# reset_home <user> — wipe applied-state of a user's home for hermetic tests.
# Keeps /home/<user>/dotfiles (the writable candidate-checkout copy) intact.
reset_home() {
  local user="$1"
  local home="/home/$user"
  rm -rf "$home/.config" "$home/.local" "$home/.cache" "$home/.gitconfig" \
         "$home/.zshrc" "$home/.bashrc" "$home/.profile" "$home/.bash_profile" \
         "$home/.tmux.conf" "$home/.wezterm.lua" "$home/.gnupg" "$home/.zsh" \
         "$home/.oh-my-zsh" "$home/.zsh_history" "$home/.vimrc" \
         /tmp/xdgtest 2>/dev/null || true
  mkdir -p "$home"
  chown "$user:$user" "$home"
}

# prepare_repo_copy <user> — copy the read-only /repo mount into the user's home.
# The copy MUST be writable by the user: chezmoi runs `git init` inside the
# candidate-checkout source.
prepare_repo_copy() {
  local user="$1"
  local home="/home/$user"
  rm -rf "$home/dotfiles"
  cp -a /repo "$home/dotfiles"
  chown -R "$user:$user" "$home/dotfiles"
}

# --- portable installer plumbing ----------------------------------------------

# unattended_envs <name> <email> [extra env...] — echo env assignments for an
# unattended install. DOTFILES_TEST_SKIP_PACKAGES=1 is included when the
# container was started in the fast lane (see tests/sandbox/run.sh --full).
unattended_envs() {
  local name="$1" email="$2"; shift 2
  local s="DOTFILES_NONINTERACTIVE=1"
  if [ "${DOTFILES_TEST_SKIP_PACKAGES:-}" = "1" ]; then
    s="$s DOTFILES_TEST_SKIP_PACKAGES=1"
  fi
  for extra in "$@"; do
    s="$s $extra"
  done
  printf '%s GIT_USER_NAME="%s" GIT_USER_EMAIL="%s"' "$s" "$name" "$email"
}

# install_cmd <env-assignments> — echo the full bootstrap command line executed
# in the tests (identical shape to the documented one-liner, with --source for
# candidate-checkout mode). Wrapped in timeout so a wedged install cannot hang
# the suite indefinitely.
install_cmd() {
  local tmo="${SANDBOX_INSTALL_TIMEOUT:-1200}"
  printf '%s timeout %s sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply --source /home/tester/dotfiles' "$1" "$tmo"
}

# tz_run <cmd...> — run a command as `tester` with the tool PATH (~/.local/bin
# from chezmoi externals + ~/bin where the get.chezmoi.io bootstrap installs).
tz_run() {
  run_user tester 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH";' "$@"
}