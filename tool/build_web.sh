#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
zig build --build-file zig/build_web.zig --prefix build/wasm -Doptimize=ReleaseSafe
mkdir -p build/web
cp build/wasm/bin/dart_zig.wasm build/web/dart_zig.wasm
cp web/index.html build/web/index.html
dart compile js "${1:-web/main.dart}" -O2 -o build/web/main.dart.js
