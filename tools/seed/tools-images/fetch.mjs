// Usage: node tools-images/fetch.mjs <candidates.json> <outDir>
// candidates.json: { key: [photoId, ...] }  photoId like "1546069901-ba9599a7e63c"
// Downloads each candidate at w=400 and writes <outDir>/status.json with { "<key>|<id>": "200 image/jpeg" }.
import fs from 'node:fs';
import path from 'node:path';

const [, , candFile, outDir] = process.argv;
const cands = JSON.parse(fs.readFileSync(candFile, 'utf8'));
fs.mkdirSync(outDir, { recursive: true });
const statusFile = path.join(outDir, 'status.json');
const status = fs.existsSync(statusFile) ? JSON.parse(fs.readFileSync(statusFile, 'utf8')) : {};

const jobs = [];
for (const [key, ids] of Object.entries(cands)) for (const id of ids) jobs.push([key, id]);

const safe = (s) => s.replace(/[^a-z0-9-]/gi, '_');
async function run([key, id]) {
  const file = path.join(outDir, `${safe(key)}__${id}.jpg`);
  if (status[`${key}|${id}`]?.startsWith('200') && fs.existsSync(file)) return;
  const url = `https://images.unsplash.com/photo-${id}?w=400&q=70&fm=jpg`;
  try {
    const res = await fetch(url);
    const ct = res.headers.get('content-type') || '';
    if (res.status === 200 && ct.startsWith('image/')) {
      fs.writeFileSync(file, Buffer.from(await res.arrayBuffer()));
    } else await res.arrayBuffer().catch(() => {});
    status[`${key}|${id}`] = `${res.status} ${ct}`;
  } catch (e) {
    status[`${key}|${id}`] = `ERR ${e.message}`;
  }
}
const queue = [...jobs];
await Promise.all(Array.from({ length: 12 }, async () => { while (queue.length) await run(queue.shift()); }));
fs.writeFileSync(statusFile, JSON.stringify(status, null, 1));
let ok = 0, bad = [];
for (const [k, i] of jobs) (status[`${k}|${i}`].startsWith('200') ? ok++ : bad.push(`${k}|${i} ${status[`${k}|${i}`]}`));
console.log(`ok ${ok} / ${jobs.length}`);
console.log(bad.join('\n'));
