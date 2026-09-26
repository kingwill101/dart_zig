import 'dart:async';

import 'package:flutter/material.dart';
import 'package:typed_signal_flutter_example/src/generated/generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeZig();
  runApp(const MaterialApp(home: MessagePage()));
}

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  late final NativeSession _session = createSession();
  late final ZigApi _api = ZigApi(_session);
  late final Stream<({int currentNumber, bool otherBool})> _messages = _api
      .myMessage
      .stream
      .map((pack) {
        try {
          return pack.message;
        } finally {
          pack.dispose();
        }
      });

  int _nextNumber = 7;
  bool _sending = false;

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await _api.publish(_nextNumber);
      if (mounted) setState(() => _nextNumber++);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    unawaited(_session.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Zig signal to Flutter')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<({int currentNumber, bool otherBool})>(
            stream: _messages,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Error: ${snapshot.error}');
              final message = snapshot.data;
              if (message == null) {
                return const Text('Nothing received yet');
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('currentNumber: ${message.currentNumber}'),
                  Text('otherBool: ${message.otherBool}'),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: const Text('Send from Zig'),
          ),
        ],
      ),
    ),
  );
}
