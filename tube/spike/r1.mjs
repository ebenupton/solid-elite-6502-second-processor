// Phase 0 spike: R1 throughput (see r1.asm). node tube/spike/r1.mjs [B|Master]
import { bootTube } from "../../harness/tlib.mjs";
import { readFileSync } from "fs";
const host = process.argv[2] || "B";
const H = readFileSync(new URL("../build/spike-r1-host.bin", import.meta.url)), P = readFileSync(new URL("../build/spike-r1-par.bin", import.meta.url));
const NP = 16;
for (const variant of [1, 2]) {
  const t = await bootTube({ host });
  t.hostPoke(0x3000, H); t.parPoke(0x2000, P);
  for (let a = 0x70; a < 0x75; a++) t.hmem[a] = 0;
  const start = variant === 1 ? 0x3000 : 0x301b, done = variant === 1 ? 0x3018 : +process.env.H2DONE;
  t.host.pc = start; t.par.pc = 0x2000;
  const c0 = t.hostCycles();
  let first = t.hostCycles(), end = -1;
  t.host.debugInstruction.add(pc => { if (pc === done && end < 0) { end = t.hostCycles(); return true; } return false; });
  for (let k = 0; k < 200 && end < 0; k++) t.host.execute(20000);
  const n = NP * 256;
  console.log(`${host} variant ${variant}: ${n} bytes in ${end - first} host cycles: ${((end - first) / n).toFixed(2)} cycles/byte, ${(n / ((end - first) / 2e6) / 1024).toFixed(1)} KB/s`);
  if (variant === 1) { let ok = true; for (let i = 0; i < 256; i++) if (t.hmem[0x3400 + i] !== i) ok = false; console.log("  data ok:", ok); }
}
process.exit(0);
