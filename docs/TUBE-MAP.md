# The Tube version: memory maps and protocol (the dumb host)

The 6502 Second Processor version of the full Master port (`tube/build.sh`).
TUBE-PLAN.md is the plan, TUBE-REPORT.md (untracked) the report with the
numbers, DUMB-HOST-AUDIT.md the audit that this layout follows.

Two discs: `tube/build/elite-tube.ssd` (a BBC Master host) and
`tube/build/elite-tube-b.ssd` (a BBC Micro Model B host with 64K of sideways
RAM). SHIFT+BREAK on either, with a 6502 Second Processor attached.

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

| Region | Addresses | Holds |
|---|---|---|
| Zero page, stack, K%, WP | &0000-&0CCE | the game's workspaces, at the Master port's addresses; &E4-&F8: p-rast.asm's pointers and scratch; QSL (the quarter squares' low bytes) in pages 2-3 |
| Free | &0CCF-&0D07 | 57 bytes (the moon's place, with MOON=on on the Master port: the Tube's build refuses MOON=on) |
| Dummy SHEILA | &0D08 | the one SHEILA byte Master's code still writes on the parasite (ACCCON, VIA + &34) |
| Frame layer's inputs | &0D09-&13FF | tube/src/p-ws.asm (workspace: not in the image): the polygon and line inputs, the stars, the text map's row counts, the discs' and the flare's probes' scratch, R_POLY's and the kept rows' scratch, then from &0E00 the 192-byte row arrays (R_NDISCL page aligned, R_NDISCR within a page); 76 bytes free |
| Resident code and data | &1400-&B3F5 (10 free to &B3FF) | the glue (p-low.asm: Tube I/O, the overlay manager p-ovl.asm, the stubs into overlay D, the panel's game halves), the run (every block not tagged "Tube: ovl D" or the hosts'), the game data (not QQ18, the recursive tokens: the hosts keep them, below), the frame layer's parasite part and its state (F_HW, F_SR, F_RP, the text map F_TM, F_SLV), then the disc heap's drop and the surface's cold paths (p-disc0.asm) and the flare's probes' helpers (p-probe1.asm) |
| Overlay region | &B400-&F3FF | overlay D or overlay S (below); in direct mode ZPSAVE, above D, is getzp's buffer |
| The ring | &F400-&F7FF | 4 pages, above both overlays and the boot's staging (p-layout.asm asserts it): the commands buffered while register 1 is full (p-io.asm; "The ring" below) |
| High area | &F800-&FEE9 | phase A's second part (p-polyb.asm), the panel's second part (p-dash2.asm), the kept rows' T_KFRAME and pk_line (p-kept2.asm), the one-pass generator's tail; 6 bytes free to &FEEF. The client OS's copy lives here too: the host keeps whichever of the two is out (C_SWAP) |
| Page &FF | &FF00-&FFF9 | p_crash, the flare's step and tables (gfx-flare6.asm), its probes' hooks (p-probe2.asm), the directly drawn stars; 9 bytes free |

### The overlays (tube/src/p-ovl.asm)

| Overlay | Size | Free | Holds |
|---|---|---|---|
| D (direct mode) | 9,456 bytes, &B400-&D8EF | 6,928 (less ZPSAVE's 112 at &EF90) | the cold blocks that run only on the screens drawn directly (the blocks tagged "Tube: ovl D" in their headers: the charts, the market, equipment, the status and disc screens, the title, SUN's direct drawing), with the extended tokens they print |
| S (space mode) | 16,319 bytes, &B400-&F3BE | 65 | its state first (3,328 bytes, 13 pages: the rasteriser's, p-rast.asm, with the disc heap), then the rasteriser's bookkeeping (the disc layer, the dirty extents, the star records' relay, the 16-bit polygons' rows), the discs drawn as changes (p-disc.asm), the polygons' row streams (p-emit.asm), the kept solid rows (p-kept.asm), R_POLY (p-polya.asm, p-onepass.asm), the text overlay and the sights (gfx-frame.asm's "Area: ovl S" blocks), the lens flare (gfx-flare.asm) and its probes (p-probe.asm), the planet's surface: the circle engine (gfx-merid.asm) and its styles, the beach ball, craters and bands, the ring's dots (gfx-planet7.asm), one image for every planet; last, r_lost (p-lost.asm: the state rebuilt after S went out in space mode) |

Code outside an overlay calls into D through stubs that streams.py writes at
the routines' places (`JSR povd : EQUW target`; povdj for the routines that
never return); povd loads D if it is out, and loads back the overlay that was
in when the target returns, if that one has routines on the stack (ovl_dact
scans the stack). F_FRAME and F_INIT load S. S's state is never kept: the
hosts keep S's image from the state's end, and when S comes back the state
is rebuilt. If S went out in space mode (a call into D during flight:
DFAULT and STATUS, TT18, HALL, TT23 in run1), nothing is known of either
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
between the space view and a screen drawn directly: 13 loads of D and 14 of
S in iterations 0-6000 of run1.

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

### Kept solid rows (p-kept.asm, p-kept2.asm)

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

Page alignment is kept only where it buys cycles or is required: R_NDISCL
(the disc layer indexes it from its page) and R_NDISCR within one page
(f_discspans' symmetric loop); the log tables (FMLTU's operand's low byte is
the argument; 33 bytes of padding before them, the head's only gap); QSL in
pages 2-3; the lens flare's fl_htab (gfx-flare.asm: within a page); the overlay region and the
ring (whole pages: the overlays travel by pages, the ring's pointers step by
pages). tube/tools/pmap.py writes the whole map as JSON.

## The protocol (tube/src/cmds.asm)

Commands go through register 1 (the parasite polls its room bit, or
buffers in the ring: above; the host's loop polls its data bit, ringing the
parasite's doorbell while it is empty): an even opcode, which the host dispatches through a
table, then the operands. Requests that need an answer go through register 2
(preq), which the host's loop reads before the next command, and are answered
through register 4.

| Group | Commands |
|---|---|
| Frame | C_BUF b (wait for the last flip, then draw into buffer b), C_FLIP (show it at the next vsync), C_ENTERB (space mode: buffer 1's border to buffer 0), C_CLRBUF b, C_DIRECTD (direct mode: shadow RAM on show), C_INIT, C_SYNC (the end of an iteration: the harness's frame marker) |
| Spans | C_SPAN (Y, XL, XR, COLE, COLO), C_DSPANS (the disc layer, sent as made: the first row, then XL, XR and the row's colour byte (COLE even rows, COLO odd) for each span; after a row's spans 0 for the next row's, else &FF and the row; &FF 0 at the end. Rows are 1-191 and XL 2-253, inside the clip window, so neither 0 nor &FF is a row or an XL), C_SPANS (a polygon's rows, sent as made: the four colours and the first row, then left and right (exclusive) for each row, (1, 1) for a row with no pixels, &FF at the end but after row 191; phase B's fill reads them as it goes), C_ORSPAN (the lens flare: OR a mask over a span) |
| Lines and points | C_LINE (four colours, two 16-bit points), C_DOT (two colours, x, y, size), C_STARS (plot on black only; the host keeps the records), C_STARERASE (black the records' pixels), C_EORDOT (EOR a directly drawn star away); the direct-mode screen: C_LOIN, C_HLOIN, C_PIXEL (Master's LOINQ, HLOIN3, PIXEL) |
| Text | C_GLYPH (a cell: character, column, row; space mode), C_CHAR (CHPR, direct mode), C_CLS, C_BOXC, C_CLYNS |
| Panel | C_PDIALS (the dials' inputs), C_PDOT (the compass), C_PSCAN (a ship on the scanner), C_PMSBAR (a missile), C_PBULB (a bulb) |
| I/O | C_NOISE, C_SOFLUSH (sound), C_DET1 (6845 R6), C_OSCLI (a disc command: the host's MOS runs it), C_SWAP (&F800-&FEEF with the host's copy) |
| Requests (register 4, answered by the host's IRQ) | C_KEYS (the keys held), C_DKS (one key), C_WSCAN (the next vsync), C_IRB (port B), C_NOISE, C_SOFLUSH, C_TOKEN n (recursive token n's bytes as QQ18 stores them, its null included: elite-source.asm's ex prints them from TBUF with the original loop) |
| Storage | C_OVLGET n (request: overlay n's pages) |

The opcodes of the commands the dumb host no longer has (the frame begin and
end, the disc layer's state, dirty marks, the polygon's phase A rows, the
flare, Master's byte writes, the meridian window, the text map) are retired
(h_bad).

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
(hrw: the Master host's main RAM; the Model B host's &7FE0), and the IRQ
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
&7000. 65C12 code.

| Region | Addresses | Holds |
|---|---|---|
| Main RAM | &0E40-&1EDB | the drawing code's workspace (gfx-ws.asm: the arrays the line and star code still write) |
| Main RAM | &1EDC-&2DC5 | the game's host blocks (IRQ, sound, CHPR and its font, UP), the trampolines, the command loop and handlers (h-main.asm); 570 bytes free to &3000 |
| Main RAM | &3000-&3DFF, &7000-&7FFF | overlay pages (storage only; ACCCON X clear) |
| Bank 5 | &8000-&8073, &9000-&B579 | the star records' I/O (gfx-raster_stio.asm); the shared region: the row runs (the span filler), R_SPAN, R_DOT, R_STARPLOT, R_STARERASE, R_SETBUF, the line code's cold part, r_dspin (C_DSPANS: each row set up once for all of its spans). The disc layer, the repair and the flare (3.9K + 1K) are gone; h-dead.asm points the names the kept code still patches at a scratch BRK |
| ANDY | &8000-&85A4 | phase B's fill (entered at r_pcbs; each row's span read from register 1 as it fills, no dirty extents) and the line loops (R_LINE; no dirty extents); phase A (1.8K) is gone |
| Bank 6 | &8000-&9D29 | f_glyph, f_enter, f_b0new's clear, f_unstar, f_direct0, the panel's drawing (h-panel.asm with the "Tube: hostb" blocks: DIALS, SCAN's dot and stick, DOT, MSBAR, the bulbs, LOINQ, HLOIN3, PIXEL), the primitives' handlers (h-prim.asm), the rarely run code (h-cold.asm), f_enter's buffer and HSW (the high area's copy); the STA runs from &9F00 |
| Banks 4, 7 | &8000-&BFFF | the STA runs (h-sta.asm); bytes 192-255 of their pages: overlay pages kept as four 64-byte pieces (bank 7, HSTB7 on the disc); in bank 4 free (4,096 bytes in 64-byte pieces: room for 16 more overlay pages kept as bank 7's are, or tables read with bank 4 paged) |
| Overlay storage | | 88 pages, all used (D's 37 and S's code's 51; tube/build.sh assigns them): main RAM above, bank 5's tail from &B900, bank 6's from &B700, ANDY's from &8600, HAZEL &CA00-&D9FF, and bank 7's 64-byte pieces |
| HAZEL | &C000-&DEE9 | the STA runs' tables and the code that enters them (to &C936), the overlays' storage from &CA00 to &D9FF, then from &DA00 the recursive tokens (QQ18 as stored) and where each starts: h4body's C_TOKEN reads them in the IRQ, wherever the host is (HAZEL is mapped but around a disc command, while the parasite waits). &DF00-&DFFF, the MOS's, is untouched |

## The Model B host (64K sideways RAM)

NMOS code made from the same sources (tube/tools/nmos.py, with tools/longbr.py
for branches the longer code puts out of range), behind `_HOSTB` where it must
differ (no ACCCON; the screen base; the banks).

| Region | Addresses | Holds |
|---|---|---|
| Main RAM taken from the MOS | &0236-&031F, &0E00-&0E6E, &0FB0-&0FFF | the trampolines into banks P and F, the overlays' storage handlers (hb-ovl.asm), the polygon's and lines' inputs (PDATA, &0FB0); swapped with the MOS's contents through bank S for each disc command |
| Buffer 0 | &1000-&3FFF | (the screen base is patched per buffer: the r_bs operands, f_bufpatch's glyph base) |
| Buffer 1 | &4000-&6FFF | the Master port's addresses: direct mode unchanged |
| Panel | &7000-&7DFF | the dashboard, the Master port's address |
| &7E00-&7FB8 | | hwrch (WRCHV), the IRQ entry with the rupture's timer interrupt (hbi_t: point 2 whole, point 1's way into bank F), hbswap: not swapped; hrw at &7FE0 |
| Bank S | &8000- | the swapped main RAM, then overlay D's image from &8E00 (storage only) |
| Bank D | &8000-&B2FF | overlay S's image from its state's end (storage only); &B300-&BFFF free (13 pages: room for more overlay images or host tables) |
| Bank P | &8000-&BFFF | phase B's fill and the polygon stream's entry (p_polyin) from &8000; the shared region from &9000 (r_dspin, the rows' set-up, R_SETBUF, r_spc, the per-x tables, R_SPAN, R_DOT, the stars); both buffers' row runs, a page per character row, so that none is patched for a buffer: buffer 1's (&4000) at &A000-&B7FF, buffer 0's (&1000) in the pages between, &8300-&8FFF, &9100-&98FF and &BC00-&BEFF; r_rpy0 (buffer 0's page per row, at &BF00) and r_rpy1 (buffer 1's, after the stars), which r_rowset's and phase B's LDA ,Y read, R_SETBUF patching the operand for the buffer; jump table at &BFC0 (P_PGFIX, P_POLY, P_LINE, P_MARKDIRTY, P_FLARE, P_LINEIN retired: BRK; JT + 3 is P_DSPANSIN) |
| Bank F | &8000-&B875 | the command loop and handlers, f_glyph, f_enter, f_unstar, the panel's drawing, CHPR and its font, the sound, the interrupts (hb-irq.asm); then f_enter's buffer, then from &A82A the recursive tokens (QQ18 as stored, 960 bytes) and where each starts (298 bytes), which h4body's C_TOKEN reads in the IRQ (bank F paged); then from &AD14 the lines (hb-line.asm: R_LINE, its cold part, arithmetic, r_pset, tables and variables: C_LINE with no paging; f_bufpatch patches their screen base) |

The dashboard split is a CRTC vertical rupture (tube/spike/rupture.asm): two
CRTC frames per field, timer 1 firing twice a field to set each frame's
R4/R6/R7 and start address (R12 only: R13 is 0 for every start address,
written once by hb_t1init; the latch's high byte only, the two periods'
low bytes being equal); a flip takes effect at the next frame A. The
timer's interrupt saves only A: irqm's hbi_t (main RAM) does point 2
without paging, and pages bank F for point 1 (hbi_p1), where the flip's
state is. The
loader (tube/src/loader-b.asm, at &1900) finds the first four sideways RAM
banks and patches their numbers into the images (build/hb-patch.asm).

## Screen stores: the Master host's STA runs, the row runs

The Master host fills spans through full `STA abs` runs (h-sta.asm: one
run per line of the 3D view, an `STA abs` per byte, 37.6K, the same
address in both buffers, made at the host's start). `FILL=rows sh
tube/build.sh` builds it instead with the row runs (h-rows.asm: one run
per character row, `STA abs,Y` with Y the row, all in bank 5, as the
Master port's and the Model B host's, but with no patching: the two
buffers are at the same address), for comparison; the code that enters
the runs stays where it is. At a 3 MHz parasite the STA runs are
0.3-2.2% faster than the row runs (TUBE-REPORT.md). The Model B host has
the row runs, a set per buffer (48 pages of bank P, its lines moved to
bank F to make the room), so that no run is patched for a buffer.

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
