#!/usr/bin/env bash
# Replace the stock GRUB menu with the Forge-OS one (autoinstall by default).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need envsubst
[[ -d "${ISO_DIR}/boot/grub" ]] || die "work tree missing, run 10-extract-iso.sh"

: "${FORGE_KERNEL_ARGS:=}"
export FORGE_KERNEL_ARGS
vars='${FORGE_VERSION} ${PROFILE} ${GRUB_TIMEOUT} ${FORGE_KERNEL_ARGS}'
envsubst "${vars}" < "${BUILD_DIR}/grub/grub.cfg.tmpl"     > "${ISO_DIR}/boot/grub/grub.cfg"
envsubst "${vars}" < "${BUILD_DIR}/grub/loopback.cfg.tmpl" > "${ISO_DIR}/boot/grub/loopback.cfg"
log "GRUB menu installed (default entry: automated install, timeout ${GRUB_TIMEOUT}s)"
