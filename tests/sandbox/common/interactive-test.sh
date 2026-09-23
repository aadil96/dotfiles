#!/bin/bash
# tests/sandbox/common/interactive-test.sh — fresh interactive install through a
# pseudo-terminal (run.sh --interactive; separate fresh run per distro).
#
# Drives the real installer with NO DOTFILES_NONINTERACTIVE and NO identity env,
# so chezmoi prompts for Git user.name / user.email / (blank) GPG key through a
# pty. A python3 pty feeder answers each prompt ONLY after it appears — this is
# required because chezmoi's prompt (promptui) reads in raw mode and a plain
# `printf ... | script -qec` pipe delivers every line up front, which makes the
# first prompt swallow all answers. python3 is installed in every sandbox image;
# `script` is kept as a fallback when python3 is missing.
# Asserts the pty answers landed in ~/.gitconfig and no signing was configured.
set -euo pipefail

source /opt/sandbox/common/assert.sh

LOG=/tmp/interactive-test.log
INNER='sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply --source /home/tester/dotfiles'

reset_home tester
prepare_repo_copy tester

if command -v python3 >/dev/null 2>&1; then
  set +e
  timeout -k 10 600 python3 - "$INNER" <<'PY' >"$LOG" 2>&1
import os, pty, select, sys, time

cmd = sys.argv[1]
# Raw terminal bytes go to a FILE, never to the suite stdout — the driver
# greps the suite stdout for PASS:/FAIL: lines and raw pty data would corrupt
# it (and look like NUL garbage in the aggregated docker log).
raw = open("/tmp/interactive-test-pty.raw", "wb")
answers = [b"PTY User", b"pty@example.com", b""]  # 3rd = blank GPG key

pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash", "-c", cmd])

out = b""
i = 0
start = time.time()
while True:
    if time.time() - start > 540:  # wall-clock bail: leave clearly before the outer timeout
        break
    r, _, _ = select.select([fd], [], [], 5)
    if not r:
        try:
            wpid, _ = os.waitpid(pid, os.WNOHANG)
        except ChildProcessError:
            break
        if wpid == pid:
            break
        continue
    try:
        data = os.read(fd, 4096)
    except OSError:
        break
    if not data:
        break
    raw.write(data)
    raw.flush()
    out += data
    if i < len(answers):
        match = False
        if i == 0 and b"user.name" in out:
            match = True
        elif i == 1 and b"user.email" in out:
            match = True
        elif i == 2 and (b"GPG" in out or b"fingerprint" in out or b"skip" in out):
            match = True
        if match:
            time.sleep(0.4)
            os.write(fd, answers[i] + b"\r")
            i += 1
            out = b""

# reap the child; if it is still running (e.g. slow network), kill it so the
# suite cannot linger in the container after we exit.
try:
    wpid, _ = os.waitpid(pid, os.WNOHANG)
    if wpid == 0:
        os.kill(pid, 9)
        os.waitpid(pid, 0)
except ChildProcessError:
    pass
raw.close()
# non-zero when any expected prompt went unanswered — the install may still
# have completed in that case, but the pty interaction was incomplete.
sys.exit(0 if i == len(answers) else 1)
PY
  PTY_RC=$?
  set -e
elif command -v script >/dev/null 2>&1; then
  # fallback (python3 absent): feed everything up front — known-intolerant for
  # promptui but better than nothing on exotic images.
  set +e
  printf 'PTY User\npty@example.com\n\n' \
    | timeout 600 script -qec "su - tester -c '$INNER'" /dev/null >"$LOG" 2>&1
  PTY_RC=$?
  set -e
else
  PTY_RC=2
  echo "FATAL: neither python3 nor script available for pty tests" >>"$LOG"
fi

if [ "$PTY_RC" -eq 0 ]; then
  _sa_pass 'interactive install via pty completed'
else
  _sa_fail "interactive install via pty (exit $PTY_RC): $(report_capture "$LOG")"
fi

# pty answers landed in .gitconfig
CHK=/tmp/interactive-test-check.log
run_capture "$CHK" tester 'git config --global user.name'
assert_captured_ok 'pty identity: user.name present' "$CHK"
assert_eq 'pty identity: user.name value' 'PTY User' "$(cat "$CHK")"
run_capture "$CHK" tester 'git config --global user.email'
assert_captured_ok 'pty identity: user.email present' "$CHK"
assert_eq 'pty identity: user.email value' 'pty@example.com' "$(cat "$CHK")"

# blank GPG answer => no signing config
run_capture "$CHK" tester 'git config --global --get commit.gpgsign'
assert_captured_fail 'pty identity: no gpgsign configured (blank GPG answer)' "$CHK"

finish_suite 'interactive-test'