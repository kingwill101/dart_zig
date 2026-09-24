# Validation record

[Feature coverage](gap-implementation.md)

This records local checks from 2026-09-23. Build and execution are separate claims.
Commands run from this package with the selected zvm compiler on PATH.

| Check | Result |
| --- | --- |
| Dart static analysis | No issues in completed pass |
| Dartdoc | Three public libraries; zero warnings/errors |
| Documentation site | 622 HTML pages passed local link/anchor validation |
| Zig 0.15.2 native + Wasm | Passed: native demos, isolates, Wasm example, schema frontend, generation and analysis |
| Zig 0.16.0 native + Wasm | Passed in the source checkout; standalone extraction validation below |
| Separate consumer asset | Passed: distinct library, injected sync/async calls, independent allocations, retained buffer cleanup |
| Linux ARM64, Windows x64, macOS ARM64 | Cross-compiled with Zig 0.16.0; not executed on those targets |
| Browser/device UI | Not run; no browser available in the tool environment |

Generated local output and detailed command logs are in ignored `build/`.

## Standalone extraction

The Git dependency resolves to fork revision `3ffb77d6c3d33a92c5252059f7f26c94c8c96636`.
Focused examples and final package checks are being rerun from this independent checkout.
