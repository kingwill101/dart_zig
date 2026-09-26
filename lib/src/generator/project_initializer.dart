import 'dart:io';

/// Creates the native files needed by a Dart package using dart_zig.
void initializeProject({
  required Directory project,
  required String packageName,
  required Directory sharedZigDir,
}) {
  const paths = [
    'zig/build.zig.zon',
    'zig/build.zig',
    'zig/src/handlers.zig',
    'hook/build.dart',
  ];
  final existing = paths
      .where(
        (path) =>
            FileSystemEntity.typeSync('${project.path}/$path') !=
            FileSystemEntityType.notFound,
      )
      .toList();
  if (existing.isNotEmpty) {
    throw StateError(
      'Cannot initialize without replacing existing files: '
      '${existing.join(', ')}. Integrate these files manually.',
    );
  }

  final zigDir = Directory('${project.path}/zig');
  final dependencyPath = _relativePath(zigDir, sharedZigDir);
  final fingerprint = _fingerprint(packageName);
  final files = <String, String>{
    'zig/build.zig.zon': _zon(packageName, fingerprint, dependencyPath),
    'zig/build.zig': _build(packageName),
    'zig/src/handlers.zig': _handlers,
    'hook/build.dart': _hook(packageName),
  };

  for (final entry in files.entries) {
    final file = File('${project.path}/${entry.key}');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
    stdout.writeln('Created ${entry.key}');
  }
}

String _relativePath(Directory from, Directory to) {
  final source = from.absolute.uri.pathSegments
      .where((part) => part.isNotEmpty)
      .toList();
  final target = to.absolute.uri.pathSegments
      .where((part) => part.isNotEmpty)
      .toList();
  var shared = 0;
  while (shared < source.length &&
      shared < target.length &&
      source[shared] == target[shared]) {
    shared++;
  }
  return [
    for (var i = shared; i < source.length; i++) '..',
    ...target.skip(shared),
  ].join('/');
}

String _fingerprint(String packageName) {
  final scratch = Directory.systemTemp.createTempSync('dart_zig_fingerprint_');
  try {
    final package = Directory('${scratch.path}/$packageName')..createSync();
    final result = Process.runSync('zig', [
      'init',
      '--minimal',
    ], workingDirectory: package.path);
    if (result.exitCode != 0) {
      throw StateError(
        'zig init could not create a package fingerprint: ${result.stderr}',
      );
    }
    final zon = File('${package.path}/build.zig.zon').readAsStringSync();
    final fingerprint = RegExp(r'\.fingerprint\s*=\s*0x([a-fA-F0-9]+)')
        .firstMatch(zon);
    if (fingerprint == null) {
      throw StateError('zig init did not produce a package fingerprint');
    }
    return fingerprint.group(1)!;
  } finally {
    scratch.deleteSync(recursive: true);
  }
}

String _zon(String name, String fingerprint, String dependencyPath) =>
    '''
.{
    .name = .$name,
    .fingerprint = 0x$fingerprint,
    .version = "0.1.0",
    .minimum_zig_version = "0.15.2",
    .dependencies = .{
        .dart_zig = .{ .path = "$dependencyPath" },
    },
    .paths = .{ "build.zig", "build.zig.zon", "src" },
}
''';

String _build(String name) =>
    '''
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dependency = b.dependency("dart_zig", .{ .target = target, .optimize = optimize });
    const core = dependency.module("dart_zig");
    const application = b.createModule(.{ .root_source_file = b.path("src/handlers.zig"), .target = target, .optimize = optimize });
    application.addImport("dart_zig", core);
    const exports = b.createModule(.{ .root_source_file = dependency.path("src/exports.zig"), .target = target, .optimize = optimize, .link_libc = true, .pic = true });
    exports.addImport("dart_zig", core);
    exports.addImport("application", application);
    const library = b.addLibrary(.{ .name = "$name", .linkage = .dynamic, .root_module = exports });
    b.installArtifact(library);
}
''';

const _handlers = '''
pub const AddRequest = struct {
    a: i64,
    b: i64,
};

pub fn add(request: AddRequest) !i64 {
    const sum = @addWithOverflow(request.a, request.b);
    if (sum[1] != 0) return error.Overflow;
    return sum[0];
}
''';

String _hook(String name) =>
    '''
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_zig/native_toolchain_zig.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    await ZigBuilder(
      assetName: '$name.dart',
      libraryName: '$name',
      zigDir: 'zig',
    ).run(input: input, output: output, logger: Logger('$name'));
  });
}
''';
