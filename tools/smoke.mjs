import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { Script } from 'node:vm';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const [index, base, theme] = await Promise.all(['index.html', 'base.html', 'theme.css'].map(name => readFile(resolve(root, name), 'utf8')));
for (const [name, html] of [['index.html', index], ['base.html', base]]) {
  const inline = html.match(/<script>\s*([\s\S]*?)<\/script>/);
  if (!inline) throw new Error(`${name} has no inline application script`);
  new Script(inline[1], { filename: name });
}
const checks = [
  ['same-origin base file', index.includes("fetch('./base.html'")],
  ['all three layer controls', ['devTab', 'impactTab', 'compTab'].every(id => base.includes(`id="${id}"`))],
  ['CSV export and share controls', ['exportCsv', 'shareSearch'].every(id => base.includes(`id="${id}"`))],
  ['independent data-layer loading', base.includes('Promise.allSettled')],
  ['distance in marker details', index.includes('miles from searched property')],
  ['responsive theme', theme.includes('@media (max-width: 520px)')],
];
for (const [name, passed] of checks) console.log(`${passed ? 'PASS' : 'FAIL'} ${name}`);
if (checks.some(([, passed]) => !passed)) process.exitCode = 1;
