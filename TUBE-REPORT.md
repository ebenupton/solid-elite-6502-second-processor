# Tube Elite: report

Branch `tube` in `~/elite-full-tube` (not pushed, not merged). Two discs:
`tube/build/elite-tube.ssd` (BBC Master host) and `tube/build/elite-tube-b.ssd`
(BBC Micro Model B host with 64K of sideways RAM), both built by
`sh tube/build.sh` (which also builds everything below; `sh master/build.sh` first).
Maps and protocol: `docs/TUBE-MAP.md`; the plan with what happened:
`docs/TUBE-PLAN.md` section 7.

## Planets on the parasite, paging removed, the map tidied (branch `tubeplanets`, 2026-10-27)

From `dumbhost` 9fe84cb. The Master port's planet work (planetfold 96c66d4 ..
ce80ced: one circle engine for the beach ball, craters and bands; a moon;
a ring; the original's planet maths as `Area: none`) is in master/src here,
so the in-tree Master port (the pixel oracle) and the parasite share it.

| commit | what |
|---|---|
| 89b34af | The engine, styles, moon and ring in overlay S; the meridian and crater tails, p_kind and SOS1's prefetch, overlays 4 and 5 gone. The moon drawn incrementally (p-moon.asm). P4's change drawing (R_BX, pob, pdo) out: faster with the ring, and S needed the room. The in-tree Master port's bank 7 window needed 2K: 36 "Tube: ovl D" cold blocks are `Area: bank 4` there (bankcheck holds). Its pixels equal planetfold's over run1 (14603 frames, 0 mismatched); fbref, dashref and master-ref regenerated from it. |
| 341d6d3 | tmoon.sh: forced moon, ring, band and moon-only scenes (system seed pokes); pokes take SYM+n. |
| 956051b | The parasite's map tidied (page &0D packed, ZPSAVE above overlay D, CODE% &1400, the ring back to 4 pages); tube/tools/pmap.py writes the map as JSON. |
| 595e622 | EDGES, BLINE and getzp (run only on the direct screens) into overlay D; F_HW3 into overlay S: the overlay region starts at &BD00, S has 194 bytes free with the 4-page ring. ttear.mjs fixed (below). test_raster runs again, with the circle engine's tests. |

| (this) | The Master's design change mirrored (planetsun 6957750): one colour scheme (crater planets blue with green craters), bands behind BANDS=on (off), the moon kept fixed in space (MN_TURN, gfx-mnturn.asm: planetsun's gfx-ssun.asm's turn, called once an iteration from G_FRAME and G_PFHOOK, as this tree has no S_SUN); rings behind RINGS=on (off), mirroring the coordinator's note before the Master's commit landed (_PLANET_RINGS). With rings off the ring has 7 pages (&F100; 4 with RINGS=on, which fits with BANDS off only). The in-tree Master port has the same; against planetsun 6957750 (MOON=scenery) its run1 pixels differ in 67 iterations, S_SUN's, as before; fbref, dashref and master-ref regenerated. |

**Speed** (it/s, capped: flight / docking / 0-3550 / beach / beach):

| | Master host, 4 MHz | Model B host, 3 MHz |
|---|---|---|
| 9fe84cb | 21.88 / 10.58 / 20.58 / 8.92 / 9.07 | 18.11 / 8.79 / 18.13 / 7.04 / 6.88 |
| 89b34af | 18.66 / 10.63 / 18.92 / 8.97 / 8.77 | 14.10 / 8.68 / 15.82 / 7.02 / 6.65 |
| 956051b | 18.66 / 10.63 / 19.01 / 9.23 / 9.33 | 14.11 / 8.80 / 15.91 / 7.28 / 7.11 |
| 595e622 | 18.66 / 10.65 / 19.00 / 9.22 / 9.31 | 14.10 / 8.79 / 15.91 / 7.28 / 7.11 |
| now (rings off, 7-page ring) | 18.82 / 10.64 / 19.09 / 9.30 / 9.37 | 14.10 / 8.79 / 15.94 / 7.34 / 7.19 |

The flight window's planet is now a crater planet with the spherical caps,
which cost about as much as on the Master port (its crater windows fell
from 13-14.5 to 8.5-9.5 it/s there); about 2% of flight is the ring's 4
pages (11 before). The ring's size matters in the beach windows: 3 pages
are 3-6% slower there than 4.

**Pixels.** Against the old reference, only crater-planet frames differ
(the caps and the desert scheme, 6260 frames, and 587 where only the
disc's colour changed), plus 9 frames whose hidden back buffer still holds
one; beach-ball frames are identical. Against planetsun's Master (4b37359,
MOON=scenery), 64 iterations of run1 differ: the sun near the planet
(S_SUN) and its flare, not ported (below).

**ttear.** The Model B count (6,722 at 9fe84cb, 15,705 at 956051b) was the
tool's: it took the 6845's running address as the line on show, and in
the right border of frame A's last character row that address runs past
buffer 0's end into buffer 1's range, so back-buffer writes there counted
as tearing (GFRONT showed the other buffer at every one). ttear.mjs now
counts only while the 6845 displays (both enables) and by the line's start
address: 0 on both hosts at 9fe84cb and now. With h_buf's wait for the
flip removed (a deliberate tear) it reports 153 (Master) and 446 (Model B)
in iterations 1-400.

**The disc rule.** The planet's disc layer is incremental (a one-colour
row is drawn only where it changed; a two-colour row is drawn whole when
drawn, and the surface's circles move every frame with the planet's spin
and our movement, so those rows change every frame). The moon is
incremental (p-moon.asm: a still moon's one-colour rows are not drawn
again; its crater's rows, which turn with the planet, and rows cut by a
disc are drawn each frame they are on the screen). Not done:
* the second disc (sun and planet both on screen) is still drawn whole
  each frame (f_disc2), and the sun near the planet (S_SUN) is absent:
  planetsun's R_DISC2 and S_SUN need about 1.8K in space mode (S_SUN 1.1K,
  R_DISC2's code, its per-buffer spans or a compact variant), and the
  parasite has 194 bytes;
* only redrawing surface rows whose boundaries changed (still bands free)
  needs per-row boundary state (up to four boundaries, two buffers: about
  1.5K). A test of the circles' records (no per-row state) was tried: the
  records change every frame (sub-pixel drift), so it saved nothing and
  was taken out.
Room in space mode is the parasite's resident image plus overlay S plus
the ring; moving space-only code between them changes nothing, and the
code run only on the direct screens is now in overlay D. Ways to make
1.5-2K: give up K mode (750 bytes, docking 16% slower), page the idle
buffer's state to the host each frame (est. 10-20% slower), or shrink
shared data (the text map's 1.5K, the face tables' 3.3K) by redesign.

**Gates** (scratch/g4, and scratch/g6 for the design change, both hosts): lockstep 16002 clean, TUBEINT 602
clean, pixels and dashboard 0 mismatched, tsavetest, tcrash, tstation,
tstore ok, tforce 0 mismatched with base overlay loads, tmoon matched but
the poke's own frames, ttear 0. test_raster seeds 1: every test ok.

## STA runs, OVLD, 25 fps cap, 4-boundary state (branch `dumbhost`, 2026-10-24, fourth pass)

This pass continues from c841656. Every commit was gated on both hosts with
tube/tools/tgate.sh: Master port byte-identical, lockstep, pixels, dashboard,
tsavetest and tcrash. Later commits add tstation and a TUBEINT=1 lockstep.

**Commits:**

| Commit | What |
|---|---|
| cb5953b | Master host: overlay storage is page by page through a table (build/hstore.asm), in main RAM, bank 5, bank 6, ANDY and HAZEL. HAZEL moves to main RAM around each disc command, as the Master port's DOSCLI does. S's image is stored without its state pages; the parasite's ovl_sinit rebuilds them. |
| 77dd7fa | Master host: full `STA abs` runs, 192 lines × 64 + RTS, made at the host's start. The code that enters them is in HAZEL, placed by "Area: hazel" tags and streams.py passes. The erases go through them too. Measured slower: 24.68 / 9.65 against 25.22 / 10.02. |
| 0009281 | Each line's run at the start of its own page (the coordinator's layout). Entry and plant are r_j offsets with no sums. The bank is paged once per row. S's state goes in the run pages' spare bytes. Back to 25.26 / 10.02. |
| da712b2, 8607399, 9369154, b187e5b | OVLD-PLAN groups 1-4: 20 game blocks by "Tube: ovl D" tags, p_oscli and G_HANG0..G_HANGAR by "ovl D" passes. OVL_START goes from &C800 to &C300 and overlay S has 1,582 bytes free. Targeted forced-input checks (tforce.sh): f8 and f5 in flight, the chart up when the countdown ends, a mis-jump, the debrief, the mission-2 brief, H while docked. All pixel-identical to the Master port on both hosts, with no extra D or S loads. Separately, the Master host hung when storage reached HAZEL's last page, &DF00, which holds the MOS's and DFS's lasting bytes; storage now stops at &DEFF. |
| b74e5f0 | Span core trim: no empty-run test; right edge before the unplant; plant via RZ_PP's low byte; fewer per-row patches. Fixed cost per span is 47 cycles against the old row runs' 50, and stores are 4 cycles a byte, not 5. |
| e2a8818 | 25 fps cap on both hosts, as the Master port's (GVLAST, and hb_vl on the Model B). No 1-field frames. |
| f963b3b | The full 4-boundary incremental two-colour state (R_BX2b/R_BX3b, a nibble encoding for n = 4). On the Model B host, S's state moves to bank F; it had overrun bank D. |
| 25daa58 | stationfix (cherry-picked): F_PLANET keeps the planet's z high byte; tstation.mjs added to the gate. |
| 30c3a8f, 8b25dc9 | hangfix merged: the loader keeps ITU and refuses to boot without a co-processor; harness TUBEINT=1. |
| 192eee2 | Host code never writes ACCCON whole. LOIN cleared ITU; h_ovlget's save and restore could undo the IRQ's D. tgate.sh adds a TUBEINT=1 lockstep. |

**Speed (it/s: flight / docking / 0-3550 / beach / beach):**

| Build | Master host, 4 MHz | Model B host, 3 MHz |
|---|---|---|
| c841656 (start of this pass) | 25.22 / 10.02 / 24.17 / 8.47 / 8.66 | 19.19 / 8.03 / 19.24 / 6.86 / 6.76 |
| b187e5b, STA runs (trimmed) + OVLD, no cap | 25.52 / 10.20 / 24.33 / 8.60 / 8.75 | 19.19 / 8.03 / 19.23 / 6.84 / 6.73 |
| e2a8818, 25 fps cap (**the new baseline**) | 20.83 / 9.92 / 19.89 / 8.60 / 8.75 | 17.14 / 7.88 / 17.28 / 6.84 / 6.73 |
| 192eee2, + 4-boundary state, fixes (HEAD) | 20.83 / 9.92 / 19.86 / 8.49 / 8.59 | 17.14 / 7.89 / 17.26 / 6.75 / 6.61 |

The cap holds a frame for at least two fields. In flight the parasite then
waits on a full register 1 while the host holds the flip: pwait shows
r1full.hostflip at 18.9% of wall time, against 1.0% without the cap. The
parasite's game work is the same 50.4M cycles over the window.
- C_BUF goes out at F_FRAME's start, after the game code, so only the
  drawing waits, as on the Master port.
- Frames that need slightly more than two fields now take three:
  Master flip intervals over 0-3550 are 2330 × 2 fields, 572 × 3, 291 × 4
  and so on.

The 4-boundary state costs the beach windows 1.3-1.8%. S's state is now 15
pages, and both windows end in a hyperspace jump, where it goes to the host
and back. tbshare.mjs over the beach windows: 2.9% and 4.8% of rows have
3 boundaries, and none has 4.

**Host idle (Master host, 4 MHz, capped, pwait):**
- flight: busy 41.2%, idle 31.1%, waiting for vsync 27.7%;
- docking: busy 78.4%, idle 18.4%, waiting for vsync 3.2%.

**Parasite (HEAD):**
- resident run to &C2FE;
- OVL_START &C300;
- overlay S has 814 bytes free (its state 3,666 bytes; the meridian tail
  2,770);
- overlay D is 9,117 bytes, with 4,451 free;
- the high area has 6 bytes free and the page at &FF00 has 9.

**Pixels.** 51 frames in iterations 13973-14037 differ from fbref. This
is the stationfix window: the Master port has the same bug until the
planetz branch regenerates the references. Outside the window there are
0 mismatches on both hosts.

**Not done:**
- **BREAK recovery.** tube/tools/tbreak.mjs (new) presses BREAK or
  SHIFT+BREAK in flight.
  - On the Model B host, SHIFT+BREAK reboots the disc and the game runs
    again.
  - On the Master host, both the Tube build and the Master port end in a
    garbled screen with the host in a ROM, and no reboot, under jsbeeb.
  - A BREAK intercept (&0287) that puts DFS's and the MOS's HAZEL bytes
    back was called twice per BREAK but changed nothing visible, so it is
    not committed.
  - What the Master needs, and what the original 6502SP Elite does on a
    BREAK, is still to be found.
- **The ship edge lists.** Dropped on the user's direction. A trial on
  the Tube (an empty EDGE macro, as nothing on the parasite reads them)
  lowered OVL_START to &B900, freeing 2,596 bytes. It was reverted and not
  gated.
- **The text-stall question.** Parked.

## One-pass polygons, no client OS, planet-kind tails (branch `dumbhost`, 2026-10-23, third pass)

This pass starts from 9a3b541. It did four things:
- made every polygon one-pass, exactly as the two-phase path;
- moved the fast I/O to register 4;
- replaced the Tube client OS with the game's own runtime, following
  `~/elite-tubeproto/tube/proto/CLIENTOS-REPORT.md` (C1-C5, P1-P4);
- drew a beach ball's two-colour rows as changes.

The hosts still only draw, do the I/O and store the overlays. The one
approved exception is that the host keeps the star records.

**Commits** (on `dumbhost`, not pushed). Each one was gated on both hosts as it was made.

| Commit | What |
|---|---|
| a06a951 | The host keeps the star records; no round trip (C_STARGET retired). |
| bce3070 | Parasite space: TT151, TT163 and TT16 to overlay D; the quarter squares after the log tables; the overlay region a page lower. |
| b4a94a0 | Tools: test_onepass.py --tube (a differential py65 test of the parasite's R_POLY); tpolycap.mjs. |
| fe18a8f | Every polygon in one pass, exactly as the two-phase path (p-onepass.asm, p-onepass2.asm). |
| d24378b | The fast I/O requests go through register 4, answered at once by a host IRQ (both hosts). |
| 7e6dcca | C_DSPANS sends one colour byte per span (the row's). |
| de334c9 | One-pass: an 8-bit polygon's orientation from its edges' x ranges first. |
| 0640b14 | Sound and the vsync wait go through register 4 too. |
| a1d2958 | Parasite space: R_POLY's set-up into overlay S, the flare's tables resident, p-io's sends through ptx. |
| b95ef52 | One-colour rows of two-colour frames drawn as changes (R_BST). |
| d33c71b | tgate.sh measures speed at the target clocks: a 4 MHz parasite on the Master host, 3 MHz on the Model B. |
| 408fdb5 | **C1**: C_DISC. The host's MOS runs a disc command as the host's own I/O: OSCLI from the host, commbuf through HDBUF=&3F00 (savosc/lodosc name FFFF3F00), and a disc error comes back as data that p_oscli passes to NEWBRK. The client OS takes no part. |
| 7978343 | **C2**: the boot takes the parasite over. p_boot (staged above overlay D, appended to PCODE) copies in the high code, and the page at &FF00 with the vectors (NMI an RTI, RESET p_start, IRQ/BRK the crash reporter p_crash). p_swap, h_swap, C_SWAP and HSW (1,776 bytes on each host) are gone. hstart clears &027A. tcrash.mjs checks that a deliberate BRK reaches p_crash. |
| 4d03ba1 | **C3**: QSL at &0200-&03FF. gfx-flare6, p-flt and F_DSX/F_DSY in the &FF00 page. OVL_START &CE00 -> &CB00. |
| 49b3a6f | **C5**: the Model B's hbswap leaves &0400-&06FF alone after the boot. The Master's &0400-&06FF is declared free host RAM (HLOW). C4 (setzp/getzp as no-ops) was not done: it is optional and would save 49 run bytes, which gains no page. |
| a6651d5, fc03c9f | P1 as first done (the crater code split into new files), then reverted on the user's direction: code is placed by tags in place plus passes, never by moving it into new files. |
| 01cef6d | Overlay D is chosen by `\       Tube: ovl D` header tags (127 blocks) instead of the hand-made list tube/src/ovl-d.txt. Every output is byte-identical. |
| 2b2da4b | **P1+P2**: overlay S becomes a common part plus a page-aligned kind tail. The meridian tail is gfx-merid.asm. The crater tail is a streams.py pass over gfx-frame.asm, whose crater blocks carry `\       Area: ovl S crater` tag lines. F_NCV/F_NPT are resident bytes. p_kind (in G_PLANET) picks the tail by TYPE. The host stores the crater tail after overlay D's image. OVL_START -> &C800. |
| 0a53ee1 | **P3**: SOS1 prefetches the tail for the new planet's kind. tkind.mjs counts the fetches and checks them against the host's image (--flip tests the fetch in flight). |
| 150a7b4 | **P4**: a beach ball's two-colour rows drawn as changes. R_BST's nibble becomes 8 + 4p + n, the boundary x are kept in R_BXib (768 bytes of S's state), pob gives the old row's segments and pdo paints the new segments less the old same-coloured ones. |

**Gates, at every commit, both hosts** (`sh tube/tools/tgate.sh`, the last
scratch/g-pk4):
- the Master port byte-identical to 87cf524;
- lockstep `REPLAY CLEAN`, 16,002 iterations, 0 findings;
- pixels: 14,610 matched, 4 sampling gaps, 0 mismatched;
- dashboard: 3,528 matched, 0 mismatched;
- tsavetest exit 0, with E.TESTA byte-identical and the catalogue entry's name and attributes identical;
- from C2 on, tcrash (a BRK reaches p_crash).

Extra checks:
- the planet tails against the pre-tail build over run1 16,000-40,000: 22,617 frames and 7,048 dashboard frames matched, 0 mismatched;
- tkind --flip in both directions: the fetched tail is identical to the host's image;
- test_onepass --tube: 300 polygons identical.

**Speed (it/s; flight 1000-1400 / docking 3420-3550 / 0-3550 / beach 300-403 / beach 5355-5457):**

| Build | Master host | Model B host |
|---|---|---|
| 9a3b541, 3 MHz parasite (the baseline) | 18.02 / 8.65 / 18.70 / 7.04 / 6.92 | 14.78 / 7.60 / 16.42 / 6.23 / 6.01 |
| 150a7b4, 3 MHz parasite | 21.41 / 9.25 / 20.88 / 6.95 / 6.90 | 19.19 / 8.03 / 19.24 / 6.86 / 6.76 |
| a1d2958, target clocks (Master 4 MHz, Model B 3 MHz) | 22.40 / 10.03 / 22.87 / 8.19 / 8.16 | 17.16 / 8.05 / 18.20 / 6.63 / 6.44 |
| b95ef52 (R_BST), target clocks | 25.41 / 10.02 / 24.19 / 8.30 / 8.16 | 19.43 / 8.03 / 19.31 / 6.75 / 6.44 |
| C1-C5, P1-P3, target clocks | 25.36 / 10.02 / 24.19 / 8.31 / 8.18 | 19.37 / 8.03 / 19.30 / 6.76 / 6.45 |
| **150a7b4 (P4), target clocks** | **25.22 / 10.02 / 24.17 / 8.47 / 8.66** | **19.19 / 8.03 / 19.24 / 6.86 / 6.76** |

Against 9a3b541 at the same 3 MHz parasite:
- Master: flight +18.8%, docking +6.9%, 0-3550 +11.7%, beach -1.3% and -0.3%;
- Model B: flight +29.8%, docking +5.7%, 0-3550 +17.2%, beach +10.1% and +12.5%.

The client-OS work (C1-C5) changes no frame. It saves about 100 ms per
disc command (no two 1,776-byte swaps; this figure is counted, not
measured) and about 50 ms at boot.

P4 trades a little flight for the beach balls:
- with the change path on for craters too, flight lost about 1%, so craters keep the whole repaint;
- even so, the per-row bookkeeping costs flight 0.6% (Master) and 0.9% (Model B).

**Host idle** (thprof, Master host, 4 MHz parasite, 150a7b4; share of
host cycles in hloop):
- flight 36.4%;
- docking 17.5%;
- beach 300-403 40.7%.

The parasite waits as follows:
- In flight it waits 28K of its 119K cycles per iteration, mostly in
  x4_csh and ptx (the frame's end and the command FIFO). The polls inside
  the disc layer are 4.6% of its instructions (tpprof). Flight is
  parasite-bound, so the host-side items below would not help it.
- In docking it waits 190K of 299K cycles, mostly for the polygon rows
  (pem_send) and the command FIFO.
- In the beach windows it waits on register 4 (prx, 62K) and register 1.

**Parasite free bytes** (150a7b4):

| Region | Free |
|---|---|
| Resident run (&1500-&C751) | 174 bytes to OVL_START &C800 |
| Overlay S, common part + meridian tail | 302 bytes to &F800 (common &C800-&EBFF; meridian tail 2,770 bytes; the crater tail is 982 bytes, so a crater system leaves 1,788 more unused) |
| Overlay D | 4,365 bytes to &F800 (D is 7,923 bytes) |
| High area &F800-&FEEF | 6 bytes |
| Page &FF00 | 9 bytes (p_crash, gfx-flare6, p-flt, F_DSX/F_DSY, the vectors) |
| Pages 2-3 | 0 (QSL) |

Overall, OVL_START went &CE00 -> &C800 (6 pages): 3 from the client OS's
holes and 3 from the crater tail.

**Remaining buffers and why:**
- *Parasite, overlay S's state* (2,898 bytes, saved to the host when S
  goes out in space mode): each buffer's disc spans and dirty extents
  (R_DISCLb/R_DISCRb, R_DIRTYLb/R_DIRTYRb), R_BST, R_BXib, R_WL/R_WR. The
  host keeps no per-buffer state, so the parasite must know what each
  buffer holds to draw only changes.
- *Parasite workspace &0E00-&14F6* (p-ws.asm): the disc layer's inputs
  (R_NDISCL/R, R_NDN, R_NDP, R_NDX0-3), the polygon vertices, the stars,
  the text map's row counts. These are the frame layer's per-frame inputs.
  R_NDX2/R_NDX3 double as the one-pass generator's variables and the disc
  error block.
- *Parasite resident frame-layer buffers*: F_HW/F_HW2, F_DL (with
  gfx-finit inside it), F_TM/F_ST (the text map and what each buffer
  shows), and the crater's recorded points (169 bytes). The points stay
  resident so that a mid-frame overlay D call cannot lose them.
- *Host*:
  - the star records (approved);
  - f_enter's F_HW/F_HW2 and F_DSX/F_DSY (bank 6 / bank F);
  - HDBUF/HDSTR/HDERR (&3E00-&3FFF), used only during a disc command;
  - the overlays' images (D plus the crater tail in bank 4 / bank S; S
    and its state in bank 7 / bank D), stored and never run.

**Tried and not adopted this pass:**
- the host ring, versions 1-3: 10.5, 15.8 and 16.7 it/s against 20.41;
- the compact C_DSPANS encoding: 17.24 / 14.69 against 20.41 / 17.16;
- disc rows made on the fly: -3.5%;
- P4's change path for craters: flight -1%;
- a narrow-row threshold and an unchanged-row shortcut for P4: no gain.

The Model B 512-byte parasite FIFO is parked: a hang at iteration 19
with overlay D in during T_POLY, unresolved. The patches are in
scratch/ring-attempt/.

**Not done, and why:**
- *The host's per-span overhead.* r_dspin and phase B's row read are
  already one polling read per byte plus the span core. Flight is
  parasite-bound, so only docking (17.5% host idle, the parasite waiting
  on pem_send) could gain, and only by the part of the host's work that
  is overhead rather than stores.
- *Full STA abs runs.* The earlier evaluation ("Evaluation: full STA abs
  screen runs") stands: 37.6K per set, about 2% at docking and nothing in
  flight. On the Master host, banks 4 and 7 now also hold the overlays'
  images (D plus the crater tail, 35 pages; S plus its state, 59 pages),
  so no bank is free for the runs.

## full-master 87cf524, kept rows on the parasite, streamed spans (branch `dumbhost`, 2026-10-23, second pass)

Everything new in the full Master port (87cf524) is in the Tube build, the
kept solid rows run on the parasite, the polygons' and the disc layer's spans
reach the host as they are made, and the hosts draw them with less overhead.
The hosts still only draw, do the I/O and store the overlays: every change on
the host side is in how a span or a line is drawn, none keeps state.

**Commits** (on `dumbhost`, after 4233af7; not pushed), each gated on both
hosts as it was made:

| Commit | What |
|---|---|
| cfaf5a5 | Merge of full-master 87cf524 (kept rows, the smaller workspace and the low area first, the hangar tables to bank 6, elite-qs.asm, the test_raster seed fix). Master port byte-identical to a fresh build of 87cf524; scratch/master-ref.ssd, scratch/fbref and scratch/dashref regenerated from it (its pixels equal the old reference's: 14,607 frames matched, 0 mismatched). |
| cb4cde4 | Polygon rows streamed: p_emit (tube/src/p-emit.asm) sends each row's span as it is produced; the host's phase B reads it from register 1 as it fills (r_pcbs), with no tables and no dirty extents of its own. The star records' relay buffer moved to R_NDX2 (S's state 386 bytes smaller). The one-pass generator (onepass b2a6182) imported and wired to p_emit, but off (below). |
| c340204 | The disc layer's spans streamed (C_DSPANS without the parasite's row buffer). |
| bda7941 | Kept solid rows on the parasite (p-kept.asm, p-kept2.asm). |
| 160216f | Hosts: C_DSPANS drawn by one loop in the rasteriser's bank (r_dspin: each row set up once; on the Model B host no trampoline per span). |
| 96d146e | Hosts: the line loops keep no dirty extents (nothing on the dumb host read them). |
| f1ed4fb | The star records fetched before C_BUF, not behind its wait for the flip. |
| (this) | TUBE-MAP.md and this report. |

**Gates, at every commit, both hosts** (the last: scratch/g-s6): the Master
port byte-identical to 87cf524; lockstep `REPLAY CLEAN`, 16,002 iterations,
0 findings; pixels 14,610 matched, 4 sampling gaps, 0 mismatched over
iterations 0..16000 (docking 3400-3600 and both beach-ball windows inside);
dashboard 3,528 matched, 0 mismatched; tsavetest exit 0. Model B pixel
checks of single steps were also run by frame key. test_raster was not run:
this branch's file split (gfx-ws.asm, gfx-raster_pset/_polyb/_lineb.asm)
predates this work and its harness does not follow it; the Master port's
rasteriser is byte-identical to 87cf524's, where it passes.

**Speed (it/s, run1 windows, `tube/tools/tspeed.mjs`):**

| | flight 1000-1400 | docking 3420-3550 | 0-3550 | beach 300-403 | beach 5355-5457 |
|---|---:|---:|---:|---:|---:|
| Master host, `tube` (before the dumb host) | 21.14 | 8.17 | 20.70 | 6.43 | 5.06 |
| Master host, 4233af7 | 16.52 | 6.91 | 17.42 | 6.55 | 6.29 |
| merge (cfaf5a5) | 16.49 | 6.92 | 17.42 | 6.55 | 6.29 |
| + polygon rows streamed (cb4cde4) | 16.50 | 7.30 | 17.55 | 6.55 | 6.29 |
| + disc spans streamed (c340204) | 16.93 | 7.31 | 17.79 | 6.59 | 6.33 |
| + kept rows (bda7941) | 16.93 | 8.47 | 18.00 | 6.59 | 6.33 |
| + r_dspin (160216f) | 17.86 | 8.53 | 18.56 | 7.01 | 6.91 |
| + lines without dirty extents (96d146e) | 17.91 | 8.64 | 18.61 | 7.04 | 6.92 |
| + star records before C_BUF (f1ed4fb) | **18.02** | **8.65** | **18.70** | **7.04** | **6.92** |
| Model B host, `tube` | 19.13 | 6.71 | 18.84 | 5.89 | 4.50 |
| Model B host, 4233af7 | 12.61 | 5.95 | 14.53 | 5.35 | 4.97 |
| merge (cfaf5a5) | 12.60 | 5.96 | 14.53 | 5.35 | 4.97 |
| + polygon rows streamed | 12.61 | 6.25 | 14.62 | 5.35 | 4.97 |
| + disc spans streamed | 12.66 | 6.26 | 14.66 | 5.37 | 4.98 |
| + kept rows | 12.65 | 7.32 | 14.84 | 5.37 | 4.98 |
| + r_dspin | 14.17 | 7.49 | 16.02 | 6.17 | 5.98 |
| + lines without dirty extents | 14.18 | 7.59 | 16.05 | 6.18 | 5.98 |
| + star records before C_BUF | **14.78** | **7.60** | **16.42** | **6.23** | **6.01** |

Against 4233af7: Master host flight +9.1%, docking +25.2%, 0-3550 +7.3%,
the beach balls +7.5% and +10.0%; Model B host flight +17.2%, docking +27.7%,
0-3550 +13.0%, the beach balls +16.4% and +20.9%. Docking and the beach
balls are now faster than on `tube` (before the dumb host) on both hosts;
flight is still below it (18.02 against 21.14, 14.78 against 19.13).

**What each piece cost or saved:**
- *The merge*: nothing (±0.03). On the Tube, kept rows were off until
  bda7941 (KMODE stayed 0).
- *Polygon rows streamed*: docking +5.5% (Master host) / +4.9% (Model B):
  the host fills a polygon's rows while the parasite produces the next
  ones, and no longer receives tables first. Flight unchanged: polygons are
  small there.
- *One-pass polygons*: kept out. Wired to p_emit, they measured flight 16.50
  (no change) and docking 7.40 against the streamed two-phase path's 7.30
  (Master host), but they are not exact: for a bow-tie sliver (vertex x
  rounding) the one-pass walk fills both lobes, the two-phase path only the
  lobe of its middle row (2 title-screen frames differed). An exact form has
  to buffer each polygon's first half; with ~600 bytes of overlay S for
  ~1% that space went to the kept rows instead. In the tree under
  OPTUBE = FALSE (gfx-raster_onepass.asm, test_onepass.py,
  ONEPASS-REPORT.md); the Master port has ONEPASS = FALSE.
- *Disc spans streamed* (the one-pass form for disc and beach-ball spans:
  each span leaves as it is made, no row buffer): flight +2.6% on the Master
  host, beach balls +0.6%; the Model B host, the slower, gained little until
  r_dspin.
- *Kept rows*: docking +15.9% (Master host) / +16.9% (Model B); nothing
  elsewhere (K mode only runs near a station).
- *r_dspin*: flight +5.5% / +12.0%, beach balls +6.4%..+9.2% / +14.9%..+20.1%.
- *Lines without dirty extents*: docking +1.3%.
- *Star records before C_BUF*: flight +0.6% / +4.2%.
- *Stars otherwise*: no one-pass form. The parasite cannot know which star
  pixels the host found black, so the records must come from the host; a
  one-way "erase what you plotted" would have the host keep per-buffer
  records, which the rule forbids. The relay stays, only earlier.

**Kept rows on the Tube** (docs/TUBE-MAP.md): as full-master's, but the state
needs no array: a kept row is never a disc row, so its R_DISCL is 255 and
its R_DISCR free; kept = (255, the colour byte v), pending = (0, v). The
Master port reads v from the screen, which here is the host's. A pending
row's settle sends nothing when the span and colour are unchanged, black for
the old pixels outside the new span (after the polygon's stream), and of the
new span only what the row lacks. One deviation, invisible in the pixels:
rows that are disc rows of the buffer are never kept (on the Master port
they can be, and the next frame's band forgets them).

**Parasite free bytes** (were: resident 28, overlay S 248, overlay D 1,922,
high area 188): resident 13 (&D3F3-&D3FF), overlay S 73, overlay D 1,922,
high area 9, the workspace (p-ws.asm) 9. Hosts: Master main RAM 1,273 free
to &3000; Model B bank P &8000-&84AC (4,179 free), main RAM 194.

**Not done, and why:**
- An exact one-pass polygon form (see above): no overlay S left for it.
- More parasite space, if it is wanted next: TT151, TT163 and TT16 (195
  bytes) run only on direct-mode screens and could join overlay D; the
  quarter squares' and the log tables' page alignment leave 84 and 26 bytes
  of padding in the resident run; 243 bytes freed there move the overlay
  region down a page (+256 bytes for overlay S).
- Flight is limited by the parasite (the host idles ~40% of an iteration):
  the game itself plus the disc layer's bookkeeping. Faster flight now needs
  parasite cycles.
- Not run on real hardware.

## The dumb host (branch `dumbhost`, 2026-10-23)

The host now only draws (lines, points, spans, text, the panel), does the I/O
and stores the parasite's overlay images; everything that decides what to
draw is the parasite's (DUMB-HOST-AUDIT.md; maps and protocol in
docs/TUBE-MAP.md). Commits on `dumbhost` (not pushed): 7864497 (phases 1-3:
overlays, the panel on the host, the renderer's bookkeeping on the parasite),
7780c71 (phase 4: requests on register 2, HLOIN and PIXEL on the host),
37e8fc7 (phase 5: the disc layer's spans batched, no x4_ stubs), and phase 6
(the host shrink).

**Moved to the parasite:** the disc layer with its repair (two-colour rows
repainted whole), phase B's row bookkeeping and the dirty extents, the star
records' scheduling, the beach ball's meridian window (with the run's quarter
squares), the lens flare's geometry, the sights, the text map and its diff
against each buffer, the frame's buffer choice and flip. **Moved to the
host:** the panel's drawing, Master's LOINQ, HLOIN3 and PIXEL (the parasite
draws nothing: SCEOR and SCSTA are assembly errors there).

**Overlays:** D (direct-mode cold code, 7,294 bytes) or S (the renderer's
parasite part, 8,968 bytes with 2,323 of state) in &D400-&F7FF. A load is
84-89 ms of host time; 13 loads in run1's iterations 0-4000.

**Host code left:** Master host main RAM &1EDC-&2B8E (1,137 bytes free to
&3000), bank 5 &8000-&8073 and &9000-&BC6A (the row runs, R_SPAN, R_DOT, the
stars, the line code's cold part), ANDY &8000-&88C9 (phase B's fill, the
line loops), bank 6 code &8000-&9BA3; banks 4 and 7 hold the overlay images.
Removed: the disc layer, the repair and the flare (5K of bank 5), phase A
(1.8K of ANDY), the text map, text overlay, sights and their 1.6K of maps
(bank 6), the meridian window (bank 7). Model B host: bank P &8000-&863C
(3,779 free) and &9000-&BF8D, bank F code to &A698; bank D and the end of bank
S hold the overlay images; the old bank D code (disc layer, meridian) is gone.

**Parasite free bytes:** resident 28 (&D3E4-&D3FF), workspace 9, high area 188,
overlay D 1,922, overlay S 248.

**Gates (scratch/g-p7):** the Master port byte-identical to master-ref; lockstep
clean over 16,002 iterations, pixels 0 mismatched over 0..16000 (14,611
frames), the dashboard 0 mismatched, tsavetest passing, on both hosts.

**Speed (it/s), before (branch `tube`) and after:**

| | flight 1000-1400 | docking 3420-3550 | 0-3550 | beach 300-403 | beach 5355-5457 |
|---|---:|---:|---:|---:|---:|
| Master host, before | 21.14 | 8.17 | 20.70 | 6.43 | 5.06 |
| Master host, after | 16.52 | 6.91 | 17.42 | 6.55 | 6.29 |
| Model B host, before | 19.13 | 6.71 | 18.84 | 5.89 | 4.50 |
| Model B host, after | 12.61 | 5.95 | 14.53 | 5.35 | 4.97 |

Slower, except at the beach balls on both hosts' second window and the
Master host's first: the work the host used to do in parallel (the disc
layer, the repair, the dirty bookkeeping) is now the parasite's, so the two
processors mostly take turns. In flight the host waits for the parasite about
38% of the time and the parasite for the host about 14%. By phase, Master
flight: phases 1-3 15.80, phase 4 15.79, phase 5 (batched disc spans) 16.47,
phase 6 16.52. Not done: packing F_ST (the text map's shown state: no space
is short now that the overlays exist), and folding the G_ stubs (about 80
bytes).

## Summary (candid)

**Passed**
- Game state: both hosts replay the curious run (run1) in lockstep with SNG47
  for all 16002 iterations, no findings.
- Pixels: both hosts' two buffers equal the Master port's at every frame over
  run1's iterations 0..16000 (14611 distinct frames matched, 3 sampling gaps, 0
  mismatched), and with the parasite at 24 MHz over 0..4000.
- Disc menu with real key presses (save, load, the error path, the catalogue,
  a launch afterwards) on both hosts; the saved file is the original's format
  (and byte-identical saves against SNG47 in the phase 2 lockstep).
- Speed: in flight both hosts beat SNG47 (12.7 it/s) and the Master port (19.1):
  Master host 21.8, Model B host 20.0; combat 2.9-3.2x SNG47.

**Not passed / not done**
- Beach ball planets (since the beachball merge, section at the end): with a
  meridian planet on screen both hosts are now slower than SNG47 (the gate's
  combat at Lave: Master host 7.6 it/s, Model B host 7.0, SNG47 9.3; before
  the beach ball 29.9 and 28.3). The host is the limit: the meridian window's
  geometry (on the host: the parasite has no room for it) and the disc layer's
  two-colour rows. Flight without one, docking and approach are unchanged.
- Docking (3420-3550) is still slower than SNG47 (12.6 it/s): Master host 8.2,
  Model B host 6.7 (the Master port 6.6). The plan's phase 4 (each byte written
  once) was not built: it needs a per-row model of both buffers on a parasite
  with no room for it; a cheaper coverage scheme was tried and was slower.
- Phase 3 is a first cut: polygons only; lines, dots and the dirty bookkeeping
  stay on the host.
- Full STA abs runs: not adopted on either host (numbers below).
- Not run on real hardware. The Model B host's CRTC rupture is proven only in
  jsbeeb; the display rolls briefly during disc access on the Model B (DFS
  keeps interrupts off), recovering afterwards.
- Joystick and sound on the Model B host are wired (the Model B's ADC at &FEC0,
  the SN76489 as the Master port drives it) but not checked by a test.

## Speed (it/s, run1 windows; `node tube/tools/tspeed.mjs --log scratch/curious/run1/inputs.jsonl --kind ref|m|t [--host B] --cand DISC --csyms SYMS --windows 1000-1400,3420-3550,0-3550`)

| | flight 1000-1400 | docking 3420-3550 | 0-3550 |
|---|---:|---:|---:|
| SNG47 (original) | 12.69 | 12.61 | 14.38 |
| Master port | 19.09 | 6.64 | 18.23 |
| Tube, Master host, phase 1 | 21.87 | 7.23 | 21.18 |
| Tube, Master host, + pre-erase (phase 5) | 21.90 | 7.64 | 21.38 |
| Tube, Master host, + phase 3 (final) | 21.81 | 8.20 | 22.08 |
| Tube, Model B host, before phase 3 | 20.00 | 6.36 | 19.59 |
| Tube, Model B host, final | 20.00 | 6.71 | 20.20 |
| Tube, Master host, parasite at 24 MHz | 29.52 | 8.30 | 27.42 |
| Tube, Model B host, parasite at 24 MHz | 22.41 | 6.76 | 22.71 |

By pilot phase (`node harness/mcompare.mjs --iters 2000 --loose [--cand ... --csyms ... --tube Master|B]`,
flight it/s, SNG47 / candidate): 

| | combat | hyperspace | approach | all |
|---|---:|---:|---:|---:|
| SNG47 | 9.27 | 9.13 | 15.75 | 12.99 |
| Master port | 24.77 | 21.78 | 13.93 | 15.99 |
| Tube, Master host | 29.94 | 26.63 | 15.42 | 18.01 |
| Tube, Model B host | 28.30 | 25.34 | 13.37 | 15.86 |

(`MCOMPARE PASS` for all three: game state identical over the 2000 iterations with `--loose`.)

## Verification commands

- Lockstep: `TUBE=Master|B node master/tools/agentplay/replay.mjs --run scratch/curious/run1 --out DIR --until 16000 --noobserve --cand tube/build/elite-tube[-b].ssd --csyms tube/build/psyms.txt` → `REPLAY CLEAN ... 16002 iterations compared, 29887 reads, findings 0` (both hosts, final build).
- Pixels: Master reference `node master/tools/agentplay/fbreplay.mjs --log scratch/curious/run1/inputs.jsonl --out scratch/fbref --cand master/build/elite-master-sng47.ssd --csyms master/build/symbols.txt --from 0 --to 16000`; candidate `node tube/tools/tfbreplay.mjs --log ... --out DIR --cand tube/build/elite-tube[-b].ssd --csyms tube/build/psyms.txt [--host B] --from 0 --to 16000`; compare `node tube/tools/fbcmp.mjs scratch/fbref/fb.json DIR/fb.json --to 15999` → `14611 matched, 3 sampling gaps, 0 mismatched` (both hosts). Sampling gaps are frames one side's hash point did not see (timing), not differences.
- Faster parasite: `TUBEMHZ=24` before the tools above.
- Disc menu: `node tube/tools/tsavetest.mjs --host Master|B` (exit 0; screenshots in scratch/tsave-*/).
- Host profile: `node tube/tools/thprof.mjs ...` (Master host), parasite waits included.

## Phases

### Phase 0: spikes
Harness: `harness/tlib.mjs` (jsbeeb Model B with sideways RAM in slots 4-7 and Master, each with the Tube65C02 at 3 MHz with fractional cycles and parasite hooks). Register 1 polled: 20 host cycles a byte (97 KB/s), 17.5 with dispatch. Register 3 by the parasite's NMI: 24.7 host cycles a byte but the parasite spends 92% in the NMI: not used. The CRTC vertical rupture works on both hosts (`tube/spike/rupture.*`, `screenshots/tube/rupture-front0/1.png`).

### Phase 1: the parasite build
The Master game and frame layer relinked flat on the parasite (`tube/src/p-*.asm`, `_TUBE`/`_TPART`), the Master port's rasteriser on the host; every T_ trampoline became a command. Playable end to end on a Master host (the Model B host came later, below).

### Phase 2: host services
Keys, joystick buttons and the vsync wait as requests; sound commands; Master's own dashboard code on the parasite writing bytes (C_SCEOR/C_SCSTA); disc commands through the MOS's Tube code (C_OSCLI, hwrch). Fixed in this session: hwrch lost X and Y (the DFS catalogue never ended), now kept, with the MOS's text cursor kept in step.

### Phase 3: offload — see its section below.

### Phase 4: not built as planned
The per-row merge needs, on the parasite, both buffers' row contents (or at least a run model of each): there were 626 bytes free. Tried instead (commit 424e65e, then removed in 2b81b59): the parasite computed the ships' per-character-row coverage (conservative, 16-bit DDA) and the host's repair skipped covered bytes. Pixel-exact, but the docking window went from 276k to 303k host cycles an iteration: the coverage maths (~64k parasite cycles) ran while the host waited, for ~38k host cycles of erase saved.

### Phase 5: polish
- Pre-erase (2b81b59): the host blacks the next back buffer's old dirty rows in its idle time. Docking 7.22 → 7.64 it/s.
- Master host options: shadow-RAM double buffering and 65C12 code (the Master port's).
- Faster co-processors: pixel-exact at 24 MHz; speed above (the host is the limit at docking).
- Pipelining beyond the pre-erase was not built: at docking the parasite already waits ~80% of its time for the host.

### Phase 6: verification — see the summary and commands above.

### The Model B host
Built from the same sources (NMOS by `tube/tools/nmos.py`), four sideways banks (D, P, F, S), main RAM taken from the MOS and swapped for disc commands, buffer 0 at &1000, buffer 1 and the panel at the Master port's &4000 and &7000, the dashboard split by a CRTC rupture, a loader that finds and patches the sideways RAM banks. Details in `docs/TUBE-MAP.md`. Its single set of row runs is patched per buffer on first use, which costs ~27k cycles an iteration at docking (all 24 pages flip every frame); moving that into idle time did not help (the host is the bottleneck there).

### Screenshots
`screenshots/tube/`: `master-it1200.png`, `master-it3480.png` (Master host in flight and docking), `modelb-it1200.png`, `modelb-it3480.png`, `modelb-it5076.png` (Model B host; the short-range chart), `rupture-front0/1.png` (phase 0), `boot.png`; disc menu runs in `scratch/tsave-Master/`, `scratch/tsave-B/` (untracked).

## Risks
- Real hardware: the rupture's timing (timer 1 against the 6845's frames) and the DFS's interrupt-off periods; a Model B with sideways RAM in other slots (the loader patches the banks; tested only with slots 4-7); 8271 vs 1770 DFS (the Model B path assumes DFS 1.2's workspace at &0E00-&10FF).
- The parasite's high area: the client OS's copy is swapped out during play; a BRK outside a disc command would land in game code.
- nmos.py's liveness is conservative but not proven; the pixel and lockstep runs cover what run1 exercises.


## Evaluation: full `STA abs` screen runs on the host (user request, 2026-10-21)

**Question.** Replace today's row runs (one 256-byte page per character row, `STA abs,Y`
with Y = the line in the row, 5 cycles a store, 6K for all 24 rows) with one `STA abs`
per screen byte (4 cycles a store), on the Model B host and on the Master host (where,
following the user's follow-up, both buffers sit at the same address, main and shadow
RAM, as in the Master port, so one set of runs serves both).

**Size.** A line is 64 bytes: its run is 64 `STA abs` (192 bytes) plus an RTS (193). One
buffer: 192 lines x 193 = 37,056 bytes, plus the entry tables (run address per line, lo
and hi, and the line's bank: 576 bytes): **about 37.6K**. The panel (56 lines) is not
filled by the rasteriser and needs none. Two buffers at different addresses (the Model B
host) need two sets: **75.3K**, more than the Model B's 64K of sideways RAM before
anything else. The runs can be generated at load time (a 6502 loop writing 37K takes
about 0.4 M cycles, a fifth of a second), so the disc need not carry them.

**Placement and entry.** A run must not straddle sideways banks, and the code that
enters it cannot be in the window it pages out: 84 lines fit a 16K bank, so one set
takes about 2.3 banks (on the Master host: banks 4 and 7 whole and 24 lines of bank 6,
whose frame-layer part leaves 11K free), and the span routine that enters the runs
(phase B's row fill, the disc layer's spans, the dirty repair, the stars' and the
flare's spans) must move to main RAM (about 9K is free on the Master host) and page
the line's bank in for each span (ROMSEL and &F4: about 18 cycles a span more than
today's in-bank entry, the RTS planting is the same: a store of &60 into the run at the
span's end and its restoration).

**Measured store counts** (the Master port over the curious run's log,
scratch/runcount.mjs; screen writes per iteration, of which row-run stores, and the
number of runs entered):

| Window | screen writes | row-run stores | runs entered | saving at 1 cycle a store | extra entry cost | net |
|---|---:|---:|---:|---:|---:|---:|
| flight (iterations 1000-1399) | 401 | 174 | 9 | 174 | ~160 | ~0 |
| docking approach (3420-3549) | 15,065 | 14,060 | 437 | 14,060 | ~7,900 | **~6,200 cycles an iteration** |

Against the Master port's ~302K cycles an iteration in the docking window that is about
2%; on the Tube host, which does only the drawing, about 3-4% of its frame. In
ordinary flight the saving is nil.

**Model B host.** Two buffers at different addresses need two sets (75K): impossible.
One set for one buffer (37.6K) would fit beside the rest of the host (which needs
about 20K of sideways RAM) only if the other buffer kept row runs, giving alternate
frames different costs for a gain of ~2% on half of them; full runs for part of the
screen (say the middle 96 lines, 18.8K per buffer, 37.6K for both) save at most half
of the above. Neither is worth its 37K. **Not adopted on the Model B.**

**Recommendation and decision.** On the Master host one set fits (shadow RAM double
buffering, as the user asked), but it buys ~2% at docking and nothing in flight, at the
cost of 37K, a span routine moved to main RAM and a bank switch per span. It is not
worth retrofitting into today's rasteriser (phases 1-3 keep the row runs). It was to
be the Master host's store path in phase 4's byte writer; phase 4's byte writer was
not built (see "Phase 4" above), so **full STA runs are not adopted on either host**. The Master host keeps the
shadow-RAM layout (buffer 0 main, buffer 1 shadow, ACCCON X for the CPU, D for the
display), superseding "both buffers in main RAM" for the Master host only; the Model B
host keeps its own layout.

## Merge of full-master (2026-10-21, coordinator request)

full-master d3b2125..7170894 merged into `tube` (merge commit db62379): b796a8b
fills the Adder's back (faces 6-8; master/src/gfx-faces.asm, master/tools/faces.py)
and 7170894 fixes harness/mlight.mjs. Clean merge. The Master build on `tube`
is byte-identical to full-master 7170894's own build (built from a detached
worktree), so scratch/master-ref.ssd was renewed from it. The pixel oracle's
Master reference (fbreplay over run1) is regenerated from the merged build for
the verification below, since frames with an Adder seen from behind change.

## Phase 3: offload (coordinator priority, 2026-10-21) — commit 228c139

**Built.** R_POLY's phase A (clipping and edge walking, both the 8-bit and the
16-bit paths) runs on the parasite: the Master port's own code
(`master/src/gfx-raster_poly.asm` assembled with `_TPART = 1`), in
`tube/src/p-polya.asm` (R_POLY, r_pf8, the arithmetic, in the parasite's last
free bytes below &F800) and `tube/src/p-polyb.asm` (from r_e8, plus `p_spans`,
in the high area &F800-&FEEF, which is now used: `TUBE_HIGH`, swapped with the
client OS's copy through the host around each disc command). `C_POLY` now
carries the colours, the clip flag, the first and last rows and each row's
left/right table entries (2 bytes a row); the host stores them and enters the
rasteriser at `r_pcbd` (orientation, horizontal clip, trimming, the dirty row
range, phase B) unchanged. Both hosts. Lines, dots and the per-buffer dirty
bookkeeping stay the host's in this first cut (the bookkeeping is phase B's
own per-row update, which needs the host's state; moving it would mean the
parasite keeping both buffers' extents).

**Gate.**
- Pixels against the Master port (fbreplay over run1, reference regenerated
  after the full-master merge): Master host 0..4000 3473/3475 distinct frames
  matched, 2 sampling gaps, 0 mismatched; docking 3400..3600 151/151 matched.
  Model B host 0..4000: 3473 matched, 0 mismatched.
- Disc menu (`tube/tools/tsavetest.mjs --host Master|B`): passes on both.

**Speed** (`node tube/tools/tspeed.mjs --log scratch/curious/run1/inputs.jsonl
--kind t [--host B] --cand ... --csyms tube/build/psyms.txt --windows
1000-1400,3420-3550,0-3550`), it/s:

| | flight 1000-1400 | docking 3420-3550 | 0-3550 |
|---|---:|---:|---:|
| Master host, phase 5 (before) | 21.90 | 7.64 | 21.38 |
| Master host, phase 3 | 21.81 | **8.20** | **22.08** |
| Model B host, before | 20.00 | 6.36 | 19.59 |
| Model B host, phase 3 | 20.00 | **6.71** | **20.20** |

Docking gains 7% (the host no longer walks edges; the 2 bytes a row it
receives cost less than phase A did). Flight is 0.4% slower on the Master host
(the parasite's extra work sits on the critical path when few rows are filled)
and unchanged on the Model B; overall faster, so phase 3 is kept.

## Experiment: kept spans (single-span rows, then "largest span as a resource") — not a win, kept out of the build

Request: remember, per buffer and per pixel row, a filled span; on the next
frame for that buffer don't erase it, and paint only what the new span does
not already cover in the same colour. First as "rows holding exactly one
span", then generalised (user refinement) to "the largest span of the row,
trimmed by whatever else lands on it, gated on size".

**Measurements (Master host, run1, the phase 3 build).** Frame buffers were
dumped at each C_SYNC and compared with the same buffer's previous frame;
polygon coverage per row came from hooking the host's C_POLY.

| | docking 3420-3550 | flight 1000-1400 | 0-3418 |
|---|---|---|---|
| polygon spans drawn per frame | 353 | 0 (planet only) | 43 |
| rows with polygons in both frames | 135 | 0 | — |
| single-span rows (one polygon, one uniform run, both frames) | 33 (27 identical) | 0 (the 88 single-run rows are the disc, which has its own incremental code) | — |
| single-span: stores saved (erase + paint) | 4,130 a frame (~17k cycles) | 0 | — |
| largest span kept (pixel-level bound, KMIN 1 / 8 / 16 / 32 bytes) | 4,235 / 4,205 / 3,968 / 2,981 bytes a frame (~34k / 34k / 32k / 24k cycles at 8 cycles a byte) | 0 | — |
| replay of the actual span sequences, first-touch rules (tube/experiments/spansim.py), KMIN 8 | 4,482 bytes kept, 137 rows settled, 308 of 353 spans land on a row with a kept span | 0 | 0.2 bytes a frame |

Upper bound: the generalised version saves ~36k host cycles a docking frame of
~244k (+15%, 8.20 -> ~9.6 it/s) if the bookkeeping were free; the single-span
version about half that. Flight: nothing (1000-1400 draws no polygons; the
rest of the run has small, moving ships: 0.2 bytes a frame kept).

**Prototype (generalised, host-side bookkeeping, KMIN 8).** Built on the
Master host (tube/experiments/kept-spans.patch: h-spank.asm in HAZEL
&C300-&CA05 with its arrays at &D000-&D5FF, copied from bank 6 by hstart;
hooks in phase B, r7_rowrep, f_glyph, and C_FB/C_FE/C_DISC/C_LINE/C_DOT/
C_SPAN/C_FLARE; commands that leave space mode black every pending kept span
and forget them). The pre-erase leaves kept bytes and marks the row pending;
the frame's first write settles it (a polygon span: black only the kept
bytes outside its interior, fill only the interior bytes not already kept in
its colour; anything else: black the overlapping kept bytes); C_FE blacks
what is still pending, then trims by the stars, sights and disc rows. Model B
and the Master port unaffected (byte-identical).

Bookkeeping lives on the host because the pre-erase, the dirty extents, the
clipped span ends and the text/sight/star overlays are all host-side; the
parasite would have to mirror all of them.

Result: pixels exact over the docking window (3400-3560: 151 matched, 0
mismatched; the full 0..4000 and SNG47 gates were not run, as the build is
not kept), but **slower everywhere**:

| it/s | flight 1000-1400 | docking 3420-3550 | 0-3550 |
|---|---|---|---|
| phase 3 (kept) | 21.81 | 8.20 | 22.08 |
| kept-spans prototype | 18.41 | 5.34 | 18.92 |

Why: docking overdraws heavily (353 spans a frame on 135 rows, ~2.6 a row),
so almost every span lands on a row that has a kept span and pays the
overlap/trim test (~50-120 cycles), and r7_rowrep's split of a kept row (two
general-path row erasures) costs ~250 cycles against its ~4 cycles a byte
saving. The cost model from the replayed sequences (spansim.py) puts host
bookkeeping at ~110k cycles a frame against ~36k saved (KMIN 32: ~64k against
~28k); raising KMIN does not close the gap. Moving the per-span tests to the
parasite (idle ~70% at docking) would leave the host with the settles and the
row splits, which the same model puts at ~35k against the ~36k saved:
break-even at best, for docking only, at the cost of mirroring the host's
overlay state on the parasite. Not pursued.

Decision: not built in. The prototype is kept as a patch
(tube/experiments/kept-spans.patch, against a6eb806) with the measurement
tools (spanpix.py: pixel classification; spanbound.py: the largest-span
bound; spanrec.mjs: record each frame's spans, lines and disc rows;
spansim.py: replay them through the kept-span rules with a cycle model).
tube/tools/thprof.mjs now labels HAZEL (&C300-&CFFF) code instead of lumping
it in with the MOS.

## Beach ball planets (merge of `beachball`, 2026-10-21)

`beachball` (full-master 85b264a: BEACHBALL-REPORT.md) merged into `tube`.
Meridian planets (TYPE 128, Lave among them) are drawn as the Master port's
beach ball on both hosts, pixel for pixel.

**Merge.** One conflict: elite-gfx.asm's constants, which `tube` had moved to
gfx-ws.asm (shared with the Tube's host); MERIDBANK and MERIDHOLD went there.
The Master build on `tube` is byte-identical to beachball's own (85b264a). The
pixel oracle scratch/fbref and scratch/master-ref.ssd are renewed from it
(the plain-disc ones kept as scratch/fbref-plaindisc and
scratch/master-ref-plaindisc.ssd; scratch/ is untracked).

**Where the geometry runs: the host.** The meridian window (PM_HOOK and
PM_MERID, gfx-merid.asm) is 3.3K; the parasite has about 300 bytes free
(104 below &F800, 121 in the high area, 81 in the workspace), so it runs on
the host, in sideways RAM, as the user's fallback allowed:

* the parasite keeps H_MERID (gfx-hooks.asm; K2 and TGT as PL9 leaves them).
  Its G_MERHOOK (p-glue.asm) sends C_MERHOOK: roofv and sidev
  (INWK+15..26), K3, K4, MCNT, PM_R (19 bytes), and sets PM_OK. The host runs
  PM_HOOK at once, in the parasite's game time, when it is otherwise idle;
* f_bounds' T_MERID (p-io.asm) marks the planet's C_DISC R_NDF = &81: its
  rows carry the spans only (no boundary bytes through the Tube). The host
  runs PM_MERID on them (the rows' boundaries need the spans: PM_MERID clips
  each crossing to its row's span) and then R_DISCROWS;
* the host's window is tube/src/h-merid.asm: the quarter squares (1K: the
  host has no QSL/QSH), PM_IN, C_MERHOOK's receiver, then gfx-merid.asm
  assembled with _TPART = 2: PM_HOOK reads PM_IN for INWK, K3, K4 and MCNT
  (symbols PM_V, PM_K3, PM_K4, PM_MCNT), and with MERIDHOLD = 0 the held
  orientation's paths (kept and moved rows, radius-only and centre-only
  constants: dead at MERIDHOLD 0) are left out (PM_HELD). The Master port
  assembles exactly as before (byte-identical);
* Master host: bank 7 &8000-&8F06 (HMERID on the disc, a new FTAB entry in
  the loader), C_MERHOOK through h_merhook, the rows through gfx-tramp.asm's
  T_MERID from h_disc;
* Model B host: bank D after the shared code, &A748-&B72B (NMOS, by nmos.py
  with two --sub fixes; 212 bytes left before the disc inputs at &B800), next
  to the disc inputs it writes; C_MERHOOK through hb_merhook (main RAM) and
  bank D's jump table (D_MERHOOK), the rows from d_disc. GVARS gained PM_OK,
  PM_R and PS_VALID (hb-ws.asm). h_disc's Master body is now under ELSE for
  the Model B (bank F: 256 bytes back).
* the parasite's frame layer and the game are otherwise unchanged (the run
  grew 3 bytes; the high area and the workspace are as they were).

**Verification** (all on the final build; run1 is scratch/curious/run1):
* Lockstep against SNG47: `REPLAY CLEAN ... 16002 iterations compared,
  29887 reads, findings 0` on both hosts.
* Pixels against the Master port (the beachball build, fbreplay over run1;
  run1 shows a beach ball at iterations 301-402 and 5355-5456, Lave and a
  second meridian planet): both hosts `14611 matched, 3 sampling gaps, 0
  mismatched` over 0..16000 (`fbcmp.mjs ... --to 15999`). The two hosts'
  frames are identical over 0..16000 (14614 distinct frames), and outside
  the beach ball iterations both equal the plain-disc oracle
  (scratch/fbref-plaindisc) frame for frame. The window's constants, spans and rows at PM_MERID/R_DISCROWS
  (iterations 301-304) equal the Master port's byte for byte on both hosts
  (a recorder that hooks PM_MERID and R_DISCROWS on each build).
* Disc menu (`tube/tools/tsavetest.mjs --host Master|B`): passes on both
  (E.TESTA 256 bytes, the commander block; 4 disc commands, the error path).
* `harness/mcompare.mjs --iters 2000 --loose --tube Master|B`: MCOMPARE PASS
  on both.
* Screenshots: screenshots/tube/master-beach-it341.png (Master host, Lave
  just after launch), modelb-beach-it5421.png (Model B host, the second
  meridian planet).

**Speed.** run1 windows (`tube/tools/tspeed.mjs`), it/s; 300-403 and
5355-5457 are run1's two beach ball windows:

| | flight 1000-1400 | docking 3420-3550 | 0-3550 | beach 300-403 | beach 5355-5457 |
|---|---:|---:|---:|---:|---:|
| SNG47 | 12.69 | 12.61 | 14.38 | 8.11 | 9.09 |
| Master port (beachball, MERIDHOLD 0) | 19.07 | 6.64 | 17.46 | 6.28 | 4.80 |
| Tube, Master host, before | 21.81 | 8.20 | 22.08 | 13.50 | 11.71 |
| Tube, Master host, after | 21.75 | 8.19 | 20.97 | 6.52 | 5.12 |
| Tube, Model B host, before | 20.00 | 6.71 | 20.20 | 12.67 | 10.99 |
| Tube, Model B host, after | 19.84 | 6.72 | 19.13 | 5.96 | 4.55 |

("Before" is `tube` a3d9090, drawing Lave as a plain disc.) By pilot phase
(`harness/mcompare.mjs --iters 2000 --loose`; the gate's pilot starts at
Lave, so its combat and hyperspace phases have a beach ball on screen), flight
it/s:

| | combat | hyperspace | approach | all |
|---|---:|---:|---:|---:|
| SNG47 | 9.27 | 9.13 | 15.75 | 12.99 |
| Master port (beachball) | 7.14 | 6.56 | 13.91 | 10.75 |
| Tube, Master host, before | 29.94 | 26.63 | 15.42 | 18.01 |
| Tube, Master host, after | 7.59 | 6.85 | 15.36 | 11.65 |
| Tube, Model B host, before | 28.30 | 25.34 | 13.37 | 15.86 |
| Tube, Model B host, after | 6.96 | 6.35 | 13.34 | 10.38 |

Without a beach ball on screen nothing changed (flight, docking, approach).
With one the Tube is now slower than SNG47, as the Master port is: the Master
host 4-7% faster than the Master port there, the Model B host 5% slower; a
24 MHz parasite changes nothing (300-403: 6.67 it/s, Model B host 6.03). Why (Master host, iterations 300-403, `tube/tools/thprof.mjs`): the host is the
limit, 285K cycles an iteration (the parasite waits 85% of its time). Of
those, the meridian window takes 92K (PM_HOOK 21K, the row loop 71K) and the
disc layer's two-colour rows about 108K (r_dq, r_dpe, r_dmb: the Master port's
own cost, BEACHBALL-REPORT.md); before, the plain disc's took about a third of
that.

**Tried and not kept: the row loop on the parasite** (patch:
tube/experiments/merid-rows-parasite.patch, against 6b5a8b2). To make
room: the parasite's font goes (it draws no glyphs; H_CHAR's W comes from a
96-byte table of each glyph's first-byte nibble, placed in the font's old
alignment padding), the high area grows by &FF00-&FFF9 (C_SWAP swaps it too),
PM_MERID is split in three (the end of the frame layer, &F800 and &FF00) with
its data in the workspace and PM_BLK at &0CCF; the host keeps PM_HOOK and
answers C_MERGET (44 bytes) at the frame's start. Pixel-exact (0..800 on both
hosts) and the disc menu passed, but it bought only 6.52 -> 6.83 and
5.12 -> 5.23 it/s (Master host): the host's meridian time fell from 92K to
23K cycles, but the host then waited 46K cycles for the parasite's rows, which
come between C_FB and C_DISC with nothing else for the host to do. It left
13 bytes free below &F800, so it was not kept. Overlapping the rows with the
host's work would need them a frame early (they need the frame's spans and
constants) or the disc layer drawn after the ships; neither is the Master
port's order.
