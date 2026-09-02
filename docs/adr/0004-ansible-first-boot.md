# ADR-0004: Hardening applied by Ansible at first boot, offline, re-runnable

**Status:** accepted · **Date:** 2026-09-02

## Context
Hardening could be baked into the ISO squashfs, applied through cloud-init
`runcmd`, shell scripts in late-commands, or a configuration-management run
after the first reboot.

## Decision
Ship Ansible content (Forge roles + vendored collections + CIS role) in the ISO
and run it from `forge-firstboot.service` on the installed system, before SSH
is exposed. The same playbooks are re-runnable for drift remediation and
reused unchanged in Phase 2/3 (storage and platform playbooks).

## Consequences
- Roles are testable in Docker (molecule) independently of the ISO.
- First boot takes a few minutes and ends with a reboot (initramfs, audit
  rules, kernel parameters).
- Baking into the squashfs stays an optimisation for Phase 4 image builds.
