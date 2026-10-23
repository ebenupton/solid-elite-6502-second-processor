# Dumb-host audit: can the parasite hold everything but lines, points, spans, text and panel?

Read-only audit of branch `tube` (39af107), 2026-10-22. Sizes come from tube/build/compile-p.txt, psyms.txt,
compile-h.txt, hsyms.txt and the Model B logs. Byte counts are measured where a symbol range exists. Anything
marked "est." is an estimate from the size of the host code it replaces. No speed figure below has been measured.

**The rule:** the host does lines, points, spans, text and panel updates, plus I/O services (keys, sound, disc
commands, vsync and flip). Nothing else.

## 1. The parasite today (flat 64K, 65C02 at 3 MHz)

| Region | Addresses | Bytes | Notes |
|---|---|---:|---|
| ZP, stack, K% + line heap, WP | &0000-&0CCE | — | the game's, at the Master addresses |
| Dummy SHEILA, ZPSAVE | &0D00-&0DEF | 240 | |
| Frame-layer inputs (p-ws.asm) | &0E00-&14AE | 1,711 | R_ND*, disc spans, polygon/line inputs, stars; R_NDX2/3 double as phase A tables |
| Head: sound engine, DOVDU19, CHPR, ZES, ADDK, MU8K | &1500-&1756 | 599 | the sound engine (&1500-&160D) is ~270 of it |
| Font padding (FONTPAD) | &1757-&17FF | 169 | |
| Font (P.FONT) | &1800-&1AFF | 768 | used by the parasite's CHPR glyph path (RR1..) |
| log, logL, alogh | &1B00-&1DFF | 768 | used by hot maths in the run and in LOINQ |
| UP | &1E00-&1E21 | 34 | |
| Low area: blocks tagged low, gvars | &1E22-&1E55 | 52 | |
| G_ stubs (p-glue.asm) | &1E56-&202C | 471 | includes F_DIRECT |
| H_ hooks (gfx-hooks.asm) | &202D-&2238 | 524 | |
| Command senders (p-io.asm) | &2239-&2702 | 1,226 | p_sync/fb/fe, T_SPAN/POLY/LINE/DOT/MERID/DISCROWS, p_sceor/scsta, sound, keys, OSCLI, swap |
| The run | &2712-&6775 | 16,484 | includes QSL/QSH (1,024, &3700-&3AFF) and 47 x4_ stubs, which are plain JMPs (141) |
| Master's drawing: bank 4's blocks | &6776-&778E | 4,121 | itemised below |
| Game data (hot) + hangar tables | &778F-&9582 | 7,668 | XX21, blueprints, SNE, ACT … |
| Cold code | &9583-&B2FE | 7,548 | |
| Cold data: QQ18, TKN1, RU* | &B2FF-&C4BE | 4,544 | |
| Frame layer, code | &C4BF-&EF97 | 10,969 | see the breakdown below |
| Frame layer, state: F_HW, F_HW2, F_DL (with F_INIT) | &EF98-&F797 | 2,048 | |
| Free | &F798-&F7FF | 104 | |
| High area: phase A, part 2 (p-polyb) | &F800-&FE76 | 1,655 | free to &FEF0: 121 |

**Frame layer code:**

| Part | Bytes |
|---|---:|
| gfx-frame | 5,108 |
| faces | ~3,300 |
| light6 | ~666 |
| light | ~960 |
| frame_cold, flare6, hangar | ~300 |
| p-polya (phase A, part 1) | 512 |

**Master's drawing, &6776-&778E, block by block:**

| Group | Blocks | Bytes |
|---|---|---:|
| Lines | LOIN, TWOS, TWOS2, LOINQ | 1,550 |
| Spans | HLOIN | 185 |
| Points | PIX1, PIXEL2, PIXEL, PXCL, TWFL, TWFR, orange, DOT | 285 |
| Screen addressing | ylookup | 257 |
| Clears | TTX66, CLYNS | 159 |
| Panel | SCAN 318; ddot 324 (dot tables included); ECBLB2, ECBLB, SPBLB, SPBT, ECBT 96; MSBAR 142; DIALS, PZW2, PZW, DIL2, DILI, DSEG 814 | 1,694 |

**Total free today: about 436 bytes in scraps.**

| Where | Bytes |
|---|---:|
| &F798 | 104 |
| &FE77 | 121 |
| &14AF | 81 |
| &0800-&0840 | 65 |
| &0CCF | 49 |
| &0DF0 | 16 |

Zero page &E4-&FB is also free.

## 2. What can come off the parasite

| Candidate | Bytes | Cost |
|---|---:|---|
| Master's drawing → host line/point/span/clear commands (LOIN/LOINQ, HLOIN, PIX*, DOT, ylookup, TTX66, CLYNS) | ~2,430 | These already end as C_SCEOR/C_SCSTA byte writes. A line command (6 bytes) replaces hundreds of byte commands, so it is faster for the parasite. |
| Panel drawing → host panel primitives (dial values, bulbs, missile bar, scanner blips). SCAN's 3D→2D projection stays, ~150. | ~1,550 | Panel updates are allowed on the host. A handful of bytes per update. |
| Font, its padding, CHPR's glyph path (RR1..RR3) → a host text primitive | ~1,090 | The log tables stay page-aligned; the head is re-laid. |
| Sound engine (SOUS*, SFX tables, NOISE body) → a host sound service (p_noise and p_soflush exist already) | ~250 | I/O, allowed. |
| x4_ stubs (resolve the names directly in a flat build) | 141 | none |
| G_ stubs that only wrap a JSR (call the frame layer directly) | ~150 | none |
| DOVDU19, HANGFLAG and other host-only head bits | ~50 | none |
| **Subtotal** | **~5,660** | |
| Today's free scraps | 436 | fragmented |
| Possible: swap &0236-&03FF and &FF00-&FFF7 with the client OS through C_SWAP, as the high area already is | ~700 | Risky: the client OS's vectors and workspace must be restored for every disc command. |
| **Total** | **~6.1K-6.8K** | |

**Not candidates:**
- **Quarter squares (1,024)** are hot multiply tables, and the meridian would reuse them.
- **log tables (768)** are hot maths.
- **Blueprints and game data (7.7K):** no slack.
- **Cold code and data (12.1K)** is game logic. Its tokens are expanded on the parasite even when text is drawn on the host.
- **Faces and lighting** are geometry.
- **Phase A (2.2K)** is geometry.

The x4_ stubs are the only real banking baggage left: Tube far calls are already plain JMPs.

## 3. What has to come onto the parasite

Per-buffer state means two buffers' worth.

**Code:**

| Component (the host source it replaces) | Est. bytes |
|---|---:|
| Polygon phase B as bookkeeping: orientation, horizontal clip, trim, dirty rows, span emission (host r_pcbd &810E-&8232 + phase B &837D-&84F1, 668) | 700 |
| Disc layer decisions: differential against each buffer's old spans, two-colour rows split into spans (host disc window &8000-&8C8F, 3,215 including its fill paths) | 2,400 |
| Dirty repair (r7_crep, r7_rowrep: 574) | 500 |
| R_INIT, per-buffer selection (R_SETBUF's job) | 500 |
| Star records, erase/plot decisions | 400 |
| Lens flare geometry with its half-width table (R_FLARE ~786) | 750 |
| Per-row dirty extents of lines and dots (for erasing) | 400 |
| Sights, the text map's diff, flip control (from bank 6's host part, 3,085, less text drawing and h-cold) | 1,500 |
| Meridian window PM_HOOK + PM_MERID (bank 7 3,850, less its quarter-square copy 1,024 and the PM_IN receiver) | 2,700 |
| Pre-erase scheduling (send the back buffer's erase spans right after the flip) | 300 |
| Span and command batching | 300 |
| **Code total** | **~10,450** |

**Data:**

| Item | Bytes |
|---|---:|
| R_DIRTYL/R × 2 buffers | 768 |
| R_DISCL/R × 2 | 768 |
| R_WL/R_WR | 384 |
| R_BD* two-colour boundaries × 2 (6 × 192 per buffer) | 2,304 |
| F_TM + F_ST + row counts | 1,608 |
| Star records × 2 | ~200 |
| Scalars | ~50 |
| **Data total** | **~6,080** |

**Total about 16.5K.** Without R_BD*, see cut C below: about 14.2K.

## 4. The dumb-host protocol

All commands go through register 1. Buffer selection is a state:
- `C_BUF b` selects the target buffer: ACCCON X on the Master, R_SETBUF's base on the Model B;
- `C_FLIP` shows the other buffer at the next vsync.

| Command | Bytes | Meaning |
|---|---|---|
| C_SPANS | op, COLE, COLO, y0, n, then (xl, xr) × n | n rows from y0. The dither colour is picked by row parity. This is today's C_POLY format without its phase-B arguments. |
| C_SPAN1 | op, y, xl, xr, col | a single span (flare, odd rows) |
| C_ERASE | op, y0, n, then (xl, xr) × n | black spans: the dirty repair and pre-erase output |
| C_LINE | op, x0, y0, x1, y1, col | as today. The host neither marks dirty extents nor returns anything. |
| C_DOT | op, x, y, size, col | as today |
| C_TEXT | op, col, row, n, chars… | text at a cell. The host draws from its own font. |
| C_PANEL | op, item, value… | dial n = v, bulb on/off, missile bar state, scanner blip (x, y, stalk, colour), panel clear |
| C_CLS | op, row0, row1 | clear rows (TTX66, CLYNS) |
| Services | | keys, sound, OSCLI, swap, sync, as today |

**Bandwidth per iteration.** Register 1 costs about 20 host cycles a byte. Counts are from runstat at 3420-3550 and the kept-span study.

| Window | Contents | Bytes | Host transfer cycles |
|---|---|---:|---:|
| **Docking** | phase B rows 299 × 2 + ~40 polygons × 6 ≈ 840; disc rows ~141 × 3 ≈ 450; erase ~190 rows × 1.3 spans × 3 ≈ 750; stars, lines, sights, text ~150 | ~2.2K | ~44K |
| **Flight** | a few spans, disc rows, stars | ~0.5-0.8K | ~10-16K |
| **Beach ball** (Lave) | up to 5 spans a row × ~150 rows × 3 | ~2.2K | ~45K |

At docking, today's traffic is already about 1.5K (C_POLY + C_DISC). The increase is mainly the erase spans.

**Host load at docking:**

| | Host cycles an iteration |
|---|---:|
| Today | 244K (8.2 it/s): 73K in the row runs, the rest edges, receiving and the bookkeeping that moves |
| Dumb host (est.) | ~190K: runs 73K + edges and span set-up ~56K (800 spans × ~70) + receiving 44K + loop ~15K |

**What the parasite would carry at docking (est.):**

| | Parasite cycles an iteration |
|---|---:|
| Busy today (about 20% of the iteration; it waits for the host the rest) | ~73K |
| Bookkeeping moved over from the host (same cycle count, 1.5× clock) | ~100K |
| Span emission | ~22K |
| **Total** | **~195K** (65 ms): it could keep up with ~15 it/s |

**Model B host after the move (est.):**

| Part | Est. bytes |
|---|---:|
| Span filler: r_spc, tables, 24 row-run pages, R_SETBUF patching | ~8K |
| Lines | ~2.9K |
| Points | ~0.3K |
| Text (font + drawing) | ~1.6K |
| Panel (the parasite's panel code moved over) | ~4K |
| Command loop and services (sound, keys, OSCLI/hwrch, HSW 1.7K, rupture IRQ) | ~4K |
| Stash, bank S | 3.5K |
| **Total** | **~24K** of the 64K |

- **About 40K of sideways RAM would be free.**
- **One full STA set (37.6K) would just fit**, spread as 84 + 84 + 24 lines over three banks, with about 2K to spare.
- **It would serve only one buffer**, since the Model B's buffers are at different addresses; the other buffer keeps the patched row runs.
- **It isn't worth having.** The measured model for the Master host puts full runs at about 3% slower at docking, from per-entry bank paging and per-row plants. Two sets (75K) still cannot fit.

## 5. Verdict

**It does not fit as things stand.** About 16.5K must come on and about 6-7K can come off, a shortfall of about 10K. Even after cuts C and D below, the shortfall is about 7K.

**Cuts that close part of the gap:**

| Cut | Saves | Cost |
|---|---:|---|
| **C. Drop R_BD*** (the two-colour boundary memory). Repaint any changed two-colour row as whole spans. | 2,304 | With MERIDHOLD 0 the beach ball's boundaries change every frame anyway, and plain discs have none. Near-neutral; a held ball costs more spans. |
| **D. Pack F_ST into per-row dirty bits** (24 rows × 2 buffers). Changed rows' cells are resent. | ~576 | Some extra text traffic. |

**What closes the rest: overlays held in host memory.** The space-view renderer is only live in space views; the docked and chart UI is only live outside them.
- On every change between a space view and any other view, swap them through the host:
  - out: the per-buffer state, the meridian and the disc layer, ~10K, which are rebuilt on return anyway, since the screen is cleared;
  - in: the docked-only cold code and data (market, equipment, status, charts, save/load, title, briefings, hangar).
- The cost is about 8K × 20 host cycles, roughly 80 ms per view change.
- **This needs the user's decision.** It uses the host as a memory store, which goes beyond the rule's list, although HSW already does the same for the high area.
- **Not yet measured:** how much of the cold code is really docked-only. Some cold routines run in flight: MESS, the launch, hyperspace, ESCAPE. Partitioning the cold area is the first piece of work.

**Expected speed** (all estimates, none measured):

| Window | Master host | Model B host |
|---|---|---|
| Docking (3420-3550) | 8.2 → ~10-11 it/s (host-bound at ~190K). SNG47 12.6. | 6.7 → ~8 it/s (its span fill is slower, NMOS, plus ~27K of run patching) |
| Flight (1000-1400) | 21.8 → ~19-20 it/s: the parasite takes on per-frame disc/dirty work. Still above SNG47 (12.7) and the Master port (19.1). | 20.0 → ~18-19 it/s |
| Lave, beach ball | 7.6 → ~9-11 it/s: the meridian runs on the 3 MHz parasite and the host only fills spans. SNG47 9.3. | 7.0 → ~9-10 it/s |

**Order of work if approved:**
1. Partition the cold area (measure what is docked-only).
2. Decide on overlays vs cuts.
3. Move panel, text and Master's drawing to host primitives. This frees ~5.7K, a win on its own: fewer byte commands.
4. Move the meridian, which removes C_MERHOOK and the host's bank 7 use.
5. Move the disc layer, phase B bookkeeping, dirty repair and stars, with the protocol above.
6. Gate: lockstep, fbreplay pixels, tsavetest, tspeed on both hosts.

**Side finding (outside the rule):** the Master host's ANDY still carries the dead R_POLY phase A, about 2.2K: R_POLY, r_pf8, r_e8, r7_pf16 (&8000-&8232, &8502-&8A3D). Phase A runs on the parasite.
