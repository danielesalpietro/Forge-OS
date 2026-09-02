# ADR-0003: TPM-backed LUKS unlock with clevis, recovery key and optional Tang escrow

**Status:** accepted · **Date:** 2026-09-02

## Context
The README requires TPM-backed key management, optional remote key escrow and
AES-256 FDE. Candidates on Ubuntu 24.04:
- **clevis** (tpm2 pin, tang pin, sss) with `clevis-initramfs` (initramfs-tools).
- **systemd-cryptenroll --tpm2** which needs `systemd-cryptsetup` in the initrd
  (dracut) on 24.04; signed PCR policies are attractive but the dracut switch
  is intrusive for an Ubuntu base.
- Ubuntu's snap-based TPM FDE (desktop-oriented, experimental for server).

## Decision
Use **clevis**: bind the LUKS2 volume to the TPM2 with PCR 7 (Secure Boot
policy) by default (`FORGE_TPM_PCRS` configurable), optionally combined with
Tang servers through Shamir secret sharing for remote escrow. Always keep a
random recovery passphrase (`/root/forge-recovery-key`) and remove the
build-time key at first boot. Re-evaluate `systemd-cryptenroll` + dracut in
P1.2-07.

## Consequences
- Unattended reboots on trusted hardware; a changed Secure Boot state (or
  firmware when PCR 0/2 are used) falls back to the recovery key.
- Operators must escrow the recovery key and follow the re-enrol runbook after
  bootloader/firmware updates.
