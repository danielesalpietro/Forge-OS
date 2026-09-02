# Contributing to Forge-OS

## Workflow

1. Pick (or open) an issue using the **Plan task** template; reference the
   identifier from `docs/PLAN.md` (e.g. `P1.2-03`).
2. Branch from `develop`: `feature/<phase>-<short-name>`.
3. Develop in the smallest environment that can prove the change:
   - **Docker** for build tooling and Ansible roles (`make lint-docker`, molecule).
   - **KVM** (`tests/kvm/run-iso.sh`) for anything touching the installer,
     boot chain, LUKS/TPM, firewall or audit.
   - **VMware** for parity checks; **bare-metal** before a release tag.
4. `make lint` must pass. Include the `forge-validate` report in the PR when the
   baseline changes.
5. Open a PR against `develop` using the template. `main` only receives release
   merges (tags `vX.Y.Z` trigger the ISO release workflow).

## Conventions

- Shell: `bash`, `set -euo pipefail`, shellcheck clean.
- Ansible: fully-qualified module names, idempotent tasks, `forge_` variable
  prefix, every hardware/kernel-dependent task guarded by `forge_container_mode`.
- Secrets never enter the repository or the ISO except the build-time LUKS key,
  which is rotated at first boot (see `docs/ARCHITECTURE.md`).
- Architecture decisions go into `docs/adr/` (one file per decision).

## Commit messages

`<area>: <imperative summary>` - e.g. `autoinstall: separate /var/log/audit LV`.
