import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_zig/native_toolchain_zig.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    await ZigBuilder(
      assetName: 'particle_stream_flutter_example.dart',
      libraryName: 'particle_stream_flutter_example',
      zigDir: 'zig',
      optimization: Optimization.releaseFast,
    ).run(input: input, output: output, logger: Logger('particle_stream_flutter_example'));
  });
}
