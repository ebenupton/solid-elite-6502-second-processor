# The Tube version: memory maps and protocol (the dumb host)

The 6502 Second Processor version of the full Master port, as built on branch
`dumbhost` (`tube/build.sh`). TUBE-PLAN.md is the plan, TUBE-REPORT.md
(untracked) the report with the numbers, DUMB-HOST-AUDIT.md the audit that
this layout follows.

Two discs: `tube/build/elite-tube.ssd` (a BBC Master host) and
`tube/build/elite-tube-b.ssd` (a BBC Micro Model B host with 64K of sideways
RAM). SHIFT+BREAK on either, with a 6502 Second Processor attached.

## The rule

The host only draws what the parasite tells it to: lines, points, spans, text
and the panel; it does the I/O (keys, sound, disc commands, vsync and the
buffer flip); and it stores the parasite's overlay images and gives them back.
It keeps no state about what the screen holds. Everything that decides what
to draw is on the parasite: the frame layer, the rasteriser's bookkeeping
(the disc layer with its repair, the dirty extents, phase B's rows, the star
records' scheduling), the planet's surface (the circle engine, its styles,
moon and ring), the lens flare's
geometry, the sights, and the text map with its diff against what each buffer
shows.

## The parasite (65C02, 3 MHz, flat 64K) — both hosts

| Region | Addresses | Holds |
|---|---|---|
| Zero page, stack, K%, WP | &0000-&0CCE | the game's workspaces, at the Master port's addresses; &E4-&F8: p-rast.asm's pointers and scratch |
| The moon's place | &0CCF-&0CEE | MN_E, MN_OK and MN_TURN's variables (gfx-mnturn.asm; never loaded: the first MN_TURN finds the system changed); 25 bytes free to &0D07 |
| Dummy SHEILA | &0D08 | the one SHEILA byte Master's code still writes on the parasite (ACCCON, VIA + &34) |
| Frame layer's inputs | &0D09-&13FF | tube/src/p-ws.asm: the polygon and line inputs, the stars, the text map's row counts (F_TMR, F_SHR0/1), then from &0E00 the 192-byte row arrays (R_NDISCL page aligned, R_NDISCR within a page) |
| Resident code and data | &1400-&B962 (157 free to &B9FF) | the run (with p-low.asm: Tube I/O, the overlay manager p-ovl.asm, the panel's game halves p-dash.asm, T_KOFF), Master's drawing's game halves, the game data (not QQ18, the recursive tokens: the hosts keep them, below), the cold blocks that run in flight, the frame layer's parasite part, TBUF (the tokens being printed, 35 bytes), F_TM and F_ST (the text map) |
| Overlay region | &BA00-&F0FF | overlay D or overlay S (below; S ends at &EC45, 1,210 bytes below the ring); in direct mode ZPSAVE, above D, is getzp's buffer |
| The ring | &F400-&F7FF | 4 pages (11 until the planet's engine joined overlay S: tubeplanets), above both overlays and the boot's staging (p-layout.asm asserts it): the commands buffered while register 1 is full (p-io.asm; "The ring" below) |
| High area | &F800-&FEE6 | phase A's second part (p-polyb.asm), the panel's second part (p-dash2.asm), the kept rows' T_KFRAME and pk_line (p-kept2.asm); 9 bytes free to &FEEF. The client OS's copy lives here too: the host keeps whichever of the two is out (C_SWAP) |

### The overlays (tube/src/p-ovl.asm)

| Overlay | Size | Free | Holds |
|---|---|---|---|
| D (direct mode) | 9,117 bytes, &BE00-&E19C | 4,707 (less ZPSAVE's 112 at the top) | the cold blocks that run only on the screens drawn directly (the blocks tagged "Tube: ovl D" in their headers: the charts, the market, equipment, the status and disc screens, the title), with the extended tokens they print |
| S (space mode) | 13,822 bytes, &BE00-&F3FD | 2 | the rasteriser's bookkeeping (p-rast.asm: its state first, 2,148 bytes to &C663, then the disc layer, the dirty extents, the star records' relay through R_NDX2 (fetched before C_BUF by p_starget, sent back after it), the 16-bit polygons' rows), the polygons' row streams (p-emit.asm), the kept solid rows (p-kept.asm), the text overlay and the sights (gfx-ftext.asm), the lens flare (p-flt.asm, gfx-flare.asm), the moon drawn incrementally (p-moon.asm), the planet's surface: the circle engine (gfx-merid.asm: pc_circ, PC_ROWS, PC_MROWS) and its styles, the beach ball, craters and bands, the moon and the ring's dots (gfx-planet7.asm), one image for every planet: no planet-kind tails, no paging at hyperspace |

Code outside an overlay calls into D through stubs that streams.py writes at
the routines' places (`JSR povd : EQUW target`; povdj for the routines that
never return); povd loads D if it is out, and loads back the overlay that was
in when the target returns, if that one has routines on the stack (ovl_dact
scans the stack). F_FRAME and F_INIT load S. S's state goes to the host
(C_OVLPUT) when S goes out in space mode, and comes back with it; out of
space mode the state is rebuilt (GSTASH, f_b0new).

A load is the overlay's whole pages through register 4: about 168,000 host
cycles for D, 179,000 for S (84 ms, 89 ms at 2 MHz), only on a change between
the space view and a screen drawn directly: 13 loads in iterations 0-4000 of
run1.

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
pages 2-3; the lens flare's fl_htab (p-flt.asm); the overlay region and the
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
| Spans | C_SPAN (Y, XL, XR, COLE, COLO), C_DSPANS (the disc layer, sent as made: per row the row, then XL, XR and the row's colour byte (COLE even rows, COLO odd) for each span, &FF ending the row; &FF for a row ends), C_SPANS (a polygon's rows, sent as made: the four colours and the first row, then left and right (exclusive) for each row, (1, 1) for a row with no pixels, &FF at the end but after row 191; phase B's fill reads them as it goes), C_ORSPAN (the lens flare: OR a mask over a span) |
| Lines and points | C_LINE (four colours, two 16-bit points), C_DOT (two colours, x, y, size), C_STARS (plot on black only; the host keeps the records), C_STARERASE (black the records' pixels), C_EORDOT (EOR a directly drawn star away); the direct-mode screen: C_LOIN, C_HLOIN, C_PIXEL (Master's LOINQ, HLOIN3, PIXEL) |
| Text | C_GLYPH (a cell: character, column, row; space mode), C_CHAR (CHPR, direct mode), C_CLS, C_BOXC, C_CLYNS |
| Panel | C_PDIALS (the dials' inputs), C_PDOT (the compass), C_PSCAN (a ship on the scanner), C_PMSBAR (a missile), C_PBULB (a bulb) |
| I/O | C_NOISE, C_SOFLUSH (sound), C_DET1 (6845 R6), C_OSCLI (a disc command: the host's MOS runs it), C_SWAP (&F800-&FEEF with the host's copy) |
| Requests (register 4, answered by the host's IRQ) | C_KEYS (the keys held), C_DKS (one key), C_WSCAN (the next vsync), C_IRB (port B), C_NOISE, C_SOFLUSH, C_TOKEN n (recursive token n's bytes as QQ18 stores them, its null included: elite-source.asm's ex prints them from TBUF with the original loop) |
| Storage | C_OVLGET n (request: overlay n's pages), C_OVLPUT n (S's state's pages to keep) |

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
`DEC rq`, 21 cycles a byte). The ring drains in the parasite's IRQ (pirq,
the &FFFE vector; a BRK still goes to p_crash): the host rings a doorbell
(any byte through register 1, host to parasite; the Tube's I flag on, J
off: htflags) whenever it finds register 1 empty, in hloop and in every HRX
(hrw: the Master host's main RAM; the Model B host's &7FE0), and the IRQ
sends up to 23 bytes without checking for room (unrolled, about 16 cycles a
byte with the IRQ's own cost), taking the doorbell last. Interrupts are on
only in ring mode; the IRQ that finds the ring empty leaves ring mode
(unless it came in on a stub) and returns with them off.

* Pages are written and read downwards, 255 to 1; a write pointer with a
  low byte of 0 is a stub between its DEC and rpg (the next page's 255).
* rq (&FA, &FB) is the write pointer; the IRQ reads through (&FE) with
  rpl, rph. p_oscli's pointer moved from &FA to &FC.
* pflush empties the ring by polling, before C_OVLGET, C_OVLPUT and
  C_DISC (ovl_need, ovl_get, p_oscli): their answers come behind the stream.
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
| Main RAM | &1EDC-&2B06 | the game's host blocks (IRQ, sound, CHPR and its font, UP), the trampolines, the command loop and handlers (h-main.asm); 1,273 bytes free to &3000 |
| Bank 4 | &8000- | overlay D's image (storage only) |
| Bank 5 | &8000-&8073, &9000-&BCD2 | the star records' I/O (gfx-raster_stio.asm); the shared region: the row runs (the span filler), R_SPAN, R_DOT, R_STARPLOT, R_STARERASE, R_SETBUF, the line code's cold part, r_dspin (C_DSPANS: each row set up once for all of its spans). The disc layer, the repair and the flare (3.9K + 1K) are gone; h-dead.asm points the names the kept code still patches at a scratch BRK |
| ANDY | &8000-&8776 | phase B's fill (entered at r_pcbs; each row's span read from register 1 as it fills, no dirty extents) and the line loops (R_LINE; no dirty extents); phase A (1.8K) is gone |
| Bank 6 | &8000-&9BA3 | f_glyph, f_enter, f_b0new's clear, f_unstar, f_direct0, the panel's drawing (h-panel.asm with the "Tube: hostb" blocks: DIALS, SCAN's dot and stick, DOT, MSBAR, the bulbs, LOINQ, HLOIN3, PIXEL), the primitives' handlers (h-prim.asm), the rarely run code (h-cold.asm); then f_enter's buffer and HSW (the high area's copy) to &A4EF |
| Banks 4, 7 | &8000-&BFFF | the STA runs (h-sta.asm); bytes 192-255 of their pages: S's state (bank 4) and overlay pages kept as four 64-byte pieces (bank 7, HSTB7 on the disc) |
| HAZEL | &C000-&DEE9 | the STA runs' tables and the code that enters them, the overlays' storage from &CA00 to &D9FF, then from &DA00 the recursive tokens (QQ18 as stored) and where each starts: h4body's C_TOKEN reads them in the IRQ, wherever the host is (HAZEL is mapped but around a disc command, while the parasite waits). &DF00-&DFFF, the MOS's, is untouched |

## The Model B host (64K sideways RAM)

NMOS code made from the same sources (tube/tools/nmos.py, with tools/longbr.py
for branches the longer code puts out of range), behind `_HOSTB` where it must
differ (no ACCCON; the screen base; the banks).

| Region | Addresses | Holds |
|---|---|---|
| Main RAM taken from the MOS | &0236-&0325, &0E00-&0E65 | the trampolines into banks P and F, the overlays' storage handlers (hb-ovl.asm); swapped with the MOS's contents through bank S for each disc command |
| Buffer 0 | &1000-&3FFF | (the screen base is patched per buffer: the r_bs operands, f_bufpatch's glyph base) |
| Buffer 1 | &4000-&6FFF | the Master port's addresses: direct mode unchanged |
| Panel | &7000-&7DFF | the dashboard, the Master port's address |
| &7E00-&7F31 | | hwrch (WRCHV), the IRQ entry, hbswap: not swapped |
| Bank S | &8000- | the swapped main RAM, then overlay D's image from &8E00 (storage only) |
| Bank D | &8000- | overlay S's image and its saved state (storage only) |
| Bank P | &8000-&84AC, &9000-&BF8D | phase B's fill and the line loops; the shared region with the row runs (patched per buffer on first use: r_pgfix), R_SPAN, R_DOT, the stars, the line code's cold part, r_dspin; the polygon stream's entry (p_polyin); jump table at &BFC0 (P_POLY, P_MARKDIRTY, P_FLARE retired: BRK; JT + 3, once P_ROWREP, is P_DSPANSIN) |
| Bank F | &8000-&AEA2 | the command loop and handlers, f_glyph, f_enter, f_unstar, the panel's drawing, CHPR and its font, the sound, the interrupts (hb-irq.asm); then f_enter's buffer, then from &A9B9 the recursive tokens (QQ18 as stored, 960 bytes) and where each starts (298 bytes), which h4body's C_TOKEN reads in the IRQ (bank F paged) |

The dashboard split is a CRTC vertical rupture (tube/spike/rupture.asm): two
CRTC frames per field, timer 1 firing twice a field to set each frame's
R4/R6/R7 and start address; a flip takes effect at the next frame A. The
loader (tube/src/loader-b.asm, at &1900) finds the first four sideways RAM
banks and patches their numbers into the images (build/hb-patch.asm).

## Screen-store runs: full `STA abs` evaluated

See TUBE-REPORT.md, "Evaluation: full STA abs screen runs": one set per buffer
is 37.6K; not adopted. The row-run span filler is kept on both hosts.
