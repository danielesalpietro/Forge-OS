# Changelog

All notable changes to Forge-OS are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and the project uses semantic
versioning (`build/forge.env: FORGE_VERSION`).

## [Unreleased]

### Added
- Development plan with phased deliverables (`docs/PLAN.md`) and architecture
  documentation (`docs/ARCHITECTURE.md`, `docs/adr/`).
- ISO remastering pipeline (`build/`, `make iso`) producing an unattended
  UEFI/Secure Boot installer with LUKS2 full-disk encryption and an embedded
  offline package repository.
- Autoinstall profiles: `baseline`, `vm-dev`, `storage-node`.
- First-boot hardening service driving the Ansible baseline (Phase 1 roles) and
  TPM2-bound LUKS unlock with build-key rotation.
- `forge-validate` validation suite, KVM end-to-end test harness, Packer
  templates, molecule container scenario.
- GitHub Actions: lint, ISO build/release, nightly KVM e2e, molecule.
