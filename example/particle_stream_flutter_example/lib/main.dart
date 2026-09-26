import 'package:flutter/material.dart';
import 'package:particle_stream_flutter_example/src/generated/generated.dart';

import 'src/particle_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeZig();
  runApp(const ParticleStreamApp());
}

class ParticleStreamApp extends StatelessWidget {
  const ParticleStreamApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Particle Stream · Dart + Zig',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff43d9c2),
        brightness: Brightness.dark,
        surface: const Color(0xff111d29),
      ),
      scaffoldBackgroundColor: const Color(0xff07111b),
    ),
    home: const ParticlePage(),
  );
}
