#!/bin/bash
# tests/sandbox/common/entrypoint.sh — in-container suite entrypoint.
#
# Runs one or more suite scripts from /opt/sandbox/common (baked into every
# sandbox image by its Dockerfile). The suite list arrives as CMD/args from
# tests/sandbox/run.sh: `docker run ... image install-test.sh negative-tests.sh`.
# Exits non-zero if any suite failed. Runs as root; suites drive installs as the
# disposable users (tester / nosudo) themselves.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  set -- install-test.sh negative-tests.sh mock-tests.sh
fi

overall_failed=0

for suite in "$@"; do
  case "$suite" in
    /*) path="$suite" ;;
    *)  path="/opt/sandbox/common/$suite" ;;
  esac
  if [ ! -f "$path" ]; then
    printf 'FATAL: suite not found: %s\n' "$path" >&2
    overall_failed=1
    continue
  fi
  printf '\n================ SUITE: %s ================\n' "$(basename "$path")"
  set +e
  if [ "${DOTFILES_SANDBOX_FULL_INSTALL:-}" = "1" ] && [ "$(basename "$path")" != "install-test.sh" ]; then
    DOTFILES_TEST_SKIP_PACKAGES=1 bash "$path"
  else
    bash "$path"
  fi
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    overall_failed=1
  fi
done

exit "$overall_failed"
