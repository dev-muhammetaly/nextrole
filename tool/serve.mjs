import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
const root = path.resolve(import.meta.dirname, '../build/web');
const port = Number(process.env.NEXTROLE_PORT || 8080);
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw Error('NEXTROLE_PORT must be a valid unprivileged port.');
const mime = {'.html':'text/html; charset=utf-8','.js':'text/javascript','.css':'text/css','.json':'application/json','.xml':'application/xml','.txt':'text/plain','.svg':'image/svg+xml','.png':'image/png','.wasm':'application/wasm','.ttf':'font/ttf'};
http.createServer((req,res) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url,'http://localhost').pathname); } catch (_) { res.writeHead(400).end(); return; }
  let target = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
  if (!target.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
  let status = 200;
  if (!fs.existsSync(target) || !fs.statSync(target).isFile()) { target = path.join(root,'404.html'); status = 404; }
  res.writeHead(status, {'Content-Type':mime[path.extname(target)] || 'application/octet-stream','Cache-Control':'no-cache'});
  fs.createReadStream(target).pipe(res);
}).listen(port,'127.0.0.1', () => console.log('Nextrole preview: http://127.0.0.1:' + port));
