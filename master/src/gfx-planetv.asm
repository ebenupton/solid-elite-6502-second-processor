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
.RG_N   EQUB 0          \ dots this frame
.RG_X   SKIP 64
.RG_Y   SKIP 64
.RG_F   SKIP 64         \ bit 7: behind the planet
