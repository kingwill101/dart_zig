# Project setup and generation

## Direct FFI

For ordinary native functions, use `native_toolchain_zig` directly. Start in a
Dart package (`dart create -t console my_app` creates one). Add these dependencies
to `pubspec.yaml`; this path does not require `dart_zig`:

```yaml
dependencies:
  hooks: ^2.2.0
  logging: ^1.3.0
  native_toolchain_zig:
    git:
      url: https://github.com/kingwill101/native_toolchain_zig.dart.git
      ref: cimport-generator-wip
```

Create `zig/` and run `zig init` there to obtain `build.zig.zon` and its unique
fingerprint. Set its package name to `.my_app` and include `"build.zig"`,
`"build.zig.zon"`, and `"src"` in `.paths`. Replace `zig/build.zig` with:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exports = b.createModule(.{
        .root_source_file = b.path("src/exports.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
    });
    const library = b.addLibrary(.{
        .name = "my_app",
        .linkage = .dynamic,
        .root_module = exports,
    });
    b.installArtifact(library);
}
```

Put a native function in `zig/src/exports.zig`:

```zig
export fn add(a: i64, b: i64) i64 {
    return a + b;
}
```

Create `hook/build.dart` so Dart builds your own native asset:

```dart
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_zig/native_toolchain_zig.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    await ZigBuilder(
      assetName: 'my_app.dart',
      libraryName: 'my_app',
      zigDir: 'zig',
    ).run(input: input, output: output, logger: Logger('my_app'));
  });
}
```

Generate the binding from your package root:

```sh
dart pub get
dart run native_toolchain_zig:zig bindings --zig-dir zig --root-source-file src/exports.zig --output lib/src/ffi.g.dart --asset-id package:my_app/my_app.dart
```

Import `src/ffi.g.dart` from your package's public library or application code.
The generated `add(int, int)` calls Zig directly; there is no session or
`BinaryWriter`. Regenerate after changing exported declarations. An existing
Zig build only needs to add the export to its library root and set the generated
asset ID to the name registered by its build hook.

## Session setup

`dart_zig` has two dependencies in an application: the Dart runtime in
`pubspec.yaml` and the reusable Zig package in `zig/build.zig.zon`. The Zig
package is imported by the application's `zig/build.zig`; a Dart build hook
compiles the application asset. After adding the Dart dependencies shown in
the [README](../README.md#getting-started), run these commands from your
package root to create the native files and bindings:

```sh
dart pub get
dart run dart_zig:dart_zig init
```

`init` creates `zig/build.zig.zon`, `zig/build.zig`,
`zig/src/handlers.zig`, and `hook/build.dart`, then generates the Dart bindings.
It uses the package name from `pubspec.yaml` and resolves the Zig dependency
path from the installed Dart package. It stops before writing if any of those
files already exist.
The native asset belongs to the application; `dart_zig` does not build a
second default asset for it.

The initialized handler is a public Zig function. Its argument defines the
request and its return type defines the response:

```zig
pub const AddRequest = struct { a: i64, b: i64 };

pub fn add(request: AddRequest) !i64 {
    return request.a + request.b;
}
```

`generate` evaluates the handler signatures and writes
`lib/src/generated/api.g.dart` with the matching codecs and `ZigApi`.
Export that generated API from your package and use it with the generated
`createSession()` factory:

```dart
import 'package:dart_zig/dart_zig.dart';

import 'src/generated/runtime_bindings.g.dart' show createSession;
import 'src/generated/api.g.dart' show ZigApi;

Future<int> add(int a, int b) async {
  await initializeZig();
  final session = createSession();
  try {
    return await ZigApi(session).add((a: a, b: b));
  } finally {
    await session.close();
  }
}
```

Call `add(20, 22)` from Dart. Keep a session open and reuse `ZigApi` when
making many calls. Generated `startAdd` returns a cancellable `TypedCall`.
A public handler returning an iterator with `Item` and `next()` becomes a
credited stream; the runtime requests one item at a time as Dart grants credit.
The shared Zig exports derive dispatch from handler signatures at comptime.
The generated Dart API derives matching route IDs from handler names; renaming
a handler requires regenerating the bindings and native asset.
The same `handlers.zig` module can declare `pub const events = .{ ... }` with
`dz.protocol.RouteKind.signal` or `.state` values. The generator adds those
endpoints to `ZigApi`; the shared dispatcher validates and relays incoming
signals. A handler can publish an event with
`dz.events.emit(context, events, .notifications, message, &.{})`.
The explicit `protocol.zig` route form remains available for `signal` and
`state` endpoints. It generates `ProtocolApi` with eagerly initialized
`SignalEndpoint` fields; construct that facade before updates you need to
replay. Zig's `codec.Reader.decode(T)` and `codec.Writer.encode(value)` use the
same field order. The field name derives a stable route ID, so a state route
can be declared as `.updates = .{ .kind = dz.protocol.RouteKind.state, .message = dz.protocol.Text }`
without writing a number or string key. Zig code refers to it with the enum
literal `.updates`, for example `dz.events.id(routes, .updates)` or
`dz.events.relay(context, routes, .updates, bytes)`. Renaming a route requires
regenerating the Dart bindings and Zig asset. An explicit `.id` remains
available when matching an existing protocol.

The generator supports booleans, 8/16/32/64-bit integers, 32/64-bit floats,
nested named structs, `@import("dart_zig").protocol.Text` for UTF-8,
`[]const u8` for bytes, and `@import("dart_zig").protocol.Empty` for a
zero-byte message. Ordinary zero-field Zig structs also map to a zero-byte
Dart `Null` value. Text and byte slices decoded in
Zig borrow the input frame. Generated Dart decoders copy byte fields so their
values remain valid after native signal storage is released. See the
[state](../example/signals_state_example/) and
[attachment](../example/attachments_example/) examples for those types and
signal routes. Other payload shapes can use explicit codecs for now.

## Existing native builds

If the package already has a Zig build or Dart build hook, add the shared
runtime to those files. In `zig/build.zig.zon`, declare `dart_zig` at the
same revision as the Dart dependency. In `zig/build.zig`, import its
`dart_zig` module into your application module, then build a dynamic library
rooted at `dependency.path("src/exports.zig")`. Import both `dart_zig` and
`application` into that root module. The application module can be a handler
module containing public request functions. The shared exports derive their
dispatcher at comptime. Existing modules with `Application.create`,
`Application.destroy`, and `dispatch` continue to use those functions. In the
existing `hook/build.dart` callback, run
`ZigBuilder` with `assetName: '<package_name>.dart'`,
`libraryName: '<package_name>'`, and `zigDir: 'zig'`. Use the same package
name for the dynamic library. Then run `dart run dart_zig:dart_zig generate`
from the package root.

The examples show the complete layout:

- [Minimal call](../example/minimal_example/): one generated direct FFI call.
- [Runtime features](../example/runtime_features_example/): application-owned typed API, native and Web assets.
- [Native requests](../example/native_requests_example/): direct `dart_api_dl` request and reply.

For a local checkout in this repository, the Zig dependency is:

```zig
.dependencies = .{
    .dart_zig = .{ .path = "../../../zig" },
},
```

A separate application points `.path` to its own checkout, or pins a published
Zig archive with `.url` and `.hash`. The path above is relative to the example's
`zig/build.zig.zon`. The Zig package exposes `dart_zig` and `dart_zig_web`
modules and the shared native runtime export source. An application supplies
handlers or a dispatcher and builds its own asset with
`dependency.path("src/exports.zig")` as the native root. It can add
application-specific exports separately.

## Dart bindings

All FFI declarations come from `native_toolchain_zig`. For a project using the
shared runtime exports, `dart_zig generate` reads their ABI from the dependency
and writes `lib/src/ffi.g.dart` for the project's own asset ID. The package
name comes from `pubspec.yaml`; the build hook uses the same asset name. After
changing native exports, run this from the project directory:

Keep the Dart package and Zig dependency at matching revisions: generation
reads the ABI from the Dart package while `build.zig` compiles the Zig package.

```sh
dart run dart_zig:dart_zig generate
```

That command uses the `native_toolchain_zig` Dart API and generates a
`createSession()` factory for the application's asset. The asset-specific
adapter stays private to the generated file. A simple FFI project such as the
minimal example uses the generated declarations directly.
The `dart_zig` package keeps only generated shared ABI types in
`lib/src/runtime_abi.g.dart`; it does not build a native asset for examples.
If the project needs additional C ABI functions, put only those functions in
`zig/src/extra_exports.zig` and import that file from its application module.
The same command writes their bindings to `lib/src/ffi_app.g.dart`; it does not
copy the runtime exports into the application.
For `handlers.zig` and `protocol.zig`, the generator also creates message
codecs and a typed facade. Other applications can define their own wire format
and Dart/Zig APIs. The
[runtime feature Dart API](../example/runtime_features_example/lib/src/models.dart),
[Zig codecs](../example/runtime_features_example/zig/src/models.zig), and
[dispatcher](../example/runtime_features_example/zig/src/application.zig)
show one application-owned implementation.

The example `hook/build.dart` files compile each application's own Zig asset
when Dart builds or runs it. `dart pub get` resolves the Dart packages; Zig
resolves `build.zig.zon` when the asset is compiled.
