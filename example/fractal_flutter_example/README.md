# Fractal Lab (Flutter + Zig)

A standalone Flutter app that renders the Mandelbrot set with `dart_zig`.
Four Zig worker streams compute separate image stripes. Each stream yields
16-row RGBA tiles; Flutter displays progress while the native workers run.
Tap the finished image to zoom. Changing the scene or resolution starts a new
render; releasing the iteration slider does the same. The previous image stays
visible behind a progress overlay until its replacement is ready.

## Run

Install Flutter and Zig 0.15.2 or 0.16.0. From this directory:

```sh
flutter pub get
flutter run -d linux --profile
```

Choose another supported native Flutter device with `flutter devices` and
`flutter run -d <device> --profile`. The example has Android, iOS, Linux,
macOS, and Windows projects; the local build was checked on Linux.

The build hook compiles the Zig asset with `ReleaseFast` optimization. The Dart
FFI declarations and typed `ZigApi.render` stream are generated from Zig; no
handwritten bindings are used. After changing `zig/src/handlers.zig`, refresh
the checked-in bindings with:

```sh
dart run dart_zig:dart_zig generate
```

The **Native stream** time covers Zig computation, encoding, FFI delivery,
and Dart tile copies. **Image decode** is measured separately. **Pixel rate**
is output megapixels per second for the complete native stream. **Iteration
rate** counts escape-loop iterations actually run by Zig; pixels inside the
main cardioid or period-two bulb are detected without entering that loop.
These are end-to-end rates, not isolated kernel benchmarks. Use profile mode
and the same scene, resolution, and iteration limit when comparing runs.

The image has one sample per output pixel. Increase the resolution for
smoother edges. The zoom indicator counts powers of two from the selected
preset, and the app stops zooming when the next step would exceed the useful
`f64` coordinate precision.
