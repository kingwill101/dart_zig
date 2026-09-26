#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
dart analyze lib bin tool test
dart test
zig build --build-file zig/build.zig
zig build --build-file zig/build.zig test
(
  cd example/minimal_example
  dart analyze lib bin hook
  zig build --build-file zig/build.zig
  dart run bin/main.dart
)
(
  cd example/runtime_features_example
  dart analyze lib bin demo hook tool web
  zig build --build-file zig/build.zig
  dart run bin/main.dart
  dart run demo/toolkit.dart
  dart run demo/isolates.dart
  dart run demo/backend_injection.dart
  sh tool/build_web.sh
  node tool/run_web.mjs
)
(
  cd example/native_requests_example
  dart analyze lib bin hook
  zig build --build-file zig/build.zig
  dart run bin/main.dart
  dart run bin/stress.dart
)
for name in calls streams signals_state attachments callbacks native_ownership lifecycle diagnostics memory_transport isolates web; do
  (
    cd "example/${name}_example"
    dart analyze lib bin hook
    zig build --build-file zig/build.zig
    dart run bin/main.dart
  )
done
(
  cd example/web_example
  dart analyze web tool
  sh tool/build_web.sh
  node tool/run_web.mjs
)
