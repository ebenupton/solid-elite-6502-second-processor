import { bootTube } from "../../harness/tlib.mjs";
import { writeFileSync, readFileSync } from "fs";
const t = await bootTube({ host: process.argv[2] || "Master", disc: process.env.DISC || "tube/build/elite-tube.ssd" });
t.s.keyDown(16); t.s.reset(true); t.host.execute(2e6*2); t.s.keyUp(16);
const psy = {}; for (const m of readFileSync("tube/build/psyms.txt","utf8").matchAll(/'([^']+)':(\d+)/g)) psy[m[1]] ??= +m[2];
const hsy = {}; for (const m of readFileSync(process.env.HSYMS || "tube/build/hsyms.txt","utf8").matchAll(/'([^']+)':(\d+)/g)) hsy[m[1]] ??= +m[2];
t.host.debugInstruction.add(pc => { if (pc === 0xfff7) { let a = t.host.x | t.host.y << 8, str = ""; for (let i = 0; i < 40; i++) { const c = t.hmem[a + i]; if (c === 13) break; str += String.fromCharCode(c); } console.log("OSCLI:", str, "at", (t.hostCycles()/2e6).toFixed(2)); } if (pc === 0x0406 && t.host.a !== 7) console.log("TUBE &0406 A=", t.host.a.toString(16), "X,Y", t.host.x.toString(16), t.host.y.toString(16), "at", (t.hostCycles()/2e6).toFixed(2)); if (pc === (t.hmem[0x202]|t.hmem[0x203]<<8) && t.hostCycles()>2e6*3) { let a=(t.hmem[0xfd]|t.hmem[0xfe]<<8)+1, str=""; for(let i=0;i<40;i++){const c=t.host.readmem(a+i); if(!c)break; str+=String.fromCharCode(c);} console.log("BRK:", str); } return false; });
let iters = 0; t.addParHook(pc => { if (pc === psy.MLOOP) iters++; return false; });
t.s._video.frameSkipCount = 1;
for (let k = 0; k < +(process.argv[3] || 20); k++) {
  t.host.execute(2e6);
  const near = (sy, pc) => { let b = null; for (const [n, v] of Object.entries(sy)) if (v <= pc && (!b || v > b[1])) b = [n, v]; return b ? `${b[0]}+${pc - b[1]}` : pc.toString(16); };
  console.log(`t=${k+1}s host pc=${t.host.pc.toString(16)} (${near(hsy, t.host.pc)}) par pc=${t.par.pc.toString(16)} (${near(psy, t.par.pc)}) iters=${iters}`);
}
writeFileSync("screenshots/tube/boot.png", await t.s.screenshot());
const pc=readFileSync("tube/build/PCODE.bin"); let same=0; for(let i=0;i<pc.length;i++) if(t.pmem[0x1500+i]===pc[i]) same++; console.log("PCODE bytes matching in parasite:", same, "/", pc.length);
process.exit(0);
