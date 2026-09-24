// Executes the compiled portable example with Node's real WebAssembly engine.
// This checks runtime contracts, not browser UI or browser policy behavior.
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
globalThis.self = globalThis;
const originalFetch = globalThis.fetch;
globalThis.fetch = async (url, options) => url === 'dart_zig.wasm'
  ? new Response(await readFile(new URL('../build/web/dart_zig.wasm', import.meta.url)))
  : originalFetch(url, options);
const timer = setTimeout(() => { console.error('Web example timed out'); process.exit(1); }, 30000);
const originalLog = console.log;
console.log = (...args) => {
  originalLog(...args);
  if ((String(args[0]).includes('reentrant shutdown, and native cleanup passed.') || String(args[0]).includes('All portable examples completed.'))) clearTimeout(timer);
};
await import(pathToFileURL(resolve('build/web/main.dart.js')));
