/// Entry point used to identify the native request example asset.
library;

export 'src/generated/generated.dart' show NativeBridge, ReplyKind, createBridge;

export 'src/demo_driver.dart'
    show submitExampleRequest, cancelExampleRequest, consumeExampleReply;
