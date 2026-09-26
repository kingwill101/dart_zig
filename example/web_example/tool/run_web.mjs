import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

globalThis.self = globalThis;
const originalFetch = globalThis.fetch;
globalThis.fetch = async (url, options) => url === 'web_example.wasm'
  ? new Response(await readFile(new URL('../build/web/web_example.wasm', import.meta.url)))
  : originalFetch(url, options);
const timer = setTimeout(() => { console.error('Web example timed out'); process.exitCode = 1; }, 30000);
const originalLog = console.log;
console.log = (...args) => {
  originalLog(...args);
  if (String(args[0]).includes('Web sum: 42')) clearTimeout(timer);
};
await import(pathToFileURL(resolve('build/web/main.dart.js')));
