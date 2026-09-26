import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final root = Directory.current.absolute;
  final output = Directory(p.join(root.path, 'build', 'docs'));
  final api = Directory(p.join(root.path, 'doc', 'api'));
  final skipApi = args.contains('--skip-api');
  if (!skipApi) {
    if (api.existsSync()) await api.delete(recursive: true);
    await _run('dart', ['doc', '--output', api.path], root.path);
  }
  if (!File(p.join(api.path, 'index.html')).existsSync()) {
    throw StateError(
      'Run without --skip-api once to create the API reference.',
    );
  }
  if (output.existsSync()) await output.delete(recursive: true);
  await output.create(recursive: true);
  await _copyTree(api, Directory(p.join(output.path, 'api')));
  File(p.join(output.path, '.nojekyll')).writeAsStringSync('');
  final assets = Directory(p.join(output.path, 'assets'));
  await assets.create(recursive: true);
  for (final file in ['style.css', 'app.js']) {
    await File(p.join(root.path, 'doc', 'site', file))
        .copy(p.join(assets.path, file));
  }

  final navigation = jsonDecode(
    File(p.join(root.path, 'doc', 'site', 'navigation.json'))
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final pages = <_Page>[];
  for (final section in navigation['sections'] as List) {
    final group = section as Map<String, dynamic>;
    for (final value in group['pages'] as List) {
      final entry = value as Map<String, dynamic>;
      final source = entry['source'] as String;
      final target = source == 'doc/index.md'
          ? 'index.html'
          : p.setExtension(source, '.html');
      pages.add(
        _Page(
          source,
          target,
          entry['title'] as String,
          group['title'] as String,
        ),
      );
    }
  }
  final targets = {for (final page in pages) page.source: page.target};
  final search = <Map<String, String>>[];
  for (final page in pages) {
    final source = File(p.join(root.path, page.source));
    if (!source.existsSync()) throw StateError('Missing guide: ${page.source}');
    final target = File(p.join(output.path, page.target));
    await target.parent.create(recursive: true);
    var markdown = await source.readAsString();
    final linkedFiles = <String>{};
    markdown = markdown.replaceAllMapped(RegExp(r'\]\(([^\s)]+)\)'), (match) {
      final raw = match.group(1)!;
      final uri = Uri.parse(raw);
      if (uri.hasScheme || raw.startsWith('#')) return match.group(0)!;
      var resolved = p.normalize(p.join(p.dirname(page.source), uri.path));
      if (Directory(p.join(root.path, resolved)).existsSync()) {
        resolved = p.join(resolved, 'README.md');
      }
      final destination = targets[resolved];
      if (destination == null) {
        if (p.isWithin(root.path, p.join(root.path, resolved)) &&
            File(p.join(root.path, resolved)).existsSync()) {
          linkedFiles.add(resolved);
        } else {
          throw StateError('Broken local link in ${page.source}: $raw');
        }
      }
      final relative = p.relative(
        destination ?? resolved,
        from: p.dirname(page.target),
      );
      return ']($relative${uri.hasFragment ? '#${uri.fragment}' : ''})';
    });
    for (final path in linkedFiles) {
      final copy = File(p.join(output.path, path));
      await copy.parent.create(recursive: true);
      await File(p.join(root.path, path)).copy(copy.path);
    }
    final rendered = await _run(
      'pandoc',
      ['--from=gfm', '--to=html5'],
      root.path,
      input: markdown,
    );
    final base = p.relative(output.path, from: target.parent.path);
    String href(String path) =>
        p.posix.normalize(p.posix.join(base.replaceAll('\\', '/'), path));
    final nav = StringBuffer();
    for (final section in navigation['sections'] as List) {
      final group = section as Map<String, dynamic>;
      nav.write(
        '<div class="nav-group"><p class="nav-label">'
        '${_escape(group['title'] as String)}</p>',
      );
      for (final item in pages.where(
        (item) => item.section == group['title'],
      )) {
        nav.write(
          '<a href="${_escape(href(item.target))}">'
          '${_escape(item.title)}</a>',
        );
      }
      nav.write('</div>');
    }
    final html =
        '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${_escape(page.title)} · dart_zig</title>
<link rel="stylesheet" href="${href('assets/style.css')}">
<script defer src="${href('assets/search-index.js')}"></script>
<script defer src="${href('assets/app.js')}"></script></head>
<body data-root="${_escape(base)}"><a class="skip" href="#content">Skip to content</a>
<aside class="sidebar" id="navigation"><a class="brand" href="${href('index.html')}"><span class="brand-mark">dz</span>dart_zig</a>
<p class="tagline">Dart ↔ Zig toolkit</p><nav aria-label="Documentation">$nav</nav>
<a class="api-link" href="${href('api/index.html')}">Dart API reference ↗</a></aside>
<div class="page"><header class="topbar"><button class="menu-button" aria-controls="navigation" aria-expanded="false">Menu</button>
<span>Documentation / ${_escape(page.section)}</span><div class="search-wrap"><label for="search">Search guides</label>
<input id="search" type="search" placeholder="Search guides…" autocomplete="off" aria-controls="search-results">
<div id="search-results" class="results" aria-live="polite" hidden></div></div></header>
<div class="layout"><main id="content"><article>$rendered</article></main></div></div></body></html>''';
    await target.writeAsString(html);
    search.add({
      'title': page.title,
      'section': page.section,
      'path': page.target,
      'text': rendered.replaceAll(RegExp(r'<[^>]+>'), ' '),
    });
  }
  await File(p.join(assets.path, 'search-index.js'))
      .writeAsString('window.DOC_PAGES = ${jsonEncode(search)};\n');
  stdout.writeln(
    'Built ${pages.length} guides and the Dart API in ${output.path}',
  );
}

Future<String> _run(
  String executable,
  List<String> args,
  String directory, {
  String? input,
}) async {
  final process = await Process.start(
    executable,
    args,
    workingDirectory: directory,
  );
  if (input != null) process.stdin.write(input);
  await process.stdin.close();
  final output = await process.stdout.transform(utf8.decoder).join();
  final error = await process.stderr.transform(utf8.decoder).join();
  final status = await process.exitCode;
  if (status != 0) throw StateError('$executable failed ($status): $error');
  return output;
}

Future<void> _copyTree(Directory source, Directory target) async {
  await target.create(recursive: true);
  await for (final entity in source.list(recursive: true)) {
    final path = p.join(
      target.path,
      p.relative(entity.path, from: source.path),
    );
    if (entity is Directory) {
      await Directory(path).create(recursive: true);
    } else if (entity is File) {
      await File(path).parent.create(recursive: true);
      await entity.copy(path);
    }
  }
}

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

final class _Page {
  const _Page(this.source, this.target, this.title, this.section);
  final String source;
  final String target;
  final String title;
  final String section;
}
