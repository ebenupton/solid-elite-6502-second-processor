# Solid Elite for the 6502 Second Processor

BBC Master Elite with filled, lit ships and solid planets, running on a 6502
Second Processor. The whole game runs on the second processor (the
"parasite", a 65C02 with a flat 64K of memory); the BBC Micro it is attached
to (the "host") only draws what it is told and does the I/O.

It is a version of the BBC Master port at
[github.com/ebenupton/solid-elite-bbc-master](https://github.com/ebenupton/solid-elite-bbc-master),
which is in turn built on Mark Moxon's documented source of Acornsoft's
BBC Master Elite (SNG47).

## Which disc

| Disc | Host | Second processor |
|---|---|---|
| `solid-elite-tube-master.ssd` | BBC Master 128 | a 6502 Second Processor, or the Master's internal 65C102 co-processor; 4 MHz target |
| `solid-elite-tube-modelb.ssd` | BBC Micro Model B with 64K of sideways RAM (four banks) | a 6502 Second Processor; 3 MHz target |

For a BBC Master with no second processor, use the Master port itself:
[solid-elite-bbc-master](https://github.com/ebenupton/solid-elite-bbc-master).

## Running it

Attach the second processor (on a Master, the internal co-processor works),
insert the disc and press SHIFT+BREAK. The game plays as BBC Master Elite
does: the same keys, the same saved commanders.

Known issue: BREAK during play does not recover yet; a cold SHIFT+BREAK boot
is fine.

## Features

- **Filled, lit ships.** Every ship is drawn as solid polygons, flat-shaded
  by the light of the system's sun, in place of the original's wireframes.
- **Solid planets and sun, drawn incrementally.** Planets are solid discs
  with their surface detail (beach-ball stripes, craters); the sun is a solid
  disc, with a lens flare when it is in view. Each screen buffer remembers
  what it shows of every disc row, and each frame redraws only the pixels
  that changed: an edge that moved is sent as the strip it moved through, an
  unchanged row costs a few compares. The surface detail and a second disc
  (the sun beside the planet) are remembered in one disc heap on the
  parasite.
- **Double buffered** at up to 25 frames a second, with stars, the sights,
  text and the dashboard as in the original.
- **The host is a dumb renderer.** It draws lines, points, spans, text and
  the dashboard; it does the keyboard, sound, disc, vsync and the buffer
  flip; and it stores the parasite's overlay images and its own star
  records. It keeps no other state about what the screen holds: everything
  that decides what to draw (the game, the 3D maths, the rasteriser's
  bookkeeping, the planets' surfaces, the flare, the text map) is on the
  parasite.
- **Two hosts.** The Master host fills spans through straight-line store
  runs in its sideways RAM. The Model B host keeps a set of row runs per
  screen buffer in its sideways RAM, and makes the split between the 3D view
  and the dashboard with a CRTC vertical rupture (two CRTC frames a field,
  set up by a timer interrupt).

## Speed

Iterations of the main loop per second, over windows of a recorded test run
(flight 1000-1400, docking 3420-3550, the first 3,550 iterations, and two
approaches to a beach-ball planet, 300-403 and 5355-5457). The original is
SNG47 on a BBC Master, with wireframe ships and planets; the Tube builds are
capped at 25 frames a second.

| | Flight | Docking | 0-3550 | Beach 300-403 | Beach 5355-5457 |
|---|---|---|---|---|---|
| Original (SNG47, BBC Master, wireframe) | 12.69 | 12.61 | 14.38 | 8.11 | 9.09 |
| Master host, 4 MHz second processor | 21.31 | 10.68 | 20.27 | 10.34 | 10.20 |
| Model B host, 3 MHz second processor | 17.54 | 10.08 | 17.96 | 8.56 | 8.13 |

Docking, with the filled station filling much of the screen, is the one
place where the original's wireframes are faster.

## Building

```
sh master/build.sh && sh tube/build.sh
```

This builds `tube/build/elite-tube.ssd` (Master host),
`tube/build/elite-tube-b.ssd` (Model B host) and
`master/build/elite-master-sng47.ssd` (the Master port); the three discs in
the repository root are copies of them. You need Python 3; beebasm is in
`tools/` (a macOS arm64 binary; elsewhere set `BEEBASM` to your own build of
beebasm). Nothing else is needed to build.

## Testing

`sh tube/tools/tgate.sh DIR` runs the gates on both hosts: lockstep against
SNG47 (16,002 iterations of the test run, the game state compared at every
read), pixel-identical frames and dashboard against the Master port, save
tests, a crash test, the overlay storage, the internal co-processor and the
speeds above. `sh tube/tools/tscenes.sh DIR` runs 13 posed planet and sun
scenes against the Master port; `tube/tools/tdrows.mjs` checks every disc row
sent against what the row must show. These need node.js.

The tests need files that are not in this repository, which you must supply:

- `master/reference/sng47/` and `master/reference/elite-master-sng47.ssd`:
  the released SNG47 binaries and disc (Acornsoft's; the lockstep's and the
  save tests' reference);
- `scratch/curious/run1/` (`config.json`, `inputs.jsonl`): the input log of
  the test run, recorded with `master/tools/agentplay` against SNG47;
- `scratch/master-ref.ssd` (a copy of `master/build/elite-master-sng47.ssd`)
  and the pixel references `scratch/fbref` and `scratch/dashref`, made from it
  with `master/tools/agentplay/fbreplay.mjs` over the same log.

## Documentation

`docs/TUBE-MAP.md`: the memory maps of both hosts and the parasite, and the
host/parasite protocol. `TUBE-REPORT.md`: the measurements and experiments.
`docs/TUBE-PLAN.md`: the plan. `docs/MASTER-PLAN.md`: the Master port.

## Credits

- Elite by Ian Bell and David Braben, published by Acornsoft; BBC Master
  Elite (SNG47).
- Mark Moxon's documented source of BBC Master Elite
  ([elite.bbcelite.com](https://elite.bbcelite.com)).
- The BBC Master port this builds on:
  [github.com/ebenupton/solid-elite-bbc-master](https://github.com/ebenupton/solid-elite-bbc-master).
