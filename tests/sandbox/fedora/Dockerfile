# tests/sandbox/fedora/Dockerfile — disposable Fedora 41 install sandbox.
# Build context is the repo root: docker build -f tests/sandbox/fedora/Dockerfile .
FROM fedora:41

RUN dnf install -y sudo curl git ca-certificates util-linux python3 \
 && dnf clean all

RUN useradd -m -u 1000 -s /bin/bash tester \
 && useradd -m -u 1001 -s /bin/bash nosudo \
 && echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester \
 && chmod 440 /etc/sudoers.d/tester

COPY tests/sandbox/common /opt/sandbox/common

ENV HOME=/home/tester
ENV DOTFILES_TEST_SKIP_PACKAGES=1

ENTRYPOINT ["/opt/sandbox/common/entrypoint.sh"]
CMD ["install-test.sh", "negative-tests.sh", "mock-tests.sh"]