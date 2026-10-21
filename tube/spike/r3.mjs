// Phase 0 spike: R3 with the parasite's NMI (see r3.asm). node tube/spike/r3.mjs [B|Master]
import { bootTube } from "../../harness/tlib.mjs";
import { readFileSync } from "fs";
const host = process.argv[2] || "B";
const H = readFileSync(new URL("../build/spike-r3-host.bin", import.meta.url)), P = readFileSync(new URL("../build/spike-r3-par.bin", import.meta.url));
const t = await bootTube({ host });
t.hostPoke(0x3000, H); t.parPoke(0x2000, P);
const HDONE = 0x3022, PCNT = 0x2038;
// the parasite first fills its buffer, then loops; start the host after that
t.par.pc = 0x2000; t.host.pc = 0x3100;  // host: park on a JMP to itself until the parasite is ready
t.hmem[0x3100] = 0x4c; t.hmem[0x3101] = 0x00; t.hmem[0x3102] = 0x31; t.hmem[0x3103] = 0x78;
t.hmem[0x3100] = 0x78; t.hmem[0x3101] = 0x4c; t.hmem[0x3102] = 0x01; t.hmem[0x3103] = 0x31; // SEI : JMP *
t.host.execute(20000);
const cnt = () => t.pmem[PCNT] | t.pmem[PCNT + 1] << 8 | t.pmem[PCNT + 2] << 16;
// baseline: how fast does the parasite count with no NMIs
let c0 = cnt(), h0 = t.hostCycles(); t.host.execute(100000); const rate = (cnt() - c0) / (t.hostCycles() - h0);
t.host.pc = 0x3000;
c0 = cnt(); h0 = t.hostCycles();
let end = -1;
t.host.debugInstruction.add(pc => { if (pc === HDONE && end < 0) { end = t.hostCycles(); return true; } return false; });
for (let k = 0; k < 200 && end < 0; k++) t.host.execute(20000);
const n = 4096, dt = end - h0, counted = cnt() - c0;
const lostParCycles = (rate * dt - counted) * 9;
console.log(`${host} R3/NMI: ${n} bytes in ${dt} host cycles: ${(dt / n).toFixed(2)} host cycles/byte, ${(n / (dt / 2e6) / 1024).toFixed(1)} KB/s; parasite main code kept ${(100 * counted / (rate * dt)).toFixed(1)}% of its time, NMI cost ${(lostParCycles / n).toFixed(1)} parasite cycles/byte`);
let ok = true; for (let i = 0; i < 256; i++) if (t.hmem[0x3400 + i] !== i) ok = false; console.log("  data ok:", ok, "count rate", rate.toFixed(4), "per host cycle");
process.exit(0);
