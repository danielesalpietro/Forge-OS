# forge-validate

Post-install validation suite installed as `/usr/local/sbin/forge-validate` on
every Forge-OS node and executed automatically at the end of the first boot
(report: `/var/lib/forge/validation-report.{json,txt}`).

| Tag     | Covers (README requirement)                                              |
|---------|---------------------------------------------------------------------------|
| `rot`   | UEFI, Secure Boot state, TPM 2.0 presence/usability, measured boot (PCR7, event log) |
| `luks`  | LUKS2 / AES-256-XTS, root and swap inside LUKS, TPM2 binding, build key removed, recovery key |
| `os`    | AppArmor, auditd, nftables default-drop, fail2ban, unattended-upgrades, sysctl, mount options |
| `admin` | root locked, sshd policy, sudo RBAC groups, sudo I/O logging, pam_tty_audit, SSSD, MFA module |
| `pro`   | Ubuntu Pro attach / ESM status (warning only)                              |

```
forge-validate                 # colour table
forge-validate --json | jq .   # machine readable
forge-validate --tag rot,luks  # subset
```

Exit status is non-zero when any *critical* check fails. Checks marked `warn`
are advisory (e.g. Secure Boot inside a VM without OVMF secure variables).
