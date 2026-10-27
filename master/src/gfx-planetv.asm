\ ******************************************************************************
\
\ gfx-planetv.asm - the planet's detail's variables that the frame layer
\ reads (HAZEL, after the game data: elite-layout.asm), where both the
\ meridian window (bank 7, which writes them in game context) and the frame
\ layer (bank 6) see them
\
\ ******************************************************************************

\ The moon, for the frame layer (pf_moon, gfx-planet7.asm; f_moon, bank 6):
\ in HAZEL, where both see it
.MN_ON  EQUB 0          \ bit 7: a moon this frame; 6: behind the planet; 5:
                        \ behind the sun
.MN_X   EQUW 0          \ its centre, radius and z (16 bits, &FFFF if further)
.MN_Y   EQUW 0
.MN_R   EQUB 0
.MN_Z   EQUW 0
.MN_N   EQUB 0          \ its crater's slots: PCMAX .. MN_N - 1
.MN_INV EQUB 0

\ The ring's dots (pf_ring, gfx-planet7.asm; f_ring, bank 6)
.RG_N   EQUB 0          \ dots this frame (0 with RINGS off, master/build.sh)
IF _PLANET_RINGS
.RG_X   SKIP 64
IF _TPART <> 1             \ (the Tube's parasite: in overlay S, p-moon.asm)
.RG_Y   SKIP 64
.RG_F   SKIP 64         \ bit 7: behind the planet
ENDIF
ENDIF

\ The moon's place (MN_TURN, gfx-mnturn.asm: planetsun's gfx-ssun.asm keeps
\ the sun's D = sun - planet first, and turns both alike: ss_turnx takes an
\ offset from ss_d, so MN_E must follow it; this tree has no S_SUN)
IF _TPART <> 1             \ (the Tube's parasite: after WP, p-ws.asm)
.ss_d   SKIP 9          \ (unused here)
.MN_E   SKIP 9          \ E = moon - planet, x, y, z (lo, hi, top), two's
                        \ complement, in the coordinates
.MN_OK  SKIP 1          \ bit 7: MN_E is this system's
ENDIF
