# Streams example

This standalone package uses the shared runtime's credited stream protocol.
Its Zig handler returns an iterator that produces one square per credit and
releases its worker while Dart pauses the stream. The Zig build uses the shared
`dart_zig` exports, and the CLI generates FFI bindings and typed stream codecs
from `zig/src/handlers.zig` for this package's native asset.

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```
