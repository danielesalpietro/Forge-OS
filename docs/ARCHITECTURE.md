# Forge-OS Architecture

## 1. Build pipeline (`make iso`)

| Step | Script | What it does |
|------|--------|--------------|
| 00 | `build/scripts/00-fetch-base-iso.sh` | Downloads the pinned Ubuntu live-server ISO, verifies `SHA256SUMS` (GPG signed by the Ubuntu CD image key) and the pinned checksum in `build/forge.env`. |
| 10 | `10-extract-iso.sh` | Extracts the ISO with xorriso and records its El Torito / GPT hybrid boot layout (`xorriso -report_el_torito as_mkisofs`), so the remastered image boots exactly like the original on BIOS and UEFI. |
| 20 | `20-build-package-repo.sh` | Downloads the packages listed in `build/packages/*.list` (delta against `ubuntu-server-minimal`, computed by apt inside the builder container) and builds a flat, `[trusted=yes]` APT repository under `/forge/repo`. |
| 25 | `25-vendor-ansible-deps.sh` | Vendors Ansible collections and the CIS role (`ansible/requirements.yml`) so the first boot works with no network. |
| 30 | `30-inject-overlay.sh` | Renders the autoinstall profile (`envsubst`), validates it against the subiquity schema, copies the payload (`overlay/`, `ansible/`, `tests/validate/`) to `/forge`, writes `manifest.json` and `forge-release`. |
| 40 | `40-patch-grub.sh` | Installs the Forge GRUB menu (default: unattended install with `autoinstall ds=nocloud;s=/cdrom/forge/autoinstall/`). |
| 50 | `50-build-iso.sh` | Regenerates `md5sum.txt`, rebuilds the ISO with the recorded boot layout, emits `.sha256` and `.manifest.json` in `build/out/`. |

The boot chain (`shim` → `grub` → kernel, all signed by Canonical) and the
installer squashfs are **not modified**, so Secure Boot works with the standard
Microsoft UEFI CA and no MOK enrolment. Everything Forge-OS adds lives under
`/forge` on the ISO plus the GRUB menu.

### Secrets

Passed through the environment (`.env.example`), never committed:

- `FORGE_ADMIN_SSH_KEY` (required): public key of the initial administrator.
- `FORGE_LUKS_PASSPHRASE`: build-time LUKS key; random per build when unset. It
  is embedded in the ISO (`/forge/autoinstall/user-data`, `/forge/keys/`) and
  **rotated at first boot** (see §4). Treat the ISO as confidential.
- `FORGE_ADMIN_PASSWORD_HASH`: random (locked) when unset; SSH keys + sudo only.

## 2. ISO layout

```
/boot/grub/grub.cfg            Forge menu (autoinstall default, serial-console and manual entries)
/boot/grub/loopback.cfg        same for loop-mounted boots (Ventoy, grml)
/casper/                       stock Ubuntu kernel / initrd / squashfs (signed)
/EFI/, [BOOT]                  stock shim + grub (signed)
/forge/autoinstall/            user-data, meta-data, vendor-data (cloud-init NoCloud seed)
/forge/keys/luks-build-key     build passphrase (consumed by first boot)
/forge/repo/                   offline APT repository (Packages.gz, Release, *.deb)
/forge/ansible/                playbooks, roles, vendor/ (collections + CIS role)
/forge/overlay/                first-boot service, late-install script, /etc/forge templates
/forge/validate/forge-validate validation suite
/forge/manifest.json, forge-release
```

## 3. Installation flow

1. **GRUB** boots `/casper/vmlinuz` with `autoinstall ds=nocloud;s=/cdrom/forge/autoinstall/`.
2. **subiquity** applies the profile: locale, `ubuntu-server-minimal` source,
   DHCP on `en*`, mirror with `fallback: offline-install`, storage (curtin),
   identity, SSH keys.
3. **curtin** creates the disk layout and writes `/etc/crypttab`, `/etc/fstab`.
4. **late-commands** copy `/cdrom/forge/*` to `/target/opt/forge`, install the
   build key to `/etc/forge/luks-build-key`, run `late-install.sh` in the target
   chroot (offline repo, ansible-core, clevis/TPM stack, first-boot unit, root lock).
5. Reboot. **`forge-firstboot.service`** (runs *before* `ssh.service`):
   `ansible-playbook site.yml` → `forge-validate` → scrub installer logs that
   contain the build key → mark done → reboot.
6. Steady state: `forge-validate.timer` daily, Ansible re-runnable from
   `/opt/forge/ansible` for drift remediation.

## 4. Disk layout and key management

```
GPT
├─ p1  ESP        1 GiB  vfat   /boot/efi  (umask=0077)
├─ p2  boot       2 GiB  ext4   /boot      (nodev,nosuid,noexec; measured by TPM via GRUB)
└─ p3  LUKS2  aes-xts-plain64 512-bit (AES-256)  → /dev/mapper/forge-crypt
      └─ LVM vg_forge
         lv_root 24G /          lv_var 16G /var (nodev)      lv_var_log 8G /var/log (nodev,nosuid,noexec)
         lv_var_log_audit 4G    lv_var_tmp 4G  lv_tmp 4G     lv_home 8G (nodev,nosuid)   lv_swap 8G (swap)
         free extents            → Phase 2 data / Ceph metadata, or grow with lvextend
```

Key slots over the lifetime of a node:

| Slot | Key | Created | Removed |
|------|-----|---------|---------|
| build passphrase | `FORGE_LUKS_PASSPHRASE` | ISO build (curtin `dm_crypt.key`) | first boot (`cryptsetup luksRemoveKey`, file shredded) |
| TPM2 (clevis) | sealed to PCR 7 (`FORGE_TPM_PCRS`) | first boot, when a TPM 2.0 is present | re-enrol after firmware/bootloader changes (`clevis luks regen`) |
| Tang / SSS (optional) | Shamir `t=1` over tpm2 + tang | first boot when `FORGE_TANG_URLS` is set | operator |
| recovery key | random 48 bytes base64 in `/root/forge-recovery-key` | first boot | operator moves it to a vault |

Unlock order in the initramfs: clevis (TPM2 / Tang) → passphrase prompt
(recovery key). `/etc/crypttab` stays UUID-based as written by the installer.

## 5. Runtime security model (Phase 1)

| Layer | Control | Owner |
|-------|---------|-------|
| Firmware | UEFI Secure Boot, TPM 2.0 measured boot | hardware + Canonical signed chain |
| Kernel | lockdown=integrity, AppArmor, sysctl hardening, module blacklist, `init_on_alloc/free` | `forge_kernel_sysctl`, `forge_apparmor` |
| Network | nftables default-deny input/forward, SSH rate-limit and optional source CIDRs, fail2ban | `forge_nftables`, `forge_fail2ban` |
| Access | root locked, SSH key-only + optional TOTP/FIDO2, `AllowGroups`, RBAC sudo with I/O recording, `pam_tty_audit`, SSSD | `forge_ssh`, `forge_sudo`, `forge_mfa`, `forge_identity` |
| Audit | auditd immutable rules, persistent journald, sudo logs, remote syslog hook | `forge_auditd`, `forge_base` |
| Patching | unattended security + ESM updates, needrestart, Ubuntu Pro (Livepatch, USG) | `forge_unattended_upgrades`, `forge_ubuntu_pro` |
| Compliance | CIS L1/L2 (ansible-lockdown), OpenSCAP/USG reports, `forge-validate` | `forge_cis`, `forge_validate` |

Later phases extend the same mechanisms: Ceph and Kubernetes open ports through
`/etc/nftables.d/*.nft`, and Kubernetes overrides sysctls through a
higher-numbered `/etc/sysctl.d` file, never by editing Phase 1 files.

## 6. Versioning and releases

- `FORGE_VERSION` in `build/forge.env` (semantic versioning), git tag `vX.Y.Z`
  triggers the release workflow (ISO + SHA-256 + manifest on GitHub Releases).
- The ISO manifest records profile, base ISO checksum, git SHA and build date;
  `/etc/forge-release` carries the same data on every node.
