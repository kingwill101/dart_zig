# Attachments example

This standalone project sends typed text and byte metadata with a separate
binary attachment. Its Zig event declaration generates the Dart codec and
endpoint. Its field name supplies the stable route ID. Two Dart listeners
receive independent attachment leases, so disposing one does not invalidate
the other. The shared handler dispatcher validates and relays the typed frame.

## Run

From this directory, with Dart and Zig 0.15.2 or 0.16.0 installed:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```

The output shows the `image` label, the two-byte tag, and the attachment
`[3, 1, 4]`.

## Follow the code

- `zig/src/handlers.zig` declares `AttachmentMessage` and the `attachments`
  signal event. There is no custom Zig handler for this example.
- Generation creates `ZigApi.attachments` and its message codec.
- `bin/main.dart` subscribes twice before calling `endpoint.send`, then reads
  the message and attachment from each signal pack.

```dart
final endpoint = ZigApi(session).attachments;
final next = endpoint.stream.first;
await endpoint.send(
  (label: 'image', tag: Uint8List.fromList([1, 2])),
  binary: Uint8List.fromList([3, 1, 4]),
);
final pack = await next;
print(pack.attachment.view);
pack.dispose();
```

Each listener owns its received pack. The example disposes both packs and
closes the session. Keep a pack or a retained attachment lease alive only for
as long as its data is needed. Change the event declaration, then rerun
`generate` to refresh the typed Dart API.
