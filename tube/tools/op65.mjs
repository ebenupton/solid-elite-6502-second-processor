// 65C02 opcode table for the Tube tools: mnemonic, addressing mode, length, and
// the registers and flags each instruction reads and writes (for liveness).
// Modes: imp, acc, imm, zp, zpx, zpy, abs, abx, aby, ind, izx, izy, izp (zp),
// rel, aix (abs,X), zpr (BBR/BBS: not used by the 65C12, left out).
const T = {};
function def(op, mn, mode) { T[op] = { mn, mode }; }
const rows = `
00 BRK imp|01 ORA izx|04 TSB zp|05 ORA zp|06 ASL zp|08 PHP imp|09 ORA imm|0A ASL acc|0C TSB abs|0D ORA abs|0E ASL abs
10 BPL rel|11 ORA izy|12 ORA izp|14 TRB zp|15 ORA zpx|16 ASL zpx|18 CLC imp|19 ORA aby|1A INC acc|1C TRB abs|1D ORA abx|1E ASL abx
20 JSR abs|21 AND izx|24 BIT zp|25 AND zp|26 ROL zp|28 PLP imp|29 AND imm|2A ROL acc|2C BIT abs|2D AND abs|2E ROL abs
30 BMI rel|31 AND izy|32 AND izp|34 BIT zpx|35 AND zpx|36 ROL zpx|38 SEC imp|39 AND aby|3A DEC acc|3C BIT abx|3D AND abx|3E ROL abx
40 RTI imp|41 EOR izx|45 EOR zp|46 LSR zp|48 PHA imp|49 EOR imm|4A LSR acc|4C JMP abs|4D EOR abs|4E LSR abs
50 BVC rel|51 EOR izy|52 EOR izp|55 EOR zpx|56 LSR zpx|58 CLI imp|59 EOR aby|5A PHY imp|5D EOR abx|5E LSR abx
60 RTS imp|61 ADC izx|64 STZ zp|65 ADC zp|66 ROR zp|68 PLA imp|69 ADC imm|6A ROR acc|6C JMP ind|6D ADC abs|6E ROR abs
70 BVS rel|71 ADC izy|72 ADC izp|74 STZ zpx|75 ADC zpx|76 ROR zpx|78 SEI imp|79 ADC aby|7A PLY imp|7C JMP aix|7D ADC abx|7E ROR abx
80 BRA rel|81 STA izx|84 STY zp|85 STA zp|86 STX zp|88 DEY imp|89 BIT imm|8A TXA imp|8C STY abs|8D STA abs|8E STX abs
90 BCC rel|91 STA izy|92 STA izp|94 STY zpx|95 STA zpx|96 STX zpy|98 TYA imp|99 STA aby|9A TXS imp|9C STZ abs|9D STA abx|9E STZ abx
A0 LDY imm|A1 LDA izx|A2 LDX imm|A4 LDY zp|A5 LDA zp|A6 LDX zp|A8 TAY imp|A9 LDA imm|AA TAX imp|AC LDY abs|AD LDA abs|AE LDX abs
B0 BCS rel|B1 LDA izy|B2 LDA izp|B4 LDY zpx|B5 LDA zpx|B6 LDX zpy|B8 CLV imp|B9 LDA aby|BA TSX imp|BC LDY abx|BD LDA abx|BE LDX aby
C0 CPY imm|C1 CMP izx|C4 CPY zp|C5 CMP zp|C6 DEC zp|C8 INY imp|C9 CMP imm|CA DEX imp|CC CPY abs|CD CMP abs|CE DEC abs
D0 BNE rel|D1 CMP izy|D2 CMP izp|D5 CMP zpx|D6 DEC zpx|D8 CLD imp|D9 CMP aby|DA PHX imp|DD CMP abx|DE DEC abx
E0 CPX imm|E1 SBC izx|E4 CPX zp|E5 SBC zp|E6 INC zp|E8 INX imp|E9 SBC imm|EA NOP imp|EC CPX abs|ED SBC abs|EE INC abs
F0 BEQ rel|F1 SBC izy|F2 SBC izp|F5 SBC zpx|F6 INC zpx|F8 SED imp|F9 SBC aby|FA PLX imp|FD SBC abx|FE INC abx`;
for (const r of rows.trim().split(/\n/)) for (const c of r.split("|")) { const [op, mn, mode] = c.trim().split(/\s+/); def(parseInt(op, 16), mn, mode); }
const LEN = { imp: 1, acc: 1, imm: 2, zp: 2, zpx: 2, zpy: 2, abs: 3, abx: 3, aby: 3, ind: 3, izx: 2, izy: 2, izp: 2, rel: 2, aix: 3 };

// registers and flags: bits A=1 X=2 Y=4 N=8 Z=16 C=32 V=64
export const RA = 1, RX = 2, RY = 4, FN = 8, FZ = 16, FC = 32, FV = 64, NZ = FN | FZ, ALLF = FN | FZ | FC | FV;
const RW = {
    LDA: [0, RA | NZ], LDX: [0, RX | NZ], LDY: [0, RY | NZ], STA: [RA, 0], STX: [RX, 0], STY: [RY, 0], STZ: [0, 0],
    ADC: [RA | FC, RA | ALLF], SBC: [RA | FC, RA | ALLF], AND: [RA, RA | NZ], ORA: [RA, RA | NZ], EOR: [RA, RA | NZ],
    CMP: [RA, NZ | FC], CPX: [RX, NZ | FC], CPY: [RY, NZ | FC], BIT: [RA, NZ | FV],
    ASL: [0, NZ | FC], LSR: [0, NZ | FC], ROL: [FC, NZ | FC], ROR: [FC, NZ | FC], INC: [0, NZ], DEC: [0, NZ],
    INX: [RX, RX | NZ], DEX: [RX, RX | NZ], INY: [RY, RY | NZ], DEY: [RY, RY | NZ],
    TAX: [RA, RX | NZ], TAY: [RA, RY | NZ], TXA: [RX, RA | NZ], TYA: [RY, RA | NZ], TSX: [0, RX | NZ], TXS: [RX, 0],
    PHA: [RA, 0], PHX: [RX, 0], PHY: [RY, 0], PHP: [ALLF, 0], PLA: [0, RA | NZ], PLX: [0, RX | NZ], PLY: [0, RY | NZ], PLP: [0, ALLF],
    BCC: [FC, 0], BCS: [FC, 0], BEQ: [FZ, 0], BNE: [FZ, 0], BMI: [FN, 0], BPL: [FN, 0], BVC: [FV, 0], BVS: [FV, 0], BRA: [0, 0],
    JMP: [0, 0], JSR: [0, 0], RTS: [0, 0], RTI: [0, ALLF], BRK: [0, 0], NOP: [0, 0],
    CLC: [0, FC], SEC: [0, FC], CLV: [0, FV], CLI: [0, 0], SEI: [0, 0], CLD: [0, 0], SED: [0, 0],
    TSB: [RA, FZ], TRB: [RA, FZ],
};
export const OPS = new Array(256);
for (let op = 0; op < 256; op++) {
    const d = T[op];
    if (!d) { OPS[op] = { mn: "???", mode: "imp", len: 1, rd: 0, wr: 0 }; continue; }
    let [rd, wr] = RW[d.mn];
    if (d.mode === "acc") { if (d.mn === "ASL" || d.mn === "LSR") rd |= RA, wr |= RA; if (d.mn === "ROL" || d.mn === "ROR") rd |= RA, wr |= RA; if (d.mn === "INC" || d.mn === "DEC") rd |= RA, wr |= RA; }
    if (d.mn === "BIT" && d.mode === "imm") wr = FZ;
    if (["zpx", "abx", "izx", "aix"].includes(d.mode)) rd |= RX;
    if (["zpy", "aby", "izy"].includes(d.mode)) rd |= RY;
    OPS[op] = { mn: d.mn, mode: d.mode, len: LEN[d.mode], rd, wr };
}
export const REGNAME = [[RA, "A"], [RX, "X"], [RY, "Y"], [FN, "N"], [FZ, "Z"], [FC, "C"], [FV, "V"]];
export const regs = m => REGNAME.filter(([b]) => m & b).map(([, n]) => n).join("");
