# Security policy

Forge-OS is a security baseline; vulnerability reports are welcome.

- **Report privately** through GitHub Security Advisories
  (*Security* > *Report a vulnerability*) or to the maintainer listed in
  `.github/CODEOWNERS`. Do not open public issues for exploitable findings.
- Include the ISO manifest (`*.manifest.json`), the profile and the output of
  `forge-validate --json` when relevant.
- Supported: the latest tagged release and the `develop` branch.

## Handling of secrets in the build

| Secret                       | Where it lives                              | Lifetime                                   |
|------------------------------|---------------------------------------------|--------------------------------------------|
| Build-time LUKS passphrase   | ISO (`/forge/autoinstall/user-data`, `/forge/keys`) and `/etc/forge/luks-build-key` on the target | Removed from LUKS and shredded at first boot |
| LUKS recovery key            | `/root/forge-recovery-key` (0600)           | Operator must move it to a vault           |
| Ubuntu Pro token             | `/etc/forge/pro-token` (if provisioned)     | Deleted after attach                       |
| AD join password             | `/etc/forge/ad-join-password`               | Operator provisioned, deleted after join   |

Treat every built ISO as confidential until the nodes installed from it have
completed their first boot.
