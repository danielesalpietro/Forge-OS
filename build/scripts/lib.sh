#!/usr/bin/env bash
# Common helpers for the Forge-OS build scripts. Source, do not execute.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

# Load non-secret build configuration.
set -a
# shellcheck source=../forge.env
source "${REPO_ROOT}/build/forge.env"
set +a

: "${PROFILE:=baseline}"
BUILD_DIR="${REPO_ROOT}/build"
CACHE_DIR="${FORGE_CACHE_DIR:-${BUILD_DIR}/cache}"
WORK_DIR="${FORGE_WORK_DIR:-${BUILD_DIR}/work}"
OUT_DIR="${FORGE_OUT_DIR:-${BUILD_DIR}/out}"
ISO_DIR="${WORK_DIR}/iso"
FORGE_DIR="${ISO_DIR}/forge"            # everything we add lives under /forge on the ISO
BASE_ISO="${CACHE_DIR}/$(basename "${BASE_ISO_URL}")"
PROFILE_DIR="${REPO_ROOT}/autoinstall/profiles/${PROFILE}"
export PROFILE BUILD_DIR CACHE_DIR WORK_DIR OUT_DIR ISO_DIR FORGE_DIR BASE_ISO PROFILE_DIR

log()  { printf '\033[1;34m[forge]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[forge] WARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[forge] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }
need() { local c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || die "missing tool: $c (run inside the builder container: make builder-shell)"; done; }

git_sha() { git -C "${REPO_ROOT}" rev-parse --short=12 HEAD 2>/dev/null || echo "unknown"; }
iso_name() { echo "forge-os-${FORGE_VERSION}-${PROFILE}-${ARCH}.iso"; }
