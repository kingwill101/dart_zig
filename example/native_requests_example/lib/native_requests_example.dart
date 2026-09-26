/// Entry point used to identify the native request example asset.
library;

export 'package:dart_zig/dart_zig.dart' show NativeBridge, ReplyKind;

export 'src/demo_driver.dart'
    show submitExampleRequest, cancelExampleRequest, consumeExampleReply;
export 'src/generated/runtime_bindings.g.dart' show createBridge;
