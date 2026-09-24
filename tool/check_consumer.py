#!/usr/bin/env python3
"""Build and run an isolated consumer asset against the shared Dart runtime."""
import pathlib, subprocess, sys, tempfile
ROOT=pathlib.Path(__file__).resolve().parent.parent
(ROOT/'build').mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='consumer-',dir=ROOT/'build') as temporary:
    destination=pathlib.Path(temporary)/'package'
    def run(args): subprocess.run(args,cwd=destination,check=True)
    subprocess.run([sys.executable,str(ROOT/'tool/dart_zig.py'),'scaffold',str(destination),'--name','zig_consumer'],cwd=ROOT,check=True)
    pubspec=destination/'pubspec.yaml'
    pubspec.write_text(pubspec.read_text().replace('dependencies:\n','dependencies:\n  dart_zig:\n    path: '+str(ROOT)+'\n',1))
    run(['dart','pub','get'])
    run(['sh','tool/regenerate.sh'])
    run([sys.executable,str(ROOT/'tool/generate_backend.py'),
        '--ffi',str(destination/'lib/src/ffi.g.dart'),
        '--output',str(destination/'lib/src/shared_adapter.g.dart'),
        '--class-name','ConsumerBindings','--native-import','ffi.g.dart',
        '--abi-import','package:dart_zig/src/ffi.g.dart',
        '--interface-import','package:dart_zig/src/generated/runtime_bindings.g.dart'])
    (destination/'bin/consumer.dart').write_text('''
import 'dart:typed_data';
import 'package:dart_zig/dart_zig.dart';
import 'package:zig_consumer/src/shared_adapter.g.dart';
void require(bool condition, String message) { if (!condition) throw StateError(message); }
Future<void> main() async {
  const bindings = ConsumerBindings();
  final session = NativeSession(bindings: bindings);
  final api = GeneratedApi(session);
  NativeBuffer? result;
  try {
    require(await api.sum(const SumArgs(a: 20, b: 22)) == 42, 'consumer call');
    require(api.sumSync(20,22) == 42, 'consumer sync call');
    result = await session.callBuffer(8, Uint8List.fromList([1,2,3])).result;
    require(bindings.dz_live_buffers() > 0, 'consumer owns its allocations');
    require(NativeSession.liveBuffers == 0, 'default asset is independent');
  } finally { await session.close(); }
  require(result!.view[2] == 3, 'consumer lease survives shutdown');
  result.dispose();
  require(bindings.dz_live_buffers() == 0, 'consumer finalizer uses owning asset');
  final original = NativeSession();
  try { require(await GeneratedApi(original).sum(const SumArgs(a: 1,b: 2)) == 3, 'default asset still usable'); }
  finally { await original.close(); }
  print('Separate consumer asset, injected sync/async calls, and allocation ownership passed.');
}
''')
    run(['dart','run','bin/consumer.dart'])
