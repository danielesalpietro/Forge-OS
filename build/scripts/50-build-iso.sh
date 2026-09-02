#!/usr/bin/env bash
# Assemble the final hybrid (BIOS+UEFI) ISO, reusing the exact boot layout of
# the base image, then publish checksum + manifest to build/out.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need xorriso sha256sum
[[ -f "${WORK_DIR}/mkisofs-args.txt" ]] || die "boot layout missing, run 10-extract-iso.sh"
[[ -f "${FORGE_DIR}/autoinstall/user-data" ]] || die "payload missing, run 30-inject-overlay.sh"

mkdir -p "${OUT_DIR}"
out="${OUT_DIR}/$(iso_name)"

# casper verifies the medium against md5sum.txt at boot: regenerate it.
if [[ -f "${ISO_DIR}/md5sum.txt" ]]; then
  log "regenerating md5sum.txt"
  ( cd "${ISO_DIR}" && find . -type f ! -name md5sum.txt ! -name boot.catalog -print0 | sort -z \
      | xargs -0 md5sum > "${WORK_DIR}/md5sum.txt" && mv "${WORK_DIR}/md5sum.txt" md5sum.txt )
fi

# Reuse the boot images of the base ISO (MBR, EFI partition, El Torito images)
# exactly as reported by xorriso; only the volume id is overridden.
args="$(sed -e "s|^-V '.*'|-V '${ISO_VOLID}'|" "${WORK_DIR}/mkisofs-args.txt" | tr '\n' ' ')"
log "building ${out}"
rm -f "${out}"
eval xorriso -as mkisofs "${args}" -o "'${out}'" "'${ISO_DIR}'" 2> "${WORK_DIR}/xorriso.log" \
  || { cat "${WORK_DIR}/xorriso.log" >&2; die "xorriso failed"; }

( cd "${OUT_DIR}" && sha256sum "$(basename "${out}")" > "$(basename "${out}").sha256" )
cp "${FORGE_DIR}/manifest.json" "${out%.iso}.manifest.json"
log "done: ${out} ($(du -h "${out}" | cut -f1))"
