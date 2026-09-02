#!/usr/bin/env bash
# Static checks shared by `make lint` and CI: shell, YAML, Ansible, autoinstall.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "${REPO_ROOT}" || exit 1
rc=0
step() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }

step "shellcheck"
mapfile -t shfiles < <(git ls-files --cached --others --exclude-standard '*.sh' 'tests/validate/forge-validate' 'overlay/etc/motd-forge' 2>/dev/null)
shellcheck -x -S warning "${shfiles[@]}" || rc=1

step "yamllint"
yamllint -c .yamllint . || rc=1

step "autoinstall profiles (render with dummy secrets + schema)"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp}"' EXIT
for p in autoinstall/profiles/*/; do
  name="$(basename "${p}")"
  FORGE_ADMIN_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyForLintOnly lint@forge" \
  FORGE_LUKS_PASSPHRASE="lint-only-passphrase" FORGE_ADMIN_PASSWORD_HASH='$6$lint$lint' \
  FORGE_HOSTNAME=lint FORGE_ADMIN_USER=forge FORGE_TIMEZONE=Etc/UTC PROFILE="${name}" \
  envsubst '${FORGE_VERSION} ${FORGE_CODENAME} ${PROFILE} ${UBUNTU_CODENAME} ${FORGE_ADMIN_USER} ${FORGE_HOSTNAME} ${FORGE_TIMEZONE} ${FORGE_ADMIN_SSH_KEY} ${FORGE_LUKS_PASSPHRASE} ${FORGE_ADMIN_PASSWORD_HASH}' \
    < "${p}/user-data" > "${tmp}/${name}.yaml"
done
python3 build/scripts/validate-autoinstall.py "${tmp}"/*.yaml || rc=1

step "ansible-lint"
if command -v ansible-lint >/dev/null 2>&1; then
  (cd ansible && ansible-lint -c ../.ansible-lint) || rc=1
else
  warn "ansible-lint not installed, skipped"
fi

step "ansible syntax check"
if command -v ansible-playbook >/dev/null 2>&1; then
  (cd ansible && ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventories/local.ini playbooks/site.yml --syntax-check) || rc=1
else
  warn "ansible-playbook not installed, skipped"
fi

if [[ ${rc} -eq 0 ]]; then log "lint OK"; else die "lint failed"; fi
