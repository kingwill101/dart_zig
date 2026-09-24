/// Advanced Web transport injection for hosts with their own Wasm loader.
///
/// Most applications only need `dart_zig.dart` and `initializeZig`.
library;

export 'src/transport_web.dart' show WebTransport, WasmApi, initializeZig;
