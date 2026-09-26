import 'package:flutter/material.dart';
import 'package:fractal_flutter_example/src/generated/generated.dart';

import 'src/fractal_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeZig();
  runApp(const FractalApp());
}

class FractalApp extends StatelessWidget {
  const FractalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fractal Lab · Dart + Zig',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff58e6c5),
          brightness: Brightness.dark,
          surface: const Color(0xff101927),
        ),
        scaffoldBackgroundColor: const Color(0xff09121d),
      ),
      home: const FractalPage(),
    );
  }
}
