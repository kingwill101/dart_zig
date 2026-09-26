/// Native and Web entry point for this example.
library;

export 'package:dart_zig/dart_zig.dart';

export 'src/generated/api.g.dart' show ZigApi;
export 'src/generated/runtime_bindings.g.dart'
    if (dart.library.js_interop) 'src/generated/web_bindings.g.dart'
    show createSession;
