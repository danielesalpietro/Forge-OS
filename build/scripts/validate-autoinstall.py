#!/usr/bin/env python3
"""Validate a rendered autoinstall user-data file against the subiquity schema.

Usage: validate-autoinstall.py <user-data> [<user-data> ...]
The schema (build/schema/autoinstall-schema.json) is vendored from
https://github.com/canonical/subiquity/blob/main/autoinstall-schema.json.
Storage configuration is only loosely typed by the schema, so a few Forge-OS
specific sanity checks are added on top.
"""
import json
import pathlib
import sys

import yaml

try:
    import jsonschema
except ImportError:  # pragma: no cover
    jsonschema = None

SCHEMA = pathlib.Path(__file__).resolve().parents[1] / "schema" / "autoinstall-schema.json"


def check(path: pathlib.Path) -> list[str]:
    errors: list[str] = []
    text = path.read_text()
    if not text.startswith("#cloud-config"):
        errors.append("first line must be '#cloud-config'")
    doc = yaml.safe_load(text)
    ai = doc.get("autoinstall") if isinstance(doc, dict) else None
    if not isinstance(ai, dict):
        return errors + ["missing top-level 'autoinstall' mapping"]

    if jsonschema is not None:
        schema = json.loads(SCHEMA.read_text())
        v = jsonschema.Draft7Validator(schema)
        errors += [f"schema: {'/'.join(map(str, e.path))}: {e.message}" for e in v.iter_errors(ai)]

    # Forge-OS invariants
    storage = ai.get("storage", {}).get("config", [])
    types = {c.get("type") for c in storage if isinstance(c, dict)}
    if "dm_crypt" not in types:
        errors.append("storage: no dm_crypt entry (full disk encryption is mandatory)")
    for c in storage:
        if isinstance(c, dict) and c.get("type") == "dm_crypt" and not c.get("key"):
            errors.append("storage: dm_crypt without key (was ${FORGE_LUKS_PASSPHRASE} rendered?)")
    ssh = ai.get("ssh", {})
    if ssh.get("allow-pw", False):
        errors.append("ssh: allow-pw must be false")
    if not ssh.get("authorized-keys"):
        errors.append("ssh: authorized-keys is empty")
    for cmd in ai.get("late-commands", []):
        if "$" + "{FORGE_" in str(cmd):
            errors.append(f"late-commands: unrendered variable in {cmd!r}")
    return errors


def main() -> int:
    rc = 0
    for arg in sys.argv[1:]:
        p = pathlib.Path(arg)
        errs = check(p)
        if errs:
            rc = 1
            print(f"FAIL {p}")
            for e in errs:
                print(f"  - {e}")
        else:
            print(f"OK   {p}")
    return rc


if __name__ == "__main__":
    sys.exit(main())
