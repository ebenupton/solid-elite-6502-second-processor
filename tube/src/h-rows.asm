\ ******************************************************************************
\
\ h-rows.asm - the Master host's span stores through the row runs (FILL=rows,
\ tube/build.sh; h-layout.asm includes it in place of h-sta.asm): the row
\ runs (gfx-raster.asm's R_RUN, one per character row, STA abs,Y with Y the
\ row) are all in bank 5, the same address in both buffers, main and shadow
\ RAM (ACCCON X choosing), as the Master port's. The code that enters them
\ stays in HAZEL, as with the STA runs, and pages bank 5 as it would a
\ line's bank
\
\ ******************************************************************************

RUN6 = &9F00            \ (h-layout.asm's bound on bank 6, as h-sta.asm's)

.s_rbk EQUB RASTBANK    \ (every row's runs' bank)

.s_pbxe                 \ (as h-sta.asm's)
 LDA s_rbk
 STA &FE30
 JMP r_pbx_e
.s_pbxo
 LDA s_rbk
 STA &FE30
 JMP r_pbx_o
.s_lspan
 LDA s_rbk
 STA &FE30
 JSR r_spc
 LDA #RASTPOLY
 STA &FE30
 RTS

\ s_clr: &4000-&6FFF black in the buffer ACCCON X chooses (f_b0new, C_CLS).
\ Returns with bank 6 (GFXBANK) paged, as h-sta.asm's

.s_clr
 LDA #&40
 STA scl1+2
 LDA #0
 TAX
.scl1
 STA &4000,X            \ (patched)
 INX
 BNE scl1
 INC scl1+2
 LDY scl1+2
 CPY #&70
 BNE scl1
 LDA #GFXBANK
 STA &FE30
 RTS
