# master/tools/grind -- grind tooling for full Master Elite

The demo port's micro-optimisation grind tooling (tools/grind/, see its README) ported
to the full BBC Master Elite build in master/: static analysis (liveness, constants,
value ranges) of the whole program, cut into review windows weighted by a cycle profile
of exactly the run the gate times, plus the gate every applied change goes through.
Everything here reads the sources; nothing here edits master/src.

    master/tools/grind/setup_worktree.sh          # worktree /Users/ebenupton/elite-full-grind, branch full-grind, at full-master
    python3 master/tools/grind/analyse.py         # build + analyses -> scratch/grind/{insns.json,annotated/,summary.md,findings.*} (~4 min)
    node master/tools/grind/profile.mjs \
        --disc scratch/grind/build/tree/master/build/elite-master-sng47.ssd \
        --syms scratch/grind/build/tree/master/build/symbols.txt   # -> scratch/grind/profile.json (~3-5 min)
                                                                   # (--pagex: also the page-crossing cycles)
    python3 master/tools/grind/windows.py         # -> scratch/grind/windows/, windows.json, windows.md (~10 s)
    master/tools/grind/verify.sh /Users/ebenupton/elite-full-grind   # the gate (~4-6 min)

`master/tools/grind/run_all.sh [root]` does analyse + profile + windows in one go (root:
the tree to analyse, default the tree the script is in; outputs always in this tree's
scratch/grind/, with analyse.log, profile.log, windows.log, run_all.log).

## Files

| file | what |
|---|---|
| `setup_worktree.sh [path] [branch] [base]` | create the grind worktree (default `/Users/ebenupton/elite-full-grind`, branch `full-grind`, base `full-master`), or reset an existing clean one whose branch has nothing the base lacks |
| `mkbuild.sh <root> <out>` | build `<root>/master` in a private copy (`<out>/tree/master`: its `src/`, `build.sh`, `tools/`; `<out>/tree/tools/beebasm`) with its own `master/build.sh`, then assemble `elite-source.asm` once more with the patched BeebAsm (`tools/grind/bin/beebasm-grind`, shared with the demo tooling) for the provenance map, checking that every image comes out byte-identical.  Never touches `<root>/master/build` |
| `df/` | the demo's adaptation of the beebgame dataflow tools, copied and changed for this build: `model.py` (segments, bank views, shadow data), `analysis.py` (far calls, SMC rules), `ranges.py` (loaded bytes only, shadow reads, a compare-link fix), `gamecfg.py` (FAR_CALLS, FAR_SCRATCH) |
| `master_config.py` | the game config those tools read (interrupt, MOS, cross-bank and far calls) |
| `analyse.py` | the driver: build, model, analyses, outputs |
| `profile.mjs` | cycles per (mapping, PC) over the gate's piloted run (harness/mlib.mjs + mpilot.mjs, as harness/mprof.mjs) |
| `windows.py` | the review windows and their ranking |
| `verify.sh <worktree> [base]` | the gate: rasteriser soak test if `master/src/gfx-raster*.asm` changed, then `<worktree>/master/verify.sh 10000` |
| `test_raster.py [--quick]` | the demo's rasteriser soak test (tools/test_raster.py) pointed at master/src's rasteriser (`GRIND_TREE=<tree>` to test another tree's) |
| `run_all.sh [root]` | analyse + profile + windows |

## The model (df/model.py)

**Segments** = CLEAR epoch + covering SAVE (elite-source.asm and the elite-gfx.asm it
INCLUDEs at its end):

| segment | image (SAVE) | what |
|---|---|---|
| `main` | `BCODE` &1F00-&3FFF, `HICODE` &7200-&7FFF | the main code and data in the original's order (it continues in bank 4), the high code: the quarter-square tables QSL/QSH at &7200, the renderer's game-context stubs and hooks (gfx-gstubs, gfx-hooks), the lighting's game half (gfx-light), the far7 stubs into the cold area |
| `B4` | `BANK4` | bank 4, Elite's home bank, code only: the main code's continuation (from DVL9a), then elite-bank4.asm (TACTICS, LL9, MVEIT, Master's drawing, the CMYK dashboard) |
| `ANDY` | `ANDY` | the cold area's &8000-&8FFF (ROMSEL &87) |
| `C7` | `COLD7` | bank 7 from COLD7LO (elite-data.asm): QQ18, the far4 stubs out of the cold area, the cold code |
| `R7` | `RAST7` | bank 7 &8000 up to COLD7LO: the rasteriser's cold code (ROMSEL 7) |
| `HZ` | `HAZEL` (&C000-&DFFF) | HAZEL: the game data (INCBIN HZDATA1, HZDATA2: blueprints, XX21 ..., SNE, ACT), and at &C300 gvars, the T_ trampolines, the text and IRQ hooks |
| `B5`, `B6` | `BANK5`, `BANK6` | the rasteriser; the frame layer, faces, lighting tables |
| `SH` | TOKENS.bin (elite-data.asm) at TKN1 = &3100 | shadow RAM data only: TKN1, RUPLA, RUGAL, RUTOK |
| `RAM` | none | zero page, stack, K%, WP ... |

The profile's bank 7 key (`B7:`) is split at COLD7LO into `R7` and `C7`.  The disc's
BCODE.bin (commander checksum set) is used rather than BCODE.unprot.bin, as the loader
loads it.

* **Loaded bytes only.**  A segment's image is what the loader puts there (BCODE at
  &1F00, HAZEL.bin to &C000, the banks, the stubs); any other byte in a segment's extent
  (the renderer's shared workspace at &0840-&0CFF and &1300-&1ECB, WP, the screen,
  &4000-&71FF) is unknown at start-up, never a link-time constant.  That is all the
  loader's state the model takes: the loader itself (elite-loader.asm) is not analysed.
* **Which bank** a reference to &8000-&BFFF reaches (`bank_at`): the segment of the label
  the operand names (`JSR F_FRAME` in a G_ stub reaches B6, `JSR R_POLY` in a T_
  trampoline B5, `STA r_pt3+2` patches B5); else what the referencing code sees paged:
  main and B4 code bank 4; cold code (ANDY, C7: ROMSEL &87) ANDY at &8000-&8FFF and bank 7
  (R7 below COLD7LO, C7 above); the rasteriser's bank 7 code (R7, ROMSEL 7) R7 and C7; B5
  and B6 themselves; HAZEL code any bank (a HAZEL reference naming no label is
  ambiguous: all banks, conservative).
* **Shadow RAM.**  The token readers (TKRD, RUPRD, RUGRD) set ACCCON X and read shadow
  &3100-.  An operand naming TKN1/RUPLA/RUGAL/RUTOK reads `SH`; any other read of main
  &3000-&7FFF through a pointer is unknown (it may be shadow RAM); stores into main
  &3000-&7FFF by a bare address (setzp's `STA &3000,X` into shadow &3000) are not taken
  as patches of the main code there (code is patched only by stores naming its label).
* **Far calls** (elite-far.asm: `JSR far7 : EQUW TT22_C`, `far4`, `far7j`, `far4j`): the
  stub's JSR is a call to its target, resolved in the bank the helper pages (far7/far7j:
  ROMSEL &87, ANDY + bank 7; far4/far4j: bank 4 or main), with the far code's effects
  added (it writes fA fX fB ft ft+1 and &F4, writes ROMSEL -- so no paged byte is killed
  across it -- and passes A X Y and every flag both ways), then a return: the EQUW's two
  bytes are a pseudo RTS (`[far return]` in insns.json, 0 cycles), since far7 drops the
  stub's return address and returns to the stub's caller.  The jump forms are modelled
  the same way (their targets never return, or reset the stack: TXS makes their summary
  unknown).  The EQUW does not make its target address-taken.  The far helpers
  themselves (far7, farc, fpc (patched), fjmp's `JMP (ft)`, farret, far4 ...) are
  entries with an unknown caller.  100 far calls resolve, none unresolved.
* **The renderer's stubs**: the G_ stubs (main, page bank 6), the T_ trampolines
  (HAZEL, page bank 5) and the rasteriser's R_TO7/r_call7/r_call5 cross-bank calls are
  modelled as in the demo (analysed as code; r_call7/5 resolved to the targets stored
  in r_hzt7/r_hzt5 just before).
* **The interrupt**: IRQ1 (main) and everything it reaches (LINSCN, H_VSYNC in HAZEL,
  SOINT, SOUS1 ...) may run between any two instructions: every byte it reads is live
  everywhere, every byte it writes is never a constant; it leaves with RTI on both paths;
  the MOS's part writes &FC.
* **MOS calls** (JSR/JMP to &E000-, where no code of ours is): read A X Y and any
  memory, may write every register and flag and I/O, write no game memory (assumption).
* **Self-modifying code, BIT skips, hidden RTSs, entries**: as the demo (README of
  tools/grind), plus: an indexed store whose base is a few bytes below a data label its
  operand names (`STA SOFLG-1,Y`) indexes that data, not the code below it.
* **The CPU** is the Master's 65C12 (65C02 instructions without BBR/BBS/RMB/SMB);
  `cycles` is the 65C02 base count, `cycles_extra` `+p`/`+t` as in the demo.
* Page &0D is off limits (the gate checks no game code writes it); the model has no
  code there (the loader's NMI handler is the loader's).

### Changes to the analyses (df/ranges.py)

* `rom()`: a byte is a link-time constant only if an image loads it (above), and main
  &3000-&7FFF read through a pointer is never one.
* After a far call the far code's scratch bytes are unknown.
* Fix: CLC/SEC drop the compare link (`cmpp`).  Before, `CPY #2 : BCS P%+5 : ... : CLC :
  BNE P%+5 : JMP x` (Elite's unrolled LOIN, LIEX7/LFT) had its Z=1 edge taken as
  infeasible (Z=1 from a compare implies C=1, contradicting the CLC): the profile's
  soundness cross-check caught 7 executed `JMP`s the analysis called unreached.  The
  demo's copy (tools/grind/df/ranges.py) has the same bug.

### Conservative / unknown (as in the demo, plus)

* Routines whose summary is unknown (stack games: SQUA, MULTU, the H_ hooks' `PLA:PLA`,
  LL120/LL123, CLIP, tnpr, DETOK2/3, TT151; TXS/TSX: FRCE, TT170, DEATH2, SVE/LOD/DELT;
  unresolved exits: rj/r7_lines's patched `JMP`, f_plrows/f_sunrows/f_seg16's patched
  opcodes, fjmp's `JMP (ft)`) make every caller assume they read and clobber everything;
  summary.md lists them.
* Unresolved exits: `JMP (ft)` in fjmp/fpj (their callers are resolved), `JMP
  (r_hzt7/5)`, the rasteriser's and frame layer's patched jumps and opcodes.
* Not modelled: NMI (the loader's handler at &0D00; DFS's), BRKV/WRCHV entered from the
  MOS (NEWBRK and CHPR are address-taken entries: everything live at their returns),
  decimal mode (SED only locally, `DECIMAL_ASSUME_CLEAR`), the loader and MOS internals.
* The range analysis' knobs and budget are the demo's (analyse.py `RANGES_DEFAULTS`,
  `RANGES_BUDGET` 3,000,000 steps); a run that exhausts its budget is NOT sound
  (`meta.ranges_sound` in insns.json, every window says so).

**Soundness check** (windows.py): every instruction the profile executed must have been
reached by the range analysis; any that was not is listed at the top of windows.md (and
printed).  windows.md also lists the profiled PCs outside the MOS that are no analysed
instruction (mid-instruction or data execution would show there).

## The profile (profile.mjs)

The gate (master/verify.sh 10000) runs harness/mcompare.mjs: the released SNG47 disc and
the candidate, both flown by harness/mpilot.mjs's pilot for 10000 MLOOP iterations, the
candidate's boot leftovers seeded from the reference at TT170 (`--seed boot`), the
commander patched; its speed figure is flight iterations per emulated second, a flight
iteration being TT100 to the next TT100 with exactly one MLOOP between.  profile.mjs
runs exactly that candidate run (the same runElite, pilot, commander patch and seed: the
reference is booted to its first MLOOP to take the seed) with an instruction hook, and
charges the cycles between consecutive hooks to the earlier PC (keyed `M:`, `A:` (ANDY),
`B4:`-`B7:`, `HZ:` (ACCCON Y), `MOS:` (the MOS and any other ROM)), into scenarios:

* `flight`: the gate's flight iterations; `cycles_per_iteration` is therefore
  2e6 / (the gate's "all" it/s for this build);
* `phase:<p>`: the same split by the pilot's phase at the closing TT100 (`approach`, the
  station approach past the big planet; `combat`; `hyper`, the countdown and jump;
  `escape` ...);
* `other`: every other cycle from the first MLOOP (docked screens, title, launch, death).

## Windows (windows.py)

As the demo: 32 code lines a window (FOR/macro lines count once), inside one routine
where possible (long routines: windows overlapping by 8; short consecutive routines
packed), 6 context lines, every line `line | base cycles | measured cycles/flight it |
annotation | source`, the labels inside and who enters them, the outside transfer
targets with their annotations (a far call's target is its resolved `_C` routine).
`est_cycles_per_frame` = measured cycles per flight iteration (the gate's weighting);
`phase_cycles` its split by pilot phase; `est_other_cycles_per_iteration` per non-flight
iteration.  windows.md: the ranking (top 200), per-segment totals, the profiled cycles
by mapping, the soundness check.

## Outputs (scratch/grind/)

As the demo (see tools/grind/README.md "Outputs"): `insns.json` (one record per
instruction, segment/address order; plus `far: true` on a far call's JSR, whose
`targets` is the far target), `annotated/<file>.txt` (each source file line for line,
`<annotation> | <source>`), `findings.md/json`, `summary.md`, `windows/w_NNNN.txt`,
`windows.json`, `windows.md`, `profile.json`.

## The gate (verify.sh)

`verify.sh <worktree> [base]` (base default `full-master`):

1. if any `master/src/gfx-raster*.asm` differs from base (working tree included):
   `GRIND_TREE=<worktree> python3 master/tools/grind/test_raster.py --quick` (about 20 s;
   FAIL on a non-zero exit).  The soak test is the demo's (tools/test_raster.py: a
   pixel-exact Python reference of every rasteriser entry, run in py65 with a write
   guard) with the Master layout: the renderer's shared workspace as elite-gfx.asm lays it
   out (raster_scr, raster_vars at its real base, R_WL, R_WR, R_NDN, the stars), the
   stubs; polygons drawn with R_COL2/R_COL3 equal to
   R_COLE/R_COLO (the 2-row colour pair the reference models; the 4-row dither is not
   checked);
2. `<worktree>/master/verify.sh 10000`: build (FAIL on error/ASSERT), determinism of game
   state against the reference over 10000 piloted iterations (and page &0D), the redock,
   save/load and view-change regressions.  PASS only on its `VERIFY PASS`, a "Game state identical
   at all" line and "regressions: PASS (redock, savetest, views)".

Prints `VERIFY PASS <cand/ref ratio> <cand it/s>` or `VERIFY FAIL <step>` (test_raster,
build, compare, redock, savetest, ...); exit status 0 only on pass.  Logs in
`<worktree>/scratch/master-verify/` and `<worktree>/scratch/grind-verify/`.

## Timings and results (full-grind at c46cd31, machine shared)

* `analyse.py` 280 s: build 2 s, model + liveness 8 s, ranges 263 s (4 rounds of ~1.29 M
  steps, sound: budget not exhausted), writing 7 s.  24698 instructions (main 5829, B4
  4059, ANDY 1877, C7 1607, R7 2821, HZ 201, B5 5466, B6 2838), 24663 reached by the
  range analysis (the 35 unreached: SOUS9's ASL, mu0, an RTS and r_lput2 in the
  rasteriser, ... -- none executed by the profile).
* `profile.mjs` 184 s wall for 795 emulated s (10000 MLOOP iterations, 9840 TT100):
  9837 flight iterations at 147523 cycles each = 13.56 it/s, the gate's figure for this
  build exactly (master/verify.sh: "all 9837 13.97 13.56 0.970").  By phase: approach
  8078 iterations (84.6% of flight cycles, 152032 cycles each), combat 1500 (12.7%,
  122788), hyper 258 (2.7%, 149776), escape 1.  Flight cycles by mapping: main 45.1%,
  bank 5 29.3%, bank 6 11.3%, bank 4 10.4%, bank 7 3.3%, HAZEL 0.4%, MOS 0.1%, ANDY 0.1%;
  every non-MOS profiled PC is an analysed instruction.
* `windows.py` < 1 s: 880 windows; soundness cross-check clean (every executed
  instruction reached).
* `verify.sh` 6.5 min (the reference run cached after the first: about 4-5 min);
  `test_raster.py --quick` 16 s.
* `run_all.sh` 7.5 min.
