\ hb-ovl.asm - the Model B host's storage of the parasite's overlays (p-ovl.asm),
\ in main RAM (MR_D: it pages the banks that hold them): overlay D in bank S
\ from OVLD_AT, overlay S in bank D

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

.hbo_at                 \ A = the overlay: page its bank, patch its first page
 TAX                    \ into the loop, X = its pages, Y = 0
 LDA hbo_b-1,X
 STA &F4
 STA &FE30
 LDA hbo_h-1,X
 STA hbo1+2
 LDA hbo_n-1,X
 TAX
 LDY #0
 RTS
.hbo_b EQUB OVLBANK, RASTBANK                  \ (D, S: S's image from its state's
.hbo_h EQUB HI(OVLD_AT), &80                    \ end, the state being never kept:
.hbo_n EQUB OVLD_PAGES, OVLS_PAGES - OVLS0_PAGES \ p-ovl.asm; bank D's rest is free)
 ASSERT OVLS_PAGES - OVLS0_PAGES <= 64
