# Solid Elite for the 6502 Second Processor

A version of [Solid Elite for the BBC Master](https://github.com/ebenupton/solid-elite-bbc-master) (Acornsoft's BBC Master Elite with solid, sunlit ships instead of wireframes) for the 6502 Second Processor. The whole game runs on the second processor (the "parasite", a 65C02 with a flat 64K of memory); the BBC Micro it is attached to (the "host") only draws what it is told and does the I/O. It runs with a BBC Master 128 or a BBC Micro Model B as the host. Like the Master port, it is built on, and would not exist without, [Mark Moxon](https://github.com/markmoxon)'s [fully documented source code for BBC Master Elite](https://github.com/markmoxon/elite-source-code-bbc-master).

<p align="center">
<img src="images/solid-elite-beach-ball-planet.png" width="50%" alt="A beach ball planet in the front view, above the dashboard">
<br>
<em>A meridian planet as a beach ball: two great circles, projected exactly, split the disc into land and sea, and spin as the original's equator and meridian do.</em>
</p>

What's new:

* **Everything in the Master port, on a second processor.** Solid ships lit by the sun; solid planets drawn by one circle engine (beach balls for meridian planets, true spherical craters for crater planets), spinning at half the original's rate, their surfaces remade every frame close up, and in deep space on the iterations they turn, every other frame; solid suns with a lens flare, still drawn near the planet where the original drops the sun for the space station; a double-buffered, flicker-free four-colour screen at up to 25 frames a second; the new dashboard; kept solid rows when docking; the solid hangar and briefing ship. Every frame the Tube version draws is pixel for pixel the Master port's.
* **The original game, exactly.** The game logic is Acornsoft's: given the same keypresses, the Tube version plays out the same game as the original (with the planet turning at half its rate, as the Master port's does), iteration for iteration, and its save files are byte-identical with the original's.
* **Every disc incremental.** Each screen buffer remembers what it shows of every row of the planet and the sun; each frame sends the host only what changed. An edge that moved is sent as the strip it moved through, and an unchanged row costs the parasite a few compares. The planet's surface and a second disc (the sun beside the planet) are remembered in one disc heap on the parasite.
* **The host is a dumb renderer.** It draws lines, points, spans, text and the dashboard; it does the keyboard, sound, disc, vsync and the buffer flip; and it stores the parasite's overlay images and its own star records. Everything that decides what to draw (the game, the 3D maths, the rasteriser's bookkeeping, the planets' surfaces, the flare, the text) is on the parasite, so the two processors work in parallel: the parasite works out the next frame while the host draws this one.
* **Two hosts.** A BBC Master fills spans through straight-line store runs in its sideways RAM. A Model B with 64K of sideways RAM keeps a set of row runs per screen buffer, and splits the 3D view from the dashboard with a CRTC vertical rupture (two CRTC frames a field, set up by a timer interrupt).

<p align="center">
<img src="images/solid-elite-craters.png" width="32%" alt="A planet with three green craters on a blue sea">
<img src="images/solid-elite-sun-near-planet.png" width="32%" alt="The sun rising behind the planet's limb, with the lens flare">
<img src="images/solid-elite-sun-and-flare.png" width="32%" alt="The sun and its lens flare">
<br>
<img src="images/solid-elite-coriolis-station.png" width="32%" alt="Approaching a Coriolis station">
<img src="images/solid-elite-combat.png" width="32%" alt="Lasers on a sunlit ship at close range">
<br>
<em>A crater planet with three craters; the sun rising behind the planet's limb, the lens flare turned down where the planet covers it; the sun and its full flare; a Coriolis station; combat. (Screenshots of the Master port, whose frames the Tube version draws pixel for pixel.)</em>
</p>

## Playing it

| Disc | Host | Second processor |
|---|---|---|
| [solid-elite-tube-master.ssd](solid-elite-tube-master.ssd) | BBC Master 128 | a 6502 Second Processor, or the Master's internal 65C102 co-processor (4 MHz) |
| [solid-elite-tube-modelb.ssd](solid-elite-tube-modelb.ssd) | BBC Micro Model B with 64K of sideways RAM (four banks) | a 6502 Second Processor (3 MHz) |

Attach the second processor (on a Master, the internal co-processor works), load the disc and press SHIFT-BREAK. The game plays as BBC Master Elite does: the same keys, the same saved commanders. BREAK during play does not recover yet; a cold SHIFT-BREAK boot is fine. In an emulator, choose a Master 128 or a Model B with a 6502 second processor (and, for the Model B, sideways RAM in four banks). For a BBC Master with no second processor, play the [Master port](https://github.com/ebenupton/solid-elite-bbc-master) itself.

## Building it

```
sh master/build.sh && sh tube/build.sh
```

This builds `tube/build/elite-tube.ssd` (Master host), `tube/build/elite-tube-b.ssd` (Model B host) and `master/build/elite-master-sng47.ssd` (the Master port); the two discs in the root are copies of the Tube ones. You need Python 3; BeebAsm is in `tools/` (a macOS arm64 binary; elsewhere set `BEEBASM` to your own build of BeebAsm 1.11). Nothing else is needed to build.

## The layout

The parasite holds the whole game at the Master port's addresses, the frame layer and the rasteriser's bookkeeping, in a flat 64K: zero page and the game's workspaces to `&0CD0`, the frame layer's inputs and state and a little resident code to `&13FF`, resident code and data from `&1400`, then an overlay region from `&B000` and a four-page command ring from `&F400`. Two overlays share the overlay region: **S** for the space view (the rasteriser's bookkeeping, the discs, the planet's surface, the lens flare, the text overlay, and the rasteriser's state with the disc heap) and **D** for the screens drawn directly (the charts, the market, equipment, status and the disc menu, the title, and the parts of the game's other routines that run only on those screens or while docked). The host keeps both images and swaps them in only when the game changes between the space view and a screen drawn directly: everything the space view runs is resident or in S, and the gate checks that no swap happens within it. S's state never goes to the host: when S is swapped out it is thrown away, and when S comes back the state is rebuilt, each buffer repainting its play area whole on its next frame. The parasite streams its commands to the host through the Tube's register 1, buffered in the ring while the host is busy and drained by interrupt.

The Master host keeps the Master port's screen (two buffers at `&4000`, one in shadow RAM, and the dashboard in shadow `&7000`) and fills spans with 37.6K of straight-line `STA` runs in sideways RAM. The Model B host puts the buffers at `&1000` and `&4000` and the dashboard at `&7000`, its code in four sideways RAM banks, and borrows a little main RAM from the MOS, swapping it back for each disc command. [docs/TUBE-MAP.md](docs/TUBE-MAP.md) has the details: both hosts' maps, the parasite's, and the protocol.

## Speed

Main-loop iterations per emulated second over windows of one recorded game: flight (iterations 1000-1400), the first 3,550 iterations, two launches from Lave towards its beach-ball planet (300-403 and 12105-12212), and flight with the sun on screen (15987-16000). The original is Acornsoft's SNG47 on a BBC Master, with wireframe ships and planets, and with the planet turning at half its rate as the Master port's does (the comparison makes it skip the other turns); the Master port and the Tube versions draw solid, double-buffered frames, capped at 25 frames a second.

| | Flight 1000-1400 | 0-3550 | Beach 300-403 | Beach 12105-12212 | Sun 15987-16000 |
|---|---:|---:|---:|---:|---:|
| Original (SNG47, BBC Master, wireframe) | 12.89 | 15.99 | 8.12 | 8.50 | 22.76 |
| Master port (BBC Master, no second processor) | 14.16 | 16.33 | 6.94 | 7.37 | 25.69 |
| Tube, Master host, 4 MHz second processor | 22.72 | 21.82 | 11.10 | 12.43 | 25.34 |
| Tube, Model B host, 3 MHz second processor | 19.52 | 19.90 | 9.18 | 10.03 | 23.62 |

With the Master as host, the Tube version runs at 1.3 to 1.7 times the Master port's speed where the Master port is below the 25 fps cap, and faster than the original in every window. In the Master port's own gate run (a deterministic pilot's 10,000 iterations of launches, fights, station approaches and hyperspace jumps, the same game on every build: flight iterations per emulated second), the original runs at 14.14, the Master port at 12.08, the Tube version at 19.98 with the Master host and at 16.90 with the Model B host. The recorded game no longer docks: with the planet's half spin its keys play out a different game after the first launch, so the docking window of earlier versions of this table is gone (the solid station filling the screen is where the Tube version was slower than the original).

## Testing

Every change was checked against Acornsoft's release (SNG47) and against the Master port:

* **The gate** (`sh tube/tools/tgate.sh DIR`, on both hosts) runs the recorded game for 16,002 iterations in lockstep with SNG47, comparing the game state at every iteration (with the Master port's two patches to the original: `Q` set to 0 at the altitude check, and the planet's own pitch and roll skipped on odd iterations, its half spin); requires every frame and the dashboard to be pixel-identical with the Master port's; saves and loads commanders and compares the files byte for byte with the original's; and checks a crash, the station, dockings with every mission briefing and debriefing and an escape pod (no overlay load between two frames of a rotating ship), the overlay storage and swaps (none within the space view), the internal co-processor, and the speeds.
* **A soak against SNG47**: 28 long sessions played by Dom Pajak's [elite-agent](https://github.com/8bitkick/elite-agent) (14 a host, 1.79 million iterations), replayed on the Tube version and the original in lockstep, found three ways in which the Tube version's disc commands did not do what the original's do, all after SNG47's own DELT bug (a delete overwrites the first byte of the next save's command): a save command in lower case was not sent to the host, the Master host crashed on an unrecognised command (it had taken the MOS's page `&DF00` for itself), and a load of the overlay holding the save command undid the bug's damage. All three are fixed (`tube/tools/tbadsave.mjs` checks every such command is answered as SNG47 answers it), and their three repros (`master/tools/agentplay/repro/tube-*.jsonl`) replay clean on both hosts.
* **Posed scenes** (`sh tube/tools/tscenes.sh DIR`): 13 planet and sun scenes compared frame by frame with the Master port, with no disc row dropped or drawn whole; `tube/tools/tdrows.mjs` checks every disc row the parasite sends against what the row must show.

The tests need files that are not in this repository, which you must supply:

* `master/reference/sng47/` and `master/reference/elite-master-sng47.ssd`: the released SNG47 binaries and disc (Acornsoft's; the lockstep's and the save tests' reference);
* `scratch/curious/run1/` (`config.json`, `inputs.jsonl`): the input log of the recorded game, made with `master/tools/agentplay` against SNG47;
* `scratch/master-ref.ssd` (a copy of `master/build/elite-master-sng47.ssd`) and the pixel references `scratch/fbref` and `scratch/dashref`, made from it with `master/tools/agentplay/fbreplay.mjs` over the same log.

They need Node.js and jsbeeb.

## Credits

* **Elite** was written by **Ian Bell and David Braben** and is copyright &copy; Acornsoft 1986.

* **The source code this is built on** is **Mark Moxon**'s reconstruction of BBC Master Elite from a disassembly of the original binaries, with every line documented and explained. The commentary is copyright &copy; Mark Moxon. See his [elite.bbcelite.com](https://elite.bbcelite.com) for the full story of how Elite works.

* **The Master port** this builds on is [Solid Elite for the BBC Master](https://github.com/ebenupton/solid-elite-bbc-master).

* **The Tube version** is by Eben Upton, written with [Claude Code](https://claude.com/claude-code).

* **Regression testing** used **Dom Pajak**'s [elite-agent](https://github.com/8bitkick/elite-agent), a rule-based Elite player, whose play recorded the game the gates replay.

This is an independent project. It is not affiliated with or endorsed by Mark Moxon, Ian Bell, David Braben or Acornsoft. As with Mark's repository, the original game and Mark's commentary are copyright, and no licence is granted.

## Documentation

[docs/TUBE-MAP.md](docs/TUBE-MAP.md): the memory maps of both hosts and the parasite, and the host/parasite protocol. [TUBE-REPORT.md](TUBE-REPORT.md): the measurements and experiments. [docs/TUBE-PLAN.md](docs/TUBE-PLAN.md): the plan. [docs/MASTER-PLAN.md](docs/MASTER-PLAN.md): the Master port.
