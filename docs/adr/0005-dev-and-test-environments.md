# ADR-0005: Development and test environments

**Status:** accepted · **Date:** 2026-09-02

## Context
During development only VMware, KVM and Docker are available; bare-metal comes
later. Secure Boot, TPM and disk encryption cannot be validated in containers.

## Decision
- **Docker**: builder image, lint, molecule for container-safe roles, lab
  services. Roles gate hardware-dependent tasks on `forge_container_mode`.
- **KVM (QEMU + OVMF with Microsoft keys + swtpm)** is the *reference*
  environment for the boot chain, TPM unlock and hardening; the harness
  `tests/kvm/run-iso.sh` also runs in GitHub Actions.
- **VMware** is used for parity and enterprise topologies (vTPM on encrypted
  VMs), driven by Packer.
- **Bare-metal** is the release gate for every phase.

## Consequences
- Every PR that touches the installer or the LUKS/TPM role must attach a KVM
  e2e report; role-only PRs can rely on molecule.
- `vm-dev` profile exists to keep VM disks small and tolerate missing TPMs.
