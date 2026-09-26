#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
dart run dart_zig:dart_zig generate
dart format lib/src/runtime_abi.g.dart
(
  cd example/minimal_example
  dart run native_toolchain_zig:zig bindings --zig-dir zig --root-source-file src/exports.zig --output lib/src/ffi.g.dart --asset-id package:minimal_example/minimal_example.dart
)
(
  cd example/runtime_features_example
  dart run dart_zig:dart_zig generate
)
(
  cd example/native_requests_example
  dart run dart_zig:dart_zig generate
)
for name in calls streams signals_state attachments callbacks native_ownership lifecycle diagnostics memory_transport isolates web; do
  (
    cd "example/${name}_example"
    dart run dart_zig:dart_zig generate
  )
done
