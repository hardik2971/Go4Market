// Renders the legal pages in data/content.mjs to static HTML in apps/website/web/page/<slug>.html.
// Hosting (cleanUrls) serves them at /page/<slug> ahead of the Flutter SPA rewrite, so crawlers such as
// Google Play's policy checker can read the text without running JavaScript.
//   node gen-legal-pages.mjs
// Flutter's incremental web build can skip new folders under web/, so after `flutter build web` also run
//   cp -r apps/website/web/page apps/website/build/web/
// before `firebase deploy --only hosting:website`, and check /page/privacy serves HTML text.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { pages } from './data/content.mjs';

const SLUGS = ['privacy', 'delete-account', 'terms'];
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const outDir = path.join(root, 'apps/website/web/page');

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const slugify = (s) => s.toLowerCase().replace(/<[^>]+>/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const inline = (s) =>
  esc(s)
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/(^|[\s(])_(.+?)_(?=[\s.,;:)]|$)/g, '$1<em>$2</em>')
    .replace(/`(.+?)`/g, '<code>$1</code>')
    .replace(/\[(.+?)\]\((.+?)\)/g, '<a href="$2">$1</a>');

function render(md) {
  const lines = md.split(/\r?\n/);
  const out = [];
  let para = [];
  const flush = () => { if (para.length) out.push(`<p>${inline(para.join(' '))}</p>`); para = []; };
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    let m;
    if (!line.trim()) { flush(); continue; }
    if ((m = line.match(/^(#{1,3})\s+(.*)$/))) {
      flush();
      const n = m[1].length, text = m[2];
      out.push(`<h${n} id="${slugify(text)}">${inline(text)}</h${n}>`);
    } else if (/^\s*[-*]\s+/.test(line) || /^\s*\d+\.\s+/.test(line)) {
      flush();
      const ordered = /^\s*\d+\./.test(line), tag = ordered ? 'ol' : 'ul', re = ordered ? /^\s*\d+\.\s+/ : /^\s*[-*]\s+/;
      const items = [];
      while (i < lines.length && re.test(lines[i])) items.push(`<li>${inline(lines[i++].replace(re, ''))}</li>`);
      i--;
      out.push(`<${tag}>${items.join('')}</${tag}>`);
    } else if (line.startsWith('|')) {
      flush();
      const rows = [];
      while (i < lines.length && lines[i].startsWith('|')) rows.push(lines[i++]);
      i--;
      const cells = (r) => r.replace(/^\||\|$/g, '').split('|').map((c) => c.trim());
      const body = rows.slice(2).map((r) => `<tr>${cells(r).map((c) => `<td>${inline(c)}</td>`).join('')}</tr>`).join('');
      out.push(`<table><thead><tr>${cells(rows[0]).map((c) => `<th>${inline(c)}</th>`).join('')}</tr></thead><tbody>${body}</tbody></table>`);
    } else if (line.startsWith('>')) {
      flush();
      out.push(`<blockquote>${inline(line.replace(/^>\s?/, ''))}</blockquote>`);
    } else {
      para.push(line.trim());
    }
  }
  flush();
  return out.join('\n');
}

const page = (slug, { title, content }) => `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)} | Go4Market</title>
<meta name="description" content="${esc(title)} for the Go4Market and Go4Market Partner apps and go4market.web.app.">
<meta name="robots" content="index, follow">
<link rel="canonical" href="https://go4market.web.app/page/${slug}">
<link rel="icon" href="/favicon.png">
<style>
  :root { --g: #0B8A4F; --ink: #14231B; --muted: #5B6B62; --line: #E3ECE6; }
  * { box-sizing: border-box; }
  body { margin: 0; font: 16px/1.65 system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif; color: var(--ink); background: #F7FAF8; }
  header { background: var(--g); padding: 14px 20px; }
  header a { color: #fff; font-weight: 700; font-size: 20px; text-decoration: none; }
  header a span { color: #FFB04D; }
  main { max-width: 820px; margin: 24px auto; background: #fff; border: 1px solid var(--line); border-radius: 16px; padding: 28px 32px; }
  h1 { font-size: 30px; line-height: 1.25; margin: 0 0 8px; }
  h2 { font-size: 21px; margin: 32px 0 8px; padding-top: 8px; border-top: 1px solid var(--line); }
  h3 { font-size: 17px; margin: 22px 0 6px; }
  a { color: var(--g); }
  em { color: var(--muted); }
  li { margin: 4px 0; }
  table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 15px; }
  th, td { border: 1px solid var(--line); padding: 8px 10px; text-align: left; vertical-align: top; }
  th { background: #F0F7F3; }
  blockquote { margin: 16px 0; padding: 12px 16px; background: #FFF6EB; border-left: 4px solid #F57C12; border-radius: 8px; }
  footer { max-width: 820px; margin: 0 auto 32px; padding: 0 8px; color: var(--muted); font-size: 14px; }
  @media (max-width: 600px) { main { margin: 0; border-radius: 0; border: 0; padding: 20px; } }
</style>
</head>
<body>
<header><a href="/">Go<span>4</span>Market</a></header>
<main>
${render(content)}
</main>
<footer><a href="/page/privacy">Privacy Policy</a> · <a href="/page/delete-account">Delete account</a> · <a href="/page/terms">Terms</a> · <a href="/">go4market.web.app</a></footer>
</body>
</html>
`;

fs.mkdirSync(outDir, { recursive: true });
for (const slug of SLUGS) {
  if (!pages[slug]) throw new Error(`No page "${slug}" in data/content.mjs`);
  fs.writeFileSync(path.join(outDir, `${slug}.html`), page(slug, pages[slug]));
  console.log(`apps/website/web/page/${slug}.html`);
}
