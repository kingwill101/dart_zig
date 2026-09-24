/// General Dart/Zig calls, signals, streams, callbacks, and native ownership.
///
/// Create a [NativeSession] and use [GeneratedApi] for the bundled application's
/// typed calls, signals, streams, and callbacks. Custom applications generate
/// their own facade and supply a [RuntimeBindings] adapter for their native asset.
///
/// Always await [NativeSession.close]. Dispose [NativeBuffer] results explicitly;
/// their borrowed views depend on the buffer remaining reachable and undisposed.
/// [NativeBridge] exposes the separate lower-level native request/reply transport.
///
/// {@example /bin/toolkit.dart#session-setup}
library;

export 'src/bridge.dart' if (dart.library.js_interop) 'src/bridge_web.dart';
export 'src/request.dart';
export 'src/codec.dart';
export 'src/runtime_error.dart';
export 'src/session.dart';
export 'src/generated/models.g.dart';
export 'src/native_object.dart';
export 'src/native_buffer.dart';
export 'src/generated/runtime_bindings.g.dart'
    if (dart.library.js_interop) 'src/web_bindings.dart';
export 'src/transport_native.dart'
    if (dart.library.js_interop) 'src/transport_web.dart'
    show initializeZig;
export 'src/transport.dart';
export 'src/cleanup.dart';
export 'src/signals.dart';
export 'src/signal_bus.dart' show OverflowPolicy, SignalBus;

export 'src/transport_memory.dart';

export 'src/diagnostics.dart';
