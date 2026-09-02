# Initial administrator key

`forge-admin.pub` is the OpenSSH **public** key baked into every ISO as the
`authorized_keys` entry of the initial admin user (`FORGE_ADMIN_USER`, default
`forge`). It is public material and safe to version; the matching private key
stays on the administrator's workstation.

Precedence at build time (`build/scripts/30-inject-overlay.sh`):

1. `FORGE_ADMIN_SSH_KEY` environment variable / GitHub Actions variable, if set
2. the first line of this directory's `forge-admin.pub`

To rotate: replace the file (or set the variable), rebuild the ISO. Nodes that
are already installed are updated through Ansible (`forge_ssh` /
`authorized_keys`), not by reinstalling.

Additional administrators are added after installation (SSSD/AD groups or
`ansible-extra-vars.yml`), not by adding files here: the autoinstall template
renders a single initial key.
