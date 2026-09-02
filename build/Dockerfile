# Forge-OS builder image: everything needed to remaster the Ubuntu ISO, build the
# offline package repository, vendor Ansible content and run the lint suite.
# ubuntu-server-minimal is installed so that apt can compute the exact package
# delta the target system will need (see build/scripts/20-build-package-repo.sh).
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ubuntu-server-minimal \
      xorriso squashfs-tools dpkg-dev apt-utils \
      gnupg curl ca-certificates rsync gettext-base jq openssl git make \
      python3 python3-yaml python3-jsonschema \
      ansible-core ansible-lint yamllint shellcheck \
 && rm -rf /var/lib/apt/lists/* \
 && git config --system --add safe.directory '*'

WORKDIR /src
CMD ["bash"]
