#!/usr/bin/env bash
# End-to-end test of a Forge-OS ISO under QEMU/KVM:
#   UEFI + Secure Boot (OVMF with Microsoft keys) + emulated TPM 2.0 (swtpm)
#   1. unattended install from the ISO      (VM reboots -> QEMU exits)
#   2. first boot: hardening + TPM enrolment (VM reboots -> QEMU exits)
#   3. steady state: LUKS must unlock via TPM without interaction; forge-validate
#      is executed over SSH and its JSON report saved next to the logs.
#
# Usage: tests/kvm/run-iso.sh <iso> [options]
#   --ssh-key <path>   private key matching FORGE_ADMIN_SSH_KEY used at build (default ~/.ssh/id_ed25519)
#   --user <name>      admin user (default: forge)
#   --workdir <dir>    state directory (default: build/test-kvm)
#   --disk-size <sz>   qcow2 size (default 60G) --memory <MiB> (4096) --cpus <n> (2)
#   --timeout <sec>    per-phase timeout (default 3600)
#   --no-secureboot    plain OVMF without Secure Boot
#   --keep             keep the VM disk / TPM state after the test
# Build the ISO with FORGE_KERNEL_ARGS="console=ttyS0,115200n8 console=tty0" to
# get the installer log on the serial console (serial-*.log).
set -euo pipefail

ISO="${1:?usage: run-iso.sh <iso> [options]}"; shift
SSH_KEY="${HOME}/.ssh/id_ed25519"; USER_NAME="${FORGE_ADMIN_USER:-forge}"
WORKDIR="$(pwd)/build/test-kvm"; DISK_SIZE=60G; MEMORY=4096; CPUS=2; TIMEOUT=3600
SECUREBOOT=1; KEEP=0; SSH_PORT="${SSH_PORT:-2222}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-key) SSH_KEY="$2"; shift;; --user) USER_NAME="$2"; shift;; --workdir) WORKDIR="$2"; shift;;
    --disk-size) DISK_SIZE="$2"; shift;; --memory) MEMORY="$2"; shift;; --cpus) CPUS="$2"; shift;;
    --timeout) TIMEOUT="$2"; shift;; --no-secureboot) SECUREBOOT=0;; --keep) KEEP=1;;
    *) echo "unknown option $1" >&2; exit 2;;
  esac; shift
done
log() { printf '\033[1;35m[test-kvm %s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }
for t in qemu-system-x86_64 qemu-img swtpm ssh; do command -v "$t" >/dev/null || die "missing $t (tests/kvm/install-deps.sh)"; done
[[ -f "${ISO}" ]] || die "ISO not found: ${ISO}"
[[ -f "${SSH_KEY}" ]] || die "SSH private key not found: ${SSH_KEY}"

# --- firmware ----------------------------------------------------------------
find_fw() { local f; for f in "$@"; do [[ -f "$f" ]] && { echo "$f"; return; }; done; return 1; }
if [[ ${SECUREBOOT} -eq 1 ]]; then
  CODE="$(find_fw /usr/share/OVMF/OVMF_CODE_4M.ms.fd /usr/share/OVMF/OVMF_CODE_4M.secboot.fd /usr/share/OVMF/OVMF_CODE.secboot.fd)" || die "no Secure Boot capable OVMF found"
  VARS="$(find_fw /usr/share/OVMF/OVMF_VARS_4M.ms.fd /usr/share/OVMF/OVMF_VARS.ms.fd)" || die "no OVMF vars with Microsoft keys found"
else
  CODE="$(find_fw /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd)" || die "no OVMF found"
  VARS="$(find_fw /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd)" || die "no OVMF vars found"
fi

mkdir -p "${WORKDIR}/tpm"
[[ ${KEEP} -eq 1 && -f "${WORKDIR}/disk.qcow2" ]] || { rm -f "${WORKDIR}/disk.qcow2"; qemu-img create -q -f qcow2 "${WORKDIR}/disk.qcow2" "${DISK_SIZE}"; cp "${VARS}" "${WORKDIR}/OVMF_VARS.fd"; rm -rf "${WORKDIR}/tpm"/*; }
ACCEL="tcg"; [[ -w /dev/kvm ]] && ACCEL="kvm"
[[ "${ACCEL}" == "kvm" ]] || log "WARNING: /dev/kvm not writable, using TCG (slow)"

SWTPM_PID=""; QEMU_PID=""
cleanup() {
  [[ -n "${QEMU_PID}" ]] && kill "${QEMU_PID}" 2>/dev/null || true
  [[ -n "${SWTPM_PID}" ]] && kill "${SWTPM_PID}" 2>/dev/null || true
  [[ ${KEEP} -eq 1 ]] || rm -f "${WORKDIR}/disk.qcow2"
}
trap cleanup EXIT

start_swtpm() {
  rm -f "${WORKDIR}/swtpm.sock"
  swtpm socket --tpm2 --tpmstate dir="${WORKDIR}/tpm" --ctrl type=unixio,path="${WORKDIR}/swtpm.sock" --log level=1 &
  SWTPM_PID=$!
  for _ in $(seq 1 50); do [[ -S "${WORKDIR}/swtpm.sock" ]] && return 0; sleep 0.1; done
  die "swtpm did not start"
}

# start_vm <phase> <with-cdrom:0|1>
start_vm() {
  local phase="$1" cdrom="$2"
  start_swtpm
  local args=(
    -name "forge-test-${phase}" -machine "q35,smm=on,accel=${ACCEL}" -cpu max -m "${MEMORY}" -smp "${CPUS}"
    -global "driver=cfi.pflash01,property=secure,value=on"
    -drive "if=pflash,format=raw,unit=0,readonly=on,file=${CODE}"
    -drive "if=pflash,format=raw,unit=1,file=${WORKDIR}/OVMF_VARS.fd"
    -chardev "socket,id=chrtpm,path=${WORKDIR}/swtpm.sock" -tpmdev "emulator,id=tpm0,chardev=chrtpm" -device "tpm-tis,tpmdev=tpm0"
    -drive "file=${WORKDIR}/disk.qcow2,if=none,id=disk0,format=qcow2" -device "virtio-blk-pci,drive=disk0,bootindex=1"
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" -device "virtio-net-pci,netdev=net0"
    -device virtio-rng-pci -display none -no-reboot
    -serial "file:${WORKDIR}/serial-${phase}.log"
    -monitor "unix:${WORKDIR}/monitor.sock,server,nowait"
  )
  if [[ "${cdrom}" == "1" ]]; then
    args+=(-drive "file=${ISO},if=none,id=cd0,media=cdrom,readonly=on" -device "ide-cd,drive=cd0,bootindex=0")
  fi
  log "phase '${phase}': starting VM (accel=${ACCEL}, secureboot=${SECUREBOOT})"
  qemu-system-x86_64 "${args[@]}" &
  QEMU_PID=$!
}
wait_vm_exit() {
  local deadline=$(( $(date +%s) + TIMEOUT ))
  while kill -0 "${QEMU_PID}" 2>/dev/null; do
    (( $(date +%s) > deadline )) && { kill "${QEMU_PID}"; die "phase timed out after ${TIMEOUT}s"; }
    sleep 5
  done
  wait "${QEMU_PID}" || true; QEMU_PID=""
  kill "${SWTPM_PID}" 2>/dev/null || true; SWTPM_PID=""
}
ssh_vm() { ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
             -i "${SSH_KEY}" -p "${SSH_PORT}" "${USER_NAME}@127.0.0.1" "$@"; }

# --- phase 1: install --------------------------------------------------------
start_vm install 1
wait_vm_exit
grep -qs 'forge-install-failure' "${WORKDIR}/serial-install.log" && die "installer reported a failure (see serial-install.log)"
log "install phase finished"

# --- phases 2..n: first boot (+ reboot), then validate ------------------------
for attempt in 1 2 3; do
  start_vm "boot${attempt}" 0
  deadline=$(( $(date +%s) + TIMEOUT ))
  validated=0
  while kill -0 "${QEMU_PID}" 2>/dev/null; do
    (( $(date +%s) > deadline )) && { kill "${QEMU_PID}"; die "boot${attempt} timed out" ; }
    if ssh_vm 'test -f /var/lib/forge/firstboot.done' 2>/dev/null; then
      log "first boot completed; running forge-validate"
      ssh_vm 'sudo forge-validate --json' > "${WORKDIR}/validation-report.json" && rc=0 || rc=$?
      ssh_vm 'sudo forge-validate --text' | tee "${WORKDIR}/validation-report.txt" || true
      ssh_vm 'sudo journalctl -u forge-firstboot --no-pager' > "${WORKDIR}/firstboot-journal.log" || true
      echo system_powerdown | socat - "unix-connect:${WORKDIR}/monitor.sock" >/dev/null 2>&1 || kill "${QEMU_PID}"
      validated=1
      break
    fi
    sleep 10
  done
  wait_vm_exit
  [[ ${validated} -eq 1 ]] && break
  log "VM rebooted (boot${attempt}); continuing"
done
[[ ${validated} -eq 1 ]] || die "system never reached a validated state"
log "validation report: ${WORKDIR}/validation-report.json (exit ${rc})"
jq -r '.summary' "${WORKDIR}/validation-report.json" 2>/dev/null || true
exit "${rc}"
