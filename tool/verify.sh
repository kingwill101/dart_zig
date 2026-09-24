#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 tool/check_generation.py
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed lib bin hook benchmark web example
zig fmt --check zig/src zig/build.zig zig/build_web.zig zig/build.zig.zon authoring
zig build --build-file zig/build.zig
# Compiler PATH is not itself a build-hook dependency; force a fresh hook run.
python3 - <<'PY'
from pathlib import Path
for path in Path('.dart_tool/hooks_runner/dart_zig').glob('*/output.json'):
    path.unlink()
PY
dart run bin/toolkit.dart
dart run bin/main.dart
dart run example/isolates.dart
dart run example/run_all.dart
dart run example/backend_injection.dart

sh tool/build_web.sh web/verify.dart
node tool/run_web.mjs
python3 tool/dart_zig.py schema --source authoring/messages.zig --output build/authoring/schema.json

sh tool/build_web.sh
node tool/run_web.mjs
