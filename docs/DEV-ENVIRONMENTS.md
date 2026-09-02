# Development environments

| Need | Docker | KVM | VMware | Bare-metal |
|------|:------:|:---:|:------:|:----------:|
| Build the ISO, lint, schema validation | ✔ | | | |
| Ansible role development (container-safe roles) | ✔ | | | |
| Lab services (Tang, Samba AD, Prometheus, registry) | ✔ | | | |
| Installer / disk layout / LUKS | | ✔ | ✔ | ✔ |
| Secure Boot, TPM 2.0, measured boot, TPM unlock | | ✔ (OVMF+swtpm) | ✔ (vTPM) | ✔ |
| nftables, auditd, AppArmor, kernel cmdline | | ✔ | ✔ | ✔ |
| Multi-node Ceph / K3s labs | | ✔ | ✔ | ✔ |
| GPU, firmware quirks, performance | | | | ✔ |

## Docker

```bash
make builder                    # build the builder image (build/Dockerfile)
cp .env.example .env && $EDITOR .env   # optional; admin key defaults to autoinstall/keys/forge-admin.pub
set -a; source .env; set +a
make iso PROFILE=vm-dev         # → build/out/forge-os-<ver>-vm-dev-amd64.iso
make lint-docker
make builder-shell              # interactive shell with all tools
```

Sub-developments that are self-contained (a role, the validation suite, the
package list) are developed and tested in Docker first, then integrated in the
main process through a PR that the KVM e2e test validates. See
`tests/docker/README.md` and `ansible/molecule/container`.

## KVM

```bash
tests/kvm/install-deps.sh
ssh-keygen -t ed25519 -N '' -f build/test-key
FORGE_ADMIN_SSH_KEY="$(cat build/test-key.pub)" \
FORGE_KERNEL_ARGS="console=ttyS0,115200n8 console=tty0" \
PROFILE=vm-dev make iso
tests/kvm/run-iso.sh build/out/forge-os-*-vm-dev-amd64.iso --ssh-key build/test-key
```

`run-iso.sh` drives install → first boot → TPM unlock → `forge-validate` and
leaves logs and the JSON report in `build/test-kvm/`. The same harness runs
nightly in GitHub Actions (`.github/workflows/test-kvm.yml`). For interactive
work use `virt-install` (see `tests/kvm/README.md`) or `tests/packer/forge-kvm.pkr.hcl`.

## VMware

Workstation/Fusion: EFI + Secure Boot supported; vTPM needs an encrypted VM.
vSphere: enable Secure Boot and add a vTPM (Key Provider required).
Automation: `tests/packer/forge-vmware.pkr.hcl`; details in `tests/vmware/README.md`.

## Bare-metal

Write the ISO with `dd` or use Ventoy (the ISO ships a `loopback.cfg`). Boot in
UEFI mode with Secure Boot **enabled** and TPM 2.0 **enabled/cleared** in the
firmware. The first GRUB entry erases the largest disk (baseline profile) or
the smallest SSD (storage-node profile) without confirmation. After the second
reboot log in with the admin key and run `sudo forge-validate`.
