# tests/sandbox/debian/Dockerfile — disposable Debian 13 install sandbox.
# Build context is the repo root: docker build -f tests/sandbox/debian/Dockerfile .
FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive

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
ENV DOTFILES_TEST_SKIP_PACKAGES=1

ENTRYPOINT ["/opt/sandbox/common/entrypoint.sh"]
CMD ["install-test.sh", "negative-tests.sh", "mock-tests.sh"]