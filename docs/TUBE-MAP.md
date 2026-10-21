# The Tube version: memory maps and protocol

(Phase 1 as built; updated as the phases land. TUBE-PLAN.md is the plan,
TUBE-REPORT.md the report.)

## The parasite (65C02, 3 MHz, flat 64K)

| Region | Addresses | Holds |
|---|---|---|
| Zero page, stack, K%, WP | &0000-&0CCE | the game's workspaces, at the Master port's addresses |
| Page &0D | &0D00-&0D7F, &0D80-&0DEF | a dummy SHEILA (VIA = &0D00: Master's drawing's ACCCON writes land there); setzp/getzp's zero-page buffer (ZPSAVE) |
| Frame layer's inputs | &0E00-&14AE | tube/src/p-ws.asm: the disc spans and boundaries, the polygon and line inputs, the stars |
| Game code (CODE%) | &1500- | the run (head, low area with the Tube glue p-low.asm, the quarter squares page aligned), Master's drawing (bank 4's blocks), the game data, the cold area, then the frame layer's parasite part and its state, to &F466 |
| Client OS | &F800-&FFFF | the 6502 Tube client ROM's copy (used only for the boot and, phase 2, disc commands) |

## The host, phase 1 (BBC Master)

The Master port's display side: buffer 0 in main RAM and buffer 1 in shadow
RAM (both &4000-&6FFF), the dashboard in shadow &7000-&7DFF, the rasteriser in
bank 5 and ANDY, the frame layer's host part (text map, text overlay, sights,
f_enter's border copy, the flip) in bank 6, the renderer's shared workspace at
&0E40-&1EDB, and from &1EDC the game's host blocks (IRQ, sound, CHPR and its
font, UP), the glue and the command loop (tube/src/h-main.asm).

## The protocol

tube/src/cmds.asm lists the commands. The parasite writes register 1 (polling
its room bit), the host reads it in its command loop (polling its data bit);
the host answers requests (keys, a key test, vsync, the joystick's button)
through register 4. The parasite runs with interrupts off.

## Screen-store runs: full `STA abs` evaluated

See TUBE-REPORT.md, "Evaluation: full STA abs screen runs": one set per buffer
is 37.6K (192 lines x 193 bytes, plus tables); the Model B host would need two
(75K) and does not get them; the Master host, with both buffers at the same
address in main and shadow RAM, gets one set in phase 4's byte writer (banks 4
and 7 and part of 6, entered from main RAM with a bank switch per span). The
measured saving is ~6,200 cycles an iteration in the docking window and nil in
flight.
