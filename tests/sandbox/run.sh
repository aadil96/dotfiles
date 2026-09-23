#!/bin/bash
# tests/sandbox/run.sh — disposable-container verification of the portable
# installer. NEVER runs tests on the host: every test executes inside throwaway
# Docker containers that mount only a read-only copy of the repo source
# (`git archive HEAD`) plus the env vars the tests set. No host credentials,
# ~/.ssh, ~/.config, or the docker socket are ever mounted.
#
# Usage:
#   tests/sandbox/run.sh                     # all four distros, fast lanes
#   tests/sandbox/run.sh --distro ubuntu     # single distro
#   tests/sandbox/run.sh --full              # full mise install lane (slow)
#   tests/sandbox/run.sh --interactive       # also run the pty interactive suite
#
# Fast lane (default) sets DOTFILES_TEST_SKIP_PACKAGES=1 inside the containers;
# --full runs the full `mise install`. Sums PASS/FAIL per test per distro and
# exits non-zero on any failure.
#
# After the feature branch merges, the same suite covers the documented GitHub
# command (INSTALL_SOURCE=github) — until then candidate-checkout (--source) is
# the tested path. For pre-commit local runs set SANDBOX_SOURCE=worktree to
# archive the working tree (excluding .git/node_modules) instead of `HEAD`.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISTROS=(ubuntu debian fedora arch)
ALL_DISTROS=" ubuntu debian fedora arch "

DISTRO=""
FULL=0
INTERACTIVE=0

usage() {
  cat <<'EOF'
Usage: run.sh [--distro ubuntu|debian|fedora|arch] [--full] [--interactive]

  --distro DISTRO   run a single distro (default: all four)
  --full            run the full mise-install lane (DOTFILES_TEST_SKIP_PACKAGES=0)
  --interactive     also run the pty-driven interactive install suite
  -h, --help        show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --distro) DISTRO="${2:-}"; shift 2 ;;
    --full) FULL=1; shift ;;
    --interactive) INTERACTIVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

if [ -n "$DISTRO" ] && [[ "$ALL_DISTROS" != *" $DISTRO "* ]]; then
  echo "ERROR: unknown distro '$DISTRO' (expected one of: ${DISTROS[*]})" >&2
  exit 2
fi

SELECTED=()
if [ -n "$DISTRO" ]; then SELECTED=("$DISTRO"); else SELECTED=("${DISTROS[@]}"); fi

# --- Docker must be reachable; the harness never falls back to the host --------
if ! docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
  echo "ERROR: Docker daemon not reachable — the sandbox harness only runs inside Docker." >&2
  exit 1
fi

# --- read-only candidate source: git archive HEAD (exactly what CI tests) --------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
chmod 755 "$TMP"

if [ "${SANDBOX_SOURCE:-head}" = "worktree" ]; then
  echo "==> archiving working tree (SANDBOX_SOURCE=worktree; excludes .git, node_modules)"
  tar --exclude='./.git' --exclude='./node_modules' -cf - -C "$REPO_ROOT" . | tar -xf - -C "$TMP"
else
  echo "==> archiving git HEAD"
  git -C "$REPO_ROOT" archive HEAD | tar -x -C "$TMP"
fi
chmod -R a+rX "$TMP" 2>/dev/null || true

# --- build the sandbox images -----------------------------------------------------
for d in "${SELECTED[@]}"; do
  echo "==> building image dotfiles-sandbox:$d"
  docker build -q -t "dotfiles-sandbox:$d" -f "$REPO_ROOT/tests/sandbox/$d/Dockerfile" "$REPO_ROOT"
done

# --- run suites per distro ----------------------------------------------------------
declare -A DIST_PASS DIST_FAIL DIST_SUITES
overall_failed=0

for d in "${SELECTED[@]}"; do
  SUITES=(install-test.sh negative-tests.sh mock-tests.sh)
  if [ "$INTERACTIVE" -eq 1 ]; then
    SUITES+=(interactive-test.sh)
  fi

  SKIP_ENV=(-e DOTFILES_TEST_SKIP_PACKAGES=1)
  [ "$FULL" -eq 1 ] && SKIP_ENV=(-e DOTFILES_TEST_SKIP_PACKAGES=0)

  log="/tmp/sandbox-$d.log"
  echo "==> running on $d: ${SUITES[*]} $( [ "$FULL" -eq 1 ] && echo '(--full)' )"

  set +e
  docker run --rm "${SKIP_ENV[@]}" -v "$TMP:/repo:ro" "dotfiles-sandbox:$d" "${SUITES[@]}" >"$log" 2>&1
  RC=$?
  set -e

  passes=$(grep -ac '^PASS:' "$log" || true)
  fails=$(grep -ac '^FAIL:' "$log" || true)
  DIST_PASS[$d]=$passes
  DIST_FAIL[$d]=$fails
  DIST_SUITES[$d]="${SUITES[*]}"

  echo "---- $d suite log (PASS/FAIL/SUMMARY) ----"
  grep -aE '^(PASS|FAIL|SUMMARY|RESULT):' "$log" || true
  if [ "$RC" -ne 0 ]; then overall_failed=1; fi
  echo "-------------------------------------------"
done

# --- summary table -------------------------------------------------------------------
echo
echo "===== SANDBOX SUMMARY ====="
printf '%-9s %-40s %-16s %s\n' 'Distro' 'Suites' 'Passed/Failed' 'Result'
for d in "${SELECTED[@]}"; do
  p="${DIST_PASS[$d]:-0}"
  f="${DIST_FAIL[$d]:-0}"
  result="PASS"
  [ "$f" -gt 0 ] && result="FAIL"
  printf '%-9s %-40s %-16s %s\n' "$d" "${DIST_SUITES[$d]}" "$p/$f" "$result"
done
echo "==========================="

if [ "$overall_failed" -ne 0 ]; then
  echo "SANDBOX RESULT: FAIL (see per-distro logs above)"
  exit 1
fi
echo "SANDBOX RESULT: PASS"
exit 0