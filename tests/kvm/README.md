# KVM end-to-end test

`run-iso.sh` boots a Forge-OS ISO in QEMU with UEFI **Secure Boot** (OVMF with
the Microsoft certificates pre-enrolled) and an emulated **TPM 2.0** (swtpm),
performs the unattended install, lets the first boot enrol the TPM, verifies
that the encrypted root unlocks **without interaction** on the following boot
and finally runs `forge-validate` over SSH.

```bash
tests/kvm/install-deps.sh
ssh-keygen -t ed25519 -N '' -f build/test-key
FORGE_ADMIN_SSH_KEY="$(cat build/test-key.pub)" \
FORGE_KERNEL_ARGS="console=ttyS0,115200n8 console=tty0" \
PROFILE=vm-dev make iso
tests/kvm/run-iso.sh build/out/forge-os-*-vm-dev-amd64.iso --ssh-key build/test-key
```

Artifacts land in `build/test-kvm/`: `serial-*.log`, `firstboot-journal.log`,
`validation-report.{json,txt}`. Use `--keep` to keep the disk image and open it
with `virsh`/`virt-manager` afterwards (`virt-install --import --boot uefi,...`).

Manual libvirt equivalent (Secure Boot + vTPM):

```bash
virt-install --name forge-dev --memory 4096 --vcpus 2 --machine q35 \
  --boot uefi,loader=/usr/share/OVMF/OVMF_CODE_4M.ms.fd,loader.secure=yes,nvram.template=/usr/share/OVMF/OVMF_VARS_4M.ms.fd \
  --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
  --disk size=60,bus=virtio --cdrom build/out/forge-os-0.1.0-vm-dev-amd64.iso \
  --network network=default --os-variant ubuntu24.04 --graphics none --console pty
```
