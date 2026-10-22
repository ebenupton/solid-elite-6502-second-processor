# Kept solid rows: cheaper close-up docking

Branch `solidspan` (worktree `~/elite-full-solid`), from `full-master` at
85b264a (beach ball planets). Not merged, not pushed.

The idea (the user's): when a filled span is one byte value, note it, and on
that buffer's next frame don't erase it; if the next frame paints the same
value there, those bytes are neither erased nor rewritten, and only what
nothing covered is cleared.

## Result

| run1 (it/s) | before (85b264a) | after (solidspan) | |
|---|---:|---:|---:|
| docking 3420-3550 | 6.64 (301,124 cycles an iteration) | **7.16** (279,208) | +7.8% |
| 3484-3500 (station filling the screen) | 5.44 (367,903) | 6.93 (288,731) | +27% |
| 3500-3515 | 4.98 (401,943) | 6.35 (315,040) | +28% |
| 3515-3530 (the slot growing) | 4.60 (435,180) | 4.99 (401,144) | +8.5% |
| flight 1000-1400 | 19.07 (104,864) | 19.06 (104,951) | -0.08% |
| 0-3550 | 17.46 | 17.58 | +0.7% |
| **gate** (verify.sh) | VERIFY PASS 0.857, 11.98 | **VERIFY PASS 0.857, 11.98** | |

Single frames in the last seconds of the approach run up to 27% faster
(3496: 378,368 cycles before, 276,540 after). Pixels are identical to the
current build over all of run1 (iterations 0-3600, frame hashes of both
buffers after every frame: 3,320 frames matched, 2 sampling gaps, 0
mismatched), and over a second run with two more dockings (agentplay
campaign1 eff-s2, iterations 0-9000), where those dockings gain 7.6% and
10.6% (12% and 18% over their last 65 iterations).

Speeds are from `master/tools/solidspan/mspeed.mjs` (replays run1, the
log the Tube report used, `~/elite-full-tube/scratch/curious/run1/inputs.jsonl`,
and times iterations exactly at MLOOP).

## The measurement first: the upper bound

`master/tools/solidspan/srec.mjs` replays run1 over the docking window
(3400-3560) and records, per frame, the buffer drawn and every polygon span
phase B draws (row, ends, colour byte), plus lines, dots, spans and marks;
`sbound.py` compares each buffer with that buffer's previous frame
(131 frame pairs, 3420-3550). Bytes "kept" are whole bytes of a uniform,
non-zero run in the old frame that hold the same value in the new one; each
saves its erase (STA abs,Y in the repair's row run, 5 cycles) and its fill (5).

| what is kept | bytes a frame | cycles a frame (10 a byte) | of 301k |
|---|---:|---:|---:|
| every uniform run (any scheme's bound) | 5,038 | ~50,000 | 17% |
| the largest run per row, >= 8 bytes | 4,239 | ~42,000 | 14% |
| the largest run per row, >= 32 bytes | 2,988 | ~30,000 | 10% |
| rows that are one run end to end ("full rows") | 2,291 (51.7 rows) | ~23,000 | 7.6% |

The gain is concentrated: before iteration 3482 no row of the station is a
single run (each row crosses two or three faces, about 550 spans a frame),
from 3484 to ~3520 most rows are one face from x = 2 to 253 (140-150 rows a
frame), and from ~3510 the docking slot splits more and more rows into three.

`ssim.py` replays the recorded spans through the rules below (with the
kills for lines, dots and spans, and each kept row checked against the
frame's real buffer): 33 rows kept a frame on average over the window,
2,004 erase and 1,998 fill bytes saved a frame (~20,000 cycles), before
bookkeeping. The thresholds do not matter for full rows (KT 1..32 give the
same: a station row is 60 bytes wide).

## What it does

**Full rows only**, so that the bookkeeping fits in one byte a row and the
spans need no bounds of their own: a row is *kept* in a buffer when the last
thing drawn on it there was one polygon span covering the row's whole dirty
extent, at least KT = 8 whole bytes, not black. The dirty extent (DIRTY,
already per buffer) is then the kept span. KF[y] (192 bytes, HAZEL after
the saved data, gfx-kept-hz.asm): bit 0/1 = kept in buffer 0/1, bit 7 =
pending this frame.

* **K mode** (T_KFRAME, before each frame): only while the space station
  (SST or DOD) is recorded with z < &200 inside the safe zone, and, once K
  mode has run three frames, only while the repair keeps finding at least 16
  kept rows (else it sits out 4 frames). Outside K mode nothing below runs and
  KF is all zero; the cost is a few BIT KMODE tests (about 90 cycles an
  iteration in flight, 330 in docking frames outside K mode).
* **Repair** (r7_rowrep in K mode: krow): a kept row is left as it is, made
  pending (its old extent stays in DIRTY, WL/WR are set as if blacked); the
  other rows go through the usual fast path. The disc band's rows are
  forgotten (r7_crep).
* **Record and settle** (k_pre, bank 7, called from R_POLY between its
  phases through T_KPRE in the low area, once per polygon): per row of the
  polygon's edge tables, a span on a pending row settles it (k_settle);
  otherwise the row is kept if the span covers its dirty extent so far, and
  forgotten if not.
* **Settle** (k_settle): the row holds the old span (DL..DR, colour v) and
  nothing else, and is to hold the new one (XL..XR, colour w). If the span
  and colour are unchanged (most rows in the last seconds: the station holds
  still between a buffer's frames) nothing is written and phase B's row is
  emptied. Otherwise only the bytes in the zones between DL and XL and
  between DR and XR are written, with their final values (columns 0 and 63
  keep the pixels outside the clip window); if w = v the row is then
  complete and phase B skips it, else phase B draws the span as usual.
* **Everything else drawn on a row** (lines, dots, spans, R_MARKDIRTY, the
  text glyphs) first blacks a pending row's old extent and forgets the row
  (k_kill, from T_LINE, T_DOT, T_SPAN, T_MARKDIRTY and T_KROWS); the lens
  flare forgets every kept row. The laser sights' vertical arm ORs a pixel
  into column 32 of kept rows: harmless, because the sights are redrawn
  whenever their rows were written (the pending rows' WL/WR), and v is read
  from column 33 when the interior starts at 32.
* **Commit** (k_commit, after the ships): rows still pending are blacked
  (row1, as the repair would have).
* Stars are only plotted on black and erased before the repair, so they
  never meet a kept byte.

## Why this doesn't repeat the Tube experiment's loss

The Tube's kept spans (TUBE-REPORT.md) tracked every span's overlap with a
kept span and split rows on the host: ~110k cycles of bookkeeping a frame
against ~36k saved, and it slowed docking 8.20 -> 5.34 it/s. Here:

* ordinary spans pay nothing per span outside K mode, and K mode is only on
  while it pays (the skip rule): the record pass costs ~45 cycles a span row,
  which is ~25k a frame in the station's many-faced frames (3473-3482), where
  nothing is kept; the skip rule limits those to one 3-frame probe;
* a kept row is the whole dirty extent, so no bounds are stored and nothing
  is split: a settle is one comparison when nothing moved, or two short
  zones;
* the first version wrote the settle's pieces through bank 5's span core
  (r_spc via a thunk, ~800 cycles a row) and was slower everywhere
  (docking 6.01 it/s); writing the zones directly, then the unchanged-row
  test, brought the settle to ~170 cycles a row (~290 with zones).

At the fastest frame, of ~277k cycles: the record pass ~12k, settles ~24k,
krow ~7k, commit ~2k, against ~100k of runs and repair no longer done.

## Space

| region | before | after | used by |
|---|---:|---:|---|
| bank 7 (after the meridian window) | 602 | 89 | k_pre, k_settle (gfx-kept7.asm) |
| bank 5 disc window | 137 | 16 | krow, the band's clear, k_commit, k_kill, k_clear; R_INIT got shorter (-35) and r7_j3 went (-59: r_jm at 4 x the column) |
| ANDY | 38 | 27 | R_POLY's call |
| bank 6 | 64 | 30 | T_KFRAME, T_KCOMMIT and T_KOFF calls, the glyph's rows |
| HAZEL | 268 | 76 | KF |
| low area (below &3000) | 479 | 46 | the trampolines' hooks, T_KFRAME, tk_line, T_KPRE, k_setbuf7, the variables |

Nothing in shadow RAM, nothing in page &0D, nothing in HAZEL &DF00-&DFFF,
no alignment padding. (Later, 2026-10-22: KF moved from HAZEL to the shared workspace,
&1E00-&1EBF, with CODE% a page up and the run's marker before HATB: HAZEL
back to 268 free, below &3000 655, bank 4 3853 -> 3622; docs/MASTER-MAP.md.) The low area is the biggest cost (433 bytes); T_KFRAME
and k_setbuf7 could move to bank 7 if room is found there.

## Tests

* `master/tools/grind/test_raster.py` has a new test, **kept** (6 runs in
  --quick, so in every gate): multi-frame sequences on two buffers driven as
  the frame layer drives K mode (T_KFRAME's set-up, the disc layer with its
  repair and a disc in some frames, a two-face "station" mostly filling
  whole rows with a slot over it, drifting or holding still, colours mostly
  kept, small ships, lines and dots after their trampolines' k_kill,
  R_MARKDIRTY, k_commit, K mode switched off and buffers reset at random);
  every frame must equal the reference exactly. 30-120 rows are kept a
  frame. Seeds 1-8 pass. The harness now loads its HAZEL block (the K state
  and the low area's thunks) and runs the kept test after the meridian tests.
* Pre-existing, not caused here: test_raster's **beachball** test fails at
  seeds 3, 4 and 5 on 85b264a itself (PM_MERID row boundaries against the
  model), so any change to the random numbers it sees exposes it; the kept
  tests are ordered after it so seed 1 sees what it saw before.
* The gate (master/tools/grind/verify.sh): VERIFY PASS 0.857 11.98 at every
  commit (the pilot docks once; the redock, save and views regressions pass).

## Verification

* run1 0-3600 (launch, flight, the docking): frame hashes identical to
  85b264a's (`fbhash.mjs` + `fbcmp.mjs`).
* eff-s2 (agentplay campaign1, seed 2, the efficient trader: it docks at
  Leesti and at Diso in this stretch), iterations 0-9000: frame hashes
  identical (8,922 frames matched, 11 sampling gaps, 0 mismatched). K mode
  ran in 3496-3572 and 7144-7218. Speed (`itcyc.mjs`, cycles of every
  iteration):

  | eff-s2 | before | after | |
  |---|---:|---:|---:|
  | docking 1, 3470-3580 | 5.79 | 6.23 | +7.6% |
  | its last 65 iterations, 3490-3555 | 5.13 | 5.75 | +12.0% |
  | docking 2, 7120-7230 | 5.42 | 5.99 | +10.6% |
  | its last 65 iterations, 7150-7215 | 5.02 | 5.94 | +18.4% |
  | 0-9000 | 17.92 | 18.03 | +0.6% |

## Tools (master/tools/solidspan)

`common.mjs` (replay an agentplay log on a Master build; it needs banks.txt
beside the symbols, or the banked hooks are dropped and the game never
starts), `mspeed.mjs` (it/s over windows), `fbhash.mjs` and `fbcmp.mjs` (the
pixel oracle), `srec.mjs` (spans and buffers per frame), `sbound.py` (the
bound), `ssim.py` (the rules on the recorded spans), `kprof.mjs` (cycles by
label between exact iteration boundaries), `kpc.mjs` (cycles by PC in a
range), `szprobe.mjs` (the recorded ships' z), `itcyc.mjs` (every
iteration's cycles, and whether it ran in K mode).

## Not done, and what would come next

* **Rows split by the slot** (3515-3530): the largest-run bound is nearly
  twice the full-row one, mostly the rows either side of the docking slot.
  Keeping them needs per-buffer bounds (a kept span inside the extent, or a
  hole for the slot): 768 bytes visible to bank 7 and bank 5, which aren't
  free.
* KZ (&200) and the skip rule were tuned on one docking (the Dodo in run1);
  a Coriolis station, or an approach off the slot's axis, may keep fewer
  rows; the skip rule then turns K mode off, at the cost of a 3-frame probe
  every 4 frames (~25-40k cycles a probe frame).
* Not run on real hardware.
