#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
for target in aarch64-linux-gnu x86_64-windows-gnu aarch64-macos; do
  zig build --build-file zig/build.zig --prefix "build/cross/$target" -Dtarget="$target" -Doptimize=ReleaseSafe
  echo "Compiled $target (execution not checked)"
done
