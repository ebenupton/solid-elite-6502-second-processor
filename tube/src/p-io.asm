\ ******************************************************************************
\
\ p-io.asm - the parasite's side of the Tube protocol (tube/src/cmds.asm,
\ docs/TUBE-MAP.md): sending commands, the requests, and the frame layer's
\ trampolines into the rasteriser, which here send the rasteriser's inputs to
\ the host instead (each T_xxx keeps A, X and Y: the rasteriser's callers rely
\ on no register it returns, and on Y, R_XL and R_XR after T_MARKDIRTY)
\
\ ******************************************************************************

R_COLE  = &06           \ (gfx-raster.asm's zero page: the rasteriser's inputs,
R_COLO  = &07           \ which the frame layer sets)
R_XL    = &08
R_XR    = &09
R_CL    = &0A
R_CR    = &0B
R_CT    = &0C
R_CB    = &0D
R_DCE   = &0E
R_DCO   = &0F

fl_dx = &10             \ (gfx-flare.asm's zero page, which the host's flare and
fl_dy = &11             \ the parasite's f_flt share: the flare's inputs)
fl_t  = &0E


\ ptx: send A to the host through register 1, waiting for room. Keeps A, X
\ and Y (and C)

.ptx
 BIT PR1S
 BVC ptx
 STA PR1D
 RTS

\ prx: A = the next byte from the host (register 4), waiting for it. Keeps X
\ and Y (and C)

.prx
 BIT PR4S
 BPL prx
 LDA PR4D
 RTS

\ ptxv: send the X bytes from (pv),Y... (Y = 0 up): used by the commands that
\ carry a block

MACRO PSEND
 BIT PR1S
 BVC P%-3
 STA PR1D
ENDMACRO

\ p_sync: the end of a main-loop iteration's frame (hframe): a marker for the
\ harness, which hashes the host's screen when the host takes it

.p_sync
 PHA
 LDA #C_SYNC
 PSEND
 PLA
 RTS

\ p_fb: the frame's beginning (F_FRAME): the buffer (F_BACK) and GSIGHT, for
\ the host's f_text1, f_sight1, its wait for the last flip and the stars'
\ erasure (tube/src/h-frame.asm)

.p_fb
 LDA #C_FB
 PSEND
 LDA F_BACK
 PSEND
 LDA GSIGHT
 PSEND
 RTS

\ p_fe: the frame's end: GSIGHT, then the stars (R_SN = NOST+1 of them: x,
\ y and size each, size 0 for none), for the host's text overlay, sights,
\ stars and flip

.p_fe
 LDA #C_FE
 PSEND
 LDA GSIGHT
 PSEND
 LDX #0
.pfe1
 LDA R_SX,X
 PSEND
 LDA R_SY,X
 PSEND
 LDA R_SS,X
 PSEND
 INX
 CPX #NOST+1
 BNE pfe1
 RTS

\ p_enter: the first space-mode frame since the screen was drawn directly
\ (f_enter2): the host's half is the screen and the text maps (the stars
\ drawn directly, buffer 0 afresh after a disc command, the border copied
\ across, buffer 1's state forgotten); the parasite's is the frame layer's
\ state, as f_enter and f_b0new leave it

.f_enter2
 LDA #C_ENTER
 PSEND
 LDA GSTASH
 PSEND
 BIT GSTASH             \ f_b0new: buffer 0's disc colour forgotten
 BPL pen1
 STZ GSTASH
 LDA #&FF
 STA F_DCOL
.pen1
 LDA #1                 \ f_enter: buffer 1's state empty, buffer 0 drawn first,
 STA F_BACK             \ space mode
 LDA #&FF
 STA F_DCOL+1
 STZ F_BACK
 LDA #&80
 STA GMODE
 STZ f_hwr              \ (as f_enter2: it used the half-width tables as its
 STZ f_hw2r             \ buffer, on the host)
 RTS

\ p_flare: R_FLARE's inputs (fl_dx, fl_dy; the host has the buffer's dirty
\ extents)

.p_flare
 LDA #C_FLARE
 PSEND
 LDA fl_dx
 PSEND
 LDA fl_dy
 PSEND
 RTS

\ The trampolines into the rasteriser (gfx-tramp.asm in the Master port)

.T_SPAN                 \ Y = row, R_XL..R_XR, R_COLE/R_COLO
 PHA
 LDA #C_SPAN
 PSEND
 TYA
 PSEND
 LDA R_XL
 PSEND
 LDA R_XR
 PSEND
 LDA R_COLE
 PSEND
 LDA R_COLO
 PSEND
 PLA
 RTS

.T_MARKDIRTY            \ Y = row, R_XL..R_XR
 PHA
 LDA #C_MARK
 PSEND
 TYA
 PSEND
 LDA R_XL
 PSEND
 LDA R_XR
 PSEND
 PLA
 RTS

.T_POLY                 \ R_PN vertices (at most 16), the four colours
 PHA
 PHX
 LDA #C_POLY
 PSEND
 LDA R_PN
 CMP #17
 BCC P%+4
 LDA #16
 STA tpn
 PSEND
 LDA R_COLE
 PSEND
 LDA R_COLO
 PSEND
 LDA R_COL2
 PSEND
 LDA R_COL3
 PSEND
 LDX #0
.tpo1
 CPX tpn
 BCS tpo9
 LDA R_PXL,X
 PSEND
 LDA R_PXH,X
 PSEND
 LDA R_PYL,X
 PSEND
 LDA R_PYH,X
 PSEND
 INX
 BNE tpo1
.tpo9
 PLX
 PLA
 RTS
.tpn EQUB 0

.T_LINE                 \ R_X0, R_Y0, R_X1, R_Y1 (words), the four colours
 PHA
 PHX
 LDA #C_LINE
 PSEND
 LDA R_COLE
 PSEND
 LDA R_COLO
 PSEND
 LDA R_COL2
 PSEND
 LDA R_COL3
 PSEND
 LDX #0
.tli1
 LDA R_X0,X
 PSEND
 INX
 CPX #8
 BNE tli1
 PLX
 PLA
 RTS

.T_DOT                  \ X = x, Y = y, A = size, R_COLE/R_COLO
 PHA
 LDA #C_DOT
 PSEND
 LDA R_COLE
 PSEND
 LDA R_COLO
 PSEND
 TXA
 PSEND
 TYA
 PSEND
 PLA
 PSEND
 RTS

\ T_DISCROWS: R_NDT, R_NDB, R_DCE, R_DCO, R_NDF (with R_DBE, R_DBO), then
\ for each row R_NDT..R_NDB, R_NDISCL and R_NDISCR, and with R_NDF set also
\ R_NDP, R_NDN and R_NDN of R_NDX0..R_NDX3

.T_DISCROWS
 PHA
 PHX
 PHY
 LDA #C_DISC
 PSEND
 LDA R_NDT
 PSEND
 LDA R_NDB
 PSEND
 LDA R_DCE
 PSEND
 LDA R_DCO
 PSEND
 LDA R_NDF
 PSEND
 LDA R_NDF              \ (PSEND's BIT has the flags)
 BEQ tdr1
 LDA R_DBE
 PSEND
 LDA R_DBO
 PSEND
.tdr1
 LDY R_NDT
.tdr2
 CPY R_NDB
 BEQ P%+4
 BCS tdr9
 LDA R_NDISCL,Y
 PSEND
 LDA R_NDISCR,Y
 PSEND
 LDA R_NDF
 BEQ tdr4
 LDA R_NDP,Y
 PSEND
 LDA R_NDN,Y            \ (the count as it is, then at most 4 boundaries,
 PSEND                  \ as the rasteriser reads at most 4)
 CMP #5
 BCC P%+4
 LDA #4
 TAX
 BEQ tdr4
 LDA R_NDX0,Y
 PSEND
 DEX
 BEQ tdr4
 LDA R_NDX1,Y
 PSEND
 DEX
 BEQ tdr4
 LDA R_NDX2,Y
 PSEND
 DEX
 BEQ tdr4
 LDA R_NDX3,Y
 PSEND
.tdr4
 INY
 BNE tdr2
.tdr9
 PLY
 PLX
 PLA
 RTS

\ ******************************************************************************
\
\ Master's drawing's screen writes (the SCEOR and SCSTA macros, elite-source.asm):
\ the address SC(1 0) + Y and the value A. Keep A, X, Y and the flags
\
\ ******************************************************************************

.p_sceor
 PHP
 PHA
 LDA #C_SCEOR
.psc1
 PSEND
 TYA
 CLC
 ADC SC
 PSEND
 LDA SC+1
 ADC #0
 PSEND
 PLA
 PSEND
 PLP
 RTS

.p_scsta
 PHP
 PHA
 LDA #C_SCSTA
 BNE psc1

.p_cls                  \ TTX66's screen clear (the direct-mode buffer)
 PHP
 LDA #C_CLS
 PSEND
 PLP
 RTS

.p_boxc                 \ BOX's two corners, in COL (A = COL)
 PHP
 PHA
 LDA #C_BOXC
 PSEND
 PLA
 PSEND
 PLP
 RTS

.p_clyns                \ CLYNS's screen clear (keeps A and the flags)
 PHP
 PHA
 LDA #C_CLYNS
 PSEND
 PLA
 PLP
 RTS

\ ******************************************************************************
\
\ The host's hardware: requests and their answers
\
\ ******************************************************************************

\ p_wscan: WSCAN: wait for the host's vertical sync; leaves DL = 72 and A =
\ 72, as WSCAN's loop leaves them (the IRQ's LINSCN sets DL to VSCAN+1)

.p_wscan
 LDA #C_WSCAN
 PSEND
 JSR prx
 LDA #72
 STA DL
 RTS

\ p_noise: NOISE: send sound Y (and DNOIZ) to the host, which makes it with its
\ own sound buffers and IRQ, then free every channel here, so that NOISE goes
\ on as the harness makes the original (docs/TUBE-MAP.md): keeps X and Y

.p_noise
 LDA #C_NOISE
 PSEND
 TYA
 PSEND
 LDA DNOIZ
 PSEND
 STZ SOPR
 STZ SOPR+1
 STZ SOPR+2
 RTS

.p_soflush
 LDA #C_SOFLUSH
 PSEND
 RTS

\ p_det1: DET1: 6845 R6 = X; returns as DET1 (A = 6)

.p_det1
 LDA #C_DET1
 PSEND
 TXA
 PSEND
 LDA #6
 RTS

\ p_irb: A = the host's System VIA port B (the joystick's fire button)

.p_irb
 LDA #C_IRB
 PSEND
 JMP prx

\ p_dks: DKS5: X = key A, with bit 7 set if the host has it held. Keeps Y and C

.p_dks                  \ (A is kept: the harness reads the key there)
 PHA
 LDA #C_DKS
 PSEND
 PLA
 PSEND
 PHA
 JSR prx
 TAX
 PLA
 RTS

\ p_fillkl: FILLKL after ZEKTRAN (X = 0): the host sends the keys held, in
\ increasing internal number from 16 up, then 0; each updates the key logger
\ through IKNS as Rd2 does, and KL holds the last. Returns as FILLKL: A = KY6
\ (after Rd7's TRB), X = KL with N and Z from it, C set if no key was held,
\ D clear

.p_fillkl
 LDA #C_KEYS
 PSEND
 LDA #1
 STA pfkn
.pfk1
 JSR prx
 BEQ pfk9
 STZ pfkn
 STA KL
.pfk2
 CMP IKNS,X
 BCC pfk1
 BEQ pfk3
 INX
 BNE pfk2
.pfk3
 DEC KY17,X
 INX
 BNE pfk1
.pfk9
 CLD
 LDA pfkn
 LSR A
 LDA KY6
 TRB KY19
 LDX KL
 RTS
.pfkn EQUB 0

\ p_oscli: DOSCLI (the disc commands, Y X = the command): the host's MOS runs
\ it through its own Tube code, which the host goes back to for it (h_oscli):
\ this side sends what the host's CHPR needs to print during the command (a
\ catalogue), waits for the host to be in the MOS's idle loop, then calls
\ the client OS's OSCLI with interrupts on (the MOS's transfers to and from
\ the parasite's memory, *SAVE and *LOAD, run through the client OS's IRQ and
\ NMI handlers), and finally brings the host back to the command loop
\ (p_resume). As DOSCLI: A and the flags are OSCLI's, and GSTASH is set (the
\ Master port's next space-mode frame clears buffer 0)

PCTX = &0A              \ CHPR's zero page: SC, SCH, P(4), XC, COL, YC, QQ17, K3, K3+1
PCTXN = 12

.p_oscli
 PHA
 PHX
 PHY
IF TUBE_HIGH
 JSR p_swap             \ the client OS back (for OSCLI and the MOS's Tube code)
ENDIF
 LDA #&80
 STA GSTASH
 LDA #C_OSCLI
 PSEND
 LDA QQ11
 ORA GFORCE
 PSEND
 LDA GMODE
 PSEND
 LDX #0
.pos1
 LDA PCTX,X
 PSEND
 INX
 CPX #PCTXN
 BNE pos1
 LDA W
 PSEND
 LDA CATF
 PSEND
 JSR prx                \ (the host is in the MOS's idle loop)
 LDA #&FF
 STA pmos
 PLY
 PLX
 PLA
 CLI
 JSR OSCLI
 SEI
 PHP
 PHA
 JSR p_resume
 PLA
 PLP
 RTS

\ p_dosnmi: NEWBRK's DOSNMI, after a disc command's error (which the MOS's Tube
\ code has brought here): back to the command loop. Keeps A and the flags

.p_dosnmi
 SEI
 PHP
 PHA
 JSR p_resume
 PLA
 PLP
 RTS

\ p_resume: if the host is in the MOS (pmos), wake its command loop (&FE through
\ register 1, which the MOS's idle loop passes to the host's WRCHV, hwrch) and
\ take back CHPR's zero page, W and CATF as the host's printing left them

.p_resume
 BIT pmos
 BPL prs9
 STZ pmos
 LDA #&FE
 PSEND
 LDX #0
.prs1
 JSR prx
 STA PCTX,X
 INX
 CPX #PCTXN
 BNE prs1
 JSR prx
 STA W
 JSR prx
 STA CATF
IF TUBE_HIGH
 JSR p_swap             \ the high code back (keeps nothing: callers save A)
ENDIF
.prs9
 RTS

.pmos EQUB 0

.T1SYNC                 \ (BEGIN's: the host's, at its start)
 RTS

.TTX66M                 \ (CHPR's call of TTX66: no banks here)
 JMP TTX66



\ p_start: the parasite's entry (the loader starts it through the MOS's Tube
\ code): interrupts off for good (the client OS's handlers would take the
\ host's replies in register 4), wake the host's command loop with &FE (the
\ host's WRCHV, as the MOS's Tube code passes the byte to OSWRCH), then the
\ renderer's initialisation (G_INIT, as the Master port's loader calls it)
\ and the game (S%)

.p_start
 SEI
 CLD
 LDX #&FF
 TXS
 LDA #&FE
 JSR ptx
IF TUBE_HIGH
 JSR p_swap             \ the high code in, the client OS out
ENDIF
 JSR G_INIT
 JMP S%

\ p_swap: exchange &F800-&FEEF with the host's copy (h_swap): the client OS
\ for the high code (p-layout.asm), or back. Keeps nothing

.p_swap
 LDA #C_SWAP
 PSEND
 LDA #&F8
 STA psw1+2
 STA psw2+2
 LDY #0
.psw0
.psw1
 LDA &F800,Y            \ (patched)
 PSEND
 JSR prx
.psw2
 STA &F800,Y            \ (patched)
 INY
 BNE psw3
 INC psw1+2
 INC psw2+2
.psw3
 LDA psw1+2
 CMP #&FE
 BNE psw0
 CPY #&F0
 BNE psw0
 RTS
