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
 JSR MN_TURN            \ (the moon's place, once an iteration: gfx-mnturn.asm)
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

\ G_PFHOOK: H_CIRC's planet surface (gfx-hooks.asm): PF_HOOK, the planet's
\ class and its circles' records (gfx-planet7.asm, with the circle engine
\ gfx-merid.asm, in overlay S), its moon and its ring; PF_CLS bit 7 says
\ that f_bounds is to colour the disc from them (T_CAPS). Keeps X and Y
\ (H_CIRC, the only caller, reads none of A and the flags after it)

.G_PFHOOK
 JSR MN_TURN            \ (the moon's place for this iteration, gfx-mnturn.asm)
 LDA #OVL_S
 JSR ovl_need
 JSR PF_HOOK
 JMP gback

\ G_DSTAR: outside record mode PIXEL2 draws star Y directly; H_STAR (C set:
\ hA = y, X = x, ZZ = distance) and H_STAROFF (C clear: off screen) note it
\ here so that the first record-mode frame can remove it (the host's
\ F_DSTAR and f_unstar). Keeps X, Y; returns C as F_DSTAR does (set, or for a
\ star noted, ZZ >= 80), A = ELITEBANK

.G_DSTAR
 JSR F_DSTAR            \ (gfx-frame_cold.asm's: the noted stars are here)
 JMP gback

\       Area: ovl D

.G_HANG0                \ (G_HANG0 to G_HANGAR: called only from HALL and HAS1,
 JSR F_HANG0            \ in overlay D)
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

\       Area: frame

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

.G_CHAR                 \ the text map (gfx-frame_cold.asm's F_CHAR ...)
 JMP F_CHAR
.G_DELCHAR
 JMP F_DELCHAR
.G_CLRTEXT
 JMP F_CLRTEXT

\ pchr: send C_CHAR: A = the character, X = the cursor column CHPR was
\ entered with: the host's CHPR draws it

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
\ A = YC: the text map has it, and outside record and space mode the host
\ draws it; CHPR then carries on as in record mode, leaving what RR3, RREN
\ and RRL1 leave

.H_CHAR
 STA hA
 JSR G_CHAR
 LDA QQ11
 ORA GFORCE
 BEQ hcr1
 BIT GMODE
 BMI hcr1
 LDX XC
 DEX
 LDA K3
 JSR pchr
.hcr1
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
 LDA K3                 \ W = the low nibble of the glyph's first byte (RRL1's
 AND #&7F               \ (P),Y with Y = 0), from PFONTW: the font is the host's
 TAY                    \ only (elite-source.asm)
 LDA PFONTW-32,Y
 STA W
 JMP RR4

\ H_DEL: CHPR is deleting the character at (XC, YC) (after its DEC XC): the
\ text map too, and outside record mode the host blanks it

.H_DEL
 PHA
 JSR G_DELCHAR
 LDA QQ11
 ORA GFORCE
 BEQ hdl1
 LDX XC
 INX
 LDA #127
 JSR pchr
.hdl1
 PLA                    \ (A, and the return address: record mode's exit)
 PLA
 PLA
 JMP RR4

\ T_KOFF: (F_FRAME, not a space view: overlay S may be out) K mode off. Its
\ kept rows are forgotten by the next frame's T_KFRAME (p-kept.asm), and
\ until then nothing reads them but the disc layer's band (KANY)
.T_KOFF
 STZ KMODE
 RTS
