# VMware test environments

| Feature            | Workstation / Fusion                          | vSphere / ESXi                                   |
|--------------------|-----------------------------------------------|--------------------------------------------------|
| UEFI Secure Boot   | yes (`firmware = "efi-secure"`)               | yes (VM options > Boot > Secure Boot)            |
| vTPM 2.0           | only on **encrypted** VMs (manual step)       | yes, requires a Key Provider (Native/Standard KMS)|
| Measured boot      | yes with vTPM                                 | yes with vTPM                                    |
| Automation         | `tests/packer/forge-vmware.pkr.hcl`           | `vsphere-iso` builder (`vTPM = true`) or `govc`   |

## Workstation quick start (manual)

1. Create a VM: *Ubuntu 64-bit*, UEFI, **Secure Boot enabled**, 2 vCPU, 4 GiB,
   60 GiB NVMe disk, attach the Forge-OS ISO.
2. To test TPM: *VM > Settings > Options > Access Control > Encrypt* (files only,
   "Only the files needed to support a TPM"), then *Add > Trusted Platform Module*.
3. Boot: the first GRUB entry installs unattended and reboots twice.
4. `ssh -i <key> forge@<ip>` then `sudo forge-validate`.

## vSphere (govc)

```bash
export GOVC_URL=... GOVC_USERNAME=... GOVC_PASSWORD=...
govc vm.create -m 4096 -c 2 -g ubuntu64Guest -firmware efi -disk 60GB -iso "[datastore] iso/forge-os-0.1.0-baseline-amd64.iso" forge-node-01
govc vm.change -vm forge-node-01 -e "uefi.secureBoot.enabled=TRUE"
# vTPM: add it from the vSphere UI (VM > Edit Settings > Add > Trusted Platform Module); it needs a configured Key Provider
govc vm.power -on forge-node-01
```

Ubuntu's signed shim/GRUB/kernel chain boots with the stock Microsoft UEFI CA,
so no custom certificates need to be enrolled in either environment.
