\ hb-res2.asm - the Model B host's main RAM code (hb-res.asm): hb_tramp: from
\ bank F into bank P's span kernel and back (A, X, Y through), assembled in
\ the span kernel's scope (hb-layout.asm): their names are exported (.*)

.tA EQUB 0
.tback
 STA tA
 PAGE GFXBANK
 LDA tA
 RTS
.*T_SBRUNS              \ R_SETBUF's part in bank P (r_sbruns)
 TRAMPOLINE RASTPOLY, r_sbruns
.*T_SPAN
 TRAMPOLINE RASTPOLY, R_SPAN
.*hb_poly
 PAGE RASTPOLY
 JSR p_polyin
 JMP hbloop
.*hb_dspans
 PAGE RASTPOLY
 JSR r_dspin
.*hbloop
 PAGE GFXBANK
 JMP hloop
