#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
zig build wasm --build-file zig/build.zig --prefix build/wasm -Doptimize=ReleaseSafe
mkdir -p build/web
cp build/wasm/bin/runtime_features_example.wasm build/web/runtime_features_example.wasm
cp web/index.html build/web/index.html
dart compile js "${1:-web/main.dart}" -O2 -o build/web/main.dart.js
