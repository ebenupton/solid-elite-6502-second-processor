# The Tube version: memory maps and protocol (the dumb host)

The 6502 Second Processor version of the full Master port (`tube/build.sh`).
TUBE-PLAN.md is the plan, TUBE-REPORT.md (untracked) the report with the
numbers, DUMB-HOST-AUDIT.md the audit that this layout follows.

One disc, `tube/build/elite-tube.ssd`, for either host: a BBC Master, or a
BBC Micro Model B with 64K of sideways RAM, with a 6502 Second Processor
attached (on the Master, its internal co-processor will do). SHIFT+BREAK.

## The disc

`tube/src/disc.asm`; `tube/tools/discbudget.py` prints its catalogue and
room (tube/build.sh, at the end). An 80-track single-sided
DFS disc holds 800 sectors of 256 bytes (the catalogue takes 2) and 31
files.

| File | Sectors | Holds |
|---|---:|---|
| !BOOT | 1 | `*RUN ELITE` (beebasm's -boot) |
| ELITE | 1 | the boot (tube/src/boot.asm, 44 bytes at &0900): OSBYTE 0's MOS version, 3 or more on a Master (3.20, 3.50; 4 the ET, 5 the Compact), 1 on a Model B (2 the B+); `*RUN ELITEM` or `*RUN ELITEB` |
| ELITEM | 6 | the Master host's loader (tube/src/loader.asm, &2700, entered at &2755: above the kernel's code, which it copies to &0E00): checks the Tube (OSBYTE &EA) and sideways RAM in banks 4-7, draws Saturn, loads its files (below) and puts each into place, loads PCODE, starts the parasite |
| ELITEB | 3 | the Model B host's loader (tube/src/loader-b.asm, &1900): checks the Tube, finds the first four sideways RAM slots (banks 4-7), loads its files to &1C00, patches the bank numbers into the host's images and copies each into place, loads PCODE, starts the parasite |
| HOVD, HCODE, HOVS | 133 | plain images: overlay D's stored image (41 pages: the Master's loader deals it into the STA runs' pages' tails, the Model B's copies it to bank 5), the Master host's code (bank 7 from &9400), overlay S's stored image (55 pages: on the Master main RAM from &2D00 and at &7000, then bank 7 below its code; on the Model B bank 6) |
| BDATA | 15 | the dashboard's image, both hosts' (the Master's loader copies it to shadow &7000, the Model B's to &7000) |
| HBK, HBC, HBE | 77 | the Model B host's own files, plain images: its span kernel (bank 4 from &B000), its code bank (bank 7, the whole of it: the code, the tokens, and the host's image of &0E00-&10FF in DFS's place), its persistent block (&7E00) |
| PCODE | 199 | the parasite's code, both hosts' (one build, `_HOSTB` FALSE: nothing in the parasite depends on the host) |
| HMAIN | 27 | the Master host's main RAM: CHPR's font, then the kernel's code (&0E00) |

464 of 800 sectors, 13 of 31 files: 336 sectors and 18 files free for saved
commanders. The files are in the order the loaders read them: the Master's
reads HOVD, HCODE, HOVS, BDATA, then (past the Model B's files) HMAIN and
PCODE; the Model B's reads HOVD, HOVS (past HCODE), BDATA, its own files
and PCODE.

A host that cannot run the game stops with a message in mode 7, never a
hang: no second processor ("This ELITE needs a 6502 co-processor:
*CONFIGURE TUBE, then SHIFT+BREAK." on a Master, "This ELITE needs a 6502
Second Processor." on a Model B), a Master whose banks 4-7 are not all RAM
(which bank, and the links to set), a Model B with fewer than four sideways
RAM slots ("This ELITE needs 64K of sideways RAM (four 16K banks).").
tube/tools/tloadcmp.mjs boots these cases (`--notube`, `--swram none`).

### Generated, not carried

The Master host's STA runs (h-sta.asm: 37.6K of `STA abs` in banks 4, 5
and 6) are written by hstart's s_gen at the host's start and are never on
the disc: the loader deals HOVD into their pages' tails, bytes 192-255, 64
bytes at a time (LDD), before s_gen writes the runs around them, so the
run banks need no image of their own. Every other file is a plain image
that the loader copies into place (FTAB: HCODE to bank 7, HOVS in three
parts, BDATA to shadow &7000, HMAIN's kernel to &0E00). The Model B host's
row runs (48 pages of bank 4, a set per buffer) are written by hstart's
s_gen too (r_rgen, hb-kernel.asm); its files are plain images, into which
its loader patches the bank numbers at offsets the build lists.

## The rule

The host only draws what the parasite tells it to: lines, points, spans, text
and the panel; it does the I/O (keys, sound, disc commands, vsync and the
buffer flip); and it stores the parasite's overlay images and gives them back.
It keeps no state about what the screen holds. Everything that decides what
to draw is on the parasite: the frame layer, the rasteriser's bookkeeping
(the disc layer with its repair, the discs drawn as changes and the heap
that remembers them, the dirty extents, phase B's rows, the star records'
scheduling), the planet's surface (the circle engine, its styles, the
ring), the lens flare's geometry and the pixels its probes would read, the
sights, and the text map with its diff against what each buffer shows.

## The parasite (65C02, 3 MHz, flat 64K) — both hosts

One image, PCODE, for both hosts: nothing in the parasite depends on the
host. tube/src/p-layout.asm lays it out; the figures below are from the
build (tube/build/compile-p.txt, psyms.txt; tube/tools/pmap.py writes the
whole map as JSON).

### The rules the layout follows

1. **Every place is a pass.** A source file is one file wherever its
   blocks go. The game's source (elite-source.asm, elite-data.asm) is
   placed by its headers' `Tube:` fields; the renderer's files and the
   Tube's own p-*.asm by `Area:` tag lines (a block runs from its tag line
   to the next): `frame` (the file's own place, the resident code; lines
   before the first tag are the file's own place's too), `ovl S`, `ovl D`,
   `page FE`, `page FF` and `boot`. tools/streams.py writes a copy of each
   file for each place, the other lines blanked (build/FILE-frame.asm,
   -ovls, -ovld, -fe, -ff, -boot), and p-layout.asm includes each copy at
   its place, as the Master port's layout includes its low, hot and cold
   passes. The one pair of files not joined is the Master port's own
   gfx-raster_poly.asm and gfx-raster_polyb.asm (R_POLY's phase A, from
   r_e8 in the second): the Master port and both hosts assemble them too,
   with places of their own, so one file's tags could not say both where
   the parasite puts each part (overlay S, resident) and where the hosts
   do; p-poly.asm includes the first in its overlay S block and the
   second in its own place's.
2. **Written memory is one run from &0000.** Zero page, the stack, QSL in
   pages 2 and 3, the game's workspaces (K%, WP) at the Master port's
   addresses, then from WP's end the Tube's workspace (p-ws.asm) in one
   run. Nothing in it is loaded: p_boot makes QSL and zeroes the Tube's
   workspace.
3. **The resident code and data are one run**, from where the workspace
   ends (CODE%, which p-layout.asm asserts) to the overlay region: the
   glue, the game's run in the source's order, the game data, the frame
   layer with the resident parts of overlay S's files and F_INIT; then the
   one gap; then the page aligned tables (log, logL, alogh, QSH: the
   game's blocks tagged `Tube: bothb, aligned`, a pass of their own),
   ending where the overlay region starts, a page. Nothing is padded.
4. **An overlay's state lives with the overlay.** Overlay S's state (13
   pages) is the start of S; overlay D's ZPSAVE (getzp's buffer) is above
   D's pages in the region.
5. **The top belongs to the Tube.** The two pages round its registers
   (&FEF0-&FEFF) and the vectors hold only the interrupt path: pirq's
   unrolled sends (pbl, within one page) and p_crash below the registers,
   pirq in page &FF. They are the client OS's until p_boot copies them in.
6. **The build checks the map.** Besides p-layout.asm's ASSERTs (the
   overlays and the boot's staging below the ring, the ring's four pages
   below the top pages, pbl within a page, the top pages clear of the
   registers and the vectors), tube/build.sh fails if any byte the
   listing assembles is outside the place its pass names, if the places
   are out of order or overlap, or if a pass copy that assembles anything
   is included by no assembly.

### The map

| Region | Addresses | Holds | Free |
|---|---|---|---:|
| Zero page, stack | &0000-&01FF | the game's zero page (to &E3); &E4-&F8 p-rast.asm's pointers and scratch (overlay S's); &FA-&FF the ring's pointers; the stack | 1 (&F9) |
| QSL | &0200-&03FF | the quarter squares' low bytes (elite-qs.asm; QSH is with the aligned tables), made by p_boot | 0 |
| The game's workspaces | &0400-&0CD0 | K% (&0400-&05BB), the ship line heap, WP (&0841-&0CCE) and VEC, at the Master port's addresses | 0 |
| The Tube's workspace | &0CD1-&1B33 | p-ws.asm, one run: PACC (the dummy ACCCON byte, VIA + &34: the one SHEILA byte Master's code still writes); the disc heap's flags and counts, the flare's probes, R_POLY's scratch; the frame layer's inputs (the polygon and line inputs, the stars, the text map's row counts, scratch; F_DCOL); from &0E00 the row arrays R_NDISCL, R_NDX0, R_NDX1, R_NDN (page aligned); F_HW and F_HW2 (&1100, &1200) and the text map F_TM (&1300); R_NDISCR (&1600, within its page), R_NDX2, R_NDX3; S_SUN's and the second disc's places, the discs' and kept rows' scratch; the frame layer's small state (F_BX, F_BY, f_tcol, f_zsv, F_SLV); F_SR; the ship records F_RP; the stars drawn directly (F_DSX, F_DSY). No padding | 0 |
| Resident code | &1B34-&B0AE | the glue (p-low.asm, &1B34: the stubs into overlay D, the shared variables, the G_ stubs and text hooks, the hooks in Elite's drawing, the Tube's I/O, the overlay manager, the panel's game halves); the game's run (&254E: every block not tagged for overlay D, the hosts or the aligned pass, with a stub at the place of each routine of D that the run calls); the game data (&673E, not QQ18: the hosts keep the recursive tokens); the frame layer (&7B0E), then the resident parts of overlay S's files (the probes' helpers and hooks, the disc heap's drop and the surface's cold ends, R_POLY's phase A from r_e8, pk_line and T_KFRAME, the one-pass generator's vertex scan and 16-bit edges), F_INIT | - |
| Free | &B0AF-&B0FF | the resident code's one gap | 81 |
| Aligned tables | &B100-&B5FF | log, logL, alogh, QSH | 0 |
| Overlay region | &B600-&F9FF | overlay D or overlay S (below), 68 pages; above D at the boot, the boot's staging (p_start, p_boot, the top pages' images: &DEE6-&E145); in direct mode ZPSAVE (&EF90-&EFFF) | (below) |
| The ring | &FA00-&FDFF | 4 pages, above both overlays and the boot's staging: the commands buffered while register 1 is full (p-io.asm; "The ring" below) | - |
| Below the registers | &FE00-&FEEF | pbl (pirq's unrolled sends, in this page as pirq patches a low byte), p_crash and p_nmi | 78 |
| Tube registers | &FEF0-&FEFF | the guard and the registers (&FEF8-&FEFF) | - |
| Page &FF | &FF00-&FFF9 | pirq, the ring's doorbell, with its state; then the vectors (NMI p_nmi, RESET p_start, IRQ and BRK pirq) | 5 |

The parasite's entry, p_start, is in the boot's staging area above overlay
D, as p_boot is: the loader loads PCODE (CODE% to the staging's end) and
starts it through the client OS's Tube code, which is at &F800-&FFFF until
p_boot copies the top pages in over it; F_INIT, p_start's last call, loads
S over the staging and returns straight to S%. The first load of S also
covers &F800-&F9FF, the client OS's first two pages, which the game never
uses again.

### The overlays (tube/src/p-ovl.asm)

| Overlay | Size | Free | Holds |
|---|---|---|---|
| D (direct mode) | 10,470 bytes, &B600-&DEE5 | 6,938 (less ZPSAVE's 112 at &EF90) | the code that runs only on the screens drawn directly or while docked (the blocks tagged "Tube: ovl D", "both, ovl D" or "bothb, ovl D" in their headers: the charts, the market, equipment, the status and disc screens, the title, the briefings' text, the default commander; and the parts of resident routines that the space view never runs, each a block of its own: TT26's justified paragraphs (DA1), CLYNS, TT17's cursor keys (TT17afterall), T95 on a chart (T95D), HLOIN3, PIXEL's drawing (PIXELD), TT217 and NEWBRK, DOENTRY's wait and missions after the hangar (DOENTRYM, EN1), BR1's start of the game after the title screens (BR1S), ESCAPE's replacement ship after its frames (ES2), BRIEF's start before its frames (BRIEF, reached by povdj), the launch and hyperspace tunnels (LAUN, HFS2 and its rings, HFS1), the chart's home key (ping), TT110's launch (TT110L), BAY, BRIS, TT170, TT67K, the boot's DEEOR, COLD, setzp, SETINTS and SOFLUSH), CHPR's glyph drawing RREN and deletion RRDEL with ZES2 (which the parasite never runs, as H_CHAR and H_DEL leave CHPR before them, but which its resident CHPR falls into in the source's order), the Tube halves of these (p_hloin, p_pixel, p_clyns, p_soflush, G_CLRTEXT, H_CLYNS, F_CLRTEXT, F_HANG0, and the hangar's frame F_HANGAR: the files' "Area: ovl D" passes), and the text drawn directly: pchr (H_CHAR's and H_DEL's C_CHAR to the host) and F_CHAR's noting of it (fch_dd), each behind a stub of its own name in the resident code (pchr, fch_d), as the screens drawn directly are the only ones that reach them, with the extended tokens they print. None of it runs in the space view (tube/tools/tswap.mjs: no swap within the space view over run1), and none of it is on the stack for a sequence of frames: the rotating ships of the title (TITLE), the briefing (BRL1, PAS1, PAUSE) and the escape pod (ESCAPE to ESL1) are resident, and LL9B hides the calls into D on the stack for its frame (ovl_dn 0: what follows PAUSE's frames in D loads D through MT23's stub), so a frame never loads D back while the ship turns (tube/tools/tdock.mjs: no load between two frames) |
| S (space mode) | 17,330 bytes, &B600-&F9B1 | 78 | its state first (3,328 bytes, 13 pages: the rasteriser's, p-rast.asm, with the disc heap), then the rasteriser's bookkeeping (the disc layer, the dirty extents, the star records' relay, the 16-bit polygons' rows), the discs drawn as changes (p-disc.asm), the polygons' row streams (p-emit.asm), the kept solid rows (p-kept.asm), R_POLY (p-poly.asm, p-onepass.asm), the text overlay and the sights (gfx-frame.asm's "Area: ovl S" blocks), the lens flare (gfx-flare.asm) and its probes (p-probe.asm), the hangar's rectangles (gfx-hangar.asm's fh_rect, for f_hback in F_FRAME), the planet's surface: the circle engine (gfx-merid.asm) and its styles, the beach ball, craters and bands, the ring's dots (gfx-planet7.asm), one image for every planet; last, r_lost (p-lost.asm: the state rebuilt after S went out in space mode) |

Code outside an overlay calls into D through stubs that streams.py writes at
the routines' places (`JSR povd : EQUW target`; povdj for the routines that
never return); povd loads D if it is out, and loads back the overlay that was
in when the target returns, if that one has routines on the stack (ovl_dact
scans the stack). F_FRAME and F_INIT load S. S's state is never kept: the
hosts keep S's image from the state's end, and when S comes back the state
is rebuilt. If S went out in space mode (a call into D during flight: the
charts, TT18), nothing is known of either
buffer, and r_lost (p-rast.asm) marks it all unknown: in each buffer every
row inside the border dirty from the window's left to its right (2-253),
no disc rows, no second disc, no kept rows, the disc heap empty (the
surface's rows start unknown) and nothing written. Each buffer's next frame
then blacks the play area (the repair, or the disc layer's black on the
dirty extent) and draws the frame over it; the text and the sights, which
are redrawn where a frame writes, come back over that: the Master port's
pixels. The text map, the star records (the host's) and the stars' relay
are resident, untouched. If S went out in direct mode, the next space-mode
frame starts buffer 0 afresh (GSTASH, f_b0new), as after a disc command.

A load is the overlay's whole pages through register 4, only on a change
between the space view and a screen drawn directly: 13 loads of D and 13 of
S in iterations 0-16002 of run1 (as the original with the planet's half
steps plays it), none within the space view (tswap.mjs, a gate in
tgate.sh). Everything the space view runs is resident or in S: SUN's part 3
and EDGES (the sun on screen: run1 3975-4325), FRS1 (a missile fired), tnpr1 and tnpr (cargo
scooped), TT147 and prq (hyp's "range?" with too little fuel), ESCAPE to the end
of its frames. The calls into D from flight all leave the space view: the
charts, TT18 (the hyperspace tunnel), ES2 after ESCAPE's frames (to the
hangar), and DEATH's canisters (fq1) after its TT66. On the docked
screens, tdock.mjs's briefings, debriefings and escape pod load D or S
only between the text and the frames: 5 loads of D and 4 of S in the
Constrictor briefing, 2 and 1 in each other mission's screens and the
escape pod's.

### The discs (p-disc.asm, p-rast.asm)

Every disc is drawn as changes. The disc layer (the planet or the sun, in
front) keeps, per buffer, each row's span (R_DISCL, R_DISCR); with surface
detail (two colours: beach ball, craters, bands) the disc heap keeps each
row's n (twice its boundary count plus its left colour, R_NDN rotated left:
a nibble per buffer of one shared byte, through a 7-byte table each, no
shifts) and its first two boundaries. One loop (ps_rows, as the Master
port's r_dbm) takes the band's rows: an unchanged row costs a few compares;
a changed row with the same count and colour is sent as the strips its
edges (ends and boundaries) moved through, each cut short where a
neighbour's new place has passed into it (the Master port's design:
straight-line for 0, 1 or 2 boundaries, in any order of the strips), any
other segment by segment (on the parasite, where a strip costs a span as a
segment does, the Master's virtual boundaries for a count or colour that
changed cost more than the spans they save). The second disc (the sun round the planet, f_disc2) keeps its spans in
the heap too and sends only what changed against them and against what
this frame wrote over it. The heap (HEAPN bytes in S's state) is one block
partitioned by size: the surface's arrays grow from its start, the second
disc's from its end, each window sliding and growing into the room between;
only when both cannot fit are both dropped and the heap partitioned again
(hp_drops: none in run1 or the bench scenes, tube/tools/tscenes.sh), and a
body that cannot fit alone is drawn whole that frame (hp_whole: none). The
moon, the sun and the planet are never all large at once: the heap holds the
surface's 192 rows and a second disc of 100 rows.

### The lens flare's probes (p-probe.asm)

The Master port's R_FLARE reads nine pixels of the back buffer to see how
much of the sun is in sight; the parasite has no screen, so it works the
pixels out: after the discs, R_FLARE runs once in arming mode (the probes'
places), each pixel starts as the discs left it (or the sights' colour, on
an arm of the sights drawn in this buffer that nothing written this frame
covers), and the polygons' rows (p_emit) and dots (R_DOT) drawn before the
flare update it. Not followed: the lines drawn before the flare (a pixel
wide), and a sights pixel inside a row's written extent that the row's
writes went round (counted as written).

### Kept solid rows (p-kept.asm)

full-master's kept solid rows (SOLIDSPAN-REPORT.md), all on the parasite: in
K mode (a space station recorded close by, T_KFRAME), a row whose last
drawing in a buffer's frame was one polygon span covering its dirty extent
is left on screen by the next repair of that buffer (pending), and the next
polygon span on it sends only what changed: nothing if the span and colour
are the same, else black for the old pixels outside the new span (after the
polygon's stream) and of the new span what the row lacks. The state lives in
the buffer's disc span arrays, which a kept row (never a disc row) does not
use: kept is R_DISCL 255 with the colour byte in R_DISCR; pending is R_DISCL
0. The host sees only fewer spans.

Page alignment is kept only where it buys cycles or is required, and costs
no padding: in the workspace, R_NDISCL (the disc layer indexes it from its
page), R_NDISCR within one page (f_discspans' symmetric loop), F_HW and
F_HW2 (the disc rows index them by row across no page) and the text map,
each starting where the declarations before it end (p-ws.asm asserts it);
the log tables and QSH (FMLTU's and the multiplications' operands' low
byte is the argument), ending at the overlay region; QSL in pages 2-3; the
lens flare's fl_htab (gfx-flare.asm: within a page); pbl (page &FE); the
overlay region and the ring (whole pages: the overlays travel by pages, the
ring's pointers step by pages).

## The protocol (tube/src/cmds.asm)

Commands go through register 1 (the parasite polls its room bit, or
buffers in the ring: above; the host's loop polls its data bit, ringing the
parasite's doorbell while it is empty): an even opcode, which the host dispatches through a
table, then the operands. Requests go through register 4 (preq4), which the
host's IRQ answers at once, through register 4; nothing goes through
register 2.

| Group | Commands |
|---|---|
| Frame | C_BUF b (wait for the last flip, then draw into buffer b), C_FLIP (show it at the next vsync), C_ENTERB (space mode: buffer 1's border to buffer 0), C_CLRBUF b, C_DIRECTD (direct mode: shadow RAM on show), C_INIT, C_SYNC (the end of an iteration: the harness's frame marker) |
| Spans | C_SPAN (Y, XL, XR, COLE, COLO), C_DSPANS (the disc layer, sent as made: the first row, then XL, XR and the row's colour byte (COLE even rows, COLO odd) for each span; after a row's spans 0 for the next row's, else &FF and the row; &FF 0 at the end. Rows are 1-191 and XL 2-253, inside the clip window, so neither 0 nor &FF is a row or an XL), C_SPANS (a polygon's rows, sent as made: the four colours and the first row, then left and right (exclusive) for each row, (1, 1) for a row with no pixels, &FF at the end but after row 191; phase B's fill reads them as it goes), C_ORSPAN (the lens flare: OR a mask over a span) |
| Lines and points | C_LINE (four colours, two 16-bit points), C_DOT (two colours, x, y, size), C_STARS (plot on black only; the host keeps the records), C_STARERASE (black the records' pixels), C_EORDOT (EOR a directly drawn star away); the direct-mode screen: C_LOIN, C_HLOIN, C_PIXEL (Master's LOINQ, HLOIN3, PIXEL) |
| Text | C_GLYPH (a cell: character, column, row; space mode), C_CHAR (CHPR, direct mode), C_CLS, C_BOXC, C_CLYNS |
| Panel | C_PDIALS (the dials' inputs), C_PDOT (the compass), C_PSCAN (a ship on the scanner), C_PMSBAR (a missile), C_PBULB (a bulb) |
| I/O | C_DET1 (6845 R6), C_OSCLI (a disc command: the host's MOS runs it) |
| Requests (register 4, answered by the host's IRQ) | C_KEYS (the keys held), C_DKS (one key), C_WSCAN (the next vsync), C_IRB (port B), C_NOISE, C_SOFLUSH, C_TOKEN n (recursive token n's bytes as QQ18 stores them, its null included: elite-source.asm's ex prints them from TBUF with the original loop) |
| Storage | C_OVLGET n (request: overlay n's pages) |

The opcodes of the commands the dumb host no longer has (the frame begin and
end, the disc layer's state, dirty marks, the polygon's phase A rows, the
flare, Master's byte writes, the meridian window, the text map) are retired
(h_bad), as are the requests' entries in the command table (C_KEYS, C_DKS,
C_WSCAN, C_NOISE, C_SOFLUSH, C_IRB: register 4's only).

### The ring (p-io.asm)

The parasite buffers the stream so that the game's next iteration overlaps
the host's drawing of this one. A send that finds register 1 full puts its
byte into the ring, and so does every send after it (ring mode) until the
ring is empty: ppring makes ptx's and the eleven inline send sites' (psb in
p-rast.asm, p-emit.asm) `BIT PR1S` a `JMP` to their ring stubs (`STA (rq)`,
`DEC rq`, 19 cycles a byte at an inline site). The ring drains in the parasite's IRQ (pirq,
the &FFFE vector; a BRK still goes to p_crash): the host rings a doorbell
(any byte through register 1, host to parasite; the Tube's I flag on, J
off: htflags) whenever it finds register 1 empty, in hloop and in every HRX
(hrw: the Master host's main RAM; the Model B host's &7E00 block), and the IRQ
sends up to 23 bytes without checking for room (unrolled, about 16 cycles a
byte with the IRQ's own cost), taking the doorbell last. Interrupts are on
only in ring mode; the IRQ that finds the ring empty leaves ring mode
(unless it came in on a stub) and returns with them off. The stubs leave
the I flag alone: penq turns interrupts on as it enters ring mode, pfwait
leaves them on in ring mode, and p_sync clears the I flag in the flags that
hframe pushed with them off, so that its PLP does not turn them off in ring
mode.

* Pages are written and read downwards, 255 to 1; a write pointer with a
  low byte of 0 is a stub between its DEC and rpg (the next page's 255).
* rq (&FA, &FB) is the write pointer; the IRQ reads through (&FE) with
  rpl, rph. p_oscli's pointer moved from &FA to &FC.
* pflush empties the ring by polling, before C_OVLGET and C_DISC
  (ovl_need, ovl_get, p_oscli): their answers come behind the stream.
  The register 4 requests (keys, DKS, port B, WSCAN, sound) need no flush.
* p_buf (C_BUF) waits until no byte from before the C_BUF two frames back
  is still in the ring (pfwait): at most two frames queued.
* A full ring waits (rpg) with interrupts on; if a doorbell is seen with no
  IRQ (the I flag off), it sends by polling (ppump).

## The Master host

The Master port's display side: buffer 0 in main RAM &4000-&6FFF, buffer 1
in shadow RAM at the same addresses (ACCCON X), the dashboard in shadow
&7000. 65C12 code. tube/src/h-layout.asm lays it out; the figures below are
from the build (tube/build/compile-h.txt, hsyms.txt).

Below &2B00, the kernel; at the top of bank 7, the host's code; banks 4, 5
and 6, the 192 STA runs in line order. Every other byte the host uses is a
stored page of an overlay, in address order. HAZEL is the MOS's, and ANDY
is spare.

### The rules the layout follows

1. **The kernel is below &3000.** Whatever an interrupt, a MOS vector or
   code with its bank paged out can reach lives in main RAM below &3000,
   where every bank and either setting of ACCCON X sees it: the IRQ (h4irq,
   IRQ1, the sound), WRCHV's hwrch and CHPR, BRKV's hdbrk, the command loop,
   the requests and the recursive tokens they send, the storage reader, and
   the span kernel, which pages a line's bank in to enter its run. Its code
   runs up from &0E00 and its workspace down from the disc commands'
   buffers, with the one free gap between them; above the buffers is the
   first of overlay S's pages (h-layout.asm asserts that the workspace
   ends at the buffers, the code below it, the buffers below S).
2. **One code bank.** Bank 7 (GFXBANK) is paged whenever the host runs
   outside a run. All host code that is not the kernel is there, in one run
   from &9400, and calls itself and the kernel with JSR. Only the kernel
   pages, and only a line's bank in and bank 7 back (hbank, s_gen, s_clr,
   h_ovlget); &F4 holds 7, written with ROMSEL only where the MOS may have
   left another bank (hwrch, hstart, hdbrk, h_disc's return).
3. **The runs are addressed by line.** Line L's run starts page &80 + L
   MOD 64 of bank 4 + L DIV 64; r_rowset still reads the page and the bank
   from s_pg and s_bk, two tables of 192 made by FOR loops. Phase B stops
   at r_yend, which r_pcbs sets to R_ROWS (192), before it reads a row's
   page and bank: line 192 would be page &80 of bank 7, a stored page
   (h-sta.asm asserts that the last line's run is in bank 6).
4. **A tail has one tenant.** Bytes 192 to 255 of line q's page hold
   quarter q of overlay D: D's page p is quarters 4p to 4p+3, four
   consecutive run pages in one bank. s_gen writes bytes 0 to 189, and the
   RTS that r_spc and phase B plant never leaves them. D's 41 pages take
   the tails of lines 0-163 (h-layout.asm asserts that D fits in 192).
5. **Hidden RAM only stores, in order.** Main RAM that ACCCON X hides
   (&3000-&3FFF, &7000-&7FFF) holds stored pages only: nothing there runs or
   is read while drawing. Overlay S's pages rise with the address: main RAM
   from &2D00, then &7000-&7FFF, then bank 7 below the code (h-layout.asm
   asserts that the three extents hold S's 55 pages exactly).
6. **What is not ours stays untouched.** HAZEL (ACCCON Y is never set: the
   MOS and DFS keep it, and a disc command needs no stash), page &0D but
   for HNMI's minimal NMI handler, and shadow RAM outside the screen and the
   panel. Every ROMSEL write is a plain 4 to 7: bit 7, ANDY, is never set.
7. **The source stays where it is.** The rasteriser's blocks tagged
   `Area: kernel` (streams.py's passes) are the span kernel, and the one
   tagged `Area: kernel, aligned` (the per-x tables) its first pages; the
   rest of each file is its own place's pass, in bank 7, whose first pages
   are the game's aligned tables (log, logL, alogh: their own pass,
   build/elite-source-hostba.asm). An aligned pass first where a page
   starts needs no padding, and nothing before it must end on a page. Of the renderer's shared
   workspace (elite-gfx.asm) the kernel declares only what the host's code
   names (h-layout.asm's `HWS` lines: tube/build.sh writes build/h-ws.asm
   from them); a name the host's code uses that is not listed fails the
   assembly.

### The map

| Region | Addresses | Purpose | Free |
|---|---|---|---:|
| Zero page and stack | &0000-&00FF, &0100-&01FF | the game's zero page (build/elite-source-ws.asm), where the host's copies of the game's drawing code keep their variables, as the parasite does (the commands carry the values); &E4-&E5 hsp; the rasteriser's zero page &06-&27. The game's other workspaces (K%, WP) have names on the host only because it assembles the game's drawing and panel blocks against the game's definitions: it stores nothing there (K%'s first pages are the font's), and the build fails on an instruction of the host's that names &0700-&0CFF, or page &0D outside HNMI | - |
| Font | main &0400-&06FF | CHPR's font (FONT%, h-layout.asm's HFONT), the three pages the MOS's Tube code leaves after the boot (hstart clears &027A, so the MOS never calls it again): the loader puts the font in buffer 0 (HFONTST, &4000) with HMAIN, and hstart moves it here | 0 |
| Kernel: code | main &0E00-&2492 | the per-x tables r_xo, r_jm, r_lm, r_rm (&0E00-&11FF, first, as the kernel's first page is aligned: the rasteriser's block tagged `Area: kernel, aligned`); the span kernel (r_rowset at &1200, r_spc, R_SPAN, phase B from &12D5, r_dspin at &14A0: in this order r_spc's and r_dspin's loops cross no page); the renderer's shared variables (gfx-gvars.asm, &14EC); the command loop (h-main.asm from hwrch, &14F2: the handlers that enter the runs, the storage reader h_ovlget, hbank, the requests h4body and the IRQ's h4irq); s_pg and s_bk, s_gen, s_clr (&1A74-&1C8E: h-sta.asm); the game's host blocks (the sound, IRQ1 at &1DCA, CHPR at &1E32, UP); the text and IRQ hooks (gfx-gluehooks.asm); the recursive tokens (QQ18 as stored and where each starts, &1FA9-&2492), which C_TOKEN reads in the IRQ. No padding | - |
| Free | main &2493-&2744 | the kernel's room, between its code and its workspace (at the boot, the loader runs at &2700-&2C3D, above the code it copies and below overlay S's first page: the loader asserts both) | 690 |
| Kernel: workspace | main &2745-&2AFF | one run ending below the disc buffers: f_enter's buffers F_HW and F_HW2 and f_unstar's F_DSX and F_DSY (&2745-&296E); of the renderer's shared workspace, R_X0 ... R_Y1, R_COL2, R_COL3, R_PYS, R_PYE, R_SS, R_SX, R_SY, R_SN, R_SCOL and F_DSS (&296F-&29D0); the panel's variables of WP (HWP, &29D1-&29FF: SWAP, JOPOS, DASHV ... dstab and the dials' and the compass's inputs dQQ14 ... dCOMY, which the game's workspace puts here for the Master host, as it puts them at the Model B host's HWP, in bank 7); ylookup (&2A00, a page: the page of each pixel row's character row, hstart's, for the game's drawing and the rasteriser, as r_ypg). No padding | - |
| Disc buffers | main &2B00-&2CFF | HDSTR (&2B00), HDERR (&2B80) and HDBUF (&2C00, cmds.asm's: savosc and lodosc name it) for h_disc | - |
| Stored: S 0-18 | main &2D00-&3FFF (ACCCON X clear) | 19 pages of overlay S: the kernel's room's last three, then main RAM under shadow &3000-&3FFF | 0 |
| Buffer 0 | main &4000-&6FFF | the screen; at the boot, also the loader's copy of HMAIN (the font, then the kernel's code) | - |
| Stored: S 19-34 | main &7000-&7FFF (ACCCON X clear) | 16 pages of overlay S, under the panel | 0 |
| ANDY | &8000-&8FFF | nothing: the reserve for overlay D or the host's code to grow | 4096 |
| Runs 0-63 | bank 4 &8000-&BFFF | line L's STA run at page &80 + L, bytes 0-189 (s_gen's); bytes 192-255: D's quarters 0-63 (pages 0-15) | 0 |
| Runs 64-127 | bank 5 &8000-&BFFF | lines 64-127; D's quarters 64-127 (pages 16-31) | 0 |
| Runs 128-191 | bank 6 &8000-&BFFF | lines 128-191; D's quarters 128-163 (pages 32-40), then 28 tails free | 1792 (28 tails of 64 bytes) |
| Stored: S 35-54 | bank 7 &8000-&93FF | 20 pages of overlay S at the bank's bottom, a fixed place whatever the code's size | 0 |
| Host code | bank 7 &9400-&B6A2 | one run: log, logL, alogh (&9400-&96FF, first, as the bank's first page is aligned: the blocks tagged "Tube: bothb, aligned", build/elite-source-hostba.asm); R_LINE and its loops (gfx-raster_line.asm, &9700); the panel's drawing (the blocks tagged "Tube: hostb": SCAND, HLOIN, PIXEL, DOT, the bulbs, MSBAR, DIALS, DSEG, &9BCC); the frame layer's host part (gfx-frame.asm and gfx-frame_cold.asm: F_BACK, f_direct0, f_enter, f_glyph, f_b0new, f_unstar, &A8EF); the rarely run code (h-cold.asm: hstart, h_disc, HNMI); the panel's and the drawing primitives' handlers (h-panel.asm, h-prim.asm); the rasteriser's own place (gfx-raster.asm: R_SETBUF, the star records r_s0y ... r_s1b, r_pclip, r_pset, R_LINE's variables, R_DOT, R_STARERASE, R_STARPLOT, from &B08F; gfx-raster_lcold.asm: the lines' cold part and the rasteriser's private state, of which the hosts keep R_PRBUF and R_PRSCNT); phase B's set-up (r_pcbs, &B65A) | 2397 |
| HAZEL | &C000-&DFFF | the MOS's and its filing systems': nothing of the host's | - |
| Buffer 1, panel | shadow &4000-&7DFF | the screen and the dashboard | - |
| Shadow &3000-&3FFF, &7E00-&7FFF | | unused | 4608 |

Overlay D has 48 pages of tails for its 41; overlay S has 55 pages for its
55, which is also S's ceiling on the parasite (the overlay region less its
13 pages of state), so it needs no room to grow. ANDY is the reserve for D
and for the host's code.

The loader (tube/src/loader.asm) runs at &2700-&2C3D, in the kernel's
free room, workspace and disc buffers, where nothing is loaded. It loads
HOVD to buffer 0 (&4000) and deals it into the tails, quarter q to line
q's page (LDD); then (FTAB) HCODE, loaded to &4000 and copied to bank 7
from &9400; HOVS, loaded to &4000 and copied in three parts, bank 7's and
&7000's first, as the image covers &7000-&76FF and its first part goes to
&2D00; BDATA, loaded to &0E00 (below &3000, as it is copied to shadow
&7000 with ACCCON X set); HMAIN, loaded to &4000, whose kernel part it
copies to &0E00, last, leaving the font for hstart. Then it loads PCODE into the parasite and
starts it through the MOS's Tube code, which passes the parasite's first
byte, &FE, to hwrch: hstart pages bank 7, moves the font to &0400, makes
ylookup and the STA runs (s_gen), and the command loop begins.

### The storage

C_OVLGET n is answered from the storage by h_ovlget, in the kernel, with
the rules above and no table of pages: D's page p from the tails of lines 4p
to 4p+3 (bank 4 + p DIV 16, pages &80 + 4 (p MOD 16) on, 64 bytes from each,
the banks paged in turn and bank 7 back); S's pages from its three extents
(a 6-byte table of first pages and counts), main RAM with ACCCON X clear,
then bank 7's, which is paged. tube/build.sh writes build/hstore.bin, the
storage page by page, for tube/tools/tstore.mjs.

## The Model B host (64K sideways RAM)

A BBC Micro Model B with four 16K sideways RAM banks and no shadow RAM,
ANDY or HAZEL: buffer 0 &1000-&3FFF, buffer 1 &4000-&6FFF (the Master
port's address, so direct mode is unchanged) and the panel &7000-&7DFF
all take main RAM, split by a CRTC vertical rupture. NMOS code made from
the same sources (tube/tools/nmos.py, with tools/longbr.py for branches
the longer code puts out of range), behind `_HOSTB` where it must differ
(no ACCCON; the screen base; the banks). tube/src/hb-layout.asm lays it
out, the Master host's h-layout.asm again where the hardware allows; the
figures below are from the build (tube/build/compile-hb.txt, hbmsyms.txt,
and hbksyms.txt for the span kernel's names).

Four banks, four jobs, numbered as on the Master host: bank 4 the row runs
and the span kernel, bank 5 overlay D, bank 6 overlay S, bank 7 all other
host code. In main RAM the host has three places, each for one reason, and
leaves the MOS's own alone.

### The rules the layout follows

1. **Four banks, four jobs.** Banks 4 to 7 are the first four sideways RAM
   slots the loader finds; it patches their numbers into the host's images
   at the offsets the build lists (assembled again with the banks at 8-11,
   build/hb-patch.asm). Bank 4 holds the runs and the code that enters
   them, bank 5 overlay D, bank 6 overlay S, bank 7 everything else.
2. **Bank 7 is the resting bank.** It is paged whenever the host runs
   outside bank 4. The command loop, every handler, the interrupts' bodies,
   the lines, dots and stars, the panel and the text are one run from
   &8000, after the aligned tables (log, logL, alogh, then the per-x
   tables' second copy), in the Master host's order (what the Master keeps
   in its kernel, then what it keeps in bank 7), with their private tables
   and the recursive tokens after it, and calls itself with JSR.
3. **The runs are addressed by row.** The run for character row r of
   buffer b starts page &80 + 24b + r of bank 4: 63 `STA abs,Y` (Y the
   pixel row), an RTS and the 'nothing planted' target, bytes 0-190;
   bytes 191-255 are empty. hstart makes them (s_gen, r_rgen); they are not
   on the disc. Only the span kernel enters a run, and it is in the same
   bank, so a span pages nothing; r_rowset and phase B read the run page
   from r_rpy0 or r_rpy1 (FOR loops), whichever R_SETBUF has pointed them
   at.
4. **One copy, with one exception.** No routine is assembled twice. The
   per-x tables r_xo, r_lm and r_rm are in bank 4 for the spans and in
   bank 7 for the lines, r_pset and the stars, both from the macros of
   gfx-raster_xtab.asm, so they cannot differ: no main RAM that both banks
   see could hold them. The span kernel (tube/src/hb-kernel.asm) is
   assembled in a scope of its own (its INCLUDEs flattened into
   build/nmos/hb-kernel.asm, as BeebAsm includes no file within braces)
   so that its copy can have the same names; the trampolines into it
   export theirs.
5. **Main RAM has three places.** &0400-&06FF: the font, as on the Master
   host, never swapped. &0E00-&0FFF: what both banks must see: ylookup,
   the storage reader, the trampolines into bank 4. &7E00-&7FFF: what must
   survive a disc command and be there whatever bank the MOS has paged.
6. **The MOS's memory is the MOS's.** Nothing of the host's is in
   &0236-&03FF, &0700-&0CFF or page &0D: tube/build.sh fails the build if
   an instruction of the host's has an absolute operand there, but for the
   MOS's variables it means to address (the Tube flag &027A, which hstart
   clears; the text cursor &0308 and &0318, hwpos's). The host borrows only
   DFS's workspace, &0E00-&10FF, which the screen forces it to (buffer 0
   starts at &1000), and gives it back for each disc command.
7. **One workspace.** Everything the host writes while it runs, and DFS's
   three pages while the game runs, is one run at the top of bank 7, as the
   Master host's workspace is one run at the top of its kernel: of the
   renderer's shared workspace only what the host's code names
   (hb-layout.asm's `HWS` lines; tube/build.sh writes build/hb-wsn.asm,
   and its length build/hb-wsc.asm), and the panel's variables of WP
   placed by HWP. The only such variables outside it are the span kernel's
   own (hb-kernel.asm's `HWSP` lines, build/hb-wsp.asm: phase B's colours
   and rows), which must be seen with bank 4 paged, and the persistent
   block's (hwrch's, the IRQ's, the rupture's), which must be seen with any
   bank paged. A name the host's code uses that is not listed fails the
   assembly.

### The map

| Region | Addresses | Holds | Used | Free |
|---|---|---|---:|---:|
| Zero page and stack | &0000-&01FF | the game's zero page (build/elite-source-ws.asm), as the Master host's; the rasteriser's &06-&27 | - | - |
| The MOS's | &0200-&03FF | the MOS's vectors and variables: IRQ1V = irqm, WRCHV = hwrch, BRKV = hdbrk during a disc command; nothing of the host's | - | - |
| Font | &0400-&06FF | CHPR's font (FONT%, HFONT), the pages of the MOS's Tube code, which runs the boot and then is never called again (hstart clears &027A): hstart moves it here from its first place in bank 7 (HFONTST) before anything prints | 768 | 0 |
| The MOS's | &0700-&0DFF | the MOS's buffers and page &0D: nothing of the host's (JOPOS, SWAP and the panel's variables are bank 7's, through HWP) | - | - |
| Low pages | &0E00-&0FA9 | ylookup (&0E00, a page: the page of each pixel row's character row, hstart's, for the game's drawing and the rasteriser, as r_ypg); the storage reader hb_ovlget (&0F00, hb-ovl.asm), which pages banks 5 and 6; the trampolines into bank 4 (&0F41, hb-res2.asm: tA, tback, T_SBRUNS, T_SPAN, s_gen, hb_poly, hb_dspans, hbloop). DFS's pages: exchanged, with &1000-&10FF, around a disc command | 426 | 86 |
| Buffer 0 | &1000-&3FFF | the screen. A disc command's buffers are at HDBUF - &100, HDBUF - &80 and HDBUF (&2B00 the command, &2B80 the error, &2C00 the sector buffer), by the Master host's definition | - | - |
| Buffer 1, panel | &4000-&7DFF | the screen and the dashboard (the loader copies BDATA to &7000) | - | - |
| Persistent block | &7E00-&7EEE | beyond the panel, never swapped (hb-res3.asm): hwrch (WRCHV), hdbrk, irqm (IRQ1V: register 4's requests, timer 1 and vsync are the host's, anything else the MOS's), hbi_t (the rupture's point 2 whole, point 1's way into bank 7), irq4, hrw; and their variables | 239 | 273 |
| Bank 4: buffer 0's runs | &8000-&97FF | rows 0-23, a page each (hstart's) | 24 pp | 24 tails of 65 |
| Bank 4: buffer 1's runs | &9800-&AFFF | rows 0-23 | 24 pp | 24 tails of 65 |
| Bank 4: span kernel | &B000-&BA25 | hb-kernel.asm in its scope: the per-x tables r_xo, r_jm, r_lm, r_rm (&B000-&B3FF, first: the rasteriser's block tagged `Area: kernel, aligned`); its variables R_COL2, R_COL3, R_PYS, R_PYE; the rasteriser's blocks tagged `Area: kernel` (r_rowset, r_sbruns, r_spc; R_SPAN; r_dspin); phase B's set-up and fill (gfx-raster_poly.asm and polyb, from r_pcbs at &B536); p_polyin; r_rpy0 (&B800) and r_rpy1 (&B900), each in a page of its own (145 bytes of padding); r_rgen. The loader copies HBK here | 2598 | 1498 |
| Bank 5: overlay D | &8000-&A8FF | D's 41 pages, the loader's copy of HOVD | 41 pp | 23 pp |
| Bank 6: overlay S | &8000-&B6FF | S's 55 pages from its state's end, the loader's copy of HOVS | 55 pp | 9 pp |
| Bank 7: code | &8000-&AD44 | one run (the loader copies HBC, the whole bank): log, logL, alogh (&8000-&82FF, first: the blocks tagged "Tube: bothb, aligned") and the second copy of the per-x tables r_xo, r_lm, r_rm (&8300-&85FF); the renderer's shared variables (gfx-gvars.asm), the command loop (h-main.asm), the interrupts' bodies (hb-irq.asm), the game's host blocks (the sound, CHPR, UP) and the text hooks (gfx-gluehooks.asm); the panel's drawing (the blocks tagged "Tube: hostb"); R_LINE (gfx-raster_line.asm and lineb); the frame layer's host part (gfx-frame.asm, gfx-frame_cold.asm); the rarely run code (h-cold.asm: hstart, h_disc, hbswap); the handlers (h-panel.asm, h-prim.asm); the rasteriser's own place (gfx-raster.asm: R_SETBUF, the star records, r_pclip, r_pset, R_DOT, R_STARERASE, R_STARPLOT; gfx-raster_lcold.asm: the lines' cold part and the rasteriser's private state, of which the hosts keep R_PRBUF and R_PRSCNT). No padding | 11589 | - |
| Bank 7: tokens | &AD45-&B22E | the recursive tokens (QQ18 as stored) and where each starts, which C_TOKEN reads in the IRQ (irqm pages bank 7) | 1258 | - |
| Bank 7: free | &B22F-&BA48 | the room the code leaves (the font's first place starts in its last 73 bytes) | - | 2074 |
| Bank 7: workspace | &BA49-&BFFF | one run: f_enter's buffers F_HW, F_HW2 and f_unstar's F_DSX, F_DSY (&BA49-&BC72); of the renderer's shared workspace R_X0 ... R_Y1, R_SS, R_SX, R_SY, R_SN, R_SCOL and F_DSS (&BC73-&BCD0); the panel's variables of WP (HWP, &BCD1-&BCFF); DFS's three pages while the game runs (HBST, &BD00-&BFFF), where the loader puts the host's image of &0E00-&10FF for hstart's first hbswap. CHPR's font is first put at &BA00-&BCFF, across the workspace and the room below it, and moved before anything uses them | 1463 | 0 |

Overlay D can reach 64 pages in bank 5; S is at its ceiling of 55 already.
The two overlay banks keep 31 whole pages free between them, and bank 4 its
1498 bytes and the run pages' tails.

### The swap

Around a disc command h_disc exchanges &0E00-&10FF with bank 7's HBST
(hbswap, in bank 7: interrupts off, three pages), so that DFS has its
workspace back while the MOS runs the command, and the host its low pages
after. Nothing else is swapped: the font at &0400-&06FF stays, as the MOS
never calls its Tube code again, and the MOS's own pages were never the
host's. While the command runs, irqm (in the persistent block) still takes
timer 1 and vsync, and hwrch prints the MOS's output (a catalogue) with
CHPR in bank 7. tube/tools/tsavetest.mjs checks ylookup (from the
symbols) and the font after a save, a load, an error and a catalogue; a
BREAK while DFS runs a command resets the machine (the loader's *FX200,3),
and SHIFT+BREAK boots the game again.

### The loader

tube/src/loader-b.asm runs at &1900, above DFS's workspace and clear of
everything it fills. It checks the Tube (OSBYTE &EA) and finds the first
four sideways RAM slots (a byte at &8008 that reads back as written), or
stops with a message in mode 7. Then FTAB, in the disc's order, each file
loaded to &1C00, its bank numbers patched in (PATCH, build/hb-patch.asm:
offsets by bank, 0-3 for banks 4-7) and copied: HOVD to bank 5 and HOVS to
bank 6, both from &8000 (the files the Master host's loader reads); BDATA
to &7000; HBK to bank 4 from &B000; HBC to bank 7, the whole bank; HBE to
&7E00. Then PCODE into the parasite, WRCHV = hwrch, and the parasite
started through the MOS's Tube code, which passes its first byte, &FE, to
hwrch: hstart pages bank 7, moves the font to &0400, exchanges the low
pages with DFS's (hbswap), has the row runs made (s_gen), makes ylookup,
starts the rupture (hb_t1init), and the command loop begins.

### The rupture

The dashboard split is a CRTC vertical rupture (tube/spike/rupture.asm): two
CRTC frames per field, timer 1 firing twice a field to set each frame's
R4/R6/R7 and start address (R12 only: R13 is 0 for every start address,
written once by hb_t1init; the latch's high byte only, the two periods'
low bytes being equal); a flip takes effect at the next frame A. The
timer's interrupt saves only A: irqm's hbi_t (main RAM) does point 2
without paging, and pages bank 7 for point 1 (hbi_p1), where the flip's
state is.

## Screen stores: the Master host's STA runs, the row runs

The Master host fills spans through full `STA abs` runs (h-sta.asm: one
run per line of the 3D view, an `STA abs` per byte, 37.6K, a page a line
in banks 4, 5 and 6, the same address in both buffers, made at the host's
start). At a 3 MHz parasite
they are 0.3-2.2% faster than the row runs (one run per character row,
`STA abs,Y` with Y the row, as the Master port's: TUBE-REPORT.md). The
Model B host has the row runs, a set per buffer (48 pages of bank 4, made
at the host's start), so that no run is patched for a buffer.

The Model B host's NMOS code is tube/tools/nmos.py's conversion with hand
fixes (tube/build.sh's --sub) where nmos.py, which keeps every register
live at an RTS, would save one that is dead: r_spc's store of the RTS
out of the run (Y and the flags), R_STARERASE's and R_STARPLOT's
reads and writes through RZ_PP (Y; X), r_rowset's INC A (ADC #1, the
carry clear), and phase B's: the right end less one (SEC : SBC #1, the
flags dead), the plant with X dead, the RTS out again at the end with Y
and the flags dead, a character row's new page with X dead, and pb_ob_e
placed before pb_one_e so that phase B's even half needs no long
branches.

## Tools for the hosts' time

tube/tools/thcmd.mjs: the host's cycles by command, routine, IRQ kind and
kind of instruction, and the parasite's by state (running, the ring's
stubs, IRQ and full waits, the flip's wait, requests), over windows of a
replay, on either host; tube/tools/thacct.mjs: two of its outputs'
difference as a table that sums to the wall-time gap.
tube/tools/tstream.mjs: the command stream over windows of a replay, as
the host reads it: bytes and commands by command, C_DSPANS's and C_SPANS's
bytes by field (with how rows follow each other and how often colours
repeat), the host's cycles by command; and, at the parasite's psb, every
disc span checked against C_DSPANS's ranges (rows 1-191, XL 2-253).
tube/tools/trupt.mjs: the Model B host's split screen over a replay
window: each field's CRTC frames as jsbeeb runs them (start address,
length, the row where the display ends, the vsync), counted by kind, and
the line of every write to R4, R6, R7, R12 and R13; with --shots, the
rendered picture at given iterations.
