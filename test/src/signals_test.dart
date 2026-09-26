import 'dart:typed_data';

import 'package:dart_zig/dart_zig.dart';
import 'package:test/test.dart';

final class _BorrowingCodec implements BinaryCodec<Uint8List> {
  const _BorrowingCodec();

  @override
  Uint8List encode(Uint8List value) => Uint8List.fromList(value);

  @override
  Uint8List decode(Uint8List bytes) => bytes;
}

void main() {
  group('SignalEndpoint', () {
    test(
      'borrowed metadata remains independent of a released source frame',
      () async {
        final transport = MemoryTransport(
          handler: (context, bytes) => context.signal(context.route, bytes),
        );
        final session = NativeSession(transport: transport);
        Uint8List? sourceFrame;
        final sourceSubscription = session.ownedSignals.listen((event) {
          sourceFrame = event.buffer.view;
          event.dispose();
        });
        final endpoint = SignalEndpoint<Uint8List>(
          session,
          7,
          const _BorrowingCodec(),
        );
        try {
          final received = endpoint.stream.first;
          await endpoint.send(Uint8List.fromList([10, 20, 30]));
          final pack = await received;
          try {
            expect(sourceFrame, isNotNull);
            expect(pack.message, orderedEquals([10, 20, 30]));
            // The metadata begins after its four-byte length prefix. A decoder
            // borrowing the native frame would observe this later mutation.
            sourceFrame![4] = 99;
            expect(pack.message, orderedEquals([10, 20, 30]));
          } finally {
            pack.dispose();
          }
        } finally {
          await sourceSubscription.cancel();
          await session.close();
        }
      },
    );
  });
}
