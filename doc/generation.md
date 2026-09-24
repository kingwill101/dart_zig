# Schema and binding generation

[Back to the package guide](../README.md)

## Generation

```sh
./tool/regenerate.sh
```

This runs the schema generator, Zig formatting, and the existing
`native_toolchain_zig:zig bindings` CLI. **Every Dart FFI declaration is generated**;
handwritten Dart files provide ownership, scheduling, and ergonomic wrappers.
Do not edit `*.g.dart` or `zig/src/generated/models.zig` manually.

### Other native assets

`NativeSession(bindings: yourGeneratedAdapter)` accepts a `RuntimeBindings`
implementation for an application's native library. Generate the application's
FFI with the CLI, then run `tool/generate_backend.py` with `--ffi`, `--output`,
`--native-import`, `--abi-import`, and `--interface-import` pointing to those
bindings and the shared ABI/interface. The adapter uses that same library for
buffer release and finalizers. `bin/alternate_bindings.g.dart` demonstrates the
adapter shape against this example's library. `python3 tool/check_consumer.py`
exercises a separately compiled library through the shared runtime.

The application schema facade, including synchronous functions, is generated
alongside its own FFI file. Currently synchronous schema generation supports
`i64_i64_to_i64`; other signatures require extending the generator.
`NativeSession.liveBuffers` and `liveBufferBytes` report the default asset;
custom assets expose their counters through the injected bindings.

## Adding an operation

1. Define its request/result types in [schema.json](../schema.json). Models map
   field names to types; unions map variant names to payload types.
2. Add an operation with a unique `id`, `name`, `input`, and `output`. Mark native
   streams with `"stream": true`. Signal routes are listed separately.
3. Run `./tool/regenerate.sh` to generate the models, codecs, operation constants,
   Dart facade, low-level FFI, and runtime adapters.
4. Implement the operation in [application.zig](../zig/src/application.zig),
   using the generated operation constant and matching request/result codecs.
5. Exercise it through the generated Dart facade. The existing
   [toolkit demo](../bin/toolkit.dart) shows the supported patterns.

The schema validator rejects unknown/recursive types, reserved or duplicate names,
invalid routes, duplicate enum variants, invalid callback fields, and unsupported
collection definitions before writing output. Errors identify the JSON field path.
This is strict matching, not a schema compatibility migration system.
Changing the schema fingerprint requires matching native and Dart artifacts.
Model field order and enum/union declaration order determine encoding order/tags;
the fingerprint is a mismatch check, not a substitute for coordinated versioning.

## Supported schema types

| Schema | Dart | Encoding |
| --- | --- | --- |
| `i8/u8`, `i16/u16`, `i32/u32`, `i64/u64` | `int` | Fixed-width little-endian integer bits |
| `i128`, `u128` | `BigInt` | Exact 16-byte integer, range checked |
| `f32`, `f64` | `double` | IEEE 754, little-endian |
| `bool` | `bool` | One byte: 0 or 1 |
| `string` | `String` | u32 byte length followed by UTF-8 |
| `bytes` | `Uint8List` | u32 length followed by raw bytes |
| `T?` | nullable `T` | Presence boolean followed by the value when present |
| `T[]` | `List<T>` | u32 element count followed by encoded elements |
| named map/set | `Map<K,V>` / `Set<T>` | Length-prefixed entries; duplicate keys/elements rejected |
| named fixed array | `List<T>` | Exactly the declared number of elements |
| named tuple | Dart record | Positional fields in order |
| named model | generated class | Fields in schema declaration order |
| enum / union | enum / sealed class | u32 tag, followed by a union payload |
| `void` | `void` | No result payload |

Dart native integers use signed 64-bit representation; treat opaque `u64` handles
as bits, not arithmetic values. Lists are limited to one million elements.
Generated Dart byte fields can borrow the decoded input allocation. Model
constructors retain supplied lists and bytes without deep copying.

## Reproducibility

```sh
python3 tool/check_generation.py
```

This hashes all six generated artifacts, regenerates them, and rejects drift.
It writes regenerated files even when it reports a mismatch; review those changes.
Always change generators or the schema instead of hand-editing generated files.
The adapter generator emits ordinary wrappers around CLI-generated declarations;
it does not create FFI declarations itself. Use package imports consistently in
external adapters to preserve Dart type identity for the shared runtime interface.

## Extraction

All package sources, vendored licenses, generated files, docs, and examples are
in this standalone repository. The toolchain dependency is pinned to the fork
branch `cimport-generator-wip` in pubspec.yaml; scaffolds preserve that Git source.

Pin matching Dart/schema/native revisions. Internal Zig runtime objects are not a
stable ABI across independently compiled compiler/package revisions. The existing
CLI handles low-level bindings; this prototype's schema generator handles the
higher-level models and operations. It does not yet infer arbitrary Zig APIs in
the way FRB infers Rust APIs.

## Workflow commands

`dart_zig.json` selects the schema and Dart/Zig executable paths. All workflow
commands are local Python tools in this repo; consuming applications
remain plain Dart packages.

```sh
python3 tool/dart_zig.py doctor
python3 tool/dart_zig.py generate
python3 tool/dart_zig.py watch
python3 tool/dart_zig.py web --run
python3 tool/dart_zig.py scaffold build/my_package --name my_package
```

Scaffold refuses to overwrite an existing directory and copies a standalone
starting package without caches. It preserves the Git toolchain dependency configured by this package. Watch regenerates when
the schema or handwritten Zig sources change. `doctor` checks tools and schema,
not target-device execution.

## Optional Zig declaration frontend

```sh
python3 tool/dart_zig.py schema --source authoring/messages.zig --output build/authoring/schema.json
python3 tool/generate_models.py --root build/authoring
```

The first command reflects declared Zig models into the same intermediate schema.
`authoring/messages.zig` demonstrates typed fields, metadata, and binary-field
annotation. Primitive fields, optionals, slices, and references to declared models
are inferred. Rich collection aliases, enum/union declarations, endpoints, and
operation metadata remain explicit in the JSON metadata. Arbitrary Zig function
inference is outside this frontend. Generated Dart files expect the companion
runtime imports; use the scaffold for an executable package.

## Evolution rules

Field order and enum/union order are part of the wire contract. Reordering fields,
changing types/routes, and changing optionality require coordinated Dart/native
regeneration. The fingerprint preserves declaration order and rejects mismatches.
There is no unknown-field skipping or negotiated mixed-version compatibility.
Map keys and set elements currently support string, i32/u32, and bool equality;
collection decoding rejects duplicates. Mutable Dart collection values must be
kept unchanged while shared with listeners. Web int64 precision limits are
explicit in the [platform guide](platforms.md).
