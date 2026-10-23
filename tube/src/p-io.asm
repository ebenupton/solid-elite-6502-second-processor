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

fl_dx = &10             \ (gfx-flare.asm's zero page: the flare's inputs, which
fl_dy = &11             \ the frame layer's f_flt sets, before gfx-flare.asm)
fl_t  = &0E



\ ptx: send A to the host through register 1, waiting for room. Keeps A, X
\ and Y (and C)

.ptx
 BIT PR1S
 BVC ptx
 STA PR1D
 RTS

\ preq: send A to the host through register 2, waiting for room: the
\ requests (keys, a key test, the vsync, port B, the star records), which the
\ host answers between commands, ahead of those queued in register 1. Keeps
\ A, X and Y (and C)

.preq
 BIT PR2S
 BVC preq
 STA PR2D
 RTS

\ preq4: A to the host through register 4: the fast I/O requests (C_KEYS,
\ C_DKS and its key, C_IRB), which the host's IRQ answers at once, wherever
\ it is (h4irq, h-main.asm; Model B: hb-res3.asm's irqm), rather than at the
\ command loop's next boundary (tube/proto/PROTO-REPORT.md, branch tubeproto)

.preq4
 BIT PR4S
 BVC preq4
 STA PR4D
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
 JSR ptx
 PLA
 RTS

\ p_buf: the frame's buffer, A (C_BUF): the host waits for the last flip, then
\ draws into it. p_flip: show it at the next vsync (C_FLIP)

.p_buf
 PHA
 LDA #C_BUF
 JSR ptx
 PLA
 JMP ptx

.p_flip
 LDA #C_FLIP
 JMP ptx

\ The trampolines into the rasteriser (gfx-tramp.asm in the Master port)

.T_POLY                 \ R_POLY: phase A here (p-polya.asm), the rows to the host
 PHA
 PHX
 PHY
 JSR R_POLY
 PLY
 PLX
 PLA
 RTS

\ The rasteriser's entry points are p-rast.asm's (T_SETBUF ... in the overlay
\ S, which F_FRAME and F_INIT load)


.T_MERID                \ the beach ball's rows (gfx-merid.asm's PM_MERID)
 JSR PM_MERID
 LDA #&80
 STA PS_VALID
 RTS

.T_FLARE                \ the lens flare (gfx-flare.asm), X, Y: this buffer's
 BIT KMODE              \ dirty extents' pages (K mode: no kept rows, p-kept.asm)
 BPL tfl1
 PHY
 JSR k_clear
 PLY
.tfl1
 JMP R_FLARE

\ p_hloin: HLOIN3 (Master's drawing, the host's: C_HLOIN): a line from (X1, Y1)
\ to (X2, Y1) in COL, leaving YSAV, X1, X2 and X as Master's does; keeps Y

.p_hloin
 STY YSAV
 LDX X1
 CPX X2
 BEQ phl9
 BCC phl1
 LDA X2                 \ (X1 on the left)
 STA X1
 STX X2
 TAX
.phl1
 LDA #C_HLOIN
 JSR ptx
 TXA
 JSR ptx
 LDA X2
 JSR ptx
 DEC X2                 \ (as Master's: no pixel at the end)
 LDA Y1
 JSR ptx
 LDA COL
 JSR ptx
 LDA X2
 AND #3
 TAX
.phl9
 RTS

\ p_pixel: PIXEL's drawing (the host's: C_PIXEL): a point at (X, A) sized by
\ ZZ, in COL, leaving T1 and X (x AND 3) as Master's does; keeps Y

.p_pixel
 STY T1
 PHA
 LDA #C_PIXEL
 JSR ptx
 TXA
 JSR ptx
 PLA
 JSR ptx
 LDA ZZ
 JSR ptx
 LDA COL
 JSR ptx
 TXA
 AND #3
 TAX
 RTS

.p_cls                  \ TTX66's screen clear (the direct-mode buffer)
 PHP
 LDA #C_CLS
 JSR ptx
 PLP
 RTS

.p_boxc                 \ BOX's two corners, in COL (A = COL)
 PHP
 PHA
 LDA #C_BOXC
 JSR ptx
 PLA
 JSR ptx
 PLP
 RTS

.p_clyns                \ CLYNS's screen clear (keeps A and the flags)
 PHP
 PHA
 LDA #C_CLYNS
 JSR ptx
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
 LDA #C_WSCAN           \ (register 4: the host's IRQ marks it pending, its next
 JSR preq4              \ vsync interrupt answers it)
 JSR prx
 LDA #72
 STA DL
 RTS

\ p_noise: NOISE: send sound Y (and DNOIZ) to the host, which makes it with its
\ own sound buffers and IRQ, then free every channel here, so that NOISE goes
\ on as the harness makes the original (docs/TUBE-MAP.md): keeps X and Y

.p_noise                \ (register 4: made at once by the host's IRQ, never
 LDA #C_NOISE           \ behind the drawing)
 JSR preq4
 TYA
 JSR preq4
 LDA DNOIZ
 JSR preq4
 STZ SOPR
 STZ SOPR+1
 STZ SOPR+2
 RTS

.p_soflush
 LDA #C_SOFLUSH
 JMP preq4

\ p_det1: DET1: 6845 R6 = X; returns as DET1 (A = 6)

.p_det1
 LDA #C_DET1
 JSR ptx
 TXA
 JSR ptx
 LDA #6
 RTS

\ p_irb: A = the host's System VIA port B (the joystick's fire button)

.p_irb
 LDA #C_IRB
 JSR preq4
 JMP prx

\ p_dks: DKS5: X = key A, with bit 7 set if the host has it held. Keeps Y and C

.p_dks                  \ (A is kept: the harness reads the key there)
 PHA
 LDA #C_DKS
 JSR preq4
 PLA
 JSR preq4
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
 JSR preq4
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

\       Area: ovl D

\ p_oscli: DOSCLI (the disc commands, Y X = the command, CR-ended): C_DISC,
\ the host's MOS runs it as the host's own I/O (h_disc, h-cold.asm): the
\ printing's context (QQ11 OR GFORCE, GMODE, CHPR's zero page, W, CATF), the
\ mode (1 SAVE, 2 LOAD, else 0) with, for those, commbuf's 256 bytes (the
\ host saves from and loads into its buffer at &3F00, which savosc and lodosc
\ name), then the command. The host answers through register 4: 0, or &FF
\ and the error's number, message and 0 (then NEWBRK prints it, as after the
\ MOS's BRK); then the printing's context back, and for a load commbuf. As
\ DOSCLI: GSTASH is set (the Master port's next space-mode frame clears
\ buffer 0, which the host's disc command may use)

PCTX = &0A              \ CHPR's zero page: SC, SCH, P(4), XC, COL, YC, QQ17, K3, K3+1
PCTXN = 12
\ (the error block: R_NDX3, free outside space mode)
pv = &FA                \ (the command's pointer: zero page the game leaves free)

.p_oscli
 STX pv
 STY pv+1
 LDA #&80
 STA GSTASH
 LDA #C_DISC
 JSR ptx
 LDA QQ11
 ORA GFORCE
 JSR ptx
 LDA GMODE
 JSR ptx
 LDX #0
.pos1
 LDA PCTX,X
 JSR ptx
 INX
 CPX #PCTXN
 BNE pos1
 LDA W
 JSR ptx
 LDA CATF
 JSR ptx
 LDY #0                 \ the mode: SAVE 1, LOAD 2, else 0
 LDA (pv),Y
 LDX #1
 CMP #'S'
 BEQ pos2
 INX
 CMP #'L'
 BEQ pos2
 LDX #0
.pos2
 STX pdm
 TXA
 JSR ptx
 LDA pdm
 BEQ pos4
 LDY #0                 \ commbuf
.pos3
 LDA commbuf,Y
 JSR ptx
 INY
 BNE pos3
.pos4
 LDY #0                 \ the command, to its CR
.pos5
 LDA (pv),Y
 JSR ptx
 INY
 CMP #13
 BNE pos5
 JSR prx                \ 0, or &FF: an error
 STA pdst
 BEQ pos7
 LDY #0                 \ the error's number, message and 0, into R_NDX3
.pos6
 JSR prx
 STA R_NDX3,Y
 INY
 CMP #0
 BNE pos6
 CPY #1                 \ (the number byte itself may be 0)
 BEQ pos6
.pos7
 LDX #0                 \ the printing's context back
.pos8
 JSR prx
 STA PCTX,X
 INX
 CPX #PCTXN
 BNE pos8
 JSR prx
 STA W
 JSR prx
 STA CATF
 LDA pdm                \ a load: commbuf back (as the host's buffer is, also
 CMP #2                 \ after an error)
 BNE pos10
 LDY #0
.pos9
 JSR prx
 STA commbuf,Y
 INY
 BNE pos9
.pos10
 LDA pdst
 BNE pos11
 RTS
.pos11
 LDA #LO(R_NDX3)         \ the error: as the MOS's BRK leaves it, (&FD) at the
 STA &FD                \ number, the message after it
 LDA #HI(R_NDX3)
 STA &FE
 JMP NEWBRK

\       Area: frame

\ p_dosnmi: NEWBRK's DOSNMI: nothing to do (the host is back in its command
\ loop already). Keeps A and the flags

.p_dosnmi
 RTS

.pdm  EQUB 0
.pdst EQUB 0

.T1SYNC                 \ (BEGIN's: the host's, at its start)
 RTS

.TTX66M                 \ (CHPR's call of TTX66: no banks here)
 JMP TTX66



\ p_start: the parasite's entry (the loader starts it through the client
\ OS's Tube code, its only use): the boot (p_boot, in the staging area above
\ overlay D, p-layout.asm) takes the parasite's memory over, then wakes the
\ host's command loop with &FE (the host's WRCHV, as the MOS's Tube code
\ passes the byte to OSWRCH), then the renderer's initialisation (G_INIT,
\ as the Master port's loader calls it) and the game (S%)

.p_start
 SEI
 CLD
 LDX #&FF
 TXS
 JSR p_boot
 LDA #&FE
 JSR ptx
 JSR G_INIT
 JMP S%
