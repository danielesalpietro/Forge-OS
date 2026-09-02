#!/usr/bin/env bash
# Vendor third-party Ansible content (collections + roles) so the installed
# system can run the baseline fully offline.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [[ "${FORGE_SKIP_GALAXY:-0}" == "1" ]]; then
  warn "FORGE_SKIP_GALAXY=1: not vendoring Ansible collections/roles"
  exit 0
fi
need ansible-galaxy
dest="${WORK_DIR}/ansible-vendor"
rm -rf "${dest}"
mkdir -p "${dest}/collections" "${dest}/roles"
log "installing Ansible dependencies from ansible/requirements.yml"
ansible-galaxy collection install -r "${REPO_ROOT}/ansible/requirements.yml" -p "${dest}/collections" --force
ansible-galaxy role install -r "${REPO_ROOT}/ansible/requirements.yml" -p "${dest}/roles" --force
log "vendored into ${dest}"
