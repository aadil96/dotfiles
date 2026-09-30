# tests/sandbox/ubuntu/Dockerfile — disposable Ubuntu 24.04 install sandbox.
# Build context is the repo root: docker build -f tests/sandbox/ubuntu/Dockerfile .
#
# Creates disposable users (tester: passwordless sudo; nosudo: none), installs
# the base tools the portable installer needs, and bakes in the in-container
# suite library. ENTRYPOINT runs the suite(s) passed as CMD/args by run.sh.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# ubuntu:24.04 ships an `ubuntu` user at uid 1000 — free the uid for `tester`.
RUN userdel -r ubuntu 2>/dev/null || true

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      sudo curl git ca-certificates util-linux python3 \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 -s /bin/bash tester \
 && useradd -m -u 1001 -s /bin/bash nosudo \
 && echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester \
 && chmod 440 /etc/sudoers.d/tester

COPY tests/sandbox/common /opt/sandbox/common

ENV HOME=/home/tester
# Fast lane by default; run.sh --full overrides with DOTFILES_TEST_SKIP_PACKAGES=0.
ENV DOTFILES_TEST_SKIP_PACKAGES=1

ENTRYPOINT ["/opt/sandbox/common/entrypoint.sh"]
CMD ["install-test.sh", "negative-tests.sh", "mock-tests.sh"]