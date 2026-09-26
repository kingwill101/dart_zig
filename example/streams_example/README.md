# Streams example

This standalone package uses the shared runtime's credited stream protocol.
Its Zig handler returns an iterator that produces one square per credit and
releases its worker while Dart pauses the stream. The Zig build uses the shared
`dart_zig` exports, and the CLI generates FFI bindings and typed stream codecs
from `zig/src/handlers.zig` for this package's native asset.

## Run

From this directory, with Dart and Zig 0.15.2 or 0.16.0 installed:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```

Expected output: `Squares: [0, 1, 4, 9, 16]`.

## Follow the stream

`zig/src/handlers.zig` defines `squares(count)` returning a `Squares`
iterator. The iterator declares `Item = i64`; its `next()` returns the next
square or `null` at the end. The generator recognizes that shape and writes a
typed `ZigApi.squares` stream endpoint and codecs.

```dart
final squares = ZigApi(session).squares(5);
print(await squares.toList()); // [0, 1, 4, 9, 16]
```

`bin/main.dart` requests five items and collects them with `toList()`. Dart
grants stream credits as it consumes values; Zig advances the iterator when
credit is available. This lets the consumer pause or cancel without an
unbounded producer queue. The session closes in `finally`. The handler rejects
counts above 1000 with `error.TooLarge`.
