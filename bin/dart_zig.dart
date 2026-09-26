import 'dart:io';
import 'dart:isolate';

import 'package:dart_zig/src/generator/backend_generator.dart';
import 'package:dart_zig/src/generator/project_initializer.dart';
import 'package:dart_zig/src/generator/protocol_generator.dart';
import 'package:native_toolchain_zig/native_toolchain_zig.dart';

/// Initializes a project or generates its Dart bindings from Zig exports.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 ||
      !const {'init', 'generate'}.contains(arguments.single)) {
    stderr.writeln('Usage: dart run dart_zig:dart_zig <init|generate>');
    exitCode = 64;
    return;
  }

  final project = Directory.current.absolute;
  final name = _packageName(project);
  const rootSource = 'src/exports.zig';
  final ffiOutput = name == 'dart_zig'
      ? 'lib/src/runtime_abi.g.dart'
      : 'lib/src/ffi.g.dart';
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:dart_zig/dart_zig.dart'),
  );
  if (library == null) throw StateError('Cannot locate the dart_zig package');
  final sharedZigDir = Directory.fromUri(library.resolve('../zig/'));

  if (arguments.single == 'init') {
    try {
      initializeProject(
        project: project,
        packageName: name,
        sharedZigDir: sharedZigDir,
      );
    } on StateError catch (error) {
      stderr.writeln(error.message);
      exitCode = 1;
      return;
    }
  }

  final assetId = 'package:$name/$name.dart';
  final sharedBindings = await _generateFfi(
    project: project,
    zigDir: sharedZigDir.path,
    rootSource: rootSource,
    output: ffiOutput,
    assetId: assetId,
    typesOnly: name == 'dart_zig',
    // The shared runtime module always links libc in application builds.
    linkLibc: true,
  );

  const extraExports = 'zig/src/extra_exports.zig';
  if (File('${project.path}/$extraExports').existsSync()) {
    await _generateFfi(
      project: project,
      zigDir: 'zig',
      rootSource: 'src/extra_exports.zig',
      output: 'lib/src/ffi_app.g.dart',
      assetId: assetId,
      linkLibc: false,
    );
  }

  if (name != 'dart_zig') {
    await generateBackend(
      project: project,
      functions: sharedBindings.functions,
    );
    await generateProtocol(project: project, sharedZigDir: sharedZigDir);
  }
}

Future<GeneratedBindingsResult> _generateFfi({
  required Directory project,
  required String zigDir,
  required String rootSource,
  required String output,
  required String assetId,
  bool? linkLibc,
  bool typesOnly = false,
}) async {
  final result = await generateBindingsSource(
    ZigBindingsOptions(
      packageRoot: project.path,
      zigDirectory: zigDir,
      rootSourceFile: rootSource,
      output: output,
      assetId: assetId,
      linkLibc: linkLibc,
    ),
  );
  final file = File(result.outputPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(typesOnly ? result.typesSource : result.source);
  stdout.writeln('Wrote ${result.outputPath}');
  return result;
}

String _packageName(Directory project) {
  final pubspec = File('${project.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    throw const FormatException('Expected pubspec.yaml in the package');
  }
  final match = RegExp(
    r'^name:\s*([a-z][a-z0-9_]*)\s*$',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());
  if (match == null) {
    throw const FormatException('Expected a package name in pubspec.yaml');
  }
  return match.group(1)!;
}
