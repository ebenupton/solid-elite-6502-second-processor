\ ******************************************************************************
\
\ h-main.asm - the host's command loop (docs/TUBE-MAP.md)
\
\ The host owns the screen, the sound chip and the keyboard, and executes the
\ parasite's commands (tube/src/cmds.asm). Its drawing is the Master port's:
\ the rasteriser (banks 5 and ANDY), the frame layer's text map, text overlay
\ and sights (bank 6, gfx-frame.asm's host part), CHPR, the IRQ and the sound
\ (elite-source.asm's blocks tagged "Tube: host" or "both"). Bank 6 is paged
\ in between commands (the trampolines into the rasteriser page it back).
\
\ Entered through WRCHV (hwrch): the loader starts the parasite through the
\ MOS's Tube code, which leaves the host in its idle loop, passing register
\ 1's bytes to OSWRCH; the parasite's first byte is &FE, and from then on the
\ host never returns to the MOS (until a disc command, phase 2).
\
\ ******************************************************************************

IF _HOSTB = 0
 INCLUDE "tsrc/h-zp.asm"
ENDIF

\ hwrch: WRCHV while the MOS's Tube code runs the host: &FE from the parasite
\ starts the command loop; anything else is printed (CHPR)

IF _HOSTB = 0             \ (Model B: in main RAM, hb-res.asm)
.hwrch
 CMP #&FE
 BNE hwr1
 LDA #GFXBANK           \ (hstart is in bank 6: h-cold.asm)
 STA &F4
 STA &FE30
 JMP hstart
.hwr1
 STA hwa                \ printing in the MOS (a catalogue): CHPR with its zero
 PHX                    \ page swapped for the command's (hctx), which the MOS's
 PHY                    \ Tube code's zero page (&12-&15) overlaps; X and Y kept,
 JSR hctxsw             \ as OSWRCH must (DFS's catalogue counts in Y)
 LDA hwa
 JSR CHPR
 JSR hwpos
 JSR hctxsw
 PLY
 PLX
 LDA hwa
 RTS
.hwa EQUB 0
ENDIF

.hwpos                  \ the MOS's text cursor (&0318, VDU's: OSBYTE 134's POS
 LDA hwa                \ plus the text window's left, &0308) as the characters
 CMP #13                \ printed through hwrch would leave it (CHPR drops a
 BNE hwp1               \ column of the catalogue, so its own XC would hold
 LDA #0                 \ DFS's padding loop for ever)
 STA hwcol
 BEQ hwp2
.hwp1
 CMP #32
 BCC hwp2
 INC hwcol
.hwp2
 LDA hwcol
 CLC
 ADC &0308
 STA &0318
 RTS
.hwcol EQUB 0

.hctxsw                 \ exchange zero page &0A-&15 and W with hctx
 LDX #HCTXN-1
.hcs1
 LDA &0A,X
 LDY hctx,X
 STA hctx,X
 STY &0A,X
 DEX
 BPL hcs1
 LDA W
 LDY hctx+HCTXN
 STA hctx+HCTXN
 STY W
 RTS
HCTXN = 12
.hctx SKIP HCTXN+1      \ CHPR's zero page and W, between the parasite's commands



.htab
 EQUW h_sync, h_init, h_bad, h_bad, h_bad, h_bad, h_bad, h_span
 EQUW h_bad, h_bad, h_line, h_dot, h_bad, h_bad, h_char, h_keys
 EQUW h_dks, h_wscan, h_noise, h_soflush, h_bad, h_bad, h_bad, h_cls
 EQUW h_boxc, h_clyns, h_bad, h_det1, h_irb, h_oscli, h_swap, h_bad
 EQUW h_ovlget, h_pdials, h_pdot, h_pscan, h_pmsbar, h_pbulb
 EQUW h_buf, h_flip, h_spans, h_orspan, h_stars, h_starerase, h_glyph, h_enterb
 EQUW h_clrbuf, h_eordot, h_directd, h_ovlput, h_loin, h_bad, h_hloin, h_pixel, h_dspans
ASSERT P% - htab = C_MAX

.hloop
 BIT HR2S               \ a request (register 2) first, then the next command
 BMI hreq
 BIT HR1S
 BPL hloop
 LDA HR1D
.hdisp
 TAX
IF _HOSTB                 \ (Model B: no JMP (abs,X) on an NMOS 6502)
 LDA htab,X
 STA hlpj+1
 LDA htab+1,X
 STA hlpj+2
.hlpj
 JMP &FFFF
ELSE
 JMP (htab,X)
ENDIF
.hreq
 LDA HR2D
 JMP hdisp

IF _HOSTB = 0             \ (the Model B host's: hb-ovl.asm)
ENDIF

IF _HOSTB = 0
.hdead                  \ (h-dead.asm's names: never run; R_SETBUF's patches of
 BRK                    \ their operands write here)
 EQUB 0, 0, 0
ENDIF

.h_bad                  \ (the commands of the host that kept the rasteriser's
 JMP hloop              \ state: none now)

.h_sync                 \ C_SYNC: a frame's end (the harness hashes the screen
 NOP                    \ here: at h_sync, or at h_syncb if its instruction hook
.h_syncb                \ missed h_sync, as jsbeeb's does on a slice's first
 JMP hloop              \ instruction)

\ h_oscli: C_OSCLI: QQ11 OR GFORCE, GMODE, CHPR's zero page and W, CATF: go
\ back to the MOS's Tube code (its idle loop, with its zero page back), where
\ the parasite's OSCLI runs the command; the parasite's &FE through register 1
\ comes back through hwrch to hstart

.h_init                 \ C_INIT: F_INIT's host part: the drawing code's state
IF _HOSTB = 0             \ (R_INIT's part that the drawing reads: the stars'
 LDA #&FF               \ colour, no stars, no polygon rows, buffer 0's patches;
 STA R_SCOL             \ the Model B host's are set per command, and its R_PN
 LDA #0                 \ is bank P's)
 STA R_SN
 STA R_PN
 LDA #1
 STA R_PRBUF
 LDA #0
 JSR T_SETBUF
ENDIF
IF _HOSTB = 0
 LDA #4                 \ clear main RAM's screen (buffer 0)
 TRB &FE34
ENDIF
IF _HOSTB
 LDA #HI(BUF0)          \ (Model B: buffer 0 at BUF0)
ELSE
 LDA #&40
ENDIF
 STA hin1+2
 LDA #0
 TAX
.hin1
 STA &4000,X
 INX
 BNE hin1
 INC hin1+2
 LDY hin1+2
IF _HOSTB
 CPY #HI(BUF0)+&30
ELSE
 CPY #&70
ENDIF
 BNE hin1
 LDX #23+NDSTAR
.hin2
 STA R_SS,X
 DEX
 BPL hin2
 JMP hloop

\ h_ovlget: C_OVLGET: overlay A's image (the parasite's p-ovl.asm), whole pages
\ from its place in the host's storage (h_ovl: storage only), through register 4

.h_ovlget
IF _HOSTB
 JMP hb_ovlget          \ (Model B: main RAM, hb-ovl.asm)
.h_ovlput
 JMP hb_ovlput
ELSE
 HRX
 TAX
 LDA h_ovlh-1,X
 STA hog1+2
 LDA h_ovln-1,X
 STA hogn
 LDA h_ovlb-1,X
 STA &F4
 STA &FE30
 LDY #0
.hog1
 LDA &8000,Y            \ (patched: the page)
 HTX
 INY
 BNE hog1
 INC hog1+2
 DEC hogn
 BNE hog1
 JMP hogx

.h_ovlput               \ C_OVLPUT: an overlay's pages (S's state) to keep
 HRX
 TAX
 LDA h_ovlh-1,X
 STA hop1+2
 LDA h_ovln-1,X
 STA hogn
 LDA h_ovlb-1,X
 STA &F4
 STA &FE30
 LDY #0
.hop0
 HRX
.hop1
 STA &8000,Y            \ (patched: the page)
 INY
 BNE hop0
 INC hop1+2
 DEC hogn
 BNE hop0
.hogx
 LDA #GFXBANK
 STA &F4
 STA &FE30
 JMP hloop
.hogn EQUB 0
.h_ovlb EQUB OVLBANK, OVLSBANK, OVLSBANK    \ each overlay's bank, first page, pages
.h_ovlh EQUB &80, &80, &80 + OVLS_PAGES
.h_ovln EQUB OVLD_PAGES, OVLS_PAGES, OVLSS_PAGES
ENDIF

IF _HOSTB = 0             \ (the Model B host's: hb-res2.asm)
.T_STERASE              \ (h-prim.asm's: bank 5's R_STARERASE)
 LDA #RASTBANK
 STA &F4
 STA &FE30
 JSR R_STARERASE
 JMP tback
ENDIF

.h_span                 \ C_SPAN: Y, XL, XR, COLE, COLO
 HRX
 TAY
 HRX
 STA zR_XL
 HRX
 STA zR_XR
 HRX
 STA zR_COLE
 HRX
 STA zR_COLO
 JSR T_SPAN
 JMP hloop

.h_dspans               \ C_DSPANS: rows of spans (p-rast.asm's R_DISCROWS), read
IF _HOSTB                 \ and drawn by r_dspin (gfx-raster_lcold.asm): the row,
 JMP hb_dspans          \ then XL, XR, COLE, COLO for each of its spans, &FF ending
ELSE                      \ the row; &FF for a row ends
 LDA #RASTBANK
 STA &F4
 STA &FE30
 JSR r_dspin
 JSR tback
 JMP hloop
ENDIF

.h_spans                \ C_SPANS: polygon rows (p-emit.asm): COLE, COLO, COL2,
IF _HOSTB                 \ COL3, the first row, then left and right (exclusive)
 JMP hb_poly            \ per row, clipped, which phase B's fill reads as it
ELSE                      \ goes, to the end mark (gfx-raster_poly.asm's r_pcbs)
 HRX
 STA zR_COLE
 HRX
 STA zR_COLO
 HRX
 STA R_COL2
 HRX
 STA R_COL3
 HRX
 STA R_PYS
 LDA #RASTPOLY
 STA &F4
 STA &FE30
 JSR r_pcbs
 JSR tback
 JMP hloop
ENDIF

.h_line                 \ C_LINE: the four colours, R_X0, R_Y0, R_X1, R_Y1
IF _HOSTB
 JMP hb_line               \\ (main RAM: hb-res.asm)
ENDIF
 HRX
 STA zR_COLE
 HRX
 STA zR_COLO
 HRX
 STA R_COL2
 HRX
 STA R_COL3
 LDX #0
.hli1
 HRX
 STA R_X0,X
 INX
 CPX #8
 BNE hli1
 JSR T_LINE
 JMP hloop

.h_dot                  \ C_DOT: COLE, COLO, x, y, size
 HRX
 STA zR_COLE
 HRX
 STA zR_COLO
 HRX
 STA hdx
 HRX
 STA hdy
 HRX
 LDX hdx
 LDY hdy
 JSR T_DOT
 JMP hloop
.hdx EQUB 0
.hdy EQUB 0

.h_char                 \ C_CHAR: the character, XC, YC, COL, CATF, QQ17, QQ11
 HRX                    \ OR GFORCE, GMODE: CHPR as the parasite's ran it, but
 STA hch                \ drawing
 HRX
 STA XC
 HRX
 STA YC
 HRX
 STA COL
 HRX
 STA CATF
 HRX
 STA QQ17
 HRX
 STA QQ11
 STZ GFORCE
 HRX
 STA GMODE
 LDA hch
 JSR CHPR
 JMP hloop
.hch EQUB 0

\ h_keys: C_KEYS: the keys held, internal numbers 16 to 127 in increasing
\ order, then 0. As FILLKL (and fkdet): the columns with a key held in rows
\ 1-7 first, then each row's keys in those columns

.h_keys
 LDA #%00000010         \ (vsync masked during the scan, as FILLKL)
 STA VIA+&4E
 STZ hkn
 LDY #%00000011         \ stop the auto scan
 STY VIA+&40
 LDA #%01111111
 STA VIA+&43
 LDX #0
.hkc
 LDA #15
 STA VIA+&4F
 LDA #1
 STA VIA+&4D
 STX VIA+&4F
 LDA VIA+&4D
 LSR A
 BCC hkc1
 LDY hkn
 TXA
 STA hkl,Y
 INC hkn
.hkc1
 INX
 CPX #13
 BNE hkc
 LDA #16
 STA hkr
.hkr1
 LDX #0
.hkk
 CPX hkn
 BCS hkr9
 LDA hkl,X
 ORA hkr
 STA VIA+&4F
 BIT VIA+&4F
 BPL hkk1
 AND #&7F
 HTX
.hkk1
 INX
 BNE hkk
.hkr9
 LDA hkr
 CLC
 ADC #16
 STA hkr
 BPL hkr1
 LDY #%00001011         \ restart the auto scan
 STY VIA+&40
 LDA #%10000010
 STA VIA+&4E
 LDA #0
 HTX
 JMP hloop
.hkn EQUB 0
.hkr EQUB 0
.hkl SKIP 13

.h_dks                  \ C_DKS: is key A held (DKS5): A with bit 7 if so
 HR2X
 LDX #3
 SEI
 STX VIA+&40
 LDX #%01111111
 STX VIA+&43
 STA VIA+&4F
 LDX VIA+&4F
 LDA #%00001011
 STA VIA+&40
 CLI
 TXA
 HTX
 JMP hloop

.h_wscan                \ C_WSCAN: answer at the next vsync
 STZ DL
.hws1
 LDA DL
 BEQ hws1
 HTX
 JMP hloop

.h_noise                \ C_NOISE: Y, DNOIZ
 HRX
 TAY
 HRX
 STA DNOIZ
 JSR NOISE
 JMP hloop

.h_soflush              \ C_SOFLUSH
 JSR SOFLUSH
 JMP hloop

.h_cls                  \ C_CLS: TTX66's clear, shadow &4000-&6FFF
IF _HOSTB = 0
 LDA #4
 TSB &FE34
ENDIF
 LDA #&40
 STA hcl1+2
 LDA #0
 TAX
.hcl1
 STA &4000,X
 INX
 BNE hcl1
 INC hcl1+2
 LDY hcl1+2
 CPY #&70
 BNE hcl1
IF _HOSTB = 0
 LDA #4
 TRB &FE34
ENDIF
 JMP hloop

.h_boxc                 \ C_BOXC: BOX's corners, in A
 HRX
 TAX
IF _HOSTB = 0
 LDA #4
 TSB &FE34
ENDIF
 STX &4000
 STX &41F8
IF _HOSTB = 0
 LDA #4
 TRB &FE34
ENDIF
 JMP hloop

.h_clyns                \ C_CLYNS: CLYNS's clear of text rows 20-23
IF _HOSTB = 0
 LDA #4
 TSB &FE34
ENDIF
 LDA #&6A
 STA hsp+1
 LDA #0
 STA hsp
 LDX #3
.hcy1
 LDY #8
.hcy2
 STA (hsp),Y
 INY
 BNE hcy2
 INC hsp+1
 STA (hsp),Y
 LDY #247
.hcy3
 STA (hsp),Y
 DEY
 BNE hcy3
 INC hsp+1
 DEX
 BNE hcy1
IF _HOSTB = 0
 LDA #4
 TRB &FE34
ENDIF
 JMP hloop

.h_det1                 \ C_DET1: 6845 R6 = X
 HRX
 TAX
 LDA #6
 SEI
 STA &FE00
 STX &FE01
 CLI
 JMP hloop

.h_irb                  \ C_IRB: the System VIA's port B
 LDA VIA+&40
 HTX
 JMP hloop


\ The parasite's routines that the host's copies of the game's blocks refer
\ to but never reach here

.TTX66M                 \ (CHPR's cls and its screen's end: the parasite's)
.BEEP                   \ (CHPR's R5: the parasite's)
 RTS
