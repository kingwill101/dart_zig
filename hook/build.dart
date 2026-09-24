import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_zig/native_toolchain_zig.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    await ZigBuilder(
      assetName: 'dart_zig.dart',
      libraryName: 'dart_zig',
      zigDir: 'zig',
    ).run(input: input, output: output, logger: Logger('dart_zig'));
  });
}
