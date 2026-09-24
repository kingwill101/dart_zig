#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 tool/generate_models.py
zig fmt zig/src/generated

dart run native_toolchain_zig:zig bindings \
  --root-source-file src/exports.zig --output lib/src/ffi.g.dart \
  --asset-id package:dart_zig/dart_zig.dart

dart run native_toolchain_zig:zig bindings \
  --root-source-file src/demo.zig --output bin/demo.g.dart \
  --asset-id package:dart_zig/dart_zig.dart --link-libc

python3 tool/generate_backend.py
python3 tool/generate_backend.py --output bin/alternate_bindings.g.dart --class-name AlternateRuntimeBindings --native-import package:dart_zig/src/ffi.g.dart --abi-import package:dart_zig/src/ffi.g.dart --interface-import package:dart_zig/src/generated/runtime_bindings.g.dart

dart format lib/src/generated lib/src/ffi.g.dart bin/demo.g.dart bin/alternate_bindings.g.dart
