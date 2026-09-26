import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8080 : int.parse(args.single);
  final site = Directory('build/docs').absolute;
  if (!File('${site.path}/index.html').existsSync()) {
    throw StateError('Run dart run tool/build_docs.dart first.');
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Documentation: http://127.0.0.1:${server.port}');
  await for (final request in server) {
    final relative = request.uri.path == '/'
        ? 'index.html'
        : request.uri.pathSegments.where((part) => part.isNotEmpty).join('/');
    final file = File('${site.path}/$relative');
    if (relative.contains('..') || !file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
    } else {
      request.response.headers.contentType =
          switch (file.uri.pathSegments.last) {
            final name when name.endsWith('.css') => ContentType('text', 'css'),
            final name when name.endsWith('.js') => ContentType(
              'application',
              'javascript',
            ),
            _ => ContentType.html,
          };
      await request.response.addStream(file.openRead());
    }
    await request.response.close();
  }
}
