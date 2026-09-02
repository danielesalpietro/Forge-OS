# Packer: install Forge-OS from the ISO in QEMU (UEFI + swtpm) and export a
# qcow2 golden image. Run tests/kvm/install-deps.sh first and start swtpm:
#   swtpm socket --tpm2 --tpmstate dir=/tmp/forge-tpm --ctrl type=unixio,path=/tmp/forge-swtpm.sock &
#   packer init tests/packer && packer build -var iso=build/out/forge-os-0.1.0-vm-dev-amd64.iso tests/packer/forge-kvm.pkr.hcl
packer {
  required_plugins {
    qemu = { source = "github.com/hashicorp/qemu", version = ">= 1.1.0" }
  }
}

variable "iso"            { type = string }
variable "iso_checksum"   { type = string, default = "none" }
variable "ssh_username"   { type = string, default = "forge" }
variable "ssh_private_key"{ type = string, default = "~/.ssh/id_ed25519" }
variable "disk_size"      { type = string, default = "60G" }
variable "output_dir"     { type = string, default = "build/packer-kvm" }
variable "swtpm_socket"   { type = string, default = "/tmp/forge-swtpm.sock" }

source "qemu" "forge" {
  iso_url              = var.iso
  iso_checksum         = var.iso_checksum
  output_directory     = var.output_dir
  vm_name              = "forge-os.qcow2"
  format               = "qcow2"
  disk_size            = var.disk_size
  disk_interface       = "virtio"
  net_device           = "virtio-net"
  accelerator          = "kvm"
  machine_type         = "q35"
  cpus                 = 2
  memory               = 4096
  headless             = true
  efi_boot             = true
  efi_firmware_code    = "/usr/share/OVMF/OVMF_CODE_4M.ms.fd"
  efi_firmware_vars    = "/usr/share/OVMF/OVMF_VARS_4M.ms.fd"
  qemuargs = [
    ["-chardev", "socket,id=chrtpm,path=${var.swtpm_socket}"],
    ["-tpmdev", "emulator,id=tpm0,chardev=chrtpm"],
    ["-device", "tpm-tis,tpmdev=tpm0"],
    ["-global", "driver=cfi.pflash01,property=secure,value=on"],
  ]
  boot_wait            = "5s"
  boot_command         = ["<enter>"]
  ssh_username         = var.ssh_username
  ssh_private_key_file = var.ssh_private_key
  ssh_timeout          = "90m"
  ssh_handshake_attempts = 200
  shutdown_command     = "sudo systemctl poweroff"
}

build {
  sources = ["source.qemu.forge"]

  provisioner "shell" {
    inline = [
      "until [ -f /var/lib/forge/firstboot.done ]; do sleep 15; done",
      "sudo forge-validate --text || true",
    ]
  }
}
