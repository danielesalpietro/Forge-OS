# Docker: self-contained sub-developments

Docker is used for everything that does not need a kernel, firmware or a TPM:

| Use                           | How                                                            |
|-------------------------------|----------------------------------------------------------------|
| ISO build                     | `make builder && make iso` (image from `build/Dockerfile`)     |
| Lint / schema validation      | `make lint-docker`                                             |
| Ansible role development      | `tests/docker/molecule` (ansible/molecule scenario `container`)|
| Offline package repo checks   | `make packages` then inspect `build/work/iso/forge/repo`       |

Roles read the fact `forge_container_mode` (set from `ansible_virtualization_type`)
and skip tasks that need a real kernel/TPM/firmware (sysctl, auditd, nftables
runtime, clevis). Run the container scenario with:

```bash
cd ansible && pip install molecule molecule-plugins[docker] ansible-lint
molecule test -s container
```

Anything hardware related (Secure Boot, TPM, LUKS unlock, nftables, auditd
immutable rules) must be validated in KVM (`tests/kvm`) or VMware.
