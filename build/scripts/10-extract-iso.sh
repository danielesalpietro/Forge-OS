#!/usr/bin/env bash
# Unpack the base ISO into the work tree and record the El Torito / hybrid
# boot layout so the remastered ISO can reproduce it exactly.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need xorriso

[[ -f "${BASE_ISO}" ]] || die "base ISO missing, run 00-fetch-base-iso.sh"
rm -rf "${WORK_DIR}"
mkdir -p "${ISO_DIR}"

log "extracting ${BASE_ISO} -> ${ISO_DIR}"
xorriso -osirrox on -indev "${BASE_ISO}" -extract / "${ISO_DIR}" >/dev/null 2>&1
chmod -R u+w "${ISO_DIR}"

log "recording boot layout (report_el_torito as_mkisofs)"
xorriso -indev "${BASE_ISO}" -report_el_torito as_mkisofs > "${WORK_DIR}/mkisofs-args.txt" 2>/dev/null
grep -q -- '-b ' "${WORK_DIR}/mkisofs-args.txt" || die "could not derive boot layout from base ISO"
log "boot layout saved to ${WORK_DIR}/mkisofs-args.txt"
