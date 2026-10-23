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
records' scheduling), the beach ball's meridian window, the lens flare's
geometry, the sights, and the text map with its diff against what each buffer
shows.

## The parasite (65C02, 3 MHz, flat 64K) — both hosts

| Region | Addresses | Holds |
|---|---|---|
| Zero page, stack, K%, WP | &0000-&0CCE | the game's workspaces, at the Master port's addresses; &E4-&F8: p-rast.asm's pointers and scratch |
| Page &0D | &0D00-&0DEF | a dummy SHEILA (Master's drawing's ACCCON writes land there); setzp/getzp's buffer (ZPSAVE) |
| Frame layer's inputs | &0E00-&14F6 | tube/src/p-ws.asm: the disc spans, the polygon and line inputs, the stars, the text map's row counts (F_TMR, F_SHR0/1); 9 bytes free |
| Resident code and data | &1500-&D3F2 | the run (with p-low.asm: Tube I/O, the overlay manager p-ovl.asm, the panel's game halves p-dash.asm, T_KOFF), Master's drawing's game halves, the game data, the cold blocks that run in flight, the frame layer's parasite part (&96AF-), F_TM and F_ST (the text map, &CDC9-&D3C8); 13 bytes free |
| Overlay region | &D400-&F7FF | overlay D or overlay S (below) |
| High area | &F800-&FEE6 | phase A's second part (p-polyb.asm), the panel's second part (p-dash2.asm), the kept rows' T_KFRAME and pk_line (p-kept2.asm); 9 bytes free to &FEEF. The client OS's copy lives here too: the host keeps whichever of the two is out (C_SWAP) |

### The overlays (tube/src/p-ovl.asm)

| Overlay | Size | Free | Holds |
|---|---|---|---|
| D (direct mode) | 7,294 bytes, &D400-&F07D | 1,922 | the cold blocks that run only on the screens drawn directly (the blocks tagged "Tube: ovl D" in their headers: the charts, the market, equipment, the status and disc screens, the title), with the extended tokens they print |
| S (space mode) | 9,143 bytes, &D400-&F7B6 | 73 | the rasteriser's bookkeeping (p-rast.asm: its state first, 1,938 bytes to &DB91, then the disc layer, the dirty extents, the star records' relay through R_NDX2 (fetched before C_BUF by p_starget, sent back after it), the 16-bit polygons' rows), the polygons' row streams (p-emit.asm), the kept solid rows (p-kept.asm), the text overlay and the sights (gfx-ftext.asm), the lens flare (p-flt.asm, gfx-flare.asm), the meridian window (gfx-merid.asm, with the run's quarter squares) |

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

## The protocol (tube/src/cmds.asm)

Commands go through register 1 (the parasite polls its room bit; the host's
loop polls its data bit): an even opcode, which the host dispatches through a
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
| Requests (register 2) | C_KEYS (the keys held), C_DKS (one key), C_WSCAN (the next vsync), C_IRB (port B), C_STARGET (a buffer's star records) |
| Storage | C_OVLGET n (request: overlay n's pages), C_OVLPUT n (S's state's pages to keep) |

The opcodes of the commands the dumb host no longer has (the frame begin and
end, the disc layer's state, dirty marks, the polygon's phase A rows, the
flare, Master's byte writes, the meridian window, the text map) are retired
(h_bad).

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
| Bank 7 | &8000- | overlay S's image and its saved state (storage only) |

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
| Bank F | &8000-&A698, to &AFEF | the command loop and handlers, f_glyph, f_enter, f_unstar, the panel's drawing, CHPR and its font, the sound, the interrupts (hb-irq.asm); then f_enter's buffer and HSW |

The dashboard split is a CRTC vertical rupture (tube/spike/rupture.asm): two
CRTC frames per field, timer 1 firing twice a field to set each frame's
R4/R6/R7 and start address; a flip takes effect at the next frame A. The
loader (tube/src/loader-b.asm, at &1900) finds the first four sideways RAM
banks and patches their numbers into the images (build/hb-patch.asm).

## Screen-store runs: full `STA abs` evaluated

See TUBE-REPORT.md, "Evaluation: full STA abs screen runs": one set per buffer
is 37.6K; not adopted. The row-run span filler is kept on both hosts.
