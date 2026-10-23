\ hb-res2.asm - the Model B host's main RAM code (hb-res.asm): hb_tramp: from bank F into bank D or P and back (A, X, Y through)

.tA EQUB 0
.tback
 STA tA
 PAGE GFXBANK
 LDA tA
 RTS
.T_SETBUF               \ bank P's operands for buffer A (bank D keeps the
 TRAMPOLINE RASTPOLY, P_SETBUF  \ parasite's overlay S, hb-ovl.asm)
.T_RESETBUF
.T_INIT
 RTS
.T_STOUT
 TRAMPOLINE RASTPOLY, P_STOUT
.T_STIN
 TRAMPOLINE RASTPOLY, P_STIN
.T_STARPLOT
 TRAMPOLINE RASTPOLY, P_STARPLOT
.T_SPAN
 TRAMPOLINE RASTPOLY, P_SPAN
.T_DOT
 TRAMPOLINE RASTPOLY, P_DOT
.T_LINE
 TRAMPOLINE RASTPOLY, P_LINE
.hb_poly
 PAGE RASTPOLY
 JSR P_POLYIN
 JMP hbloop
.hb_dspans
 PAGE RASTPOLY
 JSR P_DSPANSIN
 JMP hbloop
.hb_line
 PAGE RASTPOLY
 JSR P_LINEIN
.hbloop
 PAGE GFXBANK
 JMP hloop
