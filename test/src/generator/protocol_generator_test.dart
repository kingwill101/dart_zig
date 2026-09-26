import 'dart:io';
import 'dart:isolate';

import 'package:dart_zig/src/generator/protocol_generator.dart';
import 'package:test/test.dart';

void main() {
  group('generateProtocol', () {
    test('supports empty request, response, and nested structs', () async {
      final library = await Isolate.resolvePackageUri(
        Uri.parse('package:dart_zig/dart_zig.dart'),
      );
      expect(library, isNotNull);
      final sharedZigDir = Directory.fromUri(library!.resolve('../zig/'));
      final project = await Directory.systemTemp.createTemp(
        'dart_zig_empty_struct_test_',
      );
      addTearDown(() => project.delete(recursive: true));

      final handlers = File('${project.path}/zig/src/handlers.zig');
      await handlers.parent.create(recursive: true);
      await handlers.writeAsString('''
pub const Empty = struct {};
pub const Nested = struct { marker: Empty };

pub fn ping(_: Empty) !Empty {
    return .{};
}

pub fn nested(_: Nested) !Empty {
    return .{};
}
''');

      await generateProtocol(project: project, sharedZigDir: sharedZigDir);
      final generated = await File(
        '${project.path}/lib/src/generated/api.g.dart',
      ).readAsString();
      expect(generated, contains('CallEndpoint<Null, Null> _ping'));
      expect(generated, contains('Future<void> ping(Null request'));
      expect(generated, contains('Null marker'));
      expect(generated, contains('marker: null'));
      expect(generated, contains('Future<void> nested('));
    });
  });
}
