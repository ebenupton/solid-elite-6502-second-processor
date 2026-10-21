# The Tube version: memory maps and protocol

The 6502 Second Processor version of the full Master port, as built on branch
`tube` (`tube/build.sh`). TUBE-PLAN.md is the plan (with what happened),
TUBE-REPORT.md (untracked) the report with the numbers.

Two discs: `tube/build/elite-tube.ssd` (a BBC Master host) and
`tube/build/elite-tube-b.ssd` (a BBC Micro Model B host with 64K of sideways
RAM). SHIFT+BREAK on either, with a 6502 Second Processor attached.

## The parasite (65C02, 3 MHz, flat 64K) — both hosts

| Region | Addresses | Holds |
|---|---|---|
| Zero page, stack, K%, WP | &0000-&0CCE | the game's workspaces, at the Master port's addresses; &E4-&FB free (phase 4's experiment used them) |
| Page &0D | &0D00-&0D7F, &0D80-&0DEF | a dummy SHEILA (VIA = &0D00: Master's drawing's ACCCON writes land there); setzp/getzp's buffer (ZPSAVE) |
| Frame layer's inputs | &0E00-&14AE | tube/src/p-ws.asm: the disc spans and boundaries (R_NDX2/3 double as phase A's tables), the polygon and line inputs, the stars |
| Game and frame layer | &1500-&F793 | the run (with the Tube glue p-low.asm, p-io.asm), Master's drawing (bank 4's blocks, whose screen writes go to the host), the game data, the cold area, the frame layer's parasite part, phase A's first part (p-polya.asm) |
| High area | &F800-&FEEF | phase A's second part (p-polyb.asm). The client OS's copy lives here too: the host keeps whichever of the two is out (C_SWAP: at the start, and either side of each disc command) |

The parasite runs with interrupts off, except inside a disc command (DOSCLI ->
p_oscli: the client OS is swapped back in, then OSCLI with CLI).

## The protocol (tube/src/cmds.asm)

The parasite writes commands into register 1 (polling its room bit); the host
reads them in its command loop (polling its data bit); requests (keys, a key
test, vsync, the System VIA's port B) are answered through register 4. A
command is an even opcode (the host dispatches through a table) and its
operands. Notable ones:

- C_POLY: R_POLY's rows after the parasite's phase A (phase 3): COLE, COLO,
  COL2, COL3, the horizontal clip flag, ystart, ylast, then left and right per
  row; the host enters its rasteriser at r_pcbd.
- C_DISC: the disc layer's rows (spans, colours, up to 4 boundaries a row;
  R_NDF = &81: a beach ball, spans only, the host makes the boundaries).
- C_MERHOOK: a beach ball (meridian planet, TYPE 128): H_MERID's inputs to the
  host's meridian window (below): roofv and sidev (INWK+15..26), K3, K4, MCNT,
  PM_R. The host runs PM_HOOK at once (in the parasite's game time); C_DISC's
  R_NDF = &81 then has it run PM_MERID on the spans before R_DISCROWS.
- C_LINE, C_DOT, C_SPAN, C_MARK, C_FLARE, C_DSTAR: as the Master port's
  trampolines' arguments.
- C_FB / C_FE / C_SYNC: a frame's begin, end (stars, flip) and the end of the
  iteration (the harness hashes the screen there; the host then starts its
  pre-erase).
- C_SCEOR / C_SCSTA: Master's direct drawing, a byte at a time.
- C_OSCLI: hand the host back to the MOS's Tube code for a disc command; the
  parasite's &FE through register 1 (WRCHV = hwrch) brings it back.
- C_SWAP: exchange &F800-&FEEF with the host's copy, byte for byte.

## Beach ball planets (the meridian window)

The Master port draws a meridian planet as a beach ball (BEACHBALL-REPORT.md:
gfx-merid.asm, PM_HOOK and PM_MERID, 3.3K in its bank 7). The parasite has
about 300 bytes free, so the window is the host's (tube/src/h-merid.asm: the
quarter squares it multiplies with, PM_IN, C_MERHOOK's receiver h_merin, then
gfx-merid.asm assembled with _TPART = 2: its inputs from PM_IN, and with
MERIDHOLD = 0 the held orientation's paths left out, PM_HELD). The parasite
keeps H_MERID (gfx-hooks.asm: K2 and TGT as PL9 leaves them), whose
G_MERHOOK (p-glue.asm) sends C_MERHOOK and sets PM_OK; f_bounds' T_MERID
(p-io.asm) marks the C_DISC R_NDF = &81, and its rows carry the spans only.
Master host: bank 7 &8000-&8F06 (HMERID, loaded by the loader's FTAB); the
row loop through gfx-tramp.asm's T_MERID from h_disc. Model B host: bank D
after the shared code (&A748-&B72B, NMOS, beside the disc inputs it writes),
C_MERHOOK through hb_merhook and the jump table's D_MERHOOK, the row loop
from d_disc.

## The Master host

The Master port's display side: buffer 0 in main RAM &4000-&6FFF, buffer 1
in shadow RAM at the same addresses (ACCCON X), the dashboard in shadow
&7000; the rasteriser in bank 5 and ANDY, the frame layer's host part (text
map, text overlay, sights, flip) and the rarely run host code (h-cold.asm) and
the high area's copy (HSW) in bank 6; the meridian window in bank 7 (h-merid.asm); the renderer's workspace at
&0E40-&1EDB and from &1EDC the game's host blocks (IRQ, sound, CHPR and font,
UP), the trampolines, the command loop and the pre-erase (h-main.asm,
h-hpe.asm). 65C12 code.

The pre-erase (phase 5): after a space frame, once the flip has hidden the
other buffer, the command loop blacks that buffer's old dirty rows outside its
old disc rows between commands (what R_DISCROWS' repair would do at the next
frame's start); commands that may draw finish it first.

## The Model B host (64K sideways RAM)

NMOS code made from the same sources (tube/tools/nmos.py, with tools/longbr.py
for branches the longer code puts out of range), behind `_HOSTB` where it must
differ (no ACCCON; the screen base; the banks).

| Region | Addresses | Holds |
|---|---|---|
| Main RAM taken from the MOS | &0236-&0CFF (but JOPOS at &0CA7), &0E00-&0FFF | the entry points banks D/P call (runp, p_rowrepr at &0236), the trampolines, the renderer's globals, the per-buffer DIRTY/DISC arrays (the Master port's low bytes), WL/WR, the stars, the pre-erase; swapped with the MOS's contents (and &1000-&10FF, DFS's workspace over buffer 0) through bank S for each disc command (hbswap) |
| Buffer 0 | &1000-&3FFF | (the screen base is patched per buffer: r_bs1-r_bs11, f_bufpatch's sites) |
| Buffer 1 | &4000-&6FFF | the Master port's addresses: direct mode unchanged |
| Panel | &7000-&7DFF | the dashboard, the Master port's address |
| &7E00-&7FFF | | hwrch (WRCHV), the IRQ entry, hbswap: not swapped |
| Bank D | &8000-&BFFF | the disc window, the shared code without the runs (bank D's r_spc runs bank P's through runp), the boundary arrays, the meridian window (h-merid.asm, &A748-&B72B), the disc inputs (&B800), jump table at &BFC0 |
| Bank P | &8000-&BFFF | the polygon window (phase B, r_pcbd), the line loops, the shared region with the runs (patched per buffer on first use: r_pgfix), the stars, the flare, the row repair (r7_rowrep), the polygon inputs (&9500), jump table at &BFC0 |
| Bank F | &8000-&B6EF | the command loop and handlers, the frame layer's host part, CHPR and its font, the sound, the interrupts (hb-irq.asm), the high area's copy |
| Bank S | &8000-&8DC9 | the swapped main RAM |

The dashboard split is a CRTC vertical rupture (tube/spike/rupture.asm): two
CRTC frames per field (24 rows of the shown buffer without vsync, then 15 rows
of which 7 show the panel, vsync at its row 10), timer 1 firing twice a field
to set each frame's R4/R6/R7 and start address; a flip takes effect at the next
frame A. Interlace off (fields of exactly 312 lines). The loader
(tube/src/loader-b.asm, at &1900) finds the first four sideways RAM banks and
patches their numbers into the images (build/hb-patch.asm: the build
assembles again with other bank numbers and lists the operands that differ).

## Screen-store runs: full `STA abs` evaluated

See TUBE-REPORT.md, "Evaluation: full STA abs screen runs": one set per buffer
is 37.6K; the Model B host would need two (75K) and does not get them. On the
Master host (both buffers at the same address) one set would fit in banks 4
and 7 and part of 6, but the rasteriser's code that calls the runs runs in
bank 5/ANDY, so each call would need a bank switch through main RAM (~40
cycles), which costs as much as the store cycle it saves at docking; not
adopted.
