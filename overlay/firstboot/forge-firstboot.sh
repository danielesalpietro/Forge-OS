#!/usr/bin/env bash
# Forge-OS first boot: apply the Ansible baseline, enrol TPM2 unlock, rotate the
# build-time LUKS key, validate, scrub installer secrets, reboot.
set -euo pipefail
STATE=/var/lib/forge
LOGDIR=/var/log/forge
FORGE=/opt/forge
mkdir -p "${STATE}" "${LOGDIR}"
exec > >(tee -a "${LOGDIR}/firstboot.log") 2>&1
log() { printf '[forge-firstboot %s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

[[ -f "${STATE}/firstboot.done" ]] && { log "already completed"; exit 0; }
exec 9>"${STATE}/firstboot.lock"; flock -n 9 || { log "another run is in progress"; exit 1; }

# shellcheck disable=SC1091
source /etc/forge/forge.conf
for f in /etc/forge/forge.conf.d/*.conf; do
  # shellcheck disable=SC1090
  [[ -f "$f" ]] && source "$f"
done
: "${FORGE_PROFILE:=baseline}" "${FORGE_REBOOT_AFTER_FIRSTBOOT:=yes}" "${FORGE_ANSIBLE_EXTRA_VARS:=/etc/forge/ansible-extra-vars.yml}"
log "Forge-OS ${FORGE_VERSION:-?} profile=${FORGE_PROFILE} starting first boot on $(hostname)"

# ---- 1. configuration management (offline) ---------------------------------
cd "${FORGE}/ansible"
export ANSIBLE_CONFIG="${FORGE}/ansible/ansible.cfg"
export ANSIBLE_LOG_PATH="${LOGDIR}/ansible-firstboot.log"
export ANSIBLE_FORCE_COLOR=0
extra=()
[[ -f "${FORGE_ANSIBLE_EXTRA_VARS}" ]] && extra+=(-e "@${FORGE_ANSIBLE_EXTRA_VARS}")
rc=0
ansible-playbook -i inventories/local.ini playbooks/site.yml \
  -e "forge_profile=${FORGE_PROFILE}" \
  -e "forge_tpm_enroll=${FORGE_TPM_ENROLL:-auto}" \
  -e "forge_tpm_pcrs=${FORGE_TPM_PCRS:-7}" \
  -e "forge_tang_urls=${FORGE_TANG_URLS:-}" \
  -e "forge_cis_level=${FORGE_CIS_LEVEL:-1}" \
  -e "forge_identity_backend=${FORGE_IDENTITY_BACKEND:-none}" \
  -e "forge_pro_token_file=${FORGE_PRO_TOKEN_FILE:-/etc/forge/pro-token}" \
  "${extra[@]}" || rc=$?
if [[ ${rc} -ne 0 ]]; then
  log "ERROR: baseline playbook failed (rc=${rc}); see ${ANSIBLE_LOG_PATH}"
  echo "${rc}" > "${STATE}/firstboot.failed"
  # Do not mark done: the unit retries on the next boot after the operator fixes the cause.
  exit "${rc}"
fi
log "baseline applied"

# ---- 2. validation ----------------------------------------------------------
forge-validate --json > "${STATE}/validation-report.json" || log "WARNING: validation reported failures (see forge-validate)"
forge-validate --text | tee "${STATE}/validation-report.txt" || true

# ---- 3. scrub installer artefacts that contain the build-time LUKS key ---------
for f in /var/log/installer/autoinstall-user-data /var/log/installer/curtin-install-cfg.yaml \
         /var/log/installer/curtin-install/*.yaml /var/log/forge/installer-server-debug.log \
         /etc/forge/luks-build-key /opt/forge/keys/luks-build-key; do
  [[ -e "$f" ]] && { shred -u "$f" 2>/dev/null || rm -f "$f"; log "scrubbed $f"; }
done
rm -rf /opt/forge/keys

# ---- 4. done ------------------------------------------------------------------
date -u +%Y-%m-%dT%H:%M:%SZ > "${STATE}/firstboot.done"
rm -f "${STATE}/firstboot.failed"
systemctl disable forge-firstboot.service >/dev/null 2>&1 || true
log "first boot complete"
if [[ "${FORGE_REBOOT_AFTER_FIRSTBOOT}" == "yes" ]]; then
  log "rebooting to activate kernel parameters, initramfs (TPM unlock) and audit rules"
  systemctl reboot
fi
