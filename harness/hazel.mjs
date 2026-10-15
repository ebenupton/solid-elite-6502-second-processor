import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
const s = new MachineSession("Master");
await s.initialise(); await s.boot(30);
s.loadDisc(process.argv[2]);
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
await s.runFor(2000000*8);
const cpu = s._machine.processor;
const hist = {}; let n=0; const rd={}; let nr=0;
cpu.debugRead.add((a,v)=>{ if(a>=0xC000&&a<0xE000){rd[a>>8]=(rd[a>>8]||0)+1;nr++;} return false;});
cpu.debugWrite.add((a,v)=>{ if(a>=0xC000&&a<0xE000){rd['w'+(a>>8)]=(rd['w'+(a>>8)]||0)+1;nr++;} return false;});
cpu.debugInstruction.add(pc => { if (pc>=0xC000 && pc<0xE000){ hist[pc>>8]=(hist[pc>>8]||0)+1; n++;} return false; });
for (let t=0;t<20;t++){ await s.runFor(2000000*10); console.log('t',18+t*10,'hazel-pcs',n, JSON.stringify(hist),'rw',nr,JSON.stringify(rd)); }
import {writeFileSync} from 'fs'; writeFileSync('/Users/ebenupton/elite/scratch/hz.png', await s.screenshotActive({scale:1}));
