import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_zig/native_toolchain_zig.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    await ZigBuilder(
      assetName: 'runtime_features_example.dart',
      libraryName: 'runtime_features_example',
      zigDir: 'zig',
    ).run(input: input, output: output, logger: Logger('runtime_features_example'));
  });
}
