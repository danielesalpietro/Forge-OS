# Packer: install Forge-OS in VMware Workstation/Fusion (vmware-iso builder).
# Secure Boot is enabled via firmware = "efi-secure". A vTPM in Workstation
# requires an *encrypted* VM, which the builder cannot create; use this template
# for baseline/vm-dev testing without TPM (forge-validate reports TPM checks as
# warnings in VMs) and tests/vmware/README.md for vSphere + vTPM.
packer {
  required_plugins {
    vmware = { source = "github.com/hashicorp/vmware", version = ">= 1.1.0" }
  }
}

variable "iso"             { type = string }
variable "iso_checksum"    { type = string, default = "none" }
variable "ssh_username"    { type = string, default = "forge" }
variable "ssh_private_key" { type = string, default = "~/.ssh/id_ed25519" }
variable "output_dir"      { type = string, default = "build/packer-vmware" }

source "vmware-iso" "forge" {
  iso_url              = var.iso
  iso_checksum         = var.iso_checksum
  output_directory     = var.output_dir
  vm_name              = "forge-os"
  guest_os_type        = "ubuntu-64"
  firmware             = "efi-secure"
  version              = "20"
  cpus                 = 2
  memory               = 4096
  disk_size            = 61440
  disk_adapter_type    = "nvme"
  network_adapter_type = "vmxnet3"
  headless             = true
  boot_wait            = "5s"
  boot_command         = ["<enter>"]
  ssh_username         = var.ssh_username
  ssh_private_key_file = var.ssh_private_key
  ssh_timeout          = "90m"
  shutdown_command     = "sudo systemctl poweroff"
  vmx_data = {
    "uefi.secureBoot.enabled" = "TRUE"
  }
}

build {
  sources = ["source.vmware-iso.forge"]
  provisioner "shell" {
    inline = [
      "until [ -f /var/lib/forge/firstboot.done ]; do sleep 15; done",
      "sudo forge-validate --text || true",
    ]
  }
}
