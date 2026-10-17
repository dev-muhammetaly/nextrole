import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const web = path.resolve(import.meta.dirname, '../web');
let links = 0;
for (const name of fs.readdirSync(web).filter(f => f.endsWith('.html'))) {
  const text = fs.readFileSync(path.join(web, name), 'utf8');
  assert.match(text, /<html lang="en">/, name);
  assert.match(text, /<meta name="description"/, name);
  assert.match(text, /<meta name="viewport"/, name);
  for (const match of text.matchAll(/(?:href|src)="([^"#]+)(?:#[^"]*)?"/g)) {
    const link = match[1];
    if (/^https?:/.test(link)) continue;
    const pathname = new URL(link, 'http://localhost').pathname;
    const file = pathname === '/' ? 'index.html' : pathname.replace(/^\//, '');
    assert.ok(fs.existsSync(path.join(web, file)), `${name}: broken link ${link}`);
    links++;
  }
  for (const match of text.matchAll(/<img\b[^>]*>/g)) assert.match(match[0], /\balt=/, name);
  if (!['app.html', '404.html'].includes(name)) {
    assert.match(text, /rel="canonical" href="https?:\/\//, name);
    assert.match(text, /property="og:image:alt"/, name);
  }
}
for (const file of ['llms.txt','Ilms.txt','sitemap.xml','robots.txt','social-card.png','favicon.svg']) assert.ok(fs.existsSync(path.join(web,file)), file);
const css = fs.readFileSync(path.join(web, 'site.css'), 'utf8');
for (const match of css.matchAll(/url\(['"]?([^'"\)]+)['"]?\)/g)) {
  assert.ok(fs.existsSync(path.join(web, match[1].replace(/^\//,''))), `Missing stylesheet asset ${match[1]}`);
}
const script = fs.readFileSync(path.join(web, 'site.js'), 'utf8');
assert.doesNotMatch(script, /googletagmanager|google-analytics|gtag\(|fbq\(/);
console.log(`Public pages checked: ${links} local links/assets resolve; metadata and accessibility attributes present; no analytics script installed.`);
