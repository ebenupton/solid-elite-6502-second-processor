# One-pass polygon spans: prototype (branch `onepass`)

R_POLY draws in two phases: phase A walks each chain into a per-row edge table
(R_PTA / R_PTB), r_pcbd picks the orientation, clips and trims, phase B fills
the rows from the tables. The prototype, `master/src/gfx-raster_onepass.asm`
(R_SPANS), walks both chains in lockstep instead and hands each row's span on
as soon as both ends are known:

    JSR emit   Y = row, X = xl (first pixel), A = xr + 1 (exclusive)

That hand-off (fem / fem2's operand) is the seam: on the Master it would be
the row fill, on the Tube the send to the host.

## What it does

- Edge set-up is R_POLY's own: r_e8, with r7_e8c's exact clipped start.
  Under `ONEPASS`, r_e8's two DDA entries (r_pzl1, r_psh1) divert into the
  prototype (fz / fsh) when it asks (fdiv): the side's DDA is loaded (x and
  error in zero page, a, b, dy patched into the row loop) instead of being run
  down a table. Same x = x0 + ceil(dx*k/dy) per row: pixel-exact.
- Row loop (drow): both DDAs, the span's ends, an empty test, the hand-off,
  one compare for the next edge change (fseg = the nearer edge end).
  Orientation: chain A is taken as the left, swapped (dswap) the first time a
  row says otherwise, so there is no per-row min/max and no orientation scan.
  Clipping in x: a patched branch to a clamping variant (dcl), only for
  polygons with a vertex outside CL..CR. No trim pass: empty rows are simply
  not handed on.
- Not handled (C = 1, R_POLY's two-phase path draws them): any coordinate
  outside 0..255 (the 16-bit path, r7_pf16). A polygon that is not monotone
  in y (only degenerate inputs: R_POLY's faces are convex) stops at the first
  edge that does not start where the last ended.

## Results (test_onepass.py, py65, against test_raster's reference)

`GRIND_TREE=<tree> python3 master/tools/grind/test_onepass.py --seed N --n 3000`

- Exact: every handled polygon's spans equal `poly_spans` (convex, tiny,
  edge, degenerate kinds, random clip windows): 5,100+ polygons over seeds
  1-3, no mismatch.
- Cycles (the same emitter for both: JSR to an RTS), fitted over the
  polygons: one-pass **~1,590 + 101 a row**, two-phase (R_POLY up to phase
  B, then a loop reading the tables) **~1,370 + 117 a row** (that includes
  ~6 cycles an edge for the ONEPASS divert test, which the real build does
  not have). So **~16 cycles a row saved, ~220-260 more a polygon** (per edge:
  the DDA has to be saved and resumed, where phase A runs straight into its
  loop). Break-even at ~15 rows a polygon; on test_raster's mix, 3-4% fewer
  cycles overall.

## Why it is not wired into the Master build

- Space: the prototype is 606 bytes (with its variables) and must run with
  the polygon window (ANDY) paged: ANDY has 27 bytes free (the divert takes
  16 of them under ONEPASS), bank 5's shared region 107, main RAM below &3000
  none to spare. It runs from the test's HAZEL-like area here.
- Gain on the Master: phase B already reads the tables in the same loop as
  its fill, so the one-pass saving there is the table store and load only
  (~9 cycles a side a row against ~6 for zero page), less the per-edge
  save/resume; hooking the generator into phase B (JSR per row) costs more
  than it saves. And the docking window runs in K mode, whose kept-row pass
  (k_pre) reads the whole edge tables before phase B.
- `ONEPASS = FALSE` (elite-gfx.asm): the Master build is byte-identical to
  kflow 87cf524; its gate is unchanged.

## For the Tube (dumb host)

The parasite generates spans and the host fills them, so a span generator is
exactly what the parasite needs: R_SPANS's `JSR emit` becomes "send Y, X, A
(and the colour pair once per polygon) to the host" (or appends to a batch).
Compared with today's split (phase A on the parasite sending 2 bytes a row of
edge-table entries), it

- drops the two 192-byte edge tables from parasite memory (384 bytes),
- drops the orientation scan, clip and trim passes,
- sends only non-empty rows, already clipped, oriented and exclusive-ended,
- costs ~16 cycles a row less than generating spans from tables.

Still to do for the Tube: the 16-bit path (r7_pf16's clamped 16-bit DDA as a
second step form per side, chosen per edge), and batching the hand-off.
