/// Dart/Zig runtime primitives for calls, signals, streams, callbacks, and
/// native ownership.
///
/// The CLI-generated `createSession()` factory connects a [NativeSession] to
/// your application's native asset. `dart_zig generate` can create typed
/// endpoints and codecs from public Zig handlers or route declarations.
///
/// Always await [NativeSession.close]. Dispose [NativeBuffer] results explicitly;
/// their borrowed views depend on the buffer remaining reachable and undisposed.
/// [NativeBridge] exposes the separate lower-level native request/reply transport.
///
/// {@example /example/runtime_features_example/demo/toolkit.dart#session-setup}
library;

export 'src/bridge.dart' if (dart.library.js_interop) 'src/bridge_web.dart';
export 'src/request.dart';
export 'src/codec.dart';
export 'src/endpoints.dart';
export 'src/callbacks.dart';
export 'src/runtime_error.dart';
export 'src/session.dart';
export 'src/native_buffer.dart';
export 'src/transport_native.dart'
    if (dart.library.js_interop) 'src/transport_web.dart'
    show initializeZig;
export 'src/transport.dart';
export 'src/cleanup.dart';
export 'src/signals.dart';
export 'src/signal_bus.dart' show OverflowPolicy, SignalBus;

export 'src/transport_memory.dart';

export 'src/diagnostics.dart';
