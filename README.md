# Forge-OS v0.1 - Hardened Ubuntu Security Baseline Platform

## Objective

Create Forge-OS, a hardened Ubuntu-based operating system designed to serve as the secure foundation for NorthStream and future enterprise, AI, cloud-native, edge, and storage-centric projects.

The goal is to provide a repeatable, secure-by-default operating environment with integrated security controls, storage resilience, and operational hardening.

---

## Vision

Forge-OS should become the common infrastructure layer for multiple projects, providing:

- Security by Default
- Compliance-Ready Baseline
- Immutable Deployment Patterns
- Enterprise Identity Integration
- Storage Resilience
- AI Infrastructure Readiness
- Kubernetes Readiness
- Hardware Root of Trust

---

## Security Requirements

### Hardware Root of Trust

- TPM 2.0 support
- UEFI Secure Boot
- Measured Boot
- Platform integrity validation

### Encryption

- AES-256 Full Disk Encryption (LUKS)
- TPM-backed key management
- Optional remote key escrow
- Encrypted swap
- Encrypted data partitions

### Operating System Hardening

- Ubuntu LTS minimal installation
- CIS Benchmark alignment
- Ubuntu Pro integration
- AppArmor enforced
- auditd enabled
- nftables default policy
- fail2ban
- unattended security updates
- systemd hardening policies

### Administrative Access

- Root login disabled
- SSH key authentication only
- MFA support
- RBAC model
- Sudo least-privilege policies
- Session logging and auditing
- Active Directory / LDAP integration

---

## Storage Services

### Erasure Coding

Deploy a distributed storage layer supporting:

- MicroCeph or Ceph
- Erasure Coding pools
- OSD encryption
- Data-at-rest protection
- Self-healing capabilities

Target examples:

- 4+2 EC
- 8+3 EC

---

## Cloud Native Platform Readiness

Prepare the platform to host:

- NorthStream
- vMemoryFabric
- AI inference engines
- Kubernetes workloads
- Storage services
- Internal developer platforms

Optional integrations:

- K3s
- Kubernetes
- Containerd
- NVIDIA Runtime
- GPU Operators

---

## Deliverables

### Phase 1

- Ubuntu Hardened Image
- Automated Installation
- Security Baseline
- TPM Validation
- Secure Boot Validation
- Encryption Validation

### Phase 2

- Storage Stack
- Erasure Coding
- Monitoring
- Backup Integration

### Phase 3

- Kubernetes Foundation
- GPU Enablement
- GitOps Automation

---

## Repository layout and quick start

The repository produces a **self-installing UEFI/Secure Boot ISO** for
bare-metal (and VMs) that installs an encrypted, hardened Ubuntu 24.04 LTS
and applies the security baseline at first boot. See
[docs/PLAN.md](docs/PLAN.md) for the phased development plan and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the design.

```
build/        ISO remastering pipeline (Dockerfile, scripts, package lists, GRUB menu)
autoinstall/  subiquity autoinstall profiles: baseline, vm-dev, storage-node
overlay/      first-boot service, late-install script, /etc/forge templates
ansible/      hardening roles (Phase 1) and Phase 2/3 playbooks
tests/        forge-validate suite, KVM e2e harness, Packer templates, VMware/Docker notes
docs/         plan, architecture, control matrix, ADRs
.github/      CI: lint, ISO build/release, nightly KVM end-to-end, molecule
```

```bash
cp .env.example .env            # set FORGE_ADMIN_SSH_KEY (your public key)
set -a; source .env; set +a
make builder                    # builder container (xorriso, apt, ansible, linters)
make iso PROFILE=baseline       # → build/out/forge-os-<version>-baseline-amd64.iso
make lint                       # shellcheck / yamllint / ansible-lint / autoinstall schema
tests/kvm/run-iso.sh build/out/forge-os-*-vm-dev-amd64.iso --ssh-key ~/.ssh/id_ed25519
```

Boot the ISO in UEFI mode with Secure Boot and TPM 2.0 enabled: the first GRUB
entry erases the target disk and installs unattended. After two reboots log in
with your SSH key and run `sudo forge-validate`.

**Development environments:** Docker (build, lint, role development), KVM with
OVMF + swtpm (reference for Secure Boot/TPM/LUKS tests, also in CI), VMware
(parity), bare-metal (release gate). Details: [docs/DEV-ENVIRONMENTS.md](docs/DEV-ENVIRONMENTS.md).

---

## Expected Outcome

Forge-OS provides a reusable enterprise-grade operating system foundation that combines:

- Hardware-based trust
- Strong encryption
- Administrative control
- Storage resilience
- Cloud-native readiness

while remaining vendor-neutral and suitable for AI, edge, datacenter and hybrid-cloud deployments.
