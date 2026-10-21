// Phase 0 spike: the CRTC vertical rupture on a Model B (see rupture.asm).
// Fills buffer A (&1200) with colour pattern &F0, buffer B (&4200) with &0F,
// the panel (&7200) with &FF, runs, and reads jsbeeb's rendered picture:
// the colour of each displayed line at the centre column.
import { bootTube } from "../../harness/tlib.mjs";
import { readFileSync, writeFileSync } from "fs";
const host = process.argv[2] || "B";
const t = await bootTube({ host });
const bin = readFileSync(new URL("../build/spike-rupture.bin", import.meta.url));
t.hostPoke(0x0e00, bin);
const FRONT = 0xef3, FIELDS = 0xef4;
t.host.pc = 0x0e00;
t.host.execute(2e6 * 0.5);           // (MODE 1 clears &3000-&7FFF: fill the buffers after it)
for (let a = 0x1200; a < 0x4200; a++) t.hmem[a] = 0xf0;
for (let a = 0x4200; a < 0x7200; a++) t.hmem[a] = 0x0f;
for (let a = 0x7200; a < 0x8000; a++) t.hmem[a] = 0xff;
t.s._video.frameSkipCount = 1;
function picture() {
  const fb = t.s._completeFb8, W = 1024, rows = [];
  for (let y = 0; y < 625; y++) { const o = (y * W + 512) * 4; rows.push(fb[o] << 16 | fb[o + 1] << 8 | fb[o + 2]); }
  // runs of the same colour
  const runs = []; let start = 0;
  for (let y = 1; y <= 625; y++) if (y === 625 || rows[y] !== rows[start]) { runs.push(`${start}-${y - 1}:${rows[start].toString(16).padStart(6, "0")}`); start = y; }
  return runs.join(" ");
}
for (const front of [0, 1, 0]) {
  t.hmem[FRONT] = front;
  t.host.execute(2e6 * 0.2);
  console.log(`front ${front}, fields ${t.hmem[FIELDS]}: ${picture()}`);
  writeFileSync(new URL(`../../screenshots/tube/rupture-front${front}.png`, import.meta.url), await t.s.screenshot());
}
// vsync count over one second: 50 expected
const f0 = t.hmem[FIELDS]; t.host.execute(2e6); console.log("vsyncs in 1 s:", (t.hmem[FIELDS] - f0 + 256) & 255);
process.exit(0);
