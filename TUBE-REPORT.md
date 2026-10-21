# Tube Elite: report

Branch `tube` in `~/elite-full-tube` (not pushed, not merged). Two discs:
`tube/build/elite-tube.ssd` (BBC Master host) and `tube/build/elite-tube-b.ssd`
(BBC Micro Model B host with 64K of sideways RAM), both built by
`sh tube/build.sh` (which also builds everything below; `sh master/build.sh` first).
Maps and protocol: `docs/TUBE-MAP.md`; the plan with what happened:
`docs/TUBE-PLAN.md` section 7.

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
