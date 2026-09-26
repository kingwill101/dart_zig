# Writing and previewing documentation

The guides in `doc/` and each example's README are the source for the site.
Dart API comments live beside the public library code. Build the static site
and preview it locally from the repository root:

```sh
dart run tool/build_docs.dart
dart run tool/serve_docs.dart
```

The builder runs `dart doc`, renders the Markdown guides with Pandoc, and writes
`build/docs/`. Use `dart run tool/build_docs.dart --skip-api` while editing only
Markdown. The site navigation is in `doc/site/navigation.json`; its style and
browser behavior are in `doc/site/`.

Dartdoc `{@example}` regions point to code in the existing example projects.
Keep the region names on the code that users can run. The runtime feature and
native request examples have their own package, Zig project, and build hook.

Generated Dart files are replaced by `dart run dart_zig:dart_zig generate`
from the relevant package directory. Edit Zig exports when changing generated
FFI declarations. Application models and codecs are ordinary Dart and Zig
source, maintained by the application.
