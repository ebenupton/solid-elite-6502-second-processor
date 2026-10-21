\ ******************************************************************************
\
\ p-glue.asm - the parasite's renderer glue: the G_ stubs (gfx-gstubs.asm in
\ the Master port), which here call the frame layer directly (no banks), and
\ the text map's hooks (gfx-lowhooks.asm), whose work is the host's
\
\ Each G_ stub returns as the Master port's does: A = ELITEBANK (gback's
\ LDA), X, Y and C as the frame layer left them.
\
\ ******************************************************************************

.gback
 LDA #ELITEBANK
 RTS

.gA EQUB 0

.G_FRAME
 JSR F_FRAME
 JMP gback

.G_SHIP
 JSR F_SHIP
 JMP gback

.G_LINE
 JSR F_LINE
 JMP gback

.G_DOT
 JSR F_DOT
 JMP gback

\ G_DIRECT: TT66 is about to blank the screen and draw directly (from TTX66,
\ whose drawing is the host's: tube/src/p-draw.asm). F_DIRECT as the Master
\ port's (gfx-frame_cold.asm), with the screen's half sent to the host; then,
\ if space mode was kept (an in-system jump), return to TTX66's caller with
\ TTX66's results

.G_DIRECT
 JSR F_DIRECT
 BIT GMODE
 BPL gdir9
 PLA
 PLA
 JSR gback
 LDA #%00001001
 CLC
 RTS
.gdir9
 JMP gback

.F_DIRECT
 ASL GWARP              \ an in-system jump in space mode: the view stays, its
 BCC fdr1               \ text goes (the host's f_clrtext0, rows 0-23), the
 BIT GMODE              \ cursor to (1, 1)
 BPL fdr1
 STZ GSIGHT
 LDA #C_DIRECT
 JSR ptx
 LDA #1
 JSR ptx
 LDX #0
 LDY #0
 LDA #1
 STA XC
 STA YC
 RTS
.fdr1                   \ (f_direct0 and the host's text map cleared)
 LDA #C_DIRECT
 JSR ptx
 LDA #0
 JSR ptx
 STA GMODE
 STA GSIGHT
 STA GLASV
 LDX #23+NDSTAR         \ (no stars recorded, as f_direct0)
.fdr2
 STA R_SS,X
 DEX
 BPL fdr2
 RTS

.G_PLANET
 JSR F_PLANET
 JMP gback

.G_SHPPT
 JSR F_SHPPT
 JMP gback

.G_INIT
 JSR F_INIT
 JMP gback

.G_BOMB
 JSR F_BOMB
 JMP gback

.G_PCURVE
 JSR F_PCURVE
 JMP gback

.G_PPOINT
 JMP F_PPOINT           \ (it returns through gback)

\ G_DSTAR: outside record mode PIXEL2 draws star Y directly; H_STAR (C set:
\ hA = y, X = x, ZZ = distance) and H_STAROFF (C clear: off screen) note it
\ here so that the first record-mode frame can remove it (the host's
\ F_DSTAR and f_unstar). Keeps X, Y; returns C as F_DSTAR does (set, or for a
\ star noted, ZZ >= 80), A = ELITEBANK

.G_DSTAR
 PHA
 LDA #C_DSTAR
 JSR ptx
 LDA #0                 \ C into bit 0
 ROL A
 JSR ptx
 TYA
 JSR ptx
 TXA
 JSR ptx
 LDA hA
 JSR ptx
 LDA ZZ
 JSR ptx
 PLA
 BCC gds1               \ (the clear path returns C set)
 LDA ZZ
 CMP #80
 JMP gback
.gds1
 SEC
 JMP gback

.G_HANG0
 JSR F_HANG0
 JMP gback

\ G_HLL9: HAS1's LL9, with TYPE set while LL9 records the ship (as the Master
\ port's: game logic)

.G_HLL9
 LDA TYPE
 PHA
 LDA XX0
 PHA
 LDA XX0+1
 PHA
 LDX #0
.ghl1
 INX
 INX
 LDA XX21-2,X
 CMP XX0
 BNE ghl1
 LDA XX21-1,X
 CMP XX0+1
 BNE ghl1
 TXA
 LSR A
 TAY
 LDA HSUB-1,Y           \ the type drawn
 STA TYPE
 ASL A
 TAX
 LDA XX21-2,X           \ and its blueprint
 STA XX0
 LDA XX21-1,X
 STA XX0+1
 JSR LL9
 PLA
 STA XX0+1
 PLA
 STA XX0
 PLA
 STA TYPE
 RTS

.HSUB
FOR hst, 1, 21
 IF hst = 17
  EQUB 25
 ELIF hst = 18
  EQUB COPS
 ELSE
  EQUB hst
 ENDIF
NEXT

.G_HANGAR
 JSR F_HANGAR
 JMP gback

\ ******************************************************************************
\
\ The text map's hooks in CHPR and CLYNS (gfx-lowhooks.asm in the Master port).
\ The text map is the host's: H_CHAR and H_DEL send the character (or the
\ delete, 127) with the cursor as CHPR had it on entry, and the state the
\ host's CHPR needs to decide whether to draw it (tube/src/h-main.asm runs
\ the original CHPR, which keeps the host's text map and draws outside
\ record mode); here CHPR then always carries on as in record mode, leaving
\ what RR3, RREN and RRL1 leave (the drawing is the only difference).
\
\ ******************************************************************************

.hA EQUB 0

.G_CHAR                 \ (the host's: C_CHAR has them)
.G_DELCHAR
 RTS

.G_CLRTEXT              \ CLYNS's (H_CLYNS): the host clears the text map's
 LDA #C_CLRTEXT         \ rows 21-23 (A, X and Y are not kept, as the Master
 JSR ptx                \ port's)
 LDA QQ11
 ORA GFORCE
 JSR ptx
 LDA GMODE
 JMP ptx

\ pchr: send C_CHAR: A = the character, X = the cursor column CHPR was
\ entered with

.pchr
 PHA
 LDA #C_CHAR
 JSR ptx
 PLA
 JSR ptx
 TXA
 JSR ptx
 LDA YC
 JSR ptx
 LDA COL
 JSR ptx
 LDA CATF
 JSR ptx
 LDA QQ17
 JSR ptx
 LDA QQ11
 ORA GFORCE
 JSR ptx
 LDA GMODE
 JMP ptx

\ H_CHAR: CHPR (RR3) is about to draw the character in K3 at (XC-1, YC), with
\ A = YC

.H_CHAR
 STA hA
 LDX XC
 DEX
 LDA K3
 JSR pchr
 PLA
 PLA
 LDA hA                 \ leave SC(1 0), P(3 2) and W as RR3, RREN and RRL1 do
 ASL A
 ASL SC
 ADC #&40
 STA SC+1
 LDA SC
 CLC
 ADC #8
 STA P+2
 LDA SC+1
 STA P+3
 LDY #0
 LDA (P),Y
 AND #%00001111
 STA W
 JMP RR4

\ H_DEL: CHPR is deleting the character at (XC, YC) (after its DEC XC)

.H_DEL
 PHA
 LDX XC
 INX
 LDA #127
 JSR pchr
 PLA                    \ (A, and the return address: record mode's exit)
 PLA
 PLA
 JMP RR4
