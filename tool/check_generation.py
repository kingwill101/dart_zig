#!/usr/bin/env python3
"""Require checked-in generated artifacts to be reproducible with the active Zig."""
import hashlib
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
files = ['lib/src/ffi.g.dart', 'bin/demo.g.dart',
         'lib/src/generated/models.g.dart', 'zig/src/generated/models.zig',
         'lib/src/generated/runtime_bindings.g.dart', 'bin/alternate_bindings.g.dart']
def hashes():
    return {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
before = hashes()
subprocess.run(['sh', 'tool/regenerate.sh'], cwd=root, check=True)
after = hashes()
changed = [name for name in files if before[name] != after[name]]
if changed:
    raise SystemExit('Generated artifacts changed; review and regenerate before verification: ' + ', '.join(changed))
print('All six generated artifacts are reproducible.', flush=True)
