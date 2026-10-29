// Usage: node tools-images/sheet.mjs <candidates.json> <imgDir> <outPrefix> [cols=5] [rows=4]
// Builds contact sheets of all downloaded candidates, labelled "key | id-prefix".
import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';

const [, , candFile, imgDir, outPrefix, colsA, rowsA] = process.argv;
const cols = +colsA || 5, rows = +rowsA || 4, T = +process.env.T || 300, LH = 26;
const cands = JSON.parse(fs.readFileSync(candFile, 'utf8'));
const safe = (s) => s.replace(/[^a-z0-9-]/gi, '_');
const items = [];
for (const [key, ids] of Object.entries(cands))
  for (const id of ids) {
    const f = path.join(imgDir, `${safe(key)}__${id}.jpg`);
    if (fs.existsSync(f)) items.push({ key, id, f });
  }
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
const per = cols * rows;
let n = 0;
for (let p = 0; p < items.length; p += per) {
  const chunk = items.slice(p, p + per);
  const comps = [];
  for (let i = 0; i < chunk.length; i++) {
    const { key, id, f } = chunk[i];
    const x = (i % cols) * T, y = Math.floor(i / cols) * (T + LH);
    const tile = await sharp(f).resize(T, T, { fit: 'contain', background: '#222' }).jpeg().toBuffer();
    comps.push({ input: tile, left: x, top: y + LH });
    const svg = `<svg width="${T}" height="${LH}" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#000"/><text x="4" y="18" font-family="Arial" font-size="13" fill="#ff0">${esc(`${key} ${id.slice(0, 13)}`)}</text></svg>`;
    comps.push({ input: Buffer.from(svg), left: x, top: y });
  }
  const H = Math.ceil(chunk.length / cols) * (T + LH);
  const out = `${outPrefix}-${String(++n).padStart(2, '0')}.jpg`;
  await sharp({ create: { width: cols * T, height: H, channels: 3, background: '#444' } }).composite(comps).jpeg({ quality: 75 }).toFile(out);
  console.log(out, chunk.length);
}
