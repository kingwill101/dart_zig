#!/usr/bin/env python3
"""Serve the generated documentation locally; press Ctrl+C to stop."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--port', type=int, default=8080)
args = parser.parse_args()
site = Path(__file__).resolve().parent.parent / 'build/docs'
if not (site / 'index.html').is_file():
    raise SystemExit('Run python3 tool/build_docs.py first.')
handler = partial(SimpleHTTPRequestHandler, directory=str(site))
with ThreadingHTTPServer(('127.0.0.1', args.port), handler) as server:
    print(f'Documentation: http://127.0.0.1:{server.server_port}', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
