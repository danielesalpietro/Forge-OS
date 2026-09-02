#!/usr/bin/env bash
# Download the Ubuntu live-server ISO into the cache and verify it against the
# GPG-signed SHA256SUMS (and the pinned checksum in forge.env, if set).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need curl sha256sum

mkdir -p "${CACHE_DIR}"
base_url="$(dirname "${BASE_ISO_URL}")"
iso_file="$(basename "${BASE_ISO_URL}")"

if [[ ! -f "${BASE_ISO}" ]]; then
  log "downloading ${BASE_ISO_URL}"
  curl -fL --retry 5 --retry-delay 5 -C - -o "${BASE_ISO}.part" "${BASE_ISO_URL}"
  mv "${BASE_ISO}.part" "${BASE_ISO}"
else
  log "base ISO already cached: ${BASE_ISO}"
fi

log "fetching SHA256SUMS"
curl -fsSL --retry 3 -o "${CACHE_DIR}/SHA256SUMS" "${base_url}/SHA256SUMS"
curl -fsSL --retry 3 -o "${CACHE_DIR}/SHA256SUMS.gpg" "${base_url}/SHA256SUMS.gpg" || warn "SHA256SUMS.gpg not available"

if [[ "${FORGE_SKIP_GPG:-0}" != "1" ]] && command -v gpg >/dev/null 2>&1 && [[ -s "${CACHE_DIR}/SHA256SUMS.gpg" ]]; then
  export GNUPGHOME="${CACHE_DIR}/gnupg"
  mkdir -p "${GNUPGHOME}" && chmod 700 "${GNUPGHOME}"
  if ! gpg --batch --list-keys "${UBUNTU_SIGNING_KEY}" >/dev/null 2>&1; then
    gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "${UBUNTU_SIGNING_KEY}" \
      || die "cannot import Ubuntu signing key ${UBUNTU_SIGNING_KEY} (set FORGE_SKIP_GPG=1 to skip, NOT recommended)"
  fi
  gpg --batch --verify "${CACHE_DIR}/SHA256SUMS.gpg" "${CACHE_DIR}/SHA256SUMS" \
    || die "GPG verification of SHA256SUMS failed"
  log "SHA256SUMS signature OK"
else
  warn "skipping GPG verification of SHA256SUMS"
fi

expected="$(awk -v f="*${iso_file}" '$2 == f {print $1}' "${CACHE_DIR}/SHA256SUMS")"
[[ -n "${expected}" ]] || die "${iso_file} not listed in SHA256SUMS"
if [[ -n "${BASE_ISO_SHA256:-}" && "${BASE_ISO_SHA256}" != "${expected}" ]]; then
  die "pinned BASE_ISO_SHA256 (${BASE_ISO_SHA256}) differs from published checksum (${expected}); update build/forge.env deliberately"
fi
log "verifying ISO checksum (this takes a while)"
actual="$(sha256sum "${BASE_ISO}" | awk '{print $1}')"
[[ "${actual}" == "${expected}" ]] || die "checksum mismatch for ${BASE_ISO}: got ${actual}, expected ${expected}"
log "base ISO verified: ${iso_file}"
