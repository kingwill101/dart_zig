# Documentation maintenance

[Back to the package guide](../README.md)

## Build and preview the site

From this package directory:

```sh
python3 tool/build_docs.py
python3 tool/serve_docs.py
```

The build requires Dart, Python 3, and Pandoc on PATH. It generates the Dart
reference, renders Markdown guides alongside it, and checks local links and
anchors. Open `http://127.0.0.1:8080` after starting the preview server.
The static output is `build/docs/`, with the API reference under `api/`.
Generated files are ignored by Git. The preview binds only to localhost.
The Markdown guides are maintained separately under `doc/` and linked from the
README. Analysis and documentation generation check different things: build the
API reference to catch unresolved links and malformed example directives.
`dart doc` alone builds API pages but does not render the linked Markdown guides.

## Reuse existing examples

Dart comments use `{@example /bin/toolkit.dart#region-name}`. Paths beginning
with `/` are package-relative. Regions are marked using `// #region name` and
`// #endregion` in the existing executable, so the displayed snippets track
runnable code. Use a dartdoc version supporting this directive; the local
Dart 3.13.4 toolchain does.

| Region | Topic |
| --- | --- |
| `session-setup` | Session and typed facade construction |
| `typed-signals` | Subscribe before publishing |
| `native-object` | Create, update, dispose |
| `typed-stream` | Consume a typed native stream |
| `typed-callback` | Async callback that reenters native code |
| `owned-buffer` | Request and retain native bytes |

These are excerpts from one executable. Variables such as `api`, `session`, and
`retained`, plus the demo's `require` assertion helper, are defined in that file.
The complete lifecycle and cleanup remain visible in the full example.

## Maintain generated API comments

Change comments emitted by `tool/generate_models.py` or
`tool/generate_backend.py`, then run `./tool/regenerate.sh`. Do not edit generated
Dart files directly. The low-level FFI declarations continue to come from the
existing CLI generator. Documentation changes should preserve runtime behavior,
schema fingerprints, and the generated ABI.

## Add a page

1. Write a focused Markdown page under `doc/`. Start with one level-one heading.
2. Add its source path and title to `doc/site/navigation.json`, in the appropriate
   section. Navigation order also controls previous/next links.
3. Link to other Markdown sources with relative paths. The builder rewrites these
   links for the site, copies linked source assets, and checks local anchors.
4. Rebuild with `python3 tool/build_docs.py --skip-api` while editing guides.
   Refresh the browser to see the result. Run a full build after Dart API changes.

New top-level Markdown files under `doc/` are discovered automatically and appear
under “More guides” until assigned a navigation section. Page search indexes guide
contents locally; API symbols have their own search in the Dart reference.

## Grow the information architecture

- **Start here:** runnable introductions and step-by-step tutorials.
- **Build with it:** stable usage guides, ownership contracts, and reference pages.
- **Project notebook:** implementation status, research, and design proposals.

Keep proposal status explicit in prose; a navigation entry can also carry a
`label` such as `Proposal`. Add tutorials when their examples exist. Link to
verification evidence rather than presenting planned support as available.
Split a growing page when it starts answering several independent questions.

The site shell is maintained in `tool/build_docs.py`; CSS and browser behavior
live in `doc/site/`. It uses system fonts and local assets, with no CDN dependency
for the guide pages. Search, mobile navigation, and code-copy controls are small
progressive enhancements; the guide content and links are static HTML.

## Hosting later

A full build produces a self-contained static directory. Deploy the contents of
`build/docs/` to a static host when hosting is configured. Paths are
relative, so the same output can live at a domain root or under a project subpath.
A `.nojekyll` file is included for hosts that interpret it. No hosting service,
public URL, or deployment workflow has been configured yet.

Do not edit generated pages: the next build replaces `build/docs/`. Full builds
also replace the generated `doc/api/` cache. The preview server does not watch
files or rebuild automatically; run the build command and refresh.
