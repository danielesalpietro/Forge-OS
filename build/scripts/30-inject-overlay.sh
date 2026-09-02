#!/usr/bin/env bash
# Render the autoinstall profile and copy the Forge-OS payload (first-boot
# service, Ansible content, validation suite, release metadata) under /forge.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need envsubst rsync python3 openssl

[[ -d "${ISO_DIR}" ]] || die "work tree missing, run 10-extract-iso.sh"
[[ -d "${PROFILE_DIR}" ]] || die "unknown profile '${PROFILE}' (expected ${PROFILE_DIR})"

# ---- inputs (secrets come from the environment, never from the repo) -------
: "${FORGE_ADMIN_USER:=forge}"
: "${FORGE_HOSTNAME:=forge-node}"
: "${FORGE_TIMEZONE:=Etc/UTC}"
: "${FORGE_KERNEL_ARGS:=}"
# Initial admin public key: environment variable, else the key committed in
# autoinstall/keys/forge-admin.pub (public material only, safe to version).
if [[ -z "${FORGE_ADMIN_SSH_KEY:-}" && -s "${REPO_ROOT}/autoinstall/keys/forge-admin.pub" ]]; then
  FORGE_ADMIN_SSH_KEY="$(head -n1 "${REPO_ROOT}/autoinstall/keys/forge-admin.pub")"
  log "using admin key from autoinstall/keys/forge-admin.pub (${FORGE_ADMIN_SSH_KEY##* })"
fi
[[ -n "${FORGE_ADMIN_SSH_KEY:-}" ]] || die "FORGE_ADMIN_SSH_KEY must contain the initial admin's SSH public key (or commit it to autoinstall/keys/forge-admin.pub)"
[[ "${FORGE_ADMIN_SSH_KEY}" =~ ^(ssh-ed25519|sk-ssh-ed25519@openssh.com|ssh-rsa)\ [A-Za-z0-9+/=]+ ]] || die "FORGE_ADMIN_SSH_KEY does not look like an OpenSSH public key"
if [[ -n "${FORGE_LUKS_PASSPHRASE_FILE:-}" ]]; then
  FORGE_LUKS_PASSPHRASE="$(<"${FORGE_LUKS_PASSPHRASE_FILE}")"
fi
if [[ -z "${FORGE_LUKS_PASSPHRASE:-}" ]]; then
  FORGE_LUKS_PASSPHRASE="$(openssl rand -base64 33)"
  warn "FORGE_LUKS_PASSPHRASE not set: generated a random build passphrase."
  warn "It is rotated at first boot (TPM enrolment + recovery key); keep the ISO private regardless."
fi
if [[ -z "${FORGE_ADMIN_PASSWORD_HASH:-}" ]]; then
  # Random, discarded password => account usable only via SSH key (sudo is NOPASSWD for forge-admin).
  FORGE_ADMIN_PASSWORD_HASH="$(openssl passwd -6 "$(openssl rand -base64 24)")"
fi
export FORGE_ADMIN_USER FORGE_HOSTNAME FORGE_TIMEZONE FORGE_KERNEL_ARGS FORGE_ADMIN_SSH_KEY \
       FORGE_LUKS_PASSPHRASE FORGE_ADMIN_PASSWORD_HASH

# ---- autoinstall (cloud-init NoCloud seed) ---------------------------------
mkdir -p "${FORGE_DIR}/autoinstall"
render_vars='${FORGE_VERSION} ${FORGE_CODENAME} ${PROFILE} ${UBUNTU_CODENAME} ${FORGE_ADMIN_USER} ${FORGE_HOSTNAME} ${FORGE_TIMEZONE} ${FORGE_ADMIN_SSH_KEY} ${FORGE_LUKS_PASSPHRASE} ${FORGE_ADMIN_PASSWORD_HASH}'
envsubst "${render_vars}" < "${PROFILE_DIR}/user-data" > "${FORGE_DIR}/autoinstall/user-data"
cp "${PROFILE_DIR}/meta-data" "${FORGE_DIR}/autoinstall/meta-data"
: > "${FORGE_DIR}/autoinstall/vendor-data"
chmod 0644 "${FORGE_DIR}"/autoinstall/*
python3 "${BUILD_DIR}/scripts/validate-autoinstall.py" "${FORGE_DIR}/autoinstall/user-data"

# The build passphrase is copied to /etc/forge/luks-build-key by late-commands
# and consumed (then destroyed) by the first-boot key rotation.
mkdir -p "${FORGE_DIR}/keys"
printf '%s' "${FORGE_LUKS_PASSPHRASE}" > "${FORGE_DIR}/keys/luks-build-key"

# ---- payload -----------------------------------------------------------------
log "copying overlay, Ansible content and validation suite"
rsync -a --delete "${REPO_ROOT}/overlay/" "${FORGE_DIR}/overlay/"
: "${FORGE_TPM_ENROLL:=auto}" "${FORGE_TPM_PCRS:=7}" "${FORGE_TANG_URLS:=}" "${FORGE_CIS_LEVEL:=1}" \
  "${FORGE_IDENTITY_BACKEND:=none}" "${FORGE_REBOOT_AFTER_FIRSTBOOT:=yes}"
export FORGE_TPM_ENROLL FORGE_TPM_PCRS FORGE_TANG_URLS FORGE_CIS_LEVEL FORGE_IDENTITY_BACKEND FORGE_REBOOT_AFTER_FIRSTBOOT
envsubst '${FORGE_VERSION} ${PROFILE} ${FORGE_ADMIN_USER} ${FORGE_TPM_ENROLL} ${FORGE_TPM_PCRS} ${FORGE_TANG_URLS} ${FORGE_CIS_LEVEL} ${FORGE_IDENTITY_BACKEND} ${FORGE_REBOOT_AFTER_FIRSTBOOT}' \
  < "${REPO_ROOT}/overlay/etc/forge.conf.tmpl" > "${FORGE_DIR}/overlay/etc/forge.conf"
rm -f "${FORGE_DIR}/overlay/etc/forge.conf.tmpl"
rsync -a --delete --exclude 'molecule' --exclude '.cache' "${REPO_ROOT}/ansible/" "${FORGE_DIR}/ansible/"
if [[ -d "${WORK_DIR}/ansible-vendor" ]]; then
  rsync -a "${WORK_DIR}/ansible-vendor/" "${FORGE_DIR}/ansible/vendor/"
fi
rsync -a --delete "${REPO_ROOT}/tests/validate/" "${FORGE_DIR}/validate/"
chmod 0755 "${FORGE_DIR}"/validate/forge-validate "${FORGE_DIR}"/overlay/firstboot/*.sh "${FORGE_DIR}"/overlay/install/*.sh

# Release metadata (becomes /etc/forge-release on the installed system).
cat > "${FORGE_DIR}/forge-release" <<REL
FORGE_VERSION=${FORGE_VERSION}
FORGE_CODENAME=${FORGE_CODENAME}
FORGE_PROFILE=${PROFILE}
FORGE_BASE=ubuntu-${UBUNTU_POINT}
FORGE_BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FORGE_GIT_SHA=$(git_sha)
REL

python3 - "${FORGE_DIR}/manifest.json" <<PY
import json, os, sys, datetime
json.dump({
  "name": "forge-os",
  "version": os.environ["FORGE_VERSION"],
  "codename": os.environ["FORGE_CODENAME"],
  "profile": os.environ["PROFILE"],
  "arch": os.environ["ARCH"],
  "base_iso": os.path.basename(os.environ["BASE_ISO_URL"]),
  "base_iso_sha256": os.environ.get("BASE_ISO_SHA256", ""),
  "git_sha": "$(git_sha)",
  "build_date": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
  "admin_user": os.environ["FORGE_ADMIN_USER"],
  "hostname": os.environ["FORGE_HOSTNAME"],
}, open(sys.argv[1], "w"), indent=2)
PY
log "payload injected under ${FORGE_DIR}"
