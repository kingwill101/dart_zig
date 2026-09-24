# Validation record

[Feature coverage](gap-implementation.md)

This records local checks from 2026-09-24. Build and execution are separate claims.
Commands run from this package with the selected zvm compiler on PATH.

| Check | Result |
| --- | --- |
| Dart static analysis | No issues in completed pass |
| Dartdoc | Three public libraries; zero warnings/errors |
| Documentation site | 624 HTML pages passed local link/anchor validation |
| Zig 0.15.2 native + Wasm | Passed: native demos, isolates, Wasm example, schema frontend, generation and analysis |
| Zig 0.16.0 native + Wasm | Passed in the standalone package |
| Separate consumer asset | Passed: distinct library, injected sync/async calls, independent allocations, retained buffer cleanup |
| Linux ARM64, Windows x64, macOS ARM64 | Cross-compiled with Zig 0.16.0; not executed on those targets |
| Browser/device UI | Not run; no browser available in the tool environment |

Generated local output and detailed command logs are in ignored `build/`.

## Standalone extraction

The Git dependency resolved to fork revision `3ffb77d6c3d33a92c5252059f7f26c94c8c96636`. The standalone `tool/verify.sh` pass completed with Zig 0.16.0. The separate consumer asset check passed. `dart build cli --target=example/run_all.dart --output=build/cli` produced the CLI bundle. Dartdoc reported zero warnings/errors and the site validator checked 624 HTML pages.
