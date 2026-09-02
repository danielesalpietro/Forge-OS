#!/usr/bin/env bash
# Install the KVM test dependencies (Ubuntu/Debian host or GitHub Actions runner).
set -euo pipefail
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  qemu-system-x86 qemu-utils ovmf swtpm swtpm-tools openssh-client jq socat
# Allow the current user to use /dev/kvm (GitHub-hosted Linux runners expose KVM).
if [[ -e /dev/kvm ]] && ! [[ -w /dev/kvm ]]; then
  echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules >/dev/null
  sudo udevadm control --reload-rules && sudo udevadm trigger --name-match=kvm
fi
ls -l /dev/kvm || echo "WARNING: /dev/kvm not available, QEMU will fall back to TCG (very slow)"
