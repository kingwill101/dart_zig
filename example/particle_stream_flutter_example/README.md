# Particle Stream (Flutter + Zig)

A standalone Flutter app with continuously updated native state. Zig owns up to
250,000 particles and advances their positions and velocities on a worker. A
generated `ZigApi.simulate` stream carries a 160 × 90 RGBA density image and
small counters to Flutter; the particle array never crosses FFI.

## Run

Install Flutter and Zig 0.15.2 or 0.16.0. From this directory:

```sh
flutter pub get
flutter run -d linux --profile
```

Select another native Flutter target with `flutter devices` and
`flutter run -d <device> --profile`. Android, iOS, Linux, macOS, and Windows
project files are included. The local profile build and run were checked on
Linux.

The particle-count slider restarts the simulation. The display cap can be
changed while it is running. Pause keeps the Zig state alive and withholds
stream credits; one frame may already be in flight. Resume continues from that
state. Restart cancels the old stream and creates a fresh simulation.

The Dart subscription pauses after each frame until image decoding and the
display interval finish. `NativeSession` sends the next credit only after the
subscription resumes, so the Zig worker does not sleep to pace output. The
actual frame rate may be below the selected cap when computation, transport,
or image decoding takes longer than one interval.

**Native state** counts the live particle, bin, and RGBA allocations owned by
this example's Zig simulations. It should fall when the particle count falls
and return to one simulation's size after a restart. Process RSS also includes
the Flutter engine, Dart VM, libraries, and caches; freed heap pages may stay
reserved in the process, so RSS need not fall by the same amount.

The hook builds Zig with `ReleaseFast`. Dart FFI bindings and the typed stream
API are generated from `zig/src/handlers.zig`, not handwritten. After editing
that file, refresh the checked-in bindings with:

```sh
dart run dart_zig:dart_zig generate
```
