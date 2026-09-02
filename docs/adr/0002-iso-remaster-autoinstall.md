# ADR-0002: Produce the installer by remastering the live-server ISO with autoinstall

**Status:** accepted · **Date:** 2026-09-02

## Context
Options to obtain a self-installing bare-metal ISO:
1. Remaster the official Ubuntu live-server ISO and add a subiquity
   *autoinstall* configuration (curtin storage, late-commands) plus payload.
2. Build a custom rootfs (debootstrap/live-build) and a custom installer.
3. Image-based deployment (write a pre-built disk image with a tiny live system).

## Decision
Option 1. The boot chain (signed shim/GRUB/kernel) and the installer are the
official ones; Forge-OS adds `/forge/*` and the GRUB menu. Storage
(LUKS2 + LVM) is declared to curtin; hardening is applied at first boot by
Ansible shipped in the ISO together with an offline APT repository.

## Consequences
- Secure Boot works out of the box (Microsoft CA), no custom signing keys.
- Minimal maintenance: a new point release is a checksum change.
- The build-time LUKS passphrase must be embedded in the ISO; mitigated by the
  first-boot rotation (ADR-0003) and by treating ISOs as confidential.
- Option 3 remains the candidate for Phase 4 immutable/A-B deployments.
