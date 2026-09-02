# Security baseline - control matrix

Mapping of the README requirements to implementation and validation.
`forge-validate` check ids refer to `tests/validate/forge-validate`.

| README requirement | Implementation | Validation |
|--------------------|----------------|------------|
| TPM 2.0 support | tpm2-tools, clevis-tpm2, kernel TPM drivers; `forge_luks_tpm` | `rot/tpm2-present`, `rot/tpm2-usable` |
| UEFI Secure Boot | stock signed shim/GRUB/kernel, UEFI-only autoinstall | `rot/uefi-boot`, `rot/secure-boot` |
| Measured Boot | PCR 0-7 by firmware/shim/GRUB; PCR 7 sealed in the TPM policy | `rot/measured-boot`, `rot/tpm-eventlog` |
| Platform integrity validation | PCR-bound unlock (implicit attestation); Keylime remote attestation proposed in Phase 4 | `luks/tpm2-bound` |
| AES-256 full disk encryption (LUKS) | LUKS2 `aes-xts-plain64` 512-bit on root/var/home/tmp/swap | `luks/luks2-format`, `luks/aes256-xts`, `luks/root-on-luks` |
| TPM-backed key management | clevis tpm2 pin, recovery key, build key rotation | `luks/tpm2-bound`, `luks/build-key-removed`, `luks/recovery-key-stored` |
| Optional remote key escrow | clevis sss (tpm2 + Tang) via `FORGE_TANG_URLS` | manual (`clevis luks list`) |
| Encrypted swap | `lv_swap` inside the LUKS container | `luks/swap-encrypted` |
| Encrypted data partitions | free VG extents inside LUKS; Ceph OSD encryption in Phase 2 | Phase 2 |
| Ubuntu LTS minimal installation | `source: ubuntu-server-minimal`, no codecs/drivers/snaps | manifest |
| CIS Benchmark alignment | ansible-lockdown UBUNTU24-CIS L1 (L2 opt-in) + Forge roles | OpenSCAP/USG (P1.3-06), `os/*` |
| Ubuntu Pro integration | `forge_ubuntu_pro` (ESM, Livepatch, USG) | `pro/*` |
| AppArmor enforced | `forge_apparmor` (all profiles enforce, kernel cmdline) | `os/apparmor-enforced` |
| auditd enabled | `forge_auditd` (CIS rule set, immutable) | `os/auditd-active`, `os/auditd-rules` |
| nftables default policy | `forge_nftables` (input/forward drop, drop-in dir) | `os/nftables-active`, `os/nftables-input-drop` |
| fail2ban | `forge_fail2ban` (sshd aggressive, nftables actions) | `os/fail2ban-active` |
| Unattended security updates | `forge_unattended_upgrades` | `os/unattended-upgrades` |
| systemd hardening policies | `forge_systemd_hardening` (coredump off, masked units, /dev/shm, drop-ins) | `os/coredump-disabled`, `os/ctrl-alt-del-masked` |
| Root login disabled | `passwd -l root`, `PermitRootLogin no`, `pam_wheel` | `admin/root-locked`, `admin/sshd-no-root` |
| SSH key authentication only | `forge_ssh` | `admin/sshd-no-password`, `admin/sshd-pubkey` |
| MFA support | `forge_mfa` (TOTP/FIDO2 PAM) | `admin/mfa-module` |
| RBAC model | groups `forge-admin`, `forge-operator`, sudo aliases, `AllowGroups` | `admin/sudo-groups`, `admin/sshd-allowgroups` |
| Sudo least-privilege policies | `10-forge-rbac` (operator command set, deny list) | `admin/sudo-syntax` |
| Session logging and auditing | sudo `log_input/log_output`, `pam_tty_audit`, auditd login/session rules | `admin/sudo-io-logging`, `admin/pam-tty-audit` |
| Active Directory / LDAP integration | `forge_identity` (SSSD ad/ldap, realm join) | `admin/sssd-active` |
