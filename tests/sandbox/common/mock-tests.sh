#!/bin/bash
# tests/sandbox/common/mock-tests.sh — service opt-in tests using command STUBS
# only. NEVER performs a real Tailscale enrollment, never touches a real
# systemd, and never imports personal GPG keys.
#
#   * installs once with GPG_KEY set (verifies the absent-local-key path:
#     git signing gets disabled, hook logs a SKIP — real gpg present but the
#     fabricated key does not exist),
#   * renders the tailscale + gpg-preset hooks with `chezmoi execute-template`
#     and runs them on a PATH of stubs: fake `cat` reports systemd as PID 1,
#     fake `systemctl` logs and exits 0, fake `sudo` preserves env, fake
#     `tailscale` records argv+TS_AUTHKEY, fake `gpg` succeeds,
#   * asserts the opt-in contract: TS_AUTHKEY travels in the environment (never
#     as --authkey=), --ssh/--accept-routes appear only when opted in.
set -euo pipefail

source /opt/sandbox/common/assert.sh

MOCK=/tmp/mock-tests.log
CHK=/tmp/mock-tests-check.log
STUB=/tmp/stubs
STUBLOG=/tmp/stubs-calls.log
FAKE_KEY=FAKEFPR1234

reset_home tester
prepare_repo_copy tester

# --- GPG_KEY-set install: hook must run + skip (container has no systemctl), and
# the rendered hook under stubs must disable signing when the key is absent -------
run_capture "$MOCK" tester "$(install_cmd "$(unattended_envs 'Mock User' mock@example.com GPG_KEY=$FAKE_KEY)")"
assert_captured_ok 'install with GPG_KEY set completes' "$MOCK"
# --exclude=scripts: the plain `run_before_00-conflicts` guard's script target is
# run-but-never-materialized by chezmoi v2.72, so `chezmoi diff` reports it as a
# perpetual "new file"; excluding scripts asserts real-file differences only.
run_capture "$CHK" tester 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; out="$(chezmoi diff --exclude=scripts)"; [ -z "$out" ]'
assert_captured_ok 'install with GPG_KEY set: apply leaves no diffs' "$CHK"
if grep -q 'SKIP: gpg-preset service' "$MOCK"; then
  _sa_pass 'GPG_KEY set: gpg-preset hook logged a skip in this container'
else
  _sa_fail 'GPG_KEY set: gpg-preset hook skip not logged'
fi

# --- stub infrastructure ------------------------------------------------------------
mkdir -p "$STUB"
: > "$STUBLOG"
# stubs append as the disposable user; the log must be group/world-writable.
chmod 666 "$STUBLOG"
REAL_CAT="$(PATH=/usr/bin:/bin command -v cat)"

cat > "$STUB/cat" <<EOF
#!/bin/bash
# fake cat: reports systemd as PID 1, otherwise behaves like the real cat
if [ "\$*" = "/proc/1/comm" ]; then printf 'systemd\n'; exit 0; fi
exec "$REAL_CAT" "\$@"
EOF

cat > "$STUB/systemctl" <<EOF
#!/bin/bash
echo "SYSTEMCTL: \$*" >> "$STUBLOG"
exit 0
EOF

cat > "$STUB/tailscale" <<EOF
#!/bin/bash
{
  echo "TAILSCALE: \$*"
  echo "TS_AUTHKEY=\${TS_AUTHKEY:-<unset>}"
} >> "$STUBLOG"
exit 0
EOF

cat > "$STUB/sudo" <<EOF
#!/bin/bash
# fake sudo: drop -E (we preserve the environment anyway) and exec the command
args=()
for a in "\$@"; do [ "\$a" = "-E" ] || args+=("\$a"); done
exec "\${args[@]}"
EOF

# fake gpg lives in its own dir so the disable-path test can run with the REAL
# gpg (which fails on the fabricated key).
mkdir -p "$STUB/gpg-only"
cat > "$STUB/gpg-only/gpg" <<EOF
#!/bin/bash
# fake gpg: pretend every key exists locally
exit 0
EOF
chmod +x "$STUB"/* "$STUB/gpg-only"/*

# render hooks once (config data from the GPG_KEY install above)
run_capture "$CHK" tester 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; cd /home/tester/dotfiles && chezmoi execute-template < .chezmoiscripts/run_onchange_after_03-tailscale.sh.tmpl > /tmp/hook03.sh && chezmoi execute-template < .chezmoiscripts/run_onchange_after_02-enable-gpg-preset.sh.tmpl > /tmp/hook02.sh'
assert_captured_ok 'mock: hooks render via chezmoi execute-template' "$CHK"

# --- tailscale opt-in: defaults (no ssh, no accept-routes) -----------------------------
: > "$STUBLOG"
run_capture "$CHK" tester 'export PATH="/tmp/stubs:$PATH"; DOTFILES_TEST_SKIP_PACKAGES=1 TAILSCALE_AUTHKEY=tskey-test-abc bash /tmp/hook03.sh'
assert_captured_ok 'mock tailscale: hook runs with authkey set' "$CHK"

CALLS="$(cat "$STUBLOG")"
assert_contains 'mock tailscale: stub tailscale up invoked' 'TAILSCALE: up' "$CALLS"
assert_contains 'mock tailscale: TS_AUTHKEY passed via env' 'TS_AUTHKEY=tskey-test-abc' "$CALLS"
assert_not_contains 'mock tailscale: no --ssh by default' '--ssh' "$CALLS"
assert_not_contains 'mock tailscale: no --accept-routes by default' '--accept-routes' "$CALLS"
assert_not_contains 'mock tailscale: authkey never in argv' '--authkey=' "$CALLS"
assert_contains 'mock tailscale: tailscaled managed via systemctl stub' 'SYSTEMCTL: enable --now tailscaled' "$CALLS"

# --- tailscale opt-in: --ssh + --accept-routes -------------------------------------------
: > "$STUBLOG"
run_capture "$CHK" tester 'export PATH="/tmp/stubs:$PATH"; DOTFILES_TEST_SKIP_PACKAGES=1 TAILSCALE_AUTHKEY=tskey-test-abc TAILSCALE_SSH=1 TAILSCALE_ACCEPT_ROUTES=1 bash /tmp/hook03.sh'
assert_captured_ok 'mock tailscale: hook runs with ssh/routes opted in' "$CHK"

CALLS="$(cat "$STUBLOG")"
assert_contains 'mock tailscale: --ssh present when opted in' '--ssh' "$CALLS"
assert_contains 'mock tailscale: --accept-routes present when opted in' '--accept-routes' "$CALLS"
assert_contains 'mock tailscale: TS_AUTHKEY still via env' 'TS_AUTHKEY=tskey-test-abc' "$CALLS"
assert_not_contains 'mock tailscale: authkey still never in argv' '--authkey=' "$CALLS"

# --- gpg-preset: unit + helper, then disable path, then enable path (stubs only) -------
mkdir -p /home/tester/.config/systemd/user
cp /home/tester/dotfiles/dot_config/systemd/user/gpg-sign-preset.service /home/tester/.config/systemd/user/gpg-sign-preset.service
run_capture "$CHK" tester 'mkdir -p "$HOME/.local/bin" && printf "#!/bin/bash\nexit 0\n" > "$HOME/.local/bin/gpg-sign-preset" && chmod +x "$HOME/.local/bin/gpg-sign-preset"'
assert_captured_ok 'mock gpg-preset: unit + helper placed' "$CHK"

# disable path: stubs WITHOUT fake gpg — real gpg cannot find the fabricated key,
# so the hook must disable git signing.
: > "$STUBLOG"
run_capture "$CHK" tester 'export PATH="/tmp/stubs:$PATH"; XDG_RUNTIME_DIR=/tmp/xdg-runtime DOTFILES_TEST_SKIP_PACKAGES=1 bash /tmp/hook02.sh'
assert_captured_ok 'mock gpg-preset disable: hook runs under stubs (real gpg, key absent)' "$CHK"
if grep -q 'disabling git signing' "$CHK"; then
  _sa_pass 'mock gpg-preset disable: absent key disables git signing'
else
  _sa_fail 'mock gpg-preset disable: "disabling git signing" message missing'
fi
run_capture "$CHK" tester 'git config --global --get commit.gpgsign'
assert_captured_fail 'mock gpg-preset disable: gpgsign removed from .gitconfig' "$CHK"

# enable path: fake gpg reports the key exists -> service gets enabled.
: > "$STUBLOG"
run_capture "$CHK" tester 'export PATH="/tmp/stubs/gpg-only:/tmp/stubs:$PATH"; XDG_RUNTIME_DIR=/tmp/xdg-runtime DOTFILES_TEST_SKIP_PACKAGES=1 bash /tmp/hook02.sh'
assert_captured_ok 'mock gpg-preset enable: hook runs under stubs (fake gpg, key present)' "$CHK"
CALLS="$(cat "$STUBLOG")"
assert_contains 'mock gpg-preset enable: service enabled via systemctl stub' 'SYSTEMCTL: --user enable --now gpg-sign-preset.service' "$CALLS"
assert_not_contains 'mock gpg-preset enable: no disable message in enable run' 'disabling git signing' "$CHK"

finish_suite 'mock-tests'