# Beach ball planets in the full Master port

Branch `beachball` (worktree ~/elite-full-beach), from full-master 7170894.
Not merged, not pushed.

Meridian planets (TYPE 128, Lave among them) are drawn as the demo port's
beach ball again: colour B (green land) where the surface is on the same side
of both great circles (the planes normal to roofv and sidev), colour A
elsewhere. Each circle is projected exactly, so the boundaries meet the limb
and each other with no tears. Every row of every checked frame matches the
demo's reference model (tools/planet_analytic.py) bit for bit.

## Commits

| Commit | What | Gate (it/s, ratio) |
|---|---|---|
| 4e7a2d1 | Beach ball planets: the meridian window in bank 7 | 11.86, 0.849 |
| 3a36eae | The row loop adds K2 and a as immediates | 11.90, 0.851 |
| c477b06 | A planet that stays put keeps its rows for MERIDHOLD frames | 13.14, 0.941 |
| 079a121 | The orientation is taken one frame in MERIDHOLD + 1, moving or not | 13.29, 0.951 |
| 44a3cd8 | With the radius as it was, only the node rows are recomputed | 13.32, 0.953 |
| 5bdceed | A beach ball that has only moved has its rows moved | 13.46, 0.963 |
| 4b839ac | The node rows come from PM_CY, not K4 (a bug fix: see below) | **13.56, 0.971** |
| (last) | docs, this report, screenshots | (no code change) |

Before the branch, full-master read 17.24 it/s (ratio 1.234). The original
SNG47 reads 13.97.

## What "two different disc windows" can mean, and the choice

ROMSEL pages a whole 16K bank, and ANDY is the only 4K overlay. So a
"second disc window" can only be one of three things.

**A. A second bank with its own copy of the shared region and a beach-ball
disc window at &8000.** This is not possible.

* The shared region is not read-only. It holds:
  * both buffers' boundary arrays R_BD* (2,304 bytes, rewritten every frame
    by R_DISCROWS);
  * the run pages' tails (the star records, the rasteriser's and R_LINE's
    variables, the flare's state);
  * R_SETBUF's ~85 patched operand bytes, and r_dbm's 34.
* The runs are self-modified only for a moment, but the rest is live state.
  A mirror would need about 2.5K synced every frame (25K+ cycles), or all
  that state moved out.
* No bank has a free &8000-&BFFF anyway. Bank 4 is code to &B0EF, and bank 7
  is the cold area from &8000.

**B. Copy a variant into bank 5's disc window while a meridian planet is on
screen.** This is possible but pointless.

* The window (R_DISCROWS, the dirty repair, R_INIT, R_RESETBUF) is all live
  code, with 137 bytes free. Nothing in it can be evicted while a planet is
  shown, and swapping 4K means bouncing through main RAM.
* More importantly, the earlier costing was wrong on one point. R_DISCROWS
  **already** draws up to four boundaries a row (R_NDN, R_NDX0-3, R_NDP), and
  test_raster's bands, bandmix and bandjump scenarios have always exercised
  that.
* What was missing was not disc-row code. It was the geometry: the demo's
  planet4.asm, 2.7K, which bank 6 (65 bytes free) cannot hold.

**C. Split: give the beach ball's per-row boundary generator a window of its
own.** This is the option chosen. gfx-merid.asm is the "meridian window", in
bank 7 after the cold area, with its own image, MERID. It has two entry
points, each behind one stub:

* PM_HOOK runs in game context. H_MERID calls it through G_MERHOOK in place
  of PL9's equator and meridian.
* PM_MERID runs during the frame. f_bounds calls it through T_MERID before
  T_DISCROWS.

It writes the existing disc layer's arrays, so the disc window is unchanged.

Bank 4 (3,856 free) was the alternative home, and the demo used it. I rejected
it because bank 4's slack is where hot game code has to grow, while bank 7's
is spare cold-area room. The cost of the far call is the same either way.

## Memory map changes (rule bent)

* **Bent: "the renderer lives in banks 5, 6 and ANDY only."** The meridian
  window is in bank 7, &B090-&BD9D (3,342 bytes, after the cold area at
  &8000-&B08F), and is paged only by G_MERHOOK and T_MERID (MERIDBANK = 7).
  The coordinator relayed that the user is comfortable with this.
  docs/MASTER-MAP.md rule 4 and the map now say so.
* **Bank 7 free space:** 3,952 → 610.
* **Low area (main RAM below &3000):** 509 → 479 free. It gained:
  * H_MERID;
  * G_MERHOOK and T_MERID;
  * H_CIRC's PM_R store and PM_OK clear;
  * the shared variables PM_OK, PM_R and PS_VALID.
* **Bank 4:** 3,856 → 3,853 free (`JSR H_MERID` in PL25).
* **Bank 6:** 65 → 64 free (f_bounds tests PM_OK; a crater's colours only
  for a crater planet).
* **Loader:** one more FTAB entry (MERID, ROMSEL 7, at M7AT, M7LEN bytes) and
  one more disc file. The build writes M7AT and M7LEN into
  game-addresses.asm, and images.txt lists MERID.bin as a "v" image.
  COLD7.bin stays strictly checked.
* **bankcheck.py:** a new area, bank7m (a renderer area), reached only through
  the GLUE stubs. All rules hold.
* **Rules kept:**
  * nothing new in shadow RAM;
  * nothing at HAZEL &DF00-&DFFF (nothing new in HAZEL at all);
  * page &0D untouched (checked by the gate);
  * save files unchanged (msavetest passes in every gate);
  * no alignment padding.

## How it works

* **PL9 → H_MERID (record mode).**
  * Elite's half ellipses are no longer computed or recorded (PLS4, PLS1,
    PLS5, PLS22, BLINE, F_PPOINT: about 15K cycles a frame saved).
  * H_MERID leaves TGT = 31 and K2 = nosev_x / z, as PL25 does. MV40 adds K2
    into the next object's y without setting it first: without this the
    sun's y differed at gate iteration 669.
  * It then far-calls PM_HOOK and returns from PL9.
* **PM_HOOK (bank 7)** computes the constants (the demo's code, with QSL/QSH
  quarter squares), split into three parts:
  * Orientation part (about 14.5K cycles): taken one frame in MERIDHOLD + 1
    (PM_SPIN). In between it is held. The planet spins by 1/16 radian an
    iteration in both roll and pitch, so the spin shows in steps.
  * Radius part: recomputed only when the radius changed.
  * Centre part (the node rows): every computed frame.
  * When the orientation is held and the centre and radius are as they were,
    nothing is computed and the rows in the disc layer's arrays are kept
    (PM_OK = &C0).
* **PM_MERID (bank 7)** runs the demo's row loop. When the planet has only
  moved, it uses pm_shift instead: the last rows moved by (dx, dy), at about
  100 cycles a row instead of 550, and bit for bit what the loop would make.
  This needs the same orientation and radius, the disc whole between R_CL
  and R_CR in both places, and every new row among the old ones.
* **f_bounds** sends a beach ball to T_MERID. A crater planet is recorded and
  drawn as before. H_CIRC clears PS_VALID for a crater planet, because its
  boundaries overwrite the arrays.

**The bug found on the way (4b839ac).** Master Elite's K3 and K4 are at &14
and &22, inside the &10-&28 that PM_HOOK saves and uses as workspace. The
node rows read K4 after the workspace had overwritten it, which gave bands of
the wrong colour with straight tops and bottoms. The first commits had it
too, and the unit test hid it, because it put K3 and K4 outside &10-&28. The
test now uses Master's real zero-page addresses: the old code fails it and
the new code passes. Replay frames 5430-5445 match the model in every row.

## Speed

Flight it/s over the gate's 10,000 piloted iterations:

| Build | All | Beach ball on screen (windows 0-799, 5800-9999) | No beach ball (800-5799) |
|---|---:|---:|---:|
| Original SNG47 | 13.97 | 12.70 | 15.51 |
| full-master before (plain disc) | 17.24 | 20.27 | 15.03 |
| First beach ball (4e7a2d1) | 11.86 | 9.10 | 15.02 |
| **Final (4b839ac)** | **13.56** | **12.34** | **15.03** |

**Flight with no beach ball on screen is unchanged:** every window from 800
to 5799 reads 1.00 against before. Of the gate's 9,933 frames, 4,739 show a
beach ball: the pilot starts at Lave, whose planet is a meridian planet, and
a later system's is too.

The planet-close windows with the final build:

* combat right after launch at Lave (planet r ≈ 99): 10.9-11.2 it/s, against
  24-25 before and 9.2 in the original;
* the approach to the meridian planet (r 48-112): 7.7-17 it/s, against 15-25
  before.

The full per-window table is below.

**Cost of one big beach ball** (py65, cycles a frame, centre (128, 96), clip
2..253):

| Radius | Plain disc, moving 1 px/frame (disc layer) | Every frame: hook, rows, disc | MERIDHOLD 3, static: hook, rows, disc (average of 4) | MERIDHOLD 3, moving 1 px/frame |
|---:|---:|---|---|---|
| 20 | 16K | 22K, 22K, 19K | 6K, 6K, 15K | 8K, 9K, 57K |
| 50 | 39K | 22K, 48K, 58K | 6K, 12K, 44K | 8K, 21K, 136K |
| 99 | 72K | 23K, 79K, 105K | 6K, 20K, 73K | 8K, 36K, 230K |

The geometry is now small. What remains is the disc layer on a moving beach
ball. Each changed two-colour row costs about 1,200 cycles there (r_dpe's
own bookkeeping is about 675 a row, and r_sw a further 270), against about
400 for a moving plain disc's row.

**What MERIDHOLD buys** (measured on 5bdceed, before the K4 fix; see the
review round below for the final figures; 3 is the default):

| MERIDHOLD | 0 (every frame, as the demo) | 3 | 5 | 7 |
|---|---:|---:|---:|---:|
| Gate it/s | 11.98 | 13.56 | 13.89 | 14.06 |
| Spin step | 3.6° per axis per frame | every 4th frame | every 6th | every 8th |

To be at or above the original (13.97) needs MERIDHOLD 7, which shows the
spin in 29° steps. I left it at 3 for the look. It is one constant in
elite-gfx.asm.

**Tried and rejected:**

* Keeping rows while the orientation had changed by less than 2-4 pixels'
  worth: it kept 176 frames in 4,740, because the spin is too fast.
* Matching pairs of boundaries in r_dpe (counts differing by 2: an ellipse
  tip entering a row), so that 15K fewer rows fell back to a full repaint:
  the gate was 13.32 → 13.15. Strips are slower than r_segw's repaint for
  the wide bands, and the window layout shift cost crater frames too.
  Reverted.

**Next step, not done:** a fast path in r_dpe for rows whose edges all move
by the same small amount, which is a beach ball that has only moved. This is
the remaining large cost (see the table above).

## Verification

* **The gate** (master/tools/grind/verify.sh: test_raster --quick, build,
  10,000-iteration determinism against SNG47, redock, save/load, views)
  passes on every code commit. The figures are in the commit table above.
* **test_raster** (master/tools/grind/test_raster.py, with the demo's
  tools/test_raster.py extended through a small EXTRA hook):
  * `merid`: PM_HOOK and PM_MERID on random planets (radius 6-250, centres on
    and off screen), bit for bit against tools/planet_analytic.py. It also
    checks the held-orientation frames: kept rows, radius-only and
    centre-only constants, and moved rows. Registers, zero page and the write
    guard are checked too.
  * `beachball`: test_frames scenarios that feed the window's rows for a
    spinning, moving planet, with the orientation taken one frame in four,
    through R_DISCROWS, with full pixel checks against the reference.
  * The full test and seeds 1-4 all pass.
  * The task names raster_model.py, but there is no such file: the reference
    model lives in tools/test_raster.py (Ref), and the two-colour disc model
    there already covered four boundaries.
* **In-game rows:** `beachshot.mjs --dump` on the replay (curious run1,
  iterations 300-159,275, final build). All 5,057 beach ball frames that
  reached R_DISCROWS were checked: every row matches planet_analytic for the
  frame's centre, radius and spans and the orientation of its last new
  frame, including the frames with kept, moved, radius-only and centre-only
  rows.
* **Screenshots** (the curious run1 session replayed on the final build,
  headless, through master/tools/beachball/beachshot.mjs). They are in
  screenshots/beachball/, each named `beach-it<iteration>-r<radius>.png`;
  sheet.png puts them side by side:
  * Lave, just after launch (r 99-102, partly off screen, moving): 317, 5389,
    5413, 5445;
  * the next meridian planet on approach (r 27, 38, 84, 96, 108): 92313,
    92314, 93281, 93512, 93549;
  * r 63: 149603;
  * very close (r 168 and r 230, mostly off the top): 155141, 155434;
  * small (r 11): 159275.

  demo-port-shot1.png and demo-port-shot2.png are the demo port's own beach
  balls (from ~/elite/screenshots), for the look.
* Emulators ran headless only, and the processes I started have exited.

## Not verified

* **Real hardware:** not tried. In particular, the loader's new MERID entry
  has run only in the emulator.
* **The same frames on the demo port:** the demo is a different game, so its
  frames can't be replayed. The comparison is through the shared reference
  model (bit for bit) and the demo's own screenshots.
* **The spin steps in motion:** they have not been filmed or judged by eye.
  Only stills were taken.
* The orientation can be up to MERIDHOLD frames old. It is held only while
  consecutive iterations draw the beach ball (MCNT one less each time), which
  should keep a new planet from showing another planet's orientation. One
  case is not checked: a launch straight after docking with MCNT lining up,
  which could show a stale orientation for at most MERIDHOLD frames.

## Review round: further optimisation (no further change kept)

Asked to make the faithful look (MERIDHOLD 0: the original spins the planet
1/16 radian every iteration and redraws it every frame) as fast as possible,
I measured before writing more code. Nothing I found was worth a commit, so
the gate figures are unchanged from 4b839ac (this round's mcompare runs):

| MERIDHOLD | 0 | 3 (default) | 5 | 7 |
|---|---:|---:|---:|---:|
| Gate it/s (original: 13.97) | 11.98 | 13.56 | 13.89 | 14.06 |

**Where a beach ball's time goes**, over the whole gate:

* MERIDHOLD 0: 172K cycles an iteration, against 122K before beach balls.
  * Geometry (bank 7): 27.8K. Of that, the hook (the orientation's
    constants) is about 7K and the row loop about 20K.
  * Disc layer (bank 5): +29.6K over the plain disc.
* MERIDHOLD 3: 153K. Geometry 12.7K; disc layer +26K.
* Reaching 13.97 at MERIDHOLD 0 would need about 25K cycles an iteration
  cut. That is nearly all of the geometry, so it is out of reach without a
  different method.

**The r_dpe fast path (moving rows).** The idea was to update rows whose
boundaries have only shifted at a moving plain disc's ~400 cycles, not
~1,200. I instruction-profiled a moving r = 99 ball (py65).

* r_dpe's own code is about 675 cycles a row: the strip loop about 380, the
  edge lists about 86, the stores about 50. r_sw adds about 250.
* A row of a beach ball has 4-6 edges (two span ends and up to four
  boundaries); a plain disc's has 2. Per edge it costs about 70 cycles of
  bookkeeping plus 55-100 of writing (r_sw).
* A rewrite of the loop with the colour pair precomputed and the one-byte
  write inlined comes to about 75 cycles an edge against about 80 now. The
  loop is already near its floor.
* Repainting the whole row instead (r_dpe always to r_dpgl, the row runs):
  294K cycles a frame against 225K for the strips. Worse.
* Strip widths: a moving ball's strips are mostly one byte (3,080 in 5,038
  calls). A spinning stationary ball's are mostly two or three bytes. r_sw's
  one- and two-byte paths are already within about 15 cycles of the
  smallest code that could do the read-modify-write.

So for a six-edge row the strip writer is about as good as this design
allows. A 2-3x gain would need a different representation, not a faster
loop.

**The orientation constants (about 22K a new frame).**

* Shift-subtract integer square root: about the same cycles as the
  quarter-square one, so not worth it.
* Faster mul8 or fdiv: at most about 5K a new frame, which is 0.2 it/s at
  MERIDHOLD 0 and 0.05 at 3.

**The row loop (about 550 cycles a row).** It is incremental already: per
circle and row it does D -= dl, dl += K2, C += a and the s step. The exact
model needs the 16.16 precision. Merging the two circles' passes, or a
table-based s (inexact: the model would change), would save 10-15% of it.

**What does pay is reuse between frames,** which is what MERIDHOLD and the
kept, moved and radius-only rows do (11.98 → 13.56 at MERIDHOLD 3).

**Recommendation: MERIDHOLD 3** (the default).

* Every fourth frame shows a new orientation, about 3 per second in combat
  at Lave. It turns 14° each time, in a spin the original shows at 9-14
  steps a second.
* Position and size follow every frame, so the ball never lags the ship's
  turn.
* It runs at 13.56: 3% below the original's 13.97 overall. The no-beach-ball
  windows are unchanged, and windows with a beach ball read 12.3, against
  the original's 12.7.
* If the README must keep "faster than the original" for the gate, use
  MERIDHOLD 7 (14.06, 29° steps); 5 gives 13.89.

**Spin clips** (Lave just after launch, the ball standing still on screen,
iterations 330-365), in screenshots/beachball/spin/:

* sheet-mh3.png and spin-mh3.gif: MERIDHOLD 3, the recommended setting. The
  GIF runs at the measured 11.6 iterations a second; three iterations were
  not captured, so the GIF skips there.
* sheet-mh0.png and spin-mh0.gif: MERIDHOLD 0, every frame, at 7.2
  iterations a second.

## Per-window speeds (flight it/s)

| Window (iterations) | Pilot phase (reference) | Original SNG47 | full-master (before) | First beach ball (4e7a2d1) | Final (4b839ac) | Final / before |
|---|---|---:|---:|---:|---:|---:|
| 0-199 | combat 138, docked 62 | 9.21 | 24.95 | 6.34 | 12.13 | 0.49 |
| 200-399 | combat 200 | 9.37 | 25.52 | 6.37 | 11.64 | 0.46 |
| 400-599 | combat 162, hyper 38 | 9.18 | 23.40 | 6.05 | 11.13 | 0.48 |
| 600-799 | approach 152, hyper 48 | 15.00 | 22.32 | 12.93 | 17.34 | 0.78 |
| 800-999 | approach 200 | 18.63 | 17.65 | 17.63 | 17.65 | 1.00 |
| 1000-1199 | approach 200 | 17.34 | 14.42 | 14.42 | 14.42 | 1.00 |
| 1200-1399 | approach 200 | 17.27 | 14.62 | 14.62 | 14.62 | 1.00 |
| 1400-1599 | approach 200 | 15.03 | 12.94 | 12.94 | 12.94 | 1.00 |
| 1600-1799 | approach 200 | 14.02 | 12.16 | 12.16 | 12.16 | 1.00 |
| 1800-1999 | approach 200 | 12.26 | 10.25 | 10.25 | 10.25 | 1.00 |
| 2000-2199 | approach 200 | 15.29 | 12.91 | 12.90 | 12.90 | 1.00 |
| 2200-2399 | approach 200 | 15.75 | 13.22 | 13.22 | 13.22 | 1.00 |
| 2400-2599 | approach 200 | 13.70 | 11.70 | 11.71 | 11.71 | 1.00 |
| 2600-2799 | approach 200 | 14.61 | 12.91 | 12.90 | 12.91 | 1.00 |
| 2800-2999 | approach 200 | 19.87 | 25.11 | 25.12 | 25.15 | 1.00 |
| 3000-3199 | approach 200 | 21.00 | 26.79 | 26.79 | 26.82 | 1.00 |
| 3200-3399 | approach 200 | 15.48 | 19.49 | 19.49 | 19.49 | 1.00 |
| 3400-3599 | approach 200 | 16.65 | 21.72 | 21.71 | 21.71 | 1.00 |
| 3600-3799 | approach 200 | 16.04 | 20.15 | 20.15 | 20.14 | 1.00 |
| 3800-3999 | approach 200 | 14.59 | 17.98 | 17.98 | 17.98 | 1.00 |
| 4000-4199 | approach 200 | 13.35 | 14.58 | 14.58 | 14.58 | 1.00 |
| 4200-4399 | approach 200 | 23.19 | 32.19 | 32.19 | 32.19 | 1.00 |
| 4400-4599 | approach 200 | 19.02 | 19.66 | 19.65 | 19.66 | 1.00 |
| 4600-4799 | approach 200 | 21.23 | 29.79 | 29.77 | 29.79 | 1.00 |
| 4800-4999 | approach 200 | 13.07 | 10.08 | 10.08 | 10.08 | 1.00 |
| 5000-5199 | approach 200 | 14.88 | 6.04 | 6.04 | 6.04 | 1.00 |
| 5200-5399 | combat 123, docked 50, approach 27 | 13.18 | 20.54 | 20.53 | 20.51 | 1.00 |
| 5400-5599 | combat 200 | 12.10 | 18.26 | 18.24 | 18.26 | 1.00 |
| 5600-5799 | combat 177, hyper 23 | 12.12 | 16.72 | 16.71 | 16.71 | 1.00 |
| 5800-5999 | approach 137, hyper 63 | 15.41 | 20.82 | 16.70 | 18.66 | 0.90 |
| 6000-6199 | approach 200 | 18.79 | 25.49 | 18.90 | 21.79 | 0.85 |
| 6200-6399 | approach 200 | 16.02 | 25.26 | 12.97 | 17.01 | 0.67 |
| 6400-6599 | approach 200 | 13.05 | 18.29 | 10.94 | 14.09 | 0.77 |
| 6600-6799 | approach 200 | 14.51 | 21.28 | 11.86 | 15.13 | 0.71 |
| 6800-6999 | approach 200 | 15.95 | 24.73 | 12.14 | 16.14 | 0.65 |
| 7000-7199 | approach 200 | 15.84 | 25.29 | 12.85 | 16.95 | 0.67 |
| 7200-7399 | approach 200 | 15.67 | 20.78 | 17.94 | 19.21 | 0.92 |
| 7400-7599 | approach 200 | 9.10 | 11.13 | 10.17 | 10.72 | 0.96 |
| 7600-7799 | approach 162, docked 38 | 10.89 | 12.64 | 10.74 | 11.44 | 0.91 |
| 7800-7999 | combat 188, docked 12 | 9.23 | 24.90 | 6.15 | 11.99 | 0.48 |
| 8000-8199 | combat 200 | 9.14 | 24.23 | 6.04 | 11.37 | 0.47 |
| 8200-8399 | combat 112, hyper 86, approach 2 | 8.90 | 20.77 | 6.05 | 10.47 | 0.50 |
| 8400-8599 | approach 200 | 17.91 | 23.99 | 10.81 | 13.17 | 0.55 |
| 8600-8799 | approach 200 | 18.22 | 23.20 | 10.67 | 12.51 | 0.54 |
| 8800-8999 | approach 200 | 15.52 | 20.89 | 8.27 | 10.11 | 0.48 |
| 9000-9199 | approach 200 | 18.51 | 22.81 | 15.08 | 16.76 | 0.73 |
| 9200-9399 | approach 200 | 14.14 | 18.46 | 7.67 | 9.11 | 0.49 |
| 9400-9599 | approach 200 | 13.43 | 16.74 | 6.90 | 7.60 | 0.45 |
| 9600-9799 | approach 200 | 12.30 | 17.22 | 7.48 | 9.10 | 0.53 |
| 9800-9999 | approach 200 | 11.35 | 15.45 | 6.45 | 7.69 | 0.50 |
