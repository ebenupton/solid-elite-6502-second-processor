# Tube Elite: the plan

A 6502 Second Processor version of the full Master port: the game and as much
of the renderer as possible on the parasite, the host reduced to a fast
executor of drawing commands. It must run on a BBC Micro Model B host with
64K of sideways RAM, and on a Master host. Figures here are estimates to be
measured (phase 0).

## Decisions taken

- First cut through the remote rasteriser (phase 1), then spans (phases 3-4).
- One host binary for both hosts: framebuffers in main RAM, a CRTC vertical
  rupture for the dashboard, NMOS 6502 host code. Master-only optimisations
  (shadow RAM, 65C12 code) come last, if at all.
- B+ hosts are out of scope.
- (2026-10-21, the user's follow-up) The Master host keeps the Master port's
  shadow-RAM double buffering (buffer 0 in main RAM, buffer 1 in shadow RAM at
  the same addresses), so one set of screen-store runs serves both buffers; it
  may use 65C12 code. This supersedes "both buffers in main RAM" for the
  Master host; the Model B host keeps its own layout (main-RAM buffers, the
  CRTC rupture, NMOS code). Full `STA abs` runs (one store per screen byte):
  not on the Model B (two sets would need 75K); on the Master host they were
  to serve phase 4's byte writer, which was not built (below), and through a
  bank switch per call they save nothing at docking: not adopted
  (TUBE-REPORT.md, "Evaluation: full STA abs screen runs").
- Branch `tube` off `full-master`, worktree `~/elite-full-tube`.

## 1. The shape

Acornsoft's Master Elite was derived from the 6502 Second Processor version,
so its game code is already single-CPU code in one 64K space (plus banks).

| | Parasite (65C02, 3MHz, 64K) | Host (Model B + 64K SWRAM, or Master) |
|---|---|---|
| Game | all game logic, unchanged (bit-exact against SNG47) | keyboard and joystick scan, sound (the SN76489) |
| Frame layer | ship records, sort, lighting, face visibility, disc spans, text map, stars, flare geometry | - |
| Rasterising | clipping, edge walking (phase A), a per-row span model of both buffers | executes commands: byte runs, edge bytes, lines, glyphs, star pixels |
| Screen | - | two 12K space-view buffers and the 3.5K panel; buffer flip and dashboard split |
| Dashboard | sends gauge values | redraws what changed (the Master port's routines, moved) |

## 2. The protocol

Transport: we own the Tube during play (the MOS's Tube host is restored for
disc access only). The parasite streams commands into register 1 (parasite to
host, a 24-byte FIFO); the host polls it in a tight loop (about 10 host cycles
a byte, 150-200 KB/s). Register 4 (host to parasite) carries "frame done" and
key-state packets. An NMI-driven register 3 transfer would let the parasite
stream in the background, at about 25 parasite cycles a byte: measure first.

Commands, parasite to host:

1. Frame: begin (buffer b), end (flip at the next vsync), host-idle
   acknowledgement for flow control.
2. Row runs: row, then (first column, last column, fill byte) runs, plus
   single edge bytes as exact values. The parasite composes every byte,
   dither included (row mod 4 and colour give the fill byte), and the edge
   bytes shared by two faces, or a face and black: the host never masks or
   reads back; it enters its row-run code with A = the byte.
3. Lines: x0, y0, x1, y1, colour (slot outline, lasers, meridians, rings,
   sights), drawn by the host's line code.
4. Text: cell, character (the host holds the font); the parasite keeps
   today's text map and sends only changes.
5. Stars and particles: pixel lists, plotted on black.
6. Panel: gauge values, compass, missiles, bulbs, scanner dots and sticks.
7. Sound: today's NOISE/SOFLUSH requests.

Each byte written once: the parasite keeps, per buffer, what each row held
two frames ago. Per row it merges this frame's spans (painter's order), the
black needed where old content is not covered, and the disc spans, into one
ordered run list covering old and new. The erase-then-redraw that dominates
docking today goes, and so does the host's read-modify-write. A full-screen
station is about 12K byte stores (about 60k host cycles) plus about 500 runs
(about 30k): about 45 ms a frame on a 2MHz host, against about 150 ms now.
About 2-4 KB of commands a frame when docking, 0.3-0.6 KB in ordinary flight.

## 3. Host memory (Model B with 64K sideways RAM)

Main RAM: `&0E00-&11FF` host variables and trampolines; `&1200-&3DFF` buffer A
(12K); `&3E00-&69FF` buffer B (12K); `&6A00-&77FF` panel (3.5K); `&7800-&7FFF`
spare. Page &0D untouched (NMI space). The MOS Tube host code at `&0400-&07FF`
stays.

Dashboard split: the 6845 latches its start address only at the start of its
frame, so the panel after the displayed buffer needs a vertical rupture: two
CRTC frames per field, 192 lines from buffer A or B (no vsync), then 56 lines
of panel (with vsync), reprogrammed by the raster-locked timer 1 the Master
port already uses (T1SYNC). (A second panel copy does not fit.)

Sideways RAM (four 16K banks): command interpreter and row runs (about 7K),
line drawer, font and glyphs, dashboard routines, sound, keyboard, the hangar
and briefing tables if the hangar stays on the host. Host code is NMOS 6502
(no STZ, BRA, PHX/PLX, TSB/TRB, (zp)). Sideways RAM is detected at load
(boards differ in which slots hold RAM).

Master host: the same code and main-RAM layout with the split.

## 4. Parasite memory

A flat 64K, no banks: the far calls, stubs, trampolines, ROMSEL/ACCCON
handling and the HAZEL stash all go, and no screen (the 24K the Master
spends). Budget, to be accounted exactly: game code and data about 44K, frame
layer, faces and lighting about 14K, phase A, the span model and the command
writer about 5K, the two buffers' row models about 2-3K: about 65K against
about 61K usable. Cuts, in order: the parasite's copy of the dashboard code,
the hangar/briefing to the host, the display list, last of all rarely used
cold code loaded from disc.

## 5. Phases (each gated)

0. Spikes: jsbeeb's Tube (its Tube65C02 model; Model B sideways RAM) wired
   into the harness; register 1 / register 3 throughput; the CRTC rupture on
   a Model B; the parasite memory budget.
1. Parasite build: the Master game relinked flat, drawing through a remote
   primitive layer: each T_ trampoline becomes a command emitter sending
   today's arguments (R_POLY vertices, R_LINE ends, disc spans, text) to a
   host running today's rasteriser made NMOS and B-memory compatible.
   Playable end to end with the least change.
2. Host services: keyboard/joystick packets, sound, panel, loader, disc
   access (MOS Tube protocol for OSFILE; save files byte-identical).
3. Offload: clipping, edge walking and the dirty bookkeeping to the parasite;
   the host receives spans.
4. Each byte once: the per-row merge (section 2). The host becomes a pure byte
   writer; the docking slowdown goes.
5. Polish: Master-host options, pipelining (the parasite computes iteration
   N+1 while the host draws frame N), faster co-processors (65C102,
   PiTubeDirect).

## 6. Verification

- Game state: lockstep against SNG47 per iteration, as now; inputs injected at
  the parasite's key-read sites, so agentplay replays still work.
- Pixels: the oracle is today's Master port: decode the host's two buffers
  each frame and compare with fbreplay's output from the current build over a
  replayed run (timing-only differences, such as the death sequence's frame
  count, matched by iteration).
- Speed: flight iterations per emulated second against SNG47 and against the
  Master port, and the docking approach (dockprof's window).
- Real hardware (Model B plus sideways RAM, a Master host) before release;
  the CRTC rupture is the riskiest item there.

## 7. What happened (2026-10-21)

- Phase 0: as planned (tube/spike, harness/tlib.mjs). Register 1 polled: 20
  host cycles a byte; register 3 by NMI loads the parasite 92%: not used.
- Phase 1: the game and the frame layer on the parasite, the Master port's
  rasteriser on a Master host first (not NMOS, not B-memory: the Model B host
  came later as its own layout, below).
- Phase 2: keys and joystick through requests (C_KEYS, C_DKS, C_IRB), sound
  through C_NOISE/C_SOFLUSH, the panel by the Master port's own dashboard code
  on the parasite writing bytes (C_SCEOR/C_SCSTA), disc commands through the
  MOS's Tube code (C_OSCLI). Save files byte-identical (lockstep against SNG47
  with saves); the disc menu checked with real key presses (tsavetest.mjs).
- Phase 3 (done after phase 5, at the user's request): R_POLY's phase A on the
  parasite, the host receiving the rows' tables and entering its rasteriser at
  r_pcbd. Lines, dots and the dirty bookkeeping stay the host's.
- Phase 4: not built as planned. The per-row merge needs a model of both
  buffers' rows on the parasite, which has no room for it (626 bytes free
  before the high area was taken); a first try instead computed the ships'
  coverage on the parasite so the host could skip erasing what they repaint:
  pixel-exact, but slower (the parasite's ~64k cycles of coverage maths
  serialise with the host's drawing); taken out (in git history).
- Phase 5: the host pre-erases the next back buffer in its idle time (docking
  +5%); the Master host keeps shadow RAM and 65C12 code; a parasite clocked
  at 24 MHz runs pixel-exact (TUBEMHZ).
- The Model B host: built (section 3's spirit, not its letter): buffer 0 at
  &1000, buffer 1 and the panel at the Master port's &4000 and &7000, the
  rasteriser split over two banks D and P with the runs only in P (patched per
  buffer on first use), main RAM taken from the MOS and swapped back for disc
  commands, a loader that finds and patches the sideways RAM banks.
- Verification: both hosts lockstep-clean against SNG47 over run1's 16002
  iterations and pixel-exact against the Master port over 0..16000.
