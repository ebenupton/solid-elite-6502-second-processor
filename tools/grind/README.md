# tools/grind -- tooling for the 6502 micro-optimisation grind

Static analysis (liveness, constants, value ranges) of the whole Elite port, cut into
review windows weighted by a real in-game cycle profile, plus a gate that every applied
change goes through.  Everything here reads the sources; nothing here edits `src/`.

    tools/grind/setup_worktree.sh              # worktree /Users/ebenupton/elite-grind, branch grind, at master
    python3 tools/grind/analyse.py             # build + analyses -> scratch/grind/{insns.json,annotated/,...}
    node tools/grind/profile.mjs \
        --disc scratch/grind/build/tree/build/elite-master.ssd \
        --syms scratch/grind/build/symbols.txt # -> scratch/grind/profile.json (~5-10 min)
    python3 tools/grind/windows.py             # -> scratch/grind/windows/, windows.json, windows.md
    tools/grind/verify.sh /Users/ebenupton/elite-grind   # the gate (~4-6 min)

`tools/grind/run_all.sh [root]` does analyse + profile + windows in one go.

## Files

| file | what |
|---|---|
| `setup_worktree.sh [path] [branch]` | create the grind worktree (default `/Users/ebenupton/elite-grind`, branch `grind`) at master HEAD, or reset an existing clean one whose branch has nothing master lacks |
| `mkbuild.sh <root> <out>` | build `<root>` in a private copy (`<out>/tree`: its `src/`, `build.sh`, `tools/beebasm`) with its own `build.sh`, then assemble once more with the patched BeebAsm for the provenance map.  Never touches `<root>/build` |
| `beebasm/grindmap.patch`, `beebasm/build.sh` | the BeebAsm patch (stardot/beebasm @ ca2cc5f, 1.11) and its rebuild script -> `bin/beebasm-grind` |
| `df/` | the beebgame dataflow tools (ref/beebgame/tools/dataflow), copied and adapted: `model.py` (rewritten), `analysis.py`, `forward.py`, `ranges.py`, `dom.py`, `findings.py`, `gamecfg.py` |
| `elite_config.py` | the game config those tools read (interrupt, MOS, cross-bank calls) |
| `analyse.py` | the driver: build, model, analyses, outputs |
| `profile.mjs` | cycles per (bank, PC) in headless jsbeeb (adapted from harness/prof.mjs) |
| `windows.py` | the review windows and their ranking |
| `verify.sh <worktree> [base]` | build + 3000-frame determinism compare (+ rasteriser soak test if `src/raster*.asm` changed) |
| `run_all.sh [root]` | analyse + profile + windows |

## Why a patched BeebAsm

BeebAsm's `-v` listing prints address, bytes and a *disassembly* of each instruction,
but not the source line, the file, or whether bytes are code or data, and `-d` dumps
labels only (no equates).  Reconstructing provenance from it (through INCLUDEs, macros,
FOR loops, IF, and four assemblies at &8000) would be guesswork, so `grindmap.patch`
(~90 lines) makes the assembler itself write, on its second pass, to
`$BEEBASM_GRINDMAP`:

    I pc n file line sitefile siteline   an instruction (n bytes)
    D pc n file line sitefile siteline   data (EQUB/EQUW/EQUS/EQUD/INCBIN)
    S pc n ...                           SKIP
    L name pc file line                  a label        E name value file line   an equate
    C start end / O pc / V file start end / B start end dest   CLEAR / ORG / SAVE / COPYBLOCK

`file:line` is the statement's line (inside a macro: the macro body's line);
`sitefile:siteline` the outermost non-macro line (the macro invocation; a FOR body line
is itself).  The assembler's output is byte-identical to tools/beebasm's (checked: all
images and the -v listing).

## The model (df/model.py)

* **Segments** = CLEAR epoch + covering SAVE: `main` (ELTMAIN, &0F40-), `B4`
  (ELTBANK), `HZ` (HAZEL &C000-, its image taken from where gfx-build COPYBLOCKs it into
  bank 6), `B5` (BANK5 rasteriser), `B6` (BANK6 frame layer + faces), `B7` (BANK7, when
  the build has one), `WORDS` (data), `RAM` (workspace, no image).
* **Instructions** start exactly at I records; their bytes come from the saved images.
  D bytes are data, S bytes are variables (never constants).  `EQUB &2C/&24` BIT skips
  (Elite's "skip the next instruction") are modelled as the BIT they are, and a branch
  into an operand byte that is an RTS (`BNE zZ+1`) as an RTS (both `pseudo` in
  insns.json).
* **Which bank** a reference to &8000-&BFFF reaches: the segment of the label the
  operand names in the source when it names one (`JSR F_FRAME` in a G_ stub reaches
  bank 6, `JSR R_POLY` in a T_ trampoline bank 5, `STA r_pt3+2` patches bank 5), else
  the referencing segment when it is a bank, else bank 4 (main, bank 4 and HAZEL code run
  with bank 4 paged; the stubs page 5/6 only around a JSR to a named routine).  A
  HAZEL reference that names no label is ambiguous (all banks: conservative).
* **Stubs**: the G_xxx (gstubs.asm) and T_xxx (tramp.asm) stubs are analysed as code,
  so a call through one is a call to its target plus the stub's own effects (STA gA,
  LDA #bank / STA &F4 / STA &FE30, LDA gA, JMP gback...).  The rasteriser's bank 5 <->
  7 calls (`R_TO7` / `r_call7`, `r_call5`: a target address stored to r_hzt7/r_hzt5,
  then a JSR or JMP to the stub, whose `JMP (r_hzt7)` is otherwise unresolvable) are
  resolved to their targets (immediates stored just before the call), with N Z
  clobbered and r_hza / ROMSEL written by the stub.
* **MOS calls** (JSR/JMP to &E000-, where no code of ours is): read A X Y and any
  memory (a parameter block), may write every register and flag, write no game memory
  (assumption).  A JMP into the MOS is a tail call.
* **The interrupt**: IRQ1 and everything it reaches (LINSCN, H_VSYNC, H_SPLIT, the
  TVT1/TVT3 palette macros) may run between any two instructions: every byte it reads is
  live everywhere, every byte it writes is never a constant.  Its exits `JMP (VEC)` go to
  the MOS handler, taken to touch no game memory but &FC.
* **Self-modifying code**: a direct store into an instruction's bytes (in the bank the
  store reaches) makes that instruction's operand unknown (`smc: operand`), or the
  instruction a barrier if the opcode is written (none in this build).  Indexed stores
  count only when their base is inside an instruction.
* **Entries**: JSR targets; address-taken labels (a code label in an immediate
  `#LO(x)`/`#HI(x)`, in data `EQUW x`, or a macro argument -- BeebAsm keeps no
  reference lists, so this comes from the source text); EQUW data equal to a code
  address (+1); code with no predecessor.  Entries other than JSR targets return with
  every register and flag live.

The analyses themselves are beebgame's (see ref/beebgame/tools/dataflow/README.md for
the full model): global interprocedural liveness of A X Y N Z C V and of every directly
named memory byte, with routine summaries (`use`, must/may-def, memory read/written,
I/O); forward constants (`known`); the ranges abstract interpreter (interval + known
bits + small sets per register and memory byte, the stack modelled, procedures
analysed per entry and small ones per call site, loops split by their counter).
Paged memory is &3000-&BFFF (the shadow screen and the sideways banks; HAZEL is fixed
RAM during the game): a store there is never killed across a JSR that may write I/O.

### Conservative / unknown (limitations of the adaptation)

* Routines whose summary is unknown (stack games -- Elite's `PLA:PLA` early returns in
  the H_ hooks, LL145/LL147/LL120/LL123, tnpr; `TXS` in TT110/M%; `RTI`; unresolved
  exits) make every caller assume they read and clobber everything; summary.md lists
  them.  Liveness around their call sites is therefore pessimistic (more live), never
  optimistic.
* Unresolved exits (everything live there, the range analysis stops): the interrupt's
  `JMP (VEC)`, `JMP (r_hzt7/5)` inside the cross-bank stubs (their callers are
  resolved), `r7m_jsr`'s patched `JMP`, and `BNE MESS` at the end of ou1 (always
  taken, but its fall-through is token data).
* Patched operands are unknown values; stores through them (patched screen addresses
  in the rasteriser) are, like every store through an unbounded pointer, *assumed not to
  hit a byte the range analysis tracks* (beebgame's assumption; summary.md lists each).
  Liveness has no such assumption: an indirect/patched store may write any memory.
* Link-time bytes are constants for the range analysis only if no direct or indexed
  store writes them, they are not SKIP, and no label at or before them in the same
  segment is ever taken by an immediate or EQUW (i.e. reachable by a pointer).
* Cross-bank tail calls (`JMP r_call7`) return the target's flags to the caller's
  caller; the stub actually redefines N Z from A.  Liveness is conservative here; the
  range state's N Z after such a return could in principle be over-precise (only the
  four R_TO7 entry points; their callers reach them through T_ trampolines, which
  redefine N Z themselves).
* Range analysis, Elite-specific changes to beebgame's interpreter: an entry seeded with
  an unknown caller (address-taken, orphan) is its own procedure, so its unknown stack
  never poisons the JSR-entered analysis of the same routine (R_SETBUF is both); a JSR
  to a routine with stack games or no summary (the H_ hooks' `PLA:PLA:RTS` return to
  their caller's caller) also makes the caller return, with everything unknown, from
  that point (one level up only: a callee popping 4 bytes would be missed); a read
  through a pointer that can hit more than `RANGES_PTR_READ_MAX` bytes is `?` (table
  scans such as TT27's token search are not simulated byte by byte).
* Soundness cross-check: windows.py lists any instruction the profile executed that
  the range analysis never reached (a missed path) at the top of windows.md; on master
  7e6e85f there are none (11 instructions are unreached: MU11Z/MUL6 and an RTS in
  R_POLY, which the ranges show are never taken -- candidates in their own right).
* Not modelled: NMI; decimal mode (no SED anywhere); cycle-exact timing loops; the
  loader (elite-loader.asm) and MOS internals.
* `cycles` is the 65C02 base count of the opcode+mode; `cycles_extra` says `+p` (+1 on
  a page crossing) or `+t` (branch: +1 taken, +1 more crossing).
* The range analysis is the expensive part (see Timings).  Its knobs (environment):
  `RANGES_BUDGET` (steps a run, default 3,000,000), `RANGES_CLONE_MAX` (routines up to
  this many instructions are analysed per call site; default 150), `RANGES_PARTS`
  (loop-counter partitions per head, 64), `RANGES_VISITS` (changes at a node before it
  is widened, 400).  analyse.py's defaults are set in its `RANGES_DEFAULTS`.  A run that
  exhausts its budget is NOT sound: insns.json's `meta.ranges_sound` and every window
  say so.

## Timings (master 7e6e85f, machine heavily shared)

analyse.py ~3 min (build 1 s, model + liveness 6-9 s, ranges 100-330 s in 3 rounds of
~1.2 M steps, writing 7 s); profile.mjs 1-10 min wall (245 emulated s: two title
screens + 1300 TT100 iterations); windows.py 5 s; verify.sh 4-12 min (compare.mjs).

## Outputs (scratch/grind/)

* `insns.json`: `meta` (root, git head, notes, timings, `ranges_sound`) and `insns`:
  one record per instruction in segment/address order: `seg`, `addr` (hex), `file`,
  `line` (the source line -- a macro invocation for macro code, with `mfile`/`mline`/
  `mtext` the body line), `text`, `disasm`, `bytes`, `len`, `mn`, `mode`, `opname`,
  `cycles`, `cycles_extra`, `routine` (nearest global label), `label`, `live_in`,
  `live_out` (`AXYNZCV` subsets, `-` none), `known` (forward constants:
  `A=$00`, `X=[m]` equals byte m, `C=1`, `NZ~A` N Z reflect A), `ranges` (`A`/`X`/`Y`
  ranges in dom notation: `$xx`, `lo..hi`, `{a,b}`, `%xx01xxxx` known bits, `?`; `C Z N
  V` 0/1/?; `eq` {reg: byte it equals}; `mem` the operand's value range; `branch`
  never/always), `targets` (resolved transfer targets `seg:ADDR`, `[]` unresolved),
  `entry`, `smc`, `pseudo`, `ann` (the one-line annotation below).
* `annotated/<file>.txt`: each source file line for line (line N is source line N);
  a code line is `<annotation> | <source>`, other lines `<blanks> | <source>`.
  Annotation: `in:<live-in> out:<live-out> | A=.. X=.. Y=.. CZNV flags [operand]=range
  NEVER/ALWAYS`; a line with 2-4 instructions lists each `[disasm] ...` separated by
  `‖`; with more (FOR loops) the first and a count.
* `findings.md/json`: beebgame's cycle-neutral mechanical findings (dead stores,
  reloads, known flags, ...) -- candidates only.
* `summary.md`: per-segment counts, model notes, unresolved exits, unknown summaries,
  self-modified instructions, unbounded pointer stores, range coverage.
* `windows/w_NNNN.txt`, `windows.json`, `windows.md`: see windows.py's docstring.
  A window = 32 code lines (a source line with instructions; a FOR/macro line counts
  once) inside one routine where possible (long routines: windows overlapping by 8;
  short consecutive routines packed), with 6 raw lines of context, every line
  `line | base cycles | measured cycles/frame | annotation | source`, the window's labels
  with the transfers that enter them from outside, and its outside transfer targets
  with their annotations.  `est_cycles_per_frame` = measured cycles of its instructions
  per TT100 iteration (flight, iterations 300-600 and 1000-1300);
  `est_title_cycles_per_frame` per title-loop pass.  `windows.json` also has
  `ranking` and `totals` (code bytes per segment, for size work in cold code).
* `profile.json`: per scenario, cycles per `M:/B4:/B5:/B6:/B7:/HZ:/MOS:<pc>`.

## The gate (verify.sh)

`verify.sh <worktree> [base]` (base default `master`): `./build.sh` (FAIL on exit status
or any error/assertion text); if any `src/raster*.asm` differs from base (working tree
included) `python3 tools/test_raster.py --quick` (its exit status); then
`node harness/compare.mjs --frames 3000 --lasct --port <wt>/build/elite-master.ssd
--psyms <wt>/build/symbols.txt --out <wt>/scratch/grind-verify/compare` (FAIL on FIRST
DIVERGENCE or no "identical at all" line).  Prints `VERIFY PASS <it/s>` (the port's
"all 3000" iterations per emulated second) or `VERIFY FAIL <step>`; exit status 0 only
on pass.  Logs in `<wt>/scratch/grind-verify/`.
