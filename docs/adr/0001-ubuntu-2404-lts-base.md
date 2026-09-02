# ADR-0001: Ubuntu 24.04 LTS as the base

**Status:** accepted · **Date:** 2026-09-02

## Context
The README requires an "Ubuntu LTS minimal installation" with Ubuntu Pro,
AppArmor and CIS alignment. Two LTS releases are candidates: 24.04 (mature,
CIS benchmark and ansible-lockdown role available, USG profiles available) and
the newer 26.04 (recent, benchmark and tooling still catching up).

## Decision
Base Forge-OS 0.x on **Ubuntu 24.04.x LTS** (`ubuntu-server-minimal`), pinned by
point release and SHA-256 in `build/forge.env`. The base is a configuration
value; moving to the next LTS is a pull request validated by the KVM e2e test.

## Consequences
- CIS Ubuntu 24.04 benchmark, USG and ansible-lockdown content apply directly.
- Kernel 6.8 GA (HWE optional via `kernel.package`), systemd 255, clevis 21.
- Support horizon: standard until 2029, ESM until 2034 with Ubuntu Pro.
