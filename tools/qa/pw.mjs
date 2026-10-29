// Scriptable Chrome session for the live panels/website.
// Usage: node pw.mjs <script.json>  — steps: {goto}, {click:[x,y]}, {type}, {key}, {wait}, {shot}, {login:{email}}
import { chromium } from 'playwright-core';
import fs from 'node:fs';
const steps = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const out = new URL('./out/', import.meta.url).pathname.replace(/^\/([A-Z]:)/, '$1');
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(String(e).slice(0, 160)));
page.on('console', (m) => { if (m.type() === 'error' || /index|denied|failed/i.test(m.text())) errors.push(m.text().slice(0, 300)); });
for (const s of steps) {
  if (s.goto) { await page.goto(s.goto, { waitUntil: 'load' }); await page.waitForTimeout(s.ms ?? 6000); }
  if (s.login) {
    await page.mouse.click(1047, 398); await page.waitForTimeout(400);
    await page.keyboard.type(s.login.email, { delay: 15 });
    await page.mouse.click(1000, 462); await page.waitForTimeout(400);
    await page.keyboard.type(s.login.password ?? 'Go4Market@123', { delay: 15 });
    await page.keyboard.press('Enter'); await page.waitForTimeout(9000);
  }
  if (s.click) { await page.mouse.click(s.click[0], s.click[1]); await page.waitForTimeout(s.ms ?? 1500); }
  if (s.type) { await page.keyboard.type(s.type, { delay: 20 }); await page.waitForTimeout(500); }
  if (s.key) { await page.keyboard.press(s.key); await page.waitForTimeout(s.ms ?? 800); }
  if (s.wait) await page.waitForTimeout(s.wait);
  if (s.shot) { await page.screenshot({ path: out + s.shot + '.png' }); console.log('shot', s.shot, page.url()); }
}
console.log(JSON.stringify({ errors: [...new Set(errors)] }));
await browser.close();
