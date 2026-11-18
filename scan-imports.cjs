const fs = require('fs');
const path = require('path');
const dir = path.join(__dirname, 'rea-extract', 'package', 'dist', 'cli-runtime');
const ext = new Set();
const add = (id) => {
  if (!id || id.startsWith('.') || id.startsWith('node:') || id.startsWith('#')) return;
  const parts = id.split('/');
  ext.add(id.startsWith('@') ? parts.slice(0, 2).join('/') : parts[0]);
};
for (const f of fs.readdirSync(dir)) {
  if (!f.endsWith('.js')) continue;
  const s = fs.readFileSync(path.join(dir, f), 'utf8');
  for (const m of s.matchAll(/(?:from|import)\s*\(?\s*["']([^"']+)["']/g)) add(m[1]);
}
console.log([...ext].sort().join('\n'));
