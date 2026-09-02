#!/usr/bin/env bash
# Full pipeline: fetch -> extract -> packages -> ansible deps -> overlay -> grub -> iso
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for step in 00-fetch-base-iso 10-extract-iso 20-build-package-repo 25-vendor-ansible-deps 30-inject-overlay 40-patch-grub 50-build-iso; do
  printf '\n\033[1;32m==> %s\033[0m\n' "${step}"
  bash "${here}/${step}.sh"
done
