\ ******************************************************************************
\
\ hb-p.asm - the Model B host's bank P (docs/TUBE-MAP.md): the rasteriser's
\ fills, as the Master port's ROMSEL RASTPOLY (ANDY over bank 5): phase B
\ (gfx-raster_poly.asm) at &8000, the shared region (gfx-raster.asm) from
\ &9000 with buffer 1's row runs, R_SPAN, r_dspin, R_DOT and the stars, and
\ buffer 0's row runs in the pages between (r_rpy0: their page per
\ row), so that no run is patched for a buffer. The lines are bank F's
\ (hb-line.asm). NMOS code (build/nmos/).
\
\ ******************************************************************************

_TPART = 2
_HOSTB = TRUE
_RBANK = 2

 INCLUDE "tsrc/cmds.asm"
 INCLUDE "build/povl.asm"
 INCLUDE "build/elite-source-ws.asm"
 INCLUDE "tsrc/hb-ws.asm"

 CLEAR &8000, &C000
 GUARD &C000
 ORG &9000
 INCLUDE "build/nmos/gfx-raster.asm"
 CPU 0
.P_SHEND
.r_rpy1                 \ buffer 1's run page per row (the shared region's end)
FOR y, 0, 191
 EQUB HI(r_run0) + y DIV 8
NEXT
 ASSERT HI(r_rpy1) = HI(P% - 1) AND P% <= &BC00
.r_rpyl EQUB LO(r_rpy0), LO(r_rpy1)   \ (R_SETBUF's)
.r_rpyh EQUB HI(r_rpy0), HI(r_rpy1)
.P_HIEND
 ORG &8000
 INCLUDE "build/nmos/gfx-raster_poly.asm"
 CPU 0
ASSERT P% <= &8300       \ (buffer 0's runs from there)
.r_bs8                  \ (R_SETBUF's patch of the lines' operand, bank F's:
 SKIP 3                 \ f_bufpatch does it there)
.r_bs7                  \ (the repair is the parasite's: r_sbuf's patch of its
                        \ operand lands here)
 SKIP 3
.p_polyin               \ h_poly's receiving part: phase A's rows (p-polya.asm),
 HRX                    \ then the rasteriser from r_pcbd
 STA &06                \ (R_COLE, R_COLO)
 HRX
 STA &07
 HRX
 STA R_COL2
 HRX
 STA R_COL3
 HRX                    \ (C_SPANS: the first row; the rows follow, which
 STA R_PYS              \ phase B reads as it goes: r_pcbs)
 JMP r_pcbs
.P_LOEND

\ Buffer 0's row runs (BUF0, &1000): a page each, as buffer 1's (r_run0 on,
\ gfx-raster.asm's R_RUN, &A000-&B7FF), in the pages the rest leaves:
\ &83-&8F, &91-&98, &BC-&BE. r_rpy0 and r_rpy1 hold each buffer's run
\ page for each row; R_SETBUF points r_rowset's and phase B's next
\ character row's LDA ,Y at the buffer's (r_bs12, r_bs13). A page's bytes
\ 191-255 are free

MACRO R_RUNB r, pg
 ORG pg * &100
 FOR c, 1, 63
  STA BUF0 + r * &200 + c * 8 - r * 8, Y
 NEXT
 RTS
 EQUB 0                 \ (the 'nothing planted' target, offset 190)
ENDMACRO
RUNB0 = &8300
FOR r, 0, 12
 R_RUNB r, &83 + r
NEXT
FOR r, 13, 20
 R_RUNB r, &91 + r - 13
NEXT
FOR r, 21, 23
 R_RUNB r, &BC + r - 21
NEXT

 ORG &BF00               \ (each a page's 192 bytes: r_rowset's LDA ,Y crosses
.r_rpy0                 \ none)
FOR y, 0, 191
 r = y DIV 8
 IF r < 13
  EQUB &83 + r
 ELIF r < 21
  EQUB &91 + r - 13
 ELSE
  EQUB &BC + r - 21
 ENDIF
NEXT
.P_RPEND
 ASSERT P_RPEND <= JT

 ORG JT
 GUARD &C000
 BRK                    \ (P_PGFIX: no run is patched for a buffer now)
 EQUW 0
 JMP r_dspin            \ (P_DSPANSIN: C_DSPANS, gfx-raster_lcold.asm)
 BRK                    \ (P_POLY: phase A is the parasite's, gone)
 EQUW 0
 BRK                    \ (P_LINE: the lines are bank F's, hb-line.asm)
 EQUW 0
 JMP R_SETBUF
 JMP R_SPAN
 BRK                    \ (P_MARKDIRTY: the parasite's, gone)
 EQUW 0
 JMP R_DOT
 JMP R_STARERASE
 JMP R_STARPLOT
 BRK                    \ (P_FLARE: the parasite's, gone)
 EQUW 0
 JMP p_polyin
 BRK                    \ (P_LINEIN: bank F's)
 EQUW 0
 BRK                    \ (P_STOUT, P_STIN: the star records' relay, gone:
 EQUW 0                 \ the host keeps them, C_STARERASE)
 BRK
 EQUW 0
 PRINT "Model B bank P: &8000-&", ~P_LOEND-1, " (free ", RUNB0-P_LOEND, "), &9000-&", ~P_HIEND-1, " (free ", &BC00-P_HIEND, ")"
 SAVE "build/HBP.bin", &8000, &C000, &8000
