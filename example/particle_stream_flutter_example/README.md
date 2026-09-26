# Particle Stream (Flutter + Zig)

A standalone Flutter app with continuously updated Zig state. Zig owns up to
250,000 particles and advances their positions and velocities on a native
worker or in WebAssembly. A generated `ZigApi.simulate` stream carries a
160 × 90 RGBA density image and small counters to Flutter; the particle array
stays in Zig.

## Run

Install Flutter and Zig 0.15.2 or 0.16.0. From this directory:

```sh
flutter pub get
dart run dart_zig:dart_zig generate
flutter run -d linux --profile
```

Select another native Flutter target with `flutter devices` and
`flutter run -d <device> --profile`. For Chrome, use `flutter run -d chrome`.
Android, iOS, Linux, macOS, Windows, and Web project files are included.
On Web, Zig work runs on the browser event loop, so frame rate can be lower
than on a native worker.

The particle-count slider restarts the simulation. The display cap can be
changed while it is running. Pause keeps the Zig state alive and withholds
stream credits; one frame may already be in flight. Resume continues from that
state. Restart cancels the old stream and creates a fresh simulation.

The Dart subscription pauses after each frame until image decoding and the
display interval finish. `NativeSession` sends the next credit only after the
subscription resumes, so the Zig worker does not sleep to pace output. The
actual frame rate may be below the selected cap when computation, transport,
or image decoding takes longer than one interval.

**Zig state** counts the live particle, bin, and RGBA allocations owned by
this example's Zig simulations. It should fall when the particle count falls
and return to one simulation's size after a restart. On native platforms,
process RSS also includes
the Flutter engine, Dart VM, libraries, and caches; freed heap pages may stay
reserved in the process, so RSS need not fall by the same amount.

The hook builds Zig with `ReleaseFast`. Dart FFI bindings and the typed stream
API are generated from `zig/src/handlers.zig`, not handwritten. After editing
that file, refresh the bindings and Web asset with:

```sh
dart run dart_zig:dart_zig generate
```

## Follow the code

`zig/src/handlers.zig` owns the particle state and exposes `simulate` as an
iterator of image frames and counters. Generation creates the typed
`ZigApi.simulate` stream. `lib/main.dart` initializes Zig;
`lib/src/particle_page.dart` opens the session, subscribes to that stream, and
renders each RGBA frame as a Flutter image. The page cancels its subscription
and closes the session on disposal. On Web, the generated entrypoint loads
`web/particle_stream_flutter_example.wasm` and uses the same stream API.
