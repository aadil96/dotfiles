# tests/sandbox/arch/Dockerfile — disposable Arch Linux install sandbox.
# Build context is the repo root: docker build -f tests/sandbox/arch/Dockerfile .
# Note: `pacman -Syu` (full upgrade) precedes package install to avoid partial
# upgrade breakage on the rolling base image.
FROM archlinux:latest

RUN pacman -Syu --noconfirm \
 && pacman -S --noconfirm --needed sudo curl git ca-certificates util-linux python

RUN useradd -m -u 1000 -s /bin/bash tester \
 && useradd -m -u 1001 -s /bin/bash nosudo \
 && echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester \
 && chmod 440 /etc/sudoers.d/tester

COPY tests/sandbox/common /opt/sandbox/common

ENV HOME=/home/tester
ENV DOTFILES_TEST_SKIP_PACKAGES=1

ENTRYPOINT ["/opt/sandbox/common/entrypoint.sh"]
CMD ["install-test.sh", "negative-tests.sh", "mock-tests.sh"]