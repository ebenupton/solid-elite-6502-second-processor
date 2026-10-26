# Solid Elite on the 6502 Second Processor

The BBC Master port's solid-polygon Elite, running on the Tube. The whole
game runs on the parasite (a 65C02 with a flat 64K); the host is a dumb
renderer. Built on Mark Moxon's annotated source of BBC Master Elite (SNG47).

## What it is

- **Parasite:** all game logic, the frame layer, the rasteriser's
  bookkeeping, the beach ball, the lens flare, the text map and its diff.
  The cold code is in two overlays (direct-mode screens, space mode).
- **Host:** draws only what it is told (lines, points, spans, text and the
  panel), does the I/O (keys, sound, disc, vsync and the buffer flip), and
  stores the parasite's overlay images, giving them back on request. It keeps
  no state about what the screen holds.

Memory maps and the host/parasite protocol: `docs/TUBE-MAP.md`. History,
numbers and experiments: `TUBE-REPORT.md`. The plan: `docs/TUBE-PLAN.md`.

## The two hosts

| Disc | Host | Parasite |
|---|---|---|
| `solid-elite-tube-master.ssd` | BBC Master | 65C02 second processor; 4 MHz target |
| `solid-elite-tube-modelb.ssd` | BBC Model B with 64K of sideways RAM | 65C02 second processor; 3 MHz target |

## Booting

Attach a 6502 Second Processor (on a Master, the internal 65C102 co-processor
works), insert the disc and press SHIFT+BREAK.

## Measured speed (iterations/s, 25 fps cap)

| Host / parasite | Flight | Docking |
|---|---|---|
| Master, 4 MHz parasite | 20.83 | 9.92 |
| Model B, 3 MHz parasite | 17.14 | 7.89 |

## Building

```
sh master/build.sh; sh tube/build.sh
```

This gives `tube/build/elite-tube.ssd` and `tube/build/elite-tube-b.ssd`; the
two discs in the repo root are builds of commit f950cbe. (beebasm is in
`tools/`.)

## Testing

`tube/tools/tgate.sh` runs the gates:

- lockstep against SNG47 (the curious run, 16,002 iterations, 0 findings), on
  both hosts;
- pixel-identical output to the Master port;
- save tests (byte-identical saves against SNG47) and the crash test;
- the internal co-processor boot test (`tube/tools/tboot.mjs`).

Note: `master/reference/sng47` (the released SNG47 binaries and disc) is not
in this repository; the lockstep and the Master port's byte-compare need them,
supplied locally.

## Known issue

BREAK during play does not recover on the Tube build yet. A cold
SHIFT+BREAK boot is fine.

## Credits

Mark Moxon's annotated source of BBC Master Elite (elite.bbcelite.com), from
the original by Ian Bell and David Braben; the Master port lineage in this
repository (`master/`, `docs/MASTER-PLAN.md`).
