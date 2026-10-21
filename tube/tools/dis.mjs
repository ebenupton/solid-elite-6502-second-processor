// dis(mem, start, end, read): a 65C02 disassembly listing (mem: function addr -> byte)
import { OPS } from "./op65.mjs";
export function dis(rd, start, end, labels = {}) {
    const out = [];
    for (let a = start; a < end;) {
        const op = rd(a), o = OPS[op], b1 = rd(a + 1), b2 = rd(a + 2);
        const w = b1 | b2 << 8, h = n => n.toString(16).toUpperCase().padStart(2, "0"), hw = n => "&" + n.toString(16).toUpperCase().padStart(4, "0");
        let arg = "";
        switch (o.mode) {
            case "imm": arg = "#&" + h(b1); break;
            case "zp": arg = "&" + h(b1); break; case "zpx": arg = "&" + h(b1) + ",X"; break; case "zpy": arg = "&" + h(b1) + ",Y"; break;
            case "abs": arg = hw(w); break; case "abx": arg = hw(w) + ",X"; break; case "aby": arg = hw(w) + ",Y"; break;
            case "ind": arg = "(" + hw(w) + ")"; break; case "aix": arg = "(" + hw(w) + ",X)"; break;
            case "izx": arg = "(&" + h(b1) + ",X)"; break; case "izy": arg = "(&" + h(b1) + "),Y"; break; case "izp": arg = "(&" + h(b1) + ")"; break;
            case "rel": arg = hw((a + 2 + ((b1 << 24) >> 24)) & 0xffff); break; case "acc": arg = "A"; break;
        }
        const bytes = [op, b1, b2].slice(0, o.len).map(h).join(" ");
        out.push(`${hw(a).slice(1)}  ${bytes.padEnd(9)} ${labels[a] ? "." + labels[a] + " " : ""}${o.mn} ${arg}`);
        a += o.len;
    }
    return out.join("\n");
}
