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
 BEQ hstart
 JMP CHPR

.hstart
 LDX #&FF
 TXS
 SEI
 LDA #%00111001         \ as SETINTS: no CB1, CB2, CA2 or T2 interrupts from the
 STA VIA+&4E            \ System VIA, none from the User VIA, IRQ1V = IRQ1
 LDA #%01111111
 STA &FE6E
 LDA #LO(IRQ1)
 STA IRQ1V
 LDA #HI(IRQ1)
 STA IRQ1V+1
 LDA #GFXBANK           \ (the resting bank: the frame layer's host part)
 STA &F4
 STA &FE30
 CLD
 JSR T1SYNC             \ (CLIs)
 JMP hloop

.htab
 EQUW h_sync, h_init, h_fb, h_fe, h_enter, h_disc, h_ddirty, h_span
 EQUW h_mark, h_poly, h_line, h_dot, h_flare, h_direct, h_char, h_keys
 EQUW h_dks, h_wscan, h_noise, h_soflush, h_dstar, h_sceor, h_scsta, h_cls
 EQUW h_boxc, h_clyns, h_clrtext, h_det1, h_irb, h_oscli
ASSERT P% - htab = C_MAX

.hloop
 BIT HR1S
 BPL hloop
 LDA HR1D
 TAX
 JMP (htab,X)

.h_sync                 \ C_SYNC: a frame's end (the harness hashes the screen
.h_oscli                \ here); C_OSCLI: phase 2
 JMP hloop

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
