# Fractal Lab (Flutter + Zig)

A standalone Flutter app that renders the Mandelbrot set with `dart_zig`.
Four Zig worker streams compute separate image stripes. Each stream yields
16-row RGBA tiles; Flutter displays progress while the native workers run.
On Web, the same stream API runs Zig in WebAssembly on the browser event loop.
Tap the finished image to zoom. Changing the scene or resolution starts a new
render; releasing the iteration slider does the same. The previous image stays
visible behind a progress overlay until its replacement is ready.

## Run

Install Flutter and Zig 0.15.2 or 0.16.0. From this directory:

```sh
flutter pub get
dart run dart_zig:dart_zig generate
flutter run -d linux --profile
```

Choose another supported native Flutter device with `flutter devices` and
`flutter run -d <device> --profile`. For Chrome, use `flutter run -d chrome`.
The example has Android, iOS, Linux, macOS, Windows, and Web projects.

The build hook compiles the Zig asset with `ReleaseFast` optimization. The Dart
FFI declarations and typed `ZigApi.render` stream are generated from Zig; no
handwritten bindings are used. After changing `zig/src/handlers.zig`, refresh
the bindings and Web asset with:

```sh
dart run dart_zig:dart_zig generate
```

## Follow the code

`zig/src/handlers.zig` defines `render(request)` and a `Render` iterator that
yields RGBA tiles. The generator turns this into `ZigApi.render`, a typed Dart
stream. `lib/main.dart` initializes Zig before starting Flutter.
`lib/src/fractal_page.dart` creates a session with four workers, splits the
image into four row ranges, and consumes the streams into a Dart pixel buffer.
It decodes that buffer into a Flutter image and closes the session when the
page is disposed. On Web, the generated entrypoint loads
`web/fractal_flutter_example.wasm`; the same Dart page uses the Web transport.

The **Zig stream** time covers Zig computation, encoding, delivery, and Dart
tile copies. **Image decode** is measured separately. **Pixel rate**
is output megapixels per second for the complete native stream. **Iteration
rate** counts escape-loop iterations actually run by Zig; pixels inside the
main cardioid or period-two bulb are detected without entering that loop.
These are end-to-end rates, not isolated kernel benchmarks. Use profile mode
and the same scene, resolution, and iteration limit when comparing runs.

The image has one sample per output pixel. Increase the resolution for
smoother edges. The zoom indicator counts powers of two from the selected
preset, and the app stops zooming when the next step would exceed the useful
`f64` coordinate precision.
