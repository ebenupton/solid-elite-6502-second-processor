\ ******************************************************************************
\
\ h-sta.asm - the Master host's STA runs (h-layout.asm, the kernel): one run per
\ screen line of the 3D view (192), the Master port's row runs' form for a
\ line (gfx-raster.asm's R_RUN): an STA abs,Y per byte of the line, Y = 8 cl
\ (cl the span's left end's column, or cl - 32 from the right half), the
\ line's byte for column c being &4000 + &200 * (L DIV 8) + (L AND 7) + 8c,
\ the same address in both buffers, main and shadow RAM, ACCCON X choosing.
\ They are made at the host's start (s_gen, from hstart), not carried on the
\ disc. The code that enters them (r_spc, phase B; r_rowset sets r_jmp and
\ s_rbk from the tables here) is in the kernel with them, main RAM, so a
\ run's bank can be paged in unconditionally for each span (LDA s_rbk : STA
\ &FE30), with no copy in &F4
\
\ ******************************************************************************

s_opSTA = &99           \ STA abs,Y (the runs' stores)
s_opJMP = &4C           \ JMP abs (their exits, to r_xw)
R_ROWS = 192            \ the lines of the 3D view, with a run each

\ Each line's run is at the start of a page of its own, 192 bytes, entered by a
\ JMP and left by its fixed exits (r_spc's header, gfx-raster.asm):
\   offset 0:   L, the stores for m = 32 down to 1 (column cl + m, Y = 8 cl)
\   offset 96:  JMP r_xw
\   offset 99:  H, m = 62 down to 33
\   offset 189: JMP r_xw (a long row points it at L for the row: the low byte
\               at offset 190)
\ so the entries are r_j's offsets in the page with no sums. The runs are in
\ line order: line L's is page &80 + L MOD 64 of bank 4 + L DIV 64, so banks
\ 4, 5 and 6 hold lines 0-63, 64-127 and 128-191. Bytes 192-255 of line L's
\ page hold quarter L of overlay D's stored image (h-main.asm's h_ovlget,
\ tube/build.sh)

.s_pg                   \ per line: its run's page, and its bank
FOR L, 0, R_ROWS - 1
 EQUB &80 + L MOD 64
NEXT
.s_bk
FOR L, 0, R_ROWS - 1
 EQUB 4 + L DIV 64
NEXT

\ Phase B steps a row at a time and stops at r_yend, which r_pcbs sets to
\ R_ROWS (gfx-raster_poly.asm), one past the last line, before it reads a
\ row's page and bank here: line R_ROWS would be page &80 of bank 7, a
\ stored page of overlay S. (The last line's run is in bank 6.)
ASSERT 4 + (R_ROWS - 1) DIV 64 = 6

.s_rbk EQUB 0           \ the row's run's bank (r_rowset)

\ The row's bank in, from the kernel (phase B's set-up, r_pcbs, in bank 7,
\ would page itself out): phase B's first row

.s_pbxe
 LDA s_rbk
 STA &FE30
 JMP r_pbx_e
.s_pbxo
 LDA s_rbk
 STA &FE30
 JMP r_pbx_o

\ s_gen: make the runs (hstart, once). Returns with bank 7 (GFXBANK) paged

.s_gen
 LDX #0                 \ X = the line
.sg1
 LDA s_bk,X
 STA &FE30
 STZ RZ_PP
 LDA s_pg,X
 STA RZ_PP+1
 TXA                    \ the line's byte in column 0: low (L AND 7), high
 AND #7
 STA sgl
 TXA
 LSR A
 LSR A
 AND #&FE
 ORA #&40
 STA sgh
 LDY #0
 LDA #32                \ L: m = 32 down to 1
 STA sgm
 STA sgc
 JSR sgr
 LDA #62                \ H: m = 62 down to 33
 STA sgm
 LDA #30
 STA sgc
 JSR sgr
 INX
 CPX #R_ROWS
 BNE sg1
 LDA #GFXBANK
 STA &FE30
 RTS
.sgr                    \ sgc stores, column sgm down, from offset Y, then JMP r_xw
 LDA #s_opSTA
 STA (RZ_PP),Y
 INY
 LDA sgm                \ 8 m (C: m >= 32) OR (L AND 7), + the line's high byte
 ASL A
 ASL A
 ASL A
 ORA sgl
 STA (RZ_PP),Y
 INY
 LDA sgh
 ADC #0
 STA (RZ_PP),Y
 INY
 DEC sgm
 DEC sgc
 BNE sgr
 LDA #s_opJMP
 STA (RZ_PP),Y
 INY
 LDA #LO(r_xw)
 STA (RZ_PP),Y
 INY
 LDA #HI(r_xw)
 STA (RZ_PP),Y
 INY
 RTS
.sgl EQUB 0
.sgh EQUB 0
.sgm EQUB 0
.sgc EQUB 0

\ s_clr: lines 0-191 black (the whole of &4000-&6FFF in the buffer ACCCON X
\ chooses): columns 0 and 63, then the line's run, L and H, with Y = 0 (cl =
\ 0: columns 32-1 and 62-33), their exit pointed here (f_b0new, C_CLS).
\ Returns with bank 7 (GFXBANK) paged

.s_clr
 LDX #0
.scl1
 LDA s_bk,X
 STA &FE30
 LDA s_pg,X
 STA scl2+2
 STA scl4+2
 TXA                    \ columns 0 and 63, which the runs do not store
 AND #7
 STA scl3+1
 ORA #&F8
 STA scl5+1
 TXA
 LSR A
 LSR A
 AND #&FE
 ORA #&40
 STA scl3+2
 INC A
 STA scl5+2
 LDA #LO(scr1)
 STA r_xw+1
 LDA #HI(scr1)
 STA r_xw+2
 LDA #0
 TAY
.scl3
 STA &FFFF              \ (patched)
.scl5
 STA &FFFF              \ (patched)
.scl2
 JMP &FF00              \ (patched: the line's run, L)
.scr1
 LDA #LO(scr2)
 STA r_xw+1
 LDA #HI(scr2)
 STA r_xw+2
 LDA #0
.scl4
 JMP &FF00 + 99         \ (patched: the line's run, H)
.scr2
 INX
 CPX #R_ROWS
 BNE scl1
 LDA #LO(r_spret)       \ (the runs' exit back to r_spc's)
 STA r_xw+1
 LDA #HI(r_spret)
 STA r_xw+2
 LDA #GFXBANK
 STA &FE30
 RTS
