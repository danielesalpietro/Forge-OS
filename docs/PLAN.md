# Forge-OS Development Plan

**Version:** 0.1 (plan) · **Target base:** Ubuntu 24.04 LTS (Noble) · **Status:** Phase 0 in progress

This plan turns the requirements in [README.md](../README.md) into phased,
testable deliverables and maps every deliverable to the environments that are
available during development (Docker, KVM, VMware, later bare-metal). Items
carry identifiers (`P<phase>.<milestone>-<nn>`) so they can be tracked as
GitHub issues with the *Plan task* template.

---

## 1. Analysis of the README

### 1.1 Requirement areas

| Area (README section)          | What it implies technically                                                                  | Phase |
|--------------------------------|----------------------------------------------------------------------------------------------|-------|
| Hardware Root of Trust         | UEFI-only boot, Secure Boot with Canonical's signed shim/GRUB/kernel, TPM 2.0 measured boot (PCR policy), integrity validation at boot and at runtime | 1 |
| Encryption                     | LUKS2 AES-256-XTS on the whole system (root, `/var`, `/home`, swap), key sealed to the TPM, recovery key, optional remote escrow (Tang / Shamir), encrypted data partitions for storage nodes | 1 (+2 for OSDs) |
| OS Hardening                   | `ubuntu-server-minimal`, CIS Ubuntu 24.04 L1 (L2 optional), AppArmor enforce, auditd immutable rules, nftables default-deny, fail2ban, unattended security updates, systemd sandboxing, kernel/sysctl hardening | 1 |
| Administrative Access          | root locked, SSH keys only + modern crypto, RBAC groups (`forge-admin`, `forge-operator`) mapped to sudo policies, MFA (TOTP/FIDO2), sudo I/O session recording + `pam_tty_audit`, SSSD for AD/LDAP | 1 |
| Storage Services               | MicroCeph/Ceph, erasure-coded pools 4+2 and 8+3, encrypted OSDs (dm-crypt), self-healing, data-at-rest | 2 |
| Cloud Native Readiness         | containerd, K3s/Kubernetes, NVIDIA runtime + GPU operator, GitOps, Ceph CSI, internal developer platform hosting | 3 |
| Deliverables Phase 1           | Hardened image, automated installation, security baseline, TPM/Secure Boot/encryption **validation** | 1 |
| Deliverables Phase 2           | Storage stack, erasure coding, monitoring, backup integration                              | 2 |
| Deliverables Phase 3           | Kubernetes foundation, GPU enablement, GitOps automation                                    | 3 |
| Vision items not in a phase    | *Immutable Deployment Patterns*, *Compliance-Ready Baseline* (evidence), vendor neutrality, edge | proposed Phase 4 |

### 1.2 Gaps and decisions taken

| Gap / ambiguity in the README                 | Decision (see ADRs)                                                                 |
|-----------------------------------------------|--------------------------------------------------------------------------------------|
| "Ubuntu LTS" not pinned                        | Ubuntu **24.04.4 LTS** live-server as base, pinned by checksum in `build/forge.env`; upgrade path to the next LTS is a config change (ADR-0001) |
| How the ISO is produced                        | **Remaster** the official live-server ISO with subiquity *autoinstall* (curtin storage config, late-commands) instead of building a rootfs from scratch: keeps Canonical's signed boot chain and kernel, minimal maintenance (ADR-0002) |
| "TPM-backed key management" mechanism          | **clevis** (tpm2 pin, PCR 7 by default) with `clevis-initramfs`; remote escrow via **Tang** with Shamir secret sharing; passphrase recovery key always present (ADR-0003) |
| How hardening is applied and re-applied        | **Ansible** at first boot (offline, content shipped in the ISO), re-runnable for drift remediation; CIS via ansible-lockdown UBUNTU24-CIS (ADR-0004) |
| No environments named for testing              | Docker = builder and role sub-development; **KVM + OVMF + swtpm** = the reference for TPM/Secure Boot/LUKS tests; VMware = parity; bare-metal = release gate (ADR-0005) |
| No install-time data model                     | Layout in the autoinstall profile: ESP, `/boot`, LUKS2 → LVM with CIS-separated volumes, encrypted swap, free VG space for data |
| "Immutable deployment patterns"                | Not achievable with a classic Ubuntu install in Phase 1; proposed **Phase 4** (image-based A/B updates, read-only root, attestation) |
| "Compliance-ready" without evidence tooling    | `forge-validate` (JSON report), OpenSCAP/USG reports as Phase 1.5 deliverable                 |

---

## 2. Architecture summary

```
 developer / CI                      ISO (hybrid BIOS+UEFI, signed boot chain untouched)
 ┌──────────────────┐   make iso     ┌───────────────────────────────────────────────┐
 │ build/ (Docker)  │ ─────────────▶ │ /casper (stock kernel, initrd, squashfs)      │
 │  fetch+verify    │                │ /boot/grub/grub.cfg  ← Forge menu (autoinstall)│
 │  extract, repo   │                │ /forge/autoinstall/  ← user-data (curtin LUKS) │
 │  overlay, grub   │                │ /forge/repo/         ← offline apt repository  │
 │  xorriso rebuild │                │ /forge/ansible/      ← roles + vendored deps   │
 └──────────────────┘                │ /forge/overlay/      ← first-boot service      │
                                     └───────────────────────────────────────────────┘
                                                        │ boot on target
                                                        ▼
  subiquity autoinstall ── late-commands ──▶ first boot (forge-firstboot.service)
  (GPT, ESP, /boot, LUKS2+LVM)   copy payload   ├ ansible-playbook site.yml (offline)
                                 install tools  ├ clevis TPM2 bind, recovery key, drop build key
                                 enable service ├ forge-validate → /var/lib/forge/validation-report.json
                                                └ scrub installer logs, reboot
```

Details: [ARCHITECTURE.md](ARCHITECTURE.md). Control matrix: [SECURITY-BASELINE.md](SECURITY-BASELINE.md).

---

## 3. Phases, milestones and deliverables

Each milestone has **exit criteria** that must be proven in the listed
environment. "KVM" always means QEMU with OVMF Secure Boot and swtpm
(`tests/kvm/run-iso.sh`).

### Phase 0 - Foundation and toolchain *(proposed addition, prerequisite for Phase 1)*

Goal: a reproducible pipeline that turns the repository into a bootable,
unattended installer, with lint and end-to-end tests in CI.

| ID       | Deliverable                                                                                   | Env     | Status |
|----------|-----------------------------------------------------------------------------------------------|---------|--------|
| P0.1-01  | Repository layout, contribution rules, ADRs, CI skeleton                                       | Docker  | done (this branch) |
| P0.1-02  | Builder container (`build/Dockerfile`) with xorriso, apt tooling, Ansible, linters             | Docker  | done, image build to verify in CI |
| P0.1-03  | Base ISO fetch with GPG-verified checksums and pinned SHA-256                                  | Docker  | done |
| P0.1-04  | ISO remaster preserving the hybrid El Torito/EFI layout (`report_el_torito as_mkisofs`)        | Docker  | done, needs first real build |
| P0.1-05  | Offline APT repository embedded in the ISO (delta vs `ubuntu-server-minimal`)                   | Docker  | done, size to measure |
| P0.1-06  | Autoinstall schema validation in lint (`validate-autoinstall.py`)                              | Docker  | done |
| P0.2-01  | First green run of `make iso` in GitHub Actions, ISO artifact published                        | CI      | todo |
| P0.2-02  | KVM e2e harness boots the ISO and reaches the installer (serial log)                            | KVM     | todo |
| P0.2-03  | Molecule container scenario green for container-safe roles                                     | Docker  | todo |

**Exit criteria:** `make lint` and `make iso` green in CI; the ISO boots in KVM
with Secure Boot on and reaches the autoinstall stage.

### Phase 1 - Hardened image and automated installation

#### Milestone 1.1 - Unattended install (README: *Automated Installation*, *Ubuntu Hardened Image*)

| ID       | Deliverable                                                                                   | Env        |
|----------|-----------------------------------------------------------------------------------------------|------------|
| P1.1-01  | `baseline` profile: GPT/UEFI, ESP + `/boot`, LUKS2 AES-256-XTS → LVM with CIS-separated volumes, encrypted swap | KVM |
| P1.1-02  | `vm-dev` profile (small disks, guest agents) and `storage-node` profile (OS on smallest SSD)   | KVM/VMware |
| P1.1-03  | Late-commands: payload copy, offline repo, first-boot service, root lock                       | KVM        |
| P1.1-04  | Installer failure capture (`error-commands`) and serial-console boot entry                     | KVM        |
| P1.1-05  | Network defaults: DHCP on any `en*`, optional; documented static override via `ansible-extra-vars.yml` | KVM |
| P1.1-06  | Bare-metal boot media test (USB, `dd`/Ventoy via `loopback.cfg`)                                | bare-metal |

**Exit criteria:** unattended install completes in KVM and VMware without
interaction; the system reboots into an encrypted root; `forge-validate --tag luks` passes.

#### Milestone 1.2 - Hardware root of trust (README: *TPM Validation*, *Secure Boot Validation*, *Encryption Validation*)

| ID       | Deliverable                                                                                   | Env        |
|----------|-----------------------------------------------------------------------------------------------|------------|
| P1.2-01  | Secure Boot verified end to end with the stock Microsoft CA (no MOK), `mokutil --sb-state`     | KVM/VMware/bare-metal |
| P1.2-02  | TPM2-bound LUKS unlock via clevis (PCR 7), `clevis-initramfs`, unattended reboot               | KVM (swtpm), bare-metal |
| P1.2-03  | Build-key rotation at first boot: recovery key added, build passphrase removed and shredded, installer logs scrubbed | KVM |
| P1.2-04  | Optional Tang escrow (Shamir `t=1` tpm2+tang; `t=2` for dual control) + Tang server role/compose for labs | Docker (tang) + KVM |
| P1.2-05  | Measured boot evidence: PCR snapshot and TPM event log stored in `/var/lib/forge/attestation/` at each boot | KVM/bare-metal |
| P1.2-06  | Firmware/bootloader update runbook (PCR change → re-enrol; recovery path)                      | docs       |
| P1.2-07  | Evaluate `systemd-cryptenroll` + dracut and signed PCR policies as a clevis alternative         | KVM (spike) |

**Exit criteria:** in KVM with Secure Boot on and swtpm, the third boot unlocks
the root volume with no passphrase prompt; `forge-validate --tag rot,luks` has
no failures; the recovery key opens the volume when the TPM is reset.

#### Milestone 1.3 - Security baseline (README: *Operating System Hardening*, *Security Baseline*)

| ID       | Deliverable                                                                                   | Env        |
|----------|-----------------------------------------------------------------------------------------------|------------|
| P1.3-01  | Roles `forge_base`, `forge_kernel_sysctl`, `forge_apparmor`, `forge_auditd`, `forge_nftables`, `forge_fail2ban`, `forge_unattended_upgrades`, `forge_systemd_hardening` applied at first boot | Docker (molecule) + KVM |
| P1.3-02  | CIS Ubuntu 24.04 L1 via ansible-lockdown role, pinned version, exclusions reconciled with Forge roles; L2 opt-in | KVM |
| P1.3-03  | systemd per-service sandboxing drop-ins validated and enabled (`forge_systemd_dropins_enabled`) | KVM |
| P1.3-04  | AIDE baseline initialised at first boot, daily check timer                                     | KVM        |
| P1.3-05  | Kernel cmdline hardening validated (lockdown, init_on_alloc/free, AppArmor) incl. perf impact note | KVM/bare-metal |
| P1.3-06  | Compliance evidence: OpenSCAP (SSG) and, with Pro, `usg audit` reports exported as HTML/JSON     | KVM        |

**Exit criteria:** OpenSCAP CIS L1 score ≥ 90 % on a fresh install;
`forge-validate --tag os` clean; all roles idempotent (second run: 0 changed).

#### Milestone 1.4 - Administrative access (README: *Administrative Access*)

| ID       | Deliverable                                                                                   | Env        |
|----------|-----------------------------------------------------------------------------------------------|------------|
| P1.4-01  | `forge_ssh`: key-only, root disabled, AllowGroups, modern KEX/ciphers, VERBOSE logging         | Docker + KVM |
| P1.4-02  | `forge_sudo`: RBAC groups, least-privilege operator command set, `log_input/log_output`, `pam_tty_audit`, `pam_wheel` | Docker + KVM |
| P1.4-03  | `forge_mfa`: TOTP (pam_google_authenticator) and FIDO2 (pam_u2f) for SSH, enrolment helper, break-glass procedure | KVM |
| P1.4-04  | `forge_identity`: AD join (realm/SSSD) and LDAP backends, group → RBAC mapping, offline cache   | Docker (Samba AD DC lab) + KVM |
| P1.4-05  | Session log shipping: sudo I/O logs and audit records to remote syslog (hook for Phase 2)      | KVM        |

**Exit criteria:** admin and operator personas tested end to end (SSH key + TOTP,
operator cannot escalate); AD user in mapped group obtains the correct sudo role.

#### Milestone 1.5 - Validation, Ubuntu Pro and release

| ID       | Deliverable                                                                                   | Env        |
|----------|-----------------------------------------------------------------------------------------------|------------|
| P1.5-01  | `forge-validate` complete for all Phase 1 controls, daily timer, JSON schema for reports       | KVM        |
| P1.5-02  | `forge_ubuntu_pro`: attach from token file, ESM/Livepatch/USG enablement, token removal        | KVM (with token) |
| P1.5-03  | Nightly KVM e2e in CI (`test-kvm.yml`) with report artifact and badge                          | CI         |
| P1.5-04  | Bare-metal acceptance on two reference machines (TPM 2.0 firmware variants, NVMe)              | bare-metal |
| P1.5-05  | Release `v0.1.0`: ISO + SHA-256 + manifest on GitHub Releases, SBOM of the offline repo         | CI         |

**Phase 1 Definition of Done:** README Phase 1 deliverables all demonstrated
by `forge-validate` output and CI artifacts; documented recovery procedures
(lost TPM, lost recovery key, firmware update).

### Phase 2 - Storage stack and operations

| ID       | Deliverable                                                                                   | Env        |
|----------|-----------------------------------------------------------------------------------------------|------------|
| P2.1-01  | `storage-node` profile finalised: OS on smallest SSD, remaining disks reserved, `nftables.d` Ceph rules | KVM (multi-disk) |
| P2.1-02  | `forge_ceph`: MicroCeph (snap, offline-downloaded at build) bootstrap; cluster join via token   | KVM (3 VMs) |
| P2.1-03  | Encrypted OSDs (`--encrypt`, dm-crypt keys in the Ceph mon key store), data-at-rest evidence    | KVM        |
| P2.1-04  | Erasure-coded pools **4+2** and **8+3** (profiles, CRUSH failure domains, min_size), RBD/CephFS/RGW enablement | KVM (6+ OSDs) |
| P2.1-05  | Self-healing tests: OSD loss, node loss, scrub/deep-scrub, recovery throttles                  | KVM        |
| P2.1-06  | Alternative path documented: cephadm (upstream Ceph) for non-snap environments                  | docs       |
| P2.2-01  | `forge_monitoring`: node_exporter + Ceph exporters, Prometheus/Alertmanager/Grafana (single-node or remote), dashboards, alert rules for baseline drift and Ceph health | Docker (stack) + KVM |
| P2.2-02  | Log pipeline: journald → rsyslog/vector to SIEM (TLS), audit + sudo I/O logs included           | Docker + KVM |
| P2.3-01  | `forge_backup`: restic (encrypted, to S3/RGW), RBD snapshot schedules, rbd-mirror for DR, restore drills | KVM |
| P2.3-02  | Backup of LUKS headers and Ceph mon store, documented restore                                   | KVM        |

**Exit criteria:** 3-node KVM cluster with 4+2 EC pool survives one node loss
with no data loss; dashboards and alerts live; restore drill documented.

### Phase 3 - Cloud-native platform

| ID       | Deliverable                                                                                   | Env        |
|----------|-----------------------------------------------------------------------------------------------|------------|
| P3.1-01  | `forge_containerd`: hardened config, registry mirrors/auth, image signature verification (cosign policy) | KVM |
| P3.1-02  | `forge_k3s`: K3s server/agent with CIS hardening profile (`--protect-kernel-defaults`, PSA), sysctl overrides via `/etc/sysctl.d/70-k8s.conf`, nftables drop-ins | KVM (3 VMs) |
| P3.1-03  | kubeadm variant for full upstream Kubernetes (optional, documented)                            | KVM        |
| P3.1-04  | Ceph CSI (RBD/CephFS) storage classes on the Phase 2 cluster                                   | KVM        |
| P3.2-01  | `forge_gpu`: NVIDIA drivers using Canonical-signed `linux-modules-nvidia-*` (Secure Boot compatible, no MOK), container toolkit, GPU operator prerequisites, MIG notes | bare-metal (GPU) |
| P3.3-01  | `forge_gitops`: Flux (default) or Argo CD bootstrap, cluster config repo layout, secrets (SOPS/age) | KVM |
| P3.3-02  | Platform readiness checks in `forge-validate --tag k8s` (kube-bench summary, GPU visible)      | KVM        |
| P3.3-03  | Reference workloads: NorthStream / vMemoryFabric deployment smoke tests                          | KVM/bare-metal |

**Exit criteria:** GitOps-managed K3s cluster on Forge-OS nodes with Ceph-backed
persistent volumes; GPU node schedules a CUDA workload with Secure Boot enabled.

### Phase 4 - Lifecycle and immutability *(proposed, covers README "Vision")*

| ID       | Deliverable                                                                                   |
|----------|-----------------------------------------------------------------------------------------------|
| P4.1-01  | Image-based updates: golden image pipeline + A/B root (evaluate `systemd-sysupdate`/`ubuntu-image`, read-only `/usr`), rollback |
| P4.1-02  | Remote attestation with Keylime (TPM quotes, IMA policy) feeding admission decisions            |
| P4.1-03  | Supply chain: signed ISO/manifests (cosign), SBOM (SPDX) per release, reproducible build checks |
| P4.1-04  | arm64 edge variant (same profiles, UEFI + TPM on supported boards)                              |
| P4.1-05  | Fleet operations: node inventory, drift dashboards from `forge-validate` reports                |

---

## 4. Development environments and how each phase uses them

| Environment                    | Role in the plan                                                                                  | Limits |
|--------------------------------|---------------------------------------------------------------------------------------------------|--------|
| **Docker**                     | Builder image (`make iso`), lint, molecule for container-safe roles, lab services (Tang, Samba AD DC, Prometheus stack, Tang), offline repo inspection | no kernel/firmware/TPM; roles skip via `forge_container_mode` |
| **KVM** (QEMU + OVMF + swtpm)  | Reference environment for Secure Boot, TPM 2.0, measured boot, LUKS unlock, nftables/auditd, multi-node Ceph/K3s labs; also in GitHub Actions (`/dev/kvm`) | no real firmware quirks, no GPU |
| **VMware** (Workstation/vSphere)| Parity checks (EFI Secure Boot, vTPM on encrypted VMs), Packer template, enterprise-like network/storage topologies | vTPM requires VM encryption / Key Provider |
| **Bare-metal**                 | Release gate: firmware variants, NVMe/RAID controllers, GPU, performance of `init_on_free` and LUKS | manual, late in each phase |

See [DEV-ENVIRONMENTS.md](DEV-ENVIRONMENTS.md) for commands.

---

## 5. Timeline (indicative, one engineer full time)

| Milestone | Duration | Depends on |
|-----------|----------|------------|
| P0        | 1-2 weeks | - |
| P1.1      | 1-2 weeks | P0 |
| P1.2      | 2 weeks   | P1.1 |
| P1.3      | 2-3 weeks | P1.1 (parallel with P1.2) |
| P1.4      | 2 weeks   | P1.3 |
| P1.5      | 1-2 weeks | all P1 |
| P2        | 5-7 weeks | P1.5 |
| P3        | 5-7 weeks | P2 (Ceph CSI), P1.5 |
| P4        | ongoing   | P3 |

---

## 6. Testing strategy

1. **Static:** shellcheck, yamllint, ansible-lint, autoinstall JSON schema (every push).
2. **Role level:** molecule with Docker (`ansible/molecule/container`), idempotence check.
3. **Integration:** KVM e2e (`tests/kvm/run-iso.sh`): install → first boot → TPM unlock → `forge-validate` JSON; nightly in CI, on demand for PRs that touch `autoinstall/`, `overlay/`, `build/` or the LUKS/TPM role.
4. **Parity:** Packer builds for QEMU and VMware; VMware Workstation manual checklist.
5. **Hardware:** bare-metal acceptance checklist per release (`docs/` runbook to be added in P1.5-04).
6. **Compliance evidence:** OpenSCAP/USG reports and `forge-validate` reports archived as CI artifacts and on the node (`/var/lib/forge/`).

---

## 7. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| TPM PCR policy breaks after firmware/bootloader updates (lockout) | Default to PCR 7 only; recovery key mandatory; re-enrol runbook (P1.2-06); Tang escrow option |
| CIS role conflicts with Forge roles or breaks services | Exclusions maintained in `forge_cis_role_vars`, pinned role version, KVM e2e gate, L2 opt-in |
| Offline repo grows large / dependency drift | Delta computed against `ubuntu-server-minimal` in the builder; size reported by the build; SBOM in P1.5-05 |
| Subiquity/curtin behaviour changes between point releases | Base ISO pinned by checksum; upgrade is an explicit PR validated by e2e |
| ISO contains the build-time LUKS passphrase | Random per build unless provided; rotated and shredded at first boot; ISO treated as confidential (SECURITY.md) |
| Secure Boot + out-of-tree modules (NVIDIA) | Use Canonical-signed `linux-modules-nvidia-*`; MOK only as documented exception |
| K3s/Kubernetes networking vs default-deny nftables and sysctl | `nftables.d` drop-ins and `/etc/sysctl.d/70-k8s.conf` owned by Phase 3 roles |

---

## 8. Backlog ready for GitHub issues

Create one issue per `P*.*-nn` row above with the *Plan task* template; use
milestones `Phase 0` … `Phase 4` and labels `phase-N`, `env:docker|kvm|vmware|bare-metal`.
The immediate next steps are **P0.2-01**, **P0.2-02** and **P1.1-01**.
