# Solid Elite on the 6502 Second Processor

The BBC Master port's solid-polygon Elite, running on the Tube. The whole
game runs on the parasite (a 65C02 with a flat 64K); the host is a dumb
renderer. Built on Mark Moxon's annotated source of BBC Master Elite (SNG47).

## What it is

- **Parasite:** all game logic, the frame layer, the rasteriser's
  bookkeeping, the planet's surface (the circle engine: beach ball, craters),
  the lens flare and the pixels its probes read, the sights, the text map and
  its diff. The cold code is in two overlays (direct-mode screens, space
  mode).
- **Host:** draws only what it is told (lines, points, spans, text and the
  panel), does the I/O (keys, sound, disc, vsync and the buffer flip), stores
  the parasite's overlay images and gives them back on request, and keeps its
  own star records. It keeps no state about what the screen holds.

**Every disc is incremental.** Each buffer keeps what it shows of every disc
row, and a frame sends only what changed: a row whose edges moved goes as the
strips they moved through, an unchanged row costs the parasite a few
compares. The planet's surface detail and the second disc (the sun beside the
planet) are remembered in one disc heap on the parasite, partitioned by size
between the two; a body that cannot fit is drawn whole that frame (none in
the test run or the bench scenes).

**The two hosts fill spans differently.** The Master host fills through
straight `STA abs` runs in its sideways RAM. The Model B host keeps two sets
of row runs in its sideways RAM, one per screen buffer, a page per character
row, so no run is patched for a buffer; a table per row gives each buffer's
run page. The Model B's split screen (the 3D view above the dashboard) is a
CRTC vertical rupture: two CRTC frames a field, set up by a timer
interrupt.

Memory maps and the host/parasite protocol: `docs/TUBE-MAP.md`. History,
numbers and experiments: `TUBE-REPORT.md`. The plan: `docs/TUBE-PLAN.md`.

## The two hosts

| Disc | Host | Parasite |
|---|---|---|
| `solid-elite-tube-master.ssd` | BBC Master | 65C02 second processor; 4 MHz target |
| `solid-elite-tube-modelb.ssd` | BBC Model B with 64K of sideways RAM | 65C02 second processor; 3 MHz target |

`elite-master-full.ssd` is the Master port itself (no second processor),
built from the same tree.

## Booting

Attach a 6502 Second Processor (on a Master, the internal 65C102 co-processor
works), insert the disc and press SHIFT+BREAK.

## Measured speed (iterations/s, 25 fps cap)

Windows of the test run: flight 1000-1400, docking 3420-3550, the first
3,550 iterations, and two beach-ball planet approaches (300-403, 5355-5457).

| Host / parasite | Flight | Docking | 0-3550 | Beach 300-403 | Beach 5355-5457 |
|---|---|---|---|---|---|
| Master, 4 MHz parasite | 21.31 | 10.68 | 20.27 | 10.34 | 10.20 |
| Model B, 3 MHz parasite | 17.47 | 9.87 | 17.89 | 8.51 | 8.08 |

Like for like, at a 3 MHz parasite, the Master host filling through the same
row runs makes 17.54 / 10.12 / 18.02 / 8.56 / 8.13: the Model B host is
within 0.4-2.5% of it, the rest being mostly the split screen's timer
interrupts.

## Building

```
sh master/build.sh && sh tube/build.sh
```

This gives `tube/build/elite-tube.ssd` (Master host),
`tube/build/elite-tube-b.ssd` (Model B host) and
`master/build/elite-master-sng47.ssd` (the Master port); the three discs in
the repository root are copies of them. beebasm is in `tools/` (a macOS
binary; elsewhere set `BEEBASM` to your own). Python 3 is needed for the
build's generators.

## Testing

`sh tube/tools/tgate.sh DIR` runs the gates, on both hosts:

- lockstep against SNG47 (the curious run, 16,002 iterations, 0 findings);
- pixel-identical output to the Master port, frames and the dashboard;
- save tests (byte-identical saves against SNG47), the crash test, the
  station in front of a far planet;
- the overlay storage, and the internal co-processor (TUBEINT=1);
- the speed windows above.

`sh tube/tools/tscenes.sh` runs the 13 posed planet and sun scenes against
the Master port; `tube/tools/tdrows.mjs` checks every disc row sent against
what the row must show.

The gates need files that are not in this repository, supplied locally:

- `master/reference/sng47/` and `master/reference/elite-master-sng47.ssd`:
  the released SNG47 binaries and disc (third-party; the lockstep's and the
  save tests' reference);
- `scratch/curious/run1/` (`config.json`, `inputs.jsonl`): the input log of
  the test run, recorded with `master/tools/agentplay` against SNG47;
- `scratch/master-ref.ssd` (a copy of `master/build/elite-master-sng47.ssd`),
  and the pixel oracles `scratch/fbref` and `scratch/dashref`, made from it
  with `master/tools/agentplay/fbreplay.mjs` over the same log.

## Known issue

BREAK during play does not recover on the Tube build yet. A cold
SHIFT+BREAK boot is fine.

## Credits

Mark Moxon's annotated source of BBC Master Elite (elite.bbcelite.com), from
the original by Ian Bell and David Braben; the Master port lineage in this
repository (`master/`, `docs/MASTER-PLAN.md`).
