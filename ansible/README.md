# Forge-OS Ansible content

Applied at first boot (`forge-firstboot.service`) from `/opt/forge/ansible`
fully offline, and re-runnable at any time for drift remediation:

```bash
sudo ansible-playbook -i inventories/local.ini playbooks/site.yml -e forge_profile=baseline
sudo ansible-playbook -i inventories/local.ini playbooks/baseline.yml --tags ssh,sudo
```

| Role                       | Phase | README requirement                                            |
|----------------------------|-------|---------------------------------------------------------------|
| forge_base                 | 1     | minimal install hygiene, NTP, journald, banners, password policy |
| forge_kernel_sysctl        | 1     | kernel/network sysctl hardening, module blacklist, kernel cmdline |
| forge_ssh                  | 1     | SSH key-only, root disabled, modern crypto, AllowGroups        |
| forge_sudo                 | 1     | RBAC (forge-admin / forge-operator), least privilege, session recording |
| forge_apparmor             | 1     | AppArmor enforced                                              |
| forge_auditd               | 1     | auditd enabled, CIS rule set, immutable                        |
| forge_nftables             | 1     | nftables default-deny policy, drop-in dir for later phases     |
| forge_fail2ban             | 1     | fail2ban (sshd, nftables actions)                              |
| forge_unattended_upgrades  | 1     | unattended security updates                                    |
| forge_systemd_hardening    | 1     | systemd hardening policies, core dumps, masked units           |
| forge_luks_tpm             | 1     | TPM-backed LUKS key (clevis), recovery key, optional Tang escrow, build-key rotation |
| forge_identity             | 1     | Active Directory / LDAP via SSSD                               |
| forge_mfa                  | 1     | MFA support (TOTP / FIDO2 PAM modules)                         |
| forge_ubuntu_pro           | 1     | Ubuntu Pro attach, ESM, Livepatch, USG                         |
| forge_cis                  | 1     | CIS Benchmark alignment (ansible-lockdown UBUNTU24-CIS)        |
| forge_validate             | 1     | validation suite + daily drift timer                           |
| forge_ceph / forge_monitoring / forge_backup | 2 | storage stack, EC pools, monitoring, backup (stubs) |
| forge_containerd / forge_k3s / forge_gpu / forge_gitops | 3 | Kubernetes foundation, GPU, GitOps (stubs) |

Variables: `group_vars/all.yml` (defaults) < `profiles/<profile>.yml` <
`/etc/forge/ansible-extra-vars.yml` (per node) < `-e` (first-boot passes the
values from `/etc/forge/forge.conf`).
