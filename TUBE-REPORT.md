# Tube Elite: report (work in progress)

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
worth retrofitting into today's rasteriser (phases 1-3 keep the row runs). It is
adopted as the Master host's store path in phase 4, when the host becomes a pure byte
writer of the parasite's merged runs: there the stores are nearly all of the host's
work, every run is entered from the host's own main-RAM loop anyway, and the phase 4
section of this report gives its measured effect. The Master host keeps the
shadow-RAM layout (buffer 0 main, buffer 1 shadow, ACCCON X for the CPU, D for the
display), superseding "both buffers in main RAM" for the Master host only; the Model B
host keeps its own layout.
