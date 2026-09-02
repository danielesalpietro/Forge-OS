#!/usr/bin/env bash
# Executed by autoinstall late-commands *inside the target system* (chroot):
#   curtin in-target --target=/target -- /opt/forge/overlay/install/late-install.sh
# Keep it minimal and idempotent: everything else happens at first boot.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
log() { printf '[forge-late-install] %s\n' "$*"; }

FORGE=/opt/forge
install -d -m 0750 /etc/forge /var/lib/forge /var/log/forge
install -m 0644 "${FORGE}/overlay/etc/forge.conf" /etc/forge/forge.conf
install -d -m 0755 /etc/forge/forge.conf.d
install -m 0644 "${FORGE}/overlay/etc/forge.conf.d/README" /etc/forge/forge.conf.d/README

# Offline repository embedded in the ISO (also used by the first-boot run).
if [[ -f "${FORGE}/repo/Packages.gz" ]]; then
  echo "deb [trusted=yes] file:${FORGE}/repo ./" > /etc/apt/sources.list.d/forge-offline.list
  log "offline repository enabled"
fi
apt-get update -qq || log "apt-get update failed (offline mirror unreachable?) - continuing with local repo"

# Minimum tool set for the first boot: configuration management + TPM/LUKS stack.
apt-get install -y -qq --no-install-recommends \
  ansible-core python3-jmespath python3-netaddr \
  clevis clevis-luks clevis-tpm2 clevis-initramfs tpm2-tools cryptsetup-initramfs \
  mokutil efibootmgr jq
log "first-boot prerequisites installed"

# Validation suite + first-boot service.
install -m 0755 "${FORGE}/validate/forge-validate" /usr/local/sbin/forge-validate
install -m 0755 "${FORGE}/overlay/firstboot/forge-firstboot.sh" /usr/local/sbin/forge-firstboot
install -m 0644 "${FORGE}/overlay/firstboot/forge-firstboot.service" /etc/systemd/system/forge-firstboot.service
install -m 0644 "${FORGE}/overlay/etc/motd-forge" /etc/update-motd.d/00-forge 2>/dev/null || true
chmod 0755 /etc/update-motd.d/00-forge 2>/dev/null || true
systemctl enable forge-firstboot.service
log "forge-firstboot.service enabled"

# Root is never a login account on Forge-OS.
passwd -l root >/dev/null
log "root account locked"
