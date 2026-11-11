\ ******************************************************************************
\
\ h-main.asm - the host's command loop (docs/TUBE-MAP.md)
\
\ The host owns the screen, the sound chip and the keyboard, and executes the
\ parasite's commands (tube/src/cmds.asm). Its drawing is the Master port's:
\ the rasteriser, the frame layer's host part (gfx-frame.asm), CHPR, the IRQ
\ and the sound (elite-source.asm's blocks tagged "Tube: host" or "both").
\ The Master host's code is bank 7's, paged whenever it runs outside the STA
\ runs, and the kernel's in main RAM (h-layout.asm): only the kernel pages a
\ line's bank in, and it pages bank 7 back (hbank). The Model B host's
\ resting bank is bank 7 (the trampolines into its rasteriser page it back).
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
 LDA #GFXBANK           \ (hstart is in the resting bank: h-cold.asm)
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

.hdbrk                  \ (BRKV during h_disc's OSCLI: the bank of h_derr)
 LDA #GFXBANK
 STA &F4
 STA &FE30
 JMP h_derr
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
 EQUW h_bad, h_bad, h_line, h_dot, h_bad, h_bad, h_char, h_bad
 EQUW h_bad, h_bad, h_bad, h_bad, h_bad, h_bad, h_bad, h_cls
 EQUW h_boxc, h_clyns, h_bad, h_det1, h_bad, h_disc, h_bad, h_bad
 EQUW h_ovlget, h_pdials, h_pdot, h_pscan, h_pmsbar, h_pbulb
 EQUW h_buf, h_flip, h_spans, h_orspan, h_stars, h_starerase, h_glyph, h_enterb
 EQUW h_clrbuf, h_eordot, h_directd, h_bad, h_loin, h_bad, h_hloin, h_pixel, h_dspans
ASSERT P% - htab = C_MAX

.hloop
 BIT HR1S               \ the next command
 BMI hlp1
 BVC hloop              \ (register 1 empty: the parasite's doorbell, through
 STA HR1D               \ register 1 to it, unless one already waits there;
 BVS hloop              \ p-io.asm's ring)
.hlp1
 LDA HR1D
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

IF _HOSTB = 0             \ (the Model B host's: hb-ovl.asm)
ENDIF

IF _HOSTB = 0             \ (the Model B host's: hb-main.asm, at a fixed place)
.hrw                    \ register 1 empty: ring the parasite's doorbell (any
 BIT HR1S               \ byte through register 1, host to parasite), and again
 BMI hrw9               \ whenever the parasite has taken it, while register 1
 BVC hrw                \ stays empty (p-io.asm's ring). Keeps A, X and Y
 STA HR1D
 BVS hrw
.hrw9
 RTS
ENDIF

.h_bad                  \ (the commands of the host that kept the rasteriser's
 JMP hloop              \ state: none now)

.h_sync                 \ C_SYNC: a frame's end (the harness hashes the screen
 NOP                    \ here: at h_sync, or at h_syncb if its instruction hook
.h_syncb                \ missed h_sync, as jsbeeb's does on a slice's first
 JMP hloop              \ instruction)

.h_init                 \ C_INIT: F_INIT's host part: the drawing code's state
 LDA #&FF               \ (R_INIT's part that the drawing reads: the stars'
 STA R_SCOL             \ colour, no stars, buffer 0's patches)
 LDA #0
 STA R_SN
 LDA #1
 STA R_PRBUF
 LDA #0
 JSR R_SETBUF
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
 LDX #NDSTAR-1
.hin2
 STA R_SS,X
 DEX
 BPL hin2
 JMP hloop

\ h_ovlget: C_OVLGET: overlay A's image (the parasite's p-ovl.asm), whole pages
\ from its place in the host's storage (storage only), through register 4

.h_ovlget
IF _HOSTB
 JMP hb_ovlget          \ (Model B: main RAM, hb-ovl.asm)
ELSE                      \ (the Master host: h-layout.asm's storage)
 HRX
 CMP #1
 BNE hos0
 LDA #4                 \ D: its page p is quarters 4p to 4p+3, bytes 192-255
 STA hogb               \ of the pages of lines 4p to 4p+3's runs, page &80
 LDA #&80               \ + 4p MOD 64 of bank 4 + 4p DIV 64 (h-sta.asm)
 STA hogq1+2
 LDX #4 * OVLD_PAGES    \ (the quarters)
.hod0
 LDA hogb
 STA &FE30
.hogq
 LDY #&C0
.hogq1
 LDA &FF00,Y            \ (patched: the quarter's line's page)
 HTX
 INY
 BNE hogq1
 INC hogq1+2
 LDA hogq1+2
 CMP #&C0
 BNE hod1
 LDA #&80               \ (the next bank's first line)
 STA hogq1+2
 INC hogb
 DEX
 BNE hod0
 BEQ hogx
.hod1
 DEX
 BNE hogq
 BEQ hogx
.hos0                   \ S: its pages from its three extents, in address
 LDA &FE34              \ order: main RAM with ACCCON X clear (only X is
 AND #4                 \ touched: TRB/TSB), then bank 7's, which is paged
 STA hova
 LDA #4
 TRB &FE34
 LDX #0
.hos1
 LDA hse_pg,X
 STA hog1+2
 LDA hse_n,X
 STA hogn
.hos2
 LDY #0
.hog1
 LDA &FF00,Y            \ (patched: the page)
 HTX
 INY
 BNE hog1
 INC hog1+2
 DEC hogn
 BNE hos2
 INX
 CPX #3
 BNE hos1
 LDA hova               \ (ACCCON's X as it was)
 TSB &FE34
.hogx
 LDA #GFXBANK
 STA &FE30
 JMP hloop
.hse_pg EQUB HI(HSTS0), &70, &80        \ (S's extents: h-layout.asm)
.hse_n  EQUB &40 - HI(HSTS0), &10, HI(B7_START) - &80
.hogb EQUB 0
.hogn EQUB 0
.hova EQUB 0
ENDIF

IF _HOSTB = 0
.hbank                  \ after the kernel's drawing through the STA runs, which
 LDA #GFXBANK           \ leaves a line's bank paged: bank 7 back, then the
 STA &FE30              \ next command
 JMP hloop
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
IF _HOSTB
 JSR T_SPAN             \ (Model B: bank 4's R_SPAN)
 JMP hloop
ELSE
 JSR R_SPAN
 JMP hbank
ENDIF

.h_dspans               \ C_DSPANS: rows of spans (p-rast.asm's R_DISCROWS), read
IF _HOSTB                 \ and drawn by r_dspin (gfx-raster_lcold.asm): the row,
 JMP hb_dspans          \ then XL, XR, the row's colour for each span, &FF ending
ELSE                      \ the row; &FF for a row ends
 JSR r_dspin
 JMP hbank
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
 JSR r_pcbs
 JMP hbank
ENDIF

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
 JSR R_LINE
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
 JSR R_DOT
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

.hk_body                \ (h4body's)
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
 RTS
.hkn EQUB 0
.hkr EQUB 0
.hkl SKIP 13

.hdks_body              \ C_DKS: is key A held (DKS5): A with bit 7 if so
                        \ (PHP/PLP, not SEI/CLI: h4body runs it in the IRQ)
 LDX #3
 PHP
 SEI
 STX VIA+&40
 LDX #%01111111
 STX VIA+&43
 STA VIA+&4F
 LDX VIA+&4F
 LDA #%00001011
 STA VIA+&40
 PLP
 TXA
 HTX
 RTS

\ h4body: a fast request from register 4 (the parasite's preq4): C_KEYS,
\ C_DKS with its key, or C_IRB, answered at once from the host's IRQ (the
\ Tube's Q flag: register 4's data), wherever the host is (the Master host's
\ h4irq below, the Model B host's irqm, hb-res3.asm). X and Y are the IRQ's

.h4body
 LDA HR4D
 CMP #C_KEYS
IF _HOSTB = 0
 BNE P%+5
 JMP h4k
 CMP #C_IRB             \ (the Master host: the short answer early, h4irq)
 BEQ h4i
 CMP #C_TOKEN
 BEQ h4t
ELSE
 BNE P%+5
 JMP hk_body
 CMP #C_TOKEN
 BEQ h4t
 CMP #C_IRB
 BEQ h4i
ENDIF
 CMP #C_WSCAN           \ C_WSCAN: pending, the next vsync interrupt answers it
 BEQ h4w                \ (H_VSYNC; Model B: hb_irq)
 CMP #C_NOISE
 BEQ h4n
 CMP #C_SOFLUSH
 BEQ h4f
.h4d                    \ C_DKS: its key next, through register 4
 BIT HR4S
 BPL h4d
 LDA HR4D
IF _HOSTB = 0
 CLI                    \ (the Master host: interrupts on once register 4's
ENDIF                   \ bytes are all read, so timer 1 is not held off: h4irq)
 JMP hdks_body
.h4i
IF _HOSTB = 0
 CLI                    \ (the Master host: as C_DKS's)
ENDIF
 LDA VIA+&40
 HTX
 RTS
.h4t                    \ C_TOKEN: the token's number next; its bytes as stored,
 BIT HR4S               \ the null included (the host keeps QQ18 as it keeps
 BPL h4t                \ the overlays' images: data only, build/HQQ18.bin, and
 LDX HR4D               \ where each token starts, build/htokix.asm)
IF _HOSTB = 0
 CLI                    \ (the Master host: as C_DKS's)
ENDIF
 LDA HTOKL,X
 STA h4tl+1
 LDA HTOKH,X
 STA h4tl+2
 LDY #0
.h4tl
 LDA &FFFF,Y            \ (patched)
 HTX
 INY
 TAX
 BNE h4tl
 RTS
.h4w
 LDA #&80
 STA hwsp
 RTS
.h4n                    \ C_NOISE: Y, DNOIZ next, through register 4
 BIT HR4S
 BPL h4n
 LDA HR4D
 TAY
.h4n1
 BIT HR4S
 BPL h4n1
 LDA HR4D
 STA DNOIZ
 LDA VIA+&4E            \ (NOISE unmasks the vsync interrupt as it ends: mask it
 PHA                    \ again if the interrupted code had)
 JSR NOISE
.h4f9
 PLA
 AND #%00000010
 BNE h4f8
 LDA #%00000010
 STA VIA+&4E
.h4f8
 RTS
.h4f                    \ C_SOFLUSH
 LDA VIA+&4E
 PHA
 JSR SOFLUSH
 JMP h4f9
.hwsp EQUB 0            \ bit 7: a C_WSCAN waits for the next vsync

IF _HOSTB = 0
\ h4irq: IRQ1V while the game runs (h4on bit 7): timer 1 first, then
\ register 4's requests, then the rest of the game's IRQ1. Off while the MOS
\ runs a disc command, whose Tube traffic uses register 4 itself. Timer 1 is
\ the split at the panel's top: IRQ1 sets ACCCON D there (the panel is in
\ shadow RAM), and the write must land in line 191's horizontal blanking, or
\ when main RAM's buffer is on show the panel's top lines come from main RAM
\ (&7000 up) for a field. So a request never holds it off for long: a timer
\ 1 interrupt goes straight to IRQ1, and so does one that comes as a
\ request starts; a request runs with interrupts on once register 4's bytes
\ are read (C_KEYS, C_IRB, C_DKS, C_TOKEN: a nested request is answered whole)

.h4irq
 BIT VIA+&4D            \ timer 1 (the split at the panel's top) before any
 BVS h4x                \ request: IRQ1's ACCCON D write must land in line
 BIT h4on               \ 191's blanking, and a request waits (the Tube's
 BPL h4x                \ interrupt stays asserted, so it comes back after)
 BIT HR4S
 BMI h4r
.h4x
 JMP IRQ1
.h4r
 PHX
 PHY
 LDA &FC                \ (A as interrupted, kept on the stack: an interrupt
 PHA                    \ within the request overwrites &FC)
 BIT VIA+&4D            \ timer 1 again, as the request has not started: if
 BVS h4u                \ it has fired since, the split first
 JSR h4body
 PLA
 PLY
 PLX
 RTI
.h4u
 PLA
 PLY
 PLX
 JMP IRQ1
.h4k                    \ C_KEYS: the scan runs with interrupts on (register
 CLI                    \ 4's interrupt is cleared, as HR4D has been read), so
 JSR hk_body            \ that timer 1 can still make the split in time, as a
 SEI                    \ scan is longer than the blanking; vsync is masked
 RTS                    \ while it scans
.h4on EQUB 0
ENDIF

.h_cls                  \ C_CLS: TTX66's clear, shadow &4000-&6FFF
IF _HOSTB = 0
 LDA #4
 TSB &FE34
 JSR s_clr              \ (the Master host: through the STA runs, h-sta.asm)
 LDA #4
 TRB &FE34
ELSE
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


\ The parasite's routines that the host's copies of the game's blocks refer
\ to but never reach here

.TTX66M                 \ (CHPR's cls and its screen's end: the parasite's)
.BEEP                   \ (CHPR's R5: the parasite's)
 RTS
