import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, extname, join, resolve, sep } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8' };
const port = Number(process.env.RV_MAP_PORT || 8765);

createServer(async (request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  const requested = resolve(join(root, pathname === '/' ? 'index.html' : pathname.slice(1)));
  if (requested !== root && !requested.startsWith(root + sep)) {
    response.writeHead(403).end('Forbidden');
    return;
  }
  try {
    const data = await readFile(requested);
    response.writeHead(200, { 'content-type': types[extname(requested)] || 'application/octet-stream' }).end(data);
  } catch {
    response.writeHead(404).end('Not found');
  }
}).listen(port, '127.0.0.1', () => {
  console.log(`Texas RV map: http://127.0.0.1:${port}/`);
});

