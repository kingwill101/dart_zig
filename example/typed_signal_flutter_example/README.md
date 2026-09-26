# Typed Zig signal in Flutter

This example mirrors the small `MyMessage` signal pattern: a Zig handler emits
`MyMessage { currentNumber, otherBool }`, and a Flutter `StreamBuilder` displays
the latest message. Press **Send from Zig** to call the generated `publish`
route. The Zig handler then emits the typed signal to the same session.

The event and message type live in `zig/src/handlers.zig`. Flutter imports
`lib/src/generated/generated.dart` for `ZigApi`, `createSession`, and the
runtime API. The generated endpoint and codecs live beside that entrypoint.
The Flutter stream converts each signal pack to a Dart record and disposes the
pack after reading it. The session closes when the page is disposed.

## Run

Install Flutter and Zig 0.15.2 or 0.16.0. From this directory:

```sh
flutter pub get
dart run dart_zig:dart_zig generate
flutter run -d linux
```

For Chrome, run `flutter run -d chrome`. Generation builds the WebAssembly
asset and conditional session entrypoint when the package has a `web/` folder.
Choose another available native device with `flutter devices`.

## Follow the signal

`zig/src/handlers.zig` declares `MyMessage` and the `myMessage` signal. Its
`publish` handler emits a message with the supplied number and a boolean
derived from whether that number is odd. Generation creates `ZigApi.publish`,
`ZigApi.myMessage`, and the message codec. `lib/main.dart` initializes Zig,
opens a session, and calls `publish` when the button is pressed. The
`StreamBuilder` displays each received record. The page disposes received
signal packs and closes its session when removed.

After changing the Zig handler or event declarations, run
`dart run dart_zig:dart_zig generate`. That command refreshes the typed API,
the native and Web session factories, and `web/typed_signal_flutter_example.wasm` together.
