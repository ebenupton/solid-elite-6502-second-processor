\ hb-ovl.asm - the Model B host's storage of the parasite's overlays (p-ovl.asm),
\ in main RAM (MR_D: it pages the banks that hold them): overlay D in bank S
\ from OVLD_AT, overlay S and its state in bank D

.hb_ovlget              \ C_OVLGET (h-main.asm's): overlay A's pages, through
 HRX                    \ register 4
 JSR hbo_at
.hbo1
 LDA &8000,Y            \ (patched: the page)
 HTX
 INY
 BNE hbo1
 INC hbo1+2
 DEX
 BNE hbo1
 JMP hbloop

.hb_ovlput              \ C_OVLPUT: an overlay's pages (S's state) to keep
 HRX
 JSR hbo_at
.hbo3
 HRX
.hbo4
 STA &8000,Y            \ (patched: the page)
 INY
 BNE hbo3
 INC hbo4+2
 DEX
 BNE hbo3
 JMP hbloop

.hbo_at                 \ A = the overlay: page its bank, patch its first page
 TAX                    \ into both loops, X = its pages, Y = 0
 LDA hbo_b-1,X
 STA &F4
 STA &FE30
 LDA hbo_h-1,X
 STA hbo1+2
 STA hbo4+2
 LDA hbo_n-1,X
 TAX
 LDY #0
 RTS
.hbo_b EQUB OVLBANK, RASTBANK, RASTBANK, RASTBANK, OVLBANK   \ (D, S's common part, S's state, the
.hbo_h EQUB HI(OVLD_AT), &80 + OVLS0_PAGES, &80 + OVLS_PAGES, &80 + OVLSC_PAGES, HI(OVLD_AT) + OVLD_PAGES   \ meridian tail,
.hbo_n EQUB OVLD_PAGES, OVLSC_PAGES - OVLS0_PAGES, OVLSS_PAGES, OVLS_PAGES - OVLSC_PAGES, OVLTC_PAGES   \ the crater tail; S from its state's last page, ovl_sinit)

