\ hb-res2.asm - the Model B host's main RAM code (hb-res.asm): hb_tramp: from
\ bank 7 into bank 4's span kernel and back (A, X, Y through), assembled in
\ the span kernel's scope (hb-layout.asm): their names are exported (.*)

.tA EQUB 0
.tback
 STA tA
 PAGE GFXBANK
 LDA tA
 RTS
.*T_SBRUNS              \ R_SETBUF's part in bank 4 (r_sbruns)
 TRAMPOLINE RUNBANK, r_sbruns
.*T_SPAN
 TRAMPOLINE RUNBANK, R_SPAN
.*s_gen                 \ the row runs (hstart's: r_rgen)
 TRAMPOLINE RUNBANK, r_rgen
.*hb_poly
 PAGE RUNBANK
 JSR p_polyin
 JMP hbloop
.*hb_dspans
 PAGE RUNBANK
 JSR r_dspin
.*hbloop
 PAGE GFXBANK
 JMP hloop
