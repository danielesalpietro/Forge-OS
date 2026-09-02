#!/usr/bin/env bash
# Build an offline APT repository under /forge/repo on the ISO with the extra
# packages Forge-OS needs beyond the stock live-server pool (ansible-core,
# clevis, tpm2-tools, auditd, nftables, ...). The delta is computed against the
# builder container, which has ubuntu-server-minimal installed (see Dockerfile).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [[ "${FORGE_SKIP_REPO:-0}" == "1" ]]; then
  warn "FORGE_SKIP_REPO=1: not embedding packages (install will need a network mirror)"
  exit 0
fi
need apt-get dpkg-scanpackages apt-ftparchive
[[ -d "${ISO_DIR}" ]] || die "work tree missing, run 10-extract-iso.sh"
[[ "$(id -u)" == "0" ]] || die "package download needs root (run inside the builder container)"

repo="${FORGE_DIR}/repo"
rm -rf "${repo}"
mkdir -p "${repo}/partial"

lists=("${BUILD_DIR}/packages/base.list")
[[ -f "${BUILD_DIR}/packages/${PROFILE}.list" ]] && lists+=("${BUILD_DIR}/packages/${PROFILE}.list")
mapfile -t pkgs < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "${lists[@]}" | sort -u)
log "resolving ${#pkgs[@]} packages from: ${lists[*]}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --download-only --no-install-recommends \
  -o Dir::Cache::archives="${repo}" -o Debug::NoLocking=1 "${pkgs[@]}"
rm -rf "${repo}/partial" "${repo}/lock"

log "generating repository index"
( cd "${repo}" && dpkg-scanpackages --multiversion . /dev/null 2>/dev/null | gzip -9c > Packages.gz \
  && apt-ftparchive release -o APT::FTPArchive::Release::Label="Forge-OS" \
       -o APT::FTPArchive::Release::Codename="${UBUNTU_CODENAME}" . > Release )
count="$(find "${repo}" -name '*.deb' | wc -l)"
size="$(du -sh "${repo}" | cut -f1)"
log "offline repository ready: ${count} packages, ${size}"
