#!/usr/bin/env python3
"""Build the static documentation site. Requires Dart, Python 3, and Pandoc."""
import argparse
import html
from html.parser import HTMLParser
import json
import os
import pathlib
import re
import shutil
import subprocess
from urllib.parse import unquote, urlsplit

root = pathlib.Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--skip-api', action='store_true', help='Reuse the last Dart API build while editing guides')
args = parser.parse_args()
output = root / 'build/docs'
api = root / 'doc/api'
site = root / 'doc/site'
if shutil.which('pandoc') is None:
    raise SystemExit('Pandoc is required to render the Markdown guides.')
if not args.skip_api:
    if api.exists():
        shutil.rmtree(api)
    subprocess.run(['dart', 'doc', '--output', str(api)], cwd=root, check=True)
if not (api / 'index.html').is_file():
    raise SystemExit('Build once without --skip-api to generate the API reference.')
# Only this generated site directory is replaced, never documentation sources.
if output.exists():
    shutil.rmtree(output)
output.mkdir(parents=True)
shutil.copytree(api, output / 'api')
(output / '.nojekyll').touch()
(output / 'assets').mkdir()
for name in ['style.css', 'app.js']:
    shutil.copy2(site / name, output / 'assets' / name)

config = json.loads((site / 'navigation.json').read_text())
entries = []
for section in config['sections']:
    for item in section['pages']:
        entries.append({**item, 'section': section['title']})
# A forgotten navigation entry must not leave a maintained page inaccessible.
sources = [root / 'README.md', *sorted((root / 'doc').glob('*.md')),
           root / 'benchmark/README.md']
listed = {item['source'] for item in entries}
for source in sources:
    relative = source.relative_to(root).as_posix()
    if relative not in listed:
        entries.append({'source': relative, 'title': source.stem, 'section': 'More guides'})
if len({item['source'] for item in entries}) != len(entries):
    raise SystemExit('Duplicate source in site navigation')
page_targets = {}
for entry in entries:
    source = (root / entry['source']).resolve()
    if not source.is_relative_to(root) or not source.is_file():
        raise SystemExit('Invalid documentation source: ' + entry['source'])
    target = pathlib.Path('index.html') if entry['source'] == 'doc/index.md' else source.relative_to(root).with_suffix('.html')
    entry['path'] = target.as_posix()
    page_targets[source] = target

def relative_link(target, page):
    return pathlib.Path(os.path.relpath(target, page.parent)).as_posix()

def target_for(source, href, page):
    parsed = urlsplit(href)
    if parsed.scheme or parsed.netloc or not parsed.path:
        return href
    target = (source.parent / unquote(parsed.path)).resolve()
    if not target.is_relative_to(root) or not target.is_file():
        raise ValueError(f'Invalid local link: {source}: {href}')
    if target in page_targets:
        dest = output / page_targets[target]
    else:
        dest = output / target.relative_to(root)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, dest)
    return relative_link(dest, page) + ('#' + parsed.fragment if parsed.fragment else '')

def render(entry, content, position):
    page = output / entry['path']
    base = relative_link(output / 'index.html', page).removesuffix('index.html')
    esc = html.escape
    navigation = ''
    for section in dict.fromkeys(item['section'] for item in entries):
        navigation += '<div class="nav-group"><p class="nav-label">' + esc(section) + '</p>'
        for item in entries:
            if item['section'] != section:
                continue
            current = ' aria-current="page"' if item == entry else ''
            navigation += f'<a href="{base}{esc(item["path"])}"{current}>{esc(item["title"])}</a>'
        navigation += '</div>'
    headings = re.findall(r'<h2 id="([^"]+)">(.*?)</h2>', content, re.S)
    toc = '<ul>' + ''.join(f'<li><a href="#{ident}">{title}</a></li>' for ident, title in headings) + '</ul>'
    pager = ''
    for offset, label in [(-1, 'Previous'), (1, 'Next')]:
        index = position + offset
        if 0 <= index < len(entries):
            item = entries[index]
            pager += f'<a href="{base}{esc(item["path"])}"><small>{label}</small>{esc(item["title"])}</a>'
        else:
            pager += '<span></span>'
    status = f'<span class="status">{esc(entry["label"])}</span>' if entry.get('label') else ''
    welcome = 'welcome' if entry['path'] == 'index.html' else ''
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(entry['title'])} · dart_zig</title>
<meta name="description" content="{esc(entry['title'])} — Dart and Zig toolkit documentation.">
<script>document.documentElement.classList.add('js');</script>
<link rel="stylesheet" href="{base}assets/style.css">
<script defer src="{base}assets/search-index.js"></script><script defer src="{base}assets/app.js"></script></head>
<body class="{welcome}" data-root="{base}"><a class="skip" href="#content">Skip to content</a>
<aside class="sidebar" id="navigation"><a class="brand" href="{base}index.html"><span class="brand-mark">dz</span>dart_zig</a>
<p class="tagline">Dart ↔ Zig toolkit</p><nav aria-label="Documentation">{navigation}</nav>
<a class="api-link" href="{base}api/index.html">Dart API reference ↗</a>
<p class="rail-note">In development<br>A living guide to the toolkit.</p></aside>
<div class="page"><header class="topbar"><button class="menu-button" aria-controls="navigation" aria-expanded="false">Menu</button>
<span>Documentation / {esc(entry['section'])}</span><div class="search-wrap"><label for="search">Search guides</label>
<input id="search" type="search" placeholder="Search guides…" autocomplete="off" aria-controls="search-results">
<div id="search-results" class="results" aria-live="polite" hidden></div></div></header>
<div class="layout"><main id="content"><div class="eyebrow">{esc(entry['section'])}{status}</div><article>{content}</article>
<nav class="pager" aria-label="Adjacent pages">{pager}</nav><footer class="footer">dart_zig · Work in progress. Verified behavior and proposals are documented separately.</footer></main>
<details class="toc" open><summary>On this page</summary>{toc}</details></div></div></body></html>'''

search = []
for position, entry in enumerate(entries):
    source = root / entry['source']
    page = output / entry['path']
    content = re.sub(r'\]\(([^\s)]+)\)', lambda m: '](' + target_for(source, m[1], page) + ')', source.read_text())
    result = subprocess.run(['pandoc', '--from=gfm', '--to=html5'], input=content, text=True, capture_output=True, check=True)
    page.parent.mkdir(parents=True, exist_ok=True)
    page.write_text(render(entry, result.stdout, position))
    text = html.unescape(re.sub('<[^>]+>', ' ', result.stdout))
    search.append({**entry, 'text': re.sub(r'\s+', ' ', text)})
(output / 'assets/search-index.js').write_text('window.DOC_PAGES = ' + json.dumps(search, ensure_ascii=False) + ';\n')

# Dartdoc embeds README links; resolve them relative to the site's API directory.
index = output / 'api/index.html'
content = index.read_text()
for href in re.findall(r'\]\(([^\s)]+)\)', (root / 'README.md').read_text()):
    rewritten = target_for(root / 'README.md', href, index)
    content = content.replace('href="' + html.escape(href, quote=True) + '"', 'href="' + html.escape(rewritten, quote=True) + '"')
content = re.sub(r'(<body[^>]*>)', r'\1<p style="padding:12px 24px"><a href="../index.html">← Documentation home</a></p>', content, count=1)
index.write_text(content)

class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.ids = set()
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            self.ids.add(attrs['id'])
        if tag == 'a' and 'href' in attrs:
            self.links.append(attrs['href'])

parsed_pages = {}
for page in output.rglob('*.html'):
    parser = Links()
    parser.feed(page.read_text())
    parsed_pages[page.resolve()] = parser
errors = []
for page, parsed in parsed_pages.items():
    for href in parsed.links:
        link = urlsplit(href)
        if link.scheme or link.netloc:
            continue
        # Dartdoc loads sidebar fragments with links relative to the site root.
        base = output / 'api' if page.name.endswith('-sidebar.html') and page.is_relative_to(output / 'api') else page.parent
        target = (base / unquote(link.path)).resolve() if link.path else page
        if target.is_dir():
            target = target / 'index.html'
        if not target.is_file():
            errors.append(f'{page.relative_to(output)}: missing {href}')
        elif link.fragment and target in parsed_pages and unquote(link.fragment) not in parsed_pages[target].ids:
            errors.append(f'{page.relative_to(output)}: missing anchor {href}')
if errors:
    raise SystemExit('\n'.join(errors))
print(f'Validated local links and anchors in {len(parsed_pages)} HTML pages.')
print('Site: ' + str(output / 'index.html'))
