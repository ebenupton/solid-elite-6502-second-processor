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

\ the rasteriser's zero page (gfx-raster.asm, gfx-flare.asm, which are
\ assembled after this file)
zR_COLE = &06
zR_COLO = &07
zR_XL = &08
zR_XR = &09
zR_CL = &0A
zR_CR = &0B
zR_CT = &0C
zR_CB = &0D
zR_DCE = &0E
zR_DCO = &0F
zfl_dx = &10
zfl_dy = &11
zc_YE = &1E              \ (r7_rowrep's c_YE, for the pre-erase)

hsp = &E4                \ (a pointer: zero page the game leaves free)

MACRO HRX               \ A = the next byte from the parasite (register 1)
 BIT HR1S
 BPL P%-3
 LDA HR1D
ENDMACRO

MACRO HTX               \ send A to the parasite (register 4)
 BIT HR4S
 BVC P%-3
 STA HR4D
ENDMACRO

\ hwrch: WRCHV while the MOS's Tube code runs the host: &FE from the parasite
\ starts the command loop; anything else is printed (CHPR)

.hwrch
 CMP #&FE
 BNE hwr1
 LDA #GFXBANK           \ (hstart is in bank 6: h-cold.asm)
 STA &F4
 STA &FE30
 JMP hstart
.hwr1
 STA hwa                \ printing in the MOS (a catalogue): CHPR with its zero
 JSR hctxsw             \ page swapped for the command's (hctx), which the MOS's
 LDA hwa                \ Tube code's zero page (&12-&15) overlaps
 JSR CHPR
 JSR hctxsw
 LDA hwa
 RTS
.hwa EQUB 0

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
 EQUW h_sync, h_init, h_fb, h_fe, h_enter, h_disc, h_ddirty, h_span
 EQUW h_mark, h_poly, h_line, h_dot, h_flare, h_direct, h_char, h_keys
 EQUW h_dks, h_wscan, h_noise, h_soflush, h_dstar, h_sceor, h_scsta, h_cls
 EQUW h_boxc, h_clyns, h_clrtext, h_det1, h_irb, h_oscli, h_swap
ASSERT P% - htab = C_MAX

.hloop
 BIT HR1S
 BMI hlp1
 LDA hpe_on             \ (idle: the pre-erase, a step at a time)
 BEQ hloop
 JSR hpe_step
 BRA hloop
.hlp1
 LDA HR1D
 TAX
 LDA hpe_on             \ a command that may draw finishes the pre-erase first
 BEQ hlp2
 LDA hsafe,X
 BNE hlp2
 JSR hpe_fin
.hlp2
 JMP (htab,X)

.h_sync                 \ C_SYNC: a frame's end (the harness hashes the screen
 NOP                    \ here: at h_sync, or at h_syncb if its instruction hook
.h_syncb                \ missed h_sync, as jsbeeb's does on a slice's first
 LDA hpe_arm            \ instruction); after a space frame, the pre-erase of
 BEQ hsy9               \ the next back buffer
 STZ hpe_arm
 JSR hpe_start
.hsy9
 JMP hloop

\ The pre-erase (phase 5): while the parasite runs an iteration's game, the
\ host blacks the next back buffer's old dirty rows outside its old disc rows
\ (what R_DISCROWS' r7_crep would do at the frame's start: these rows are
\ black whatever the new disc), a few rows at a time between commands, once
\ the flip has hidden the buffer; it starts the frame's R_WL/R_WR as
\ R_DISCROWS would (which then leaves them: hpe_w), and leaves the buffer's
\ dirty row range to the old disc rows. Commands that may draw (any not in
\ hsafe) finish it first, as does C_FB.

.hpe_start
 LDA F_BACK             \ (bank 6's)
 EOR #1
 STA hpe_b
 LDA #RASTBANK
 STA &F4
 STA &FE30
 JSR r_wclear           \ the frame's R_WL/R_WR (text2 has read the last's)
 LDA #&FF
 STA R_PRWT
 STZ R_PRWB
 LDA #1
 STA hpe_w
 LDX hpe_b
 LDA R_PRDYT,X          \ the dirty rows dyt..dyb, less the old disc rows
 STA hpe_y              \ dst..dsb: dyt..min(dyb, dst-1), max(dyt, dsb+1)..dyb
 LDA R_PRDYB,X
 STA hpe_e2
 CMP hpe_y
 BCS P%+5
 JMP hpa9               \ (no dirty rows)
 LDA R_PRDSB,X
 CMP R_PRDST,X
 BCS hpa2
 LDA hpe_e2             \ no disc rows: one part, and no dirty rows left
 STA hpe_e
 LDA #&FF
 STA hpe_y2
 STA R_PRDYT,X
 STZ R_PRDYB,X
 BRA hpa8
.hpa2
 LDA R_PRDST,X          \ first part: dyt .. min(dyb, dst - 1)
 DEC A
 CMP hpe_e2
 BCC P%+5
 LDA hpe_e2
 STA hpe_e              \ (empty if dst = 0 or dyt >= dst: hpe_e < hpe_y)
 LDA R_PRDST,X
 BEQ hpa3
 CMP hpe_y
 BCS hpa4
.hpa3
 LDA #&FF               \ (empty)
 STA hpe_e
.hpa4
 LDA R_PRDSB,X          \ second part: max(dyt, dsb + 1) .. dyb
 INC A
 BEQ hpa5
 CMP hpe_y
 BCS P%+5
 LDA hpe_y
 CMP hpe_e2
 BEQ hpa6
 BCC hpa6
.hpa5
 LDA #&FF
.hpa6
 STA hpe_y2
 LDA R_PRDST,X          \ the dirty rows left: max(dyt, dst) .. min(dyb, dsb)
 CMP hpe_y
 BCS P%+5
 LDA hpe_y
 STA hpe_t
 LDA R_PRDSB,X
 CMP hpe_e2
 BCC P%+5
 LDA hpe_e2
 CMP hpe_t
 BCS hpa7
 LDA #&FF
 STA R_PRDYT,X
 STZ R_PRDYB,X
 BRA hpa7b
.hpa7
 STA R_PRDYB,X
 LDA hpe_t
 STA R_PRDYT,X
.hpa7b
 LDA hpe_e              \ an empty first part: straight to the second
 CMP #&FF
 BNE hpa8
 JSR hpe_next
 BRA hpa9
.hpa8
 LDA #1
 STA hpe_on
.hpa9
 LDA #GFXBANK
 STA &F4
 STA &FE30
 RTS

.hpe_next               \ on to the second part (hpe_y2 = &FF: none): done?
 LDA hpe_y2
 CMP #&FF
 BEQ hnx9
 STA hpe_y
 LDA hpe_e2
 STA hpe_e
 LDA #&FF
 STA hpe_y2
 LDA #1
 STA hpe_on
 RTS
.hnx9
 STZ hpe_on
 RTS

.hpe_fin                \ finish it (waiting for the flip). Keeps X
 PHX
.hfi1
 JSR hpe_step
 LDA hpe_on
 BNE hfi1
 PLX
 RTS

.hpe_step               \ up to 4 rows (none until the flip)
 LDA GFLIP
 BNE hps9
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA R_PRBUF
 PHA
 LDX hpe_b
 STX R_PRBUF
 BEQ hps1
 LDA #4                 \ (buffer 1: shadow RAM)
 TSB &FE34
.hps1
 LDY hpe_y
 CPY R_PRWT             \ (the frame's written rows)
 BCS P%+5
 STY R_PRWT
 TYA                    \ rows Y .. min(Y + 3, e)
 CLC
 ADC #3
 CMP hpe_e
 BCC P%+5
 LDA hpe_e
 CMP R_PRWB
 BCC P%+5
 STA R_PRWB
 INC A
 STA zc_YE
 STA hpe_y
 JSR r7_rowrep
 LDA hpe_e
 CMP hpe_y
 BCS hps8
 JSR hpe_next
.hps8
 LDA #4
 TRB &FE34
 PLA
 STA R_PRBUF
 LDA #GFXBANK
 STA &F4
 STA &FE30
.hps9
 RTS

.hpe_on  EQUB 0         \ rows to black
.hpe_arm EQUB 0         \ after the next C_SYNC
.hpe_w   EQUB 0         \ R_DISCROWS: the frame's R_WL/R_WR are started
.hpe_b   EQUB 0         \ the buffer
.hpe_y   EQUB 0         \ the part: next row, last row
.hpe_e   EQUB 0
.hpe_y2  EQUB 0         \ the second part (&FF: none)
.hpe_e2  EQUB 0
.hpe_t   EQUB 0
.hsafe                  \ per command: non-zero if it never draws in the buffers
 FOR i, 0, C_MAX - 1, 2
  IF i=C_SYNC OR i=C_CHAR OR i=C_KEYS OR i=C_DKS OR i=C_WSCAN OR i=C_NOISE OR i=C_SOFLUSH OR i=C_SCEOR OR i=C_SCSTA OR i=C_CLRTEXT OR i=C_DET1 OR i=C_IRB
   EQUB 1, 1
  ELSE
   EQUB 0, 0
  ENDIF
 NEXT

\ h_oscli: C_OSCLI: QQ11 OR GFORCE, GMODE, CHPR's zero page and W, CATF: go
\ back to the MOS's Tube code (its idle loop, with its zero page back), where
\ the parasite's OSCLI runs the command; the parasite's &FE through register 1
\ comes back through hwrch to hstart

.h_init                 \ C_INIT: F_INIT's host part
 JSR T_INIT
 LDA #4                 \ clear main RAM's screen (buffer 0)
 TRB &FE34
 LDA #&40
 STA hin1+2
 LDA #0
 TAX
.hin1
 STA &4000,X
 INX
 BNE hin1
 INC hin1+2
 LDY hin1+2
 CPY #&70
 BNE hin1
 LDX #23+NDSTAR
.hin2
 STA R_SS,X
 DEX
 BPL hin2
 JSR f_tmclear
 JMP hloop

.h_fb                   \ C_FB: F_BACK, GSIGHT
 HRX
 STA F_BACK
 HRX
 STA GSIGHT
 JSR f_bufpatch
 LDA #2
 STA zR_CL
 LDA #253
 STA zR_CR
 LDA #1
 STA zR_CT
 LDA #191
 STA zR_CB
 LDA F_BACK
 JSR T_SETBUF
 JSR f_text1
 JSR f_sight1
.hfb1
 LDA GFLIP              \ wait for the previous flip
 BNE hfb1
 LDA F_BACK
 BEQ hfb2
 LDA #4
 TSB &FE34
.hfb2
 JSR T_STARERASE
 JMP hloop

.h_fe                   \ C_FE: GSIGHT, the stars
 HRX
 STA GSIGHT
 LDX #0
.hfe1
 HRX
 STA R_SX,X
 HRX
 STA R_SY,X
 HRX
 STA R_SS,X
 INX
 CPX #NOST+1
 BNE hfe1
 JSR f_text2
 JSR f_sight2
 LDA #NOST+1
 STA R_SN
 JSR T_STARPLOT
 LDA #4                 \ CPU back to main RAM, and flip at the next vsync
 TRB &FE34
 LDA #%00000010
 STA &FE4E
 LDA F_BACK
 STA GPEND
 LDA #&FF
 STA GFLIP
 LDA #%10000010
 STA &FE4E
 LDA #1                 \ (the pre-erase of the other buffer, after C_SYNC)
 STA hpe_arm
 JMP hloop

.h_enter                \ C_ENTER: GSTASH
 HRX
 STA GSTASH
 STZ QQ11
 JSR f_enter2
 JMP hloop

.h_disc                 \ C_DISC
 HRX
 STA R_NDT
 HRX
 STA R_NDB
 HRX
 STA zR_DCE
 HRX
 STA zR_DCO
 HRX
 STA R_NDF
 BEQ hdi1
 HRX
 STA R_DBE
 HRX
 STA R_DBO
.hdi1
 LDY R_NDT
.hdi2
 CPY R_NDB
 BEQ P%+4
 BCS hdi9
 HRX
 STA R_NDISCL,Y
 HRX
 STA R_NDISCR,Y
 LDA R_NDF
 BEQ hdi4
 HRX
 STA R_NDP,Y
 HRX
 STA R_NDN,Y
 CMP #5
 BCC P%+4
 LDA #4
 TAX
 BEQ hdi4
 HRX
 STA R_NDX0,Y
 DEX
 BEQ hdi4
 HRX
 STA R_NDX1,Y
 DEX
 BEQ hdi4
 HRX
 STA R_NDX2,Y
 DEX
 BEQ hdi4
 HRX
 STA R_NDX3,Y
.hdi4
 INY
 BNE hdi2
.hdi9
 JSR T_DISCROWS
 JMP hloop

.h_ddirty               \ C_DDIRTY
 JSR f_discdirty
 JMP hloop

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

.h_mark                 \ C_MARK: Y, XL, XR
 HRX
 TAY
 HRX
 STA zR_XL
 HRX
 STA zR_XR
 JSR T_MARKDIRTY
 JMP hloop

.h_poly                 \ C_POLY: n, the four colours, the vertices
 HRX
 STA R_PN
 STA hpn
 HRX
 STA zR_COLE
 HRX
 STA zR_COLO
 HRX
 STA R_COL2
 HRX
 STA R_COL3
 LDX #0
.hpo1
 CPX hpn
 BCS hpo9
 HRX
 STA R_PXL,X
 HRX
 STA R_PXH,X
 HRX
 STA R_PYL,X
 HRX
 STA R_PYH,X
 INX
 BNE hpo1
.hpo9
 JSR T_POLY
 JMP hloop
.hpn EQUB 0

.h_line                 \ C_LINE: the four colours, R_X0, R_Y0, R_X1, R_Y1
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

.h_flare                \ C_FLARE: zfl_dx, zfl_dy (this buffer's dirty extents
 HRX                    \ from f_bufpatch, in bank 6)
 STA zfl_dx
 HRX
 STA zfl_dy
 LDX fsw_d1+2
 LDY fsw_d2+2
 JSR T_FLARE
 JMP hloop

.h_direct               \ C_DIRECT: 1 = an in-system jump (space mode kept),
 HRX                    \ 0 = F_DIRECT's f_direct0
 BEQ hdr1
 JSR f_sync
 LDX #0
 LDY #23
 JSR f_clrtext0
 JMP hloop
.hdr1
 JSR f_direct0
 STZ f_dtext
 JMP hloop

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
 HRX
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

.h_dstar                \ C_DSTAR: C, star Y, x, y, ZZ: F_DSTAR
 HRX
 STA hch
 HRX
 TAY
 HRX
 TAX
 HRX
 STA hA
 HRX
 STA ZZ
 LDA hch
 LSR A
 JSR F_DSTAR
 JMP hloop

.h_sceor                \ C_SCEOR: address, value: EOR into shadow RAM (the
 JSR hscad              \ direct-mode screen and the dashboard, as Master's
 LDA #4                 \ drawing writes them with ACCCON X set)
 TSB &FE34
 TXA
 EOR (hsp)
 STA (hsp)
 LDA #4
 TRB &FE34
 JMP hloop

.h_scsta                \ C_SCSTA
 JSR hscad
 LDA #4
 TSB &FE34
 TXA
 STA (hsp)
 LDA #4
 TRB &FE34
 JMP hloop

.hscad                  \ hsp = the address, X = the value
 HRX
 STA hsp
 HRX
 STA hsp+1
 HRX
 TAX
 RTS

.h_cls                  \ C_CLS: TTX66's clear, shadow &4000-&6FFF
 LDA #4
 TSB &FE34
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
 LDA #4
 TRB &FE34
 JMP hloop

.h_boxc                 \ C_BOXC: BOX's corners, in A
 HRX
 TAX
 LDA #4
 TSB &FE34
 STX &4000
 STX &41F8
 LDA #4
 TRB &FE34
 JMP hloop

.h_clyns                \ C_CLYNS: CLYNS's clear of text rows 20-23
 LDA #4
 TSB &FE34
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
 LDA #4
 TRB &FE34
 JMP hloop

.h_clrtext              \ C_CLRTEXT: QQ11 OR GFORCE, GMODE: the text map's rows
 HRX                    \ 21-23
 STA QQ11
 STZ GFORCE
 HRX
 STA GMODE
 JSR G_CLRTEXT
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
