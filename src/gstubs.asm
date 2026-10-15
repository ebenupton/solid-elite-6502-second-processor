\ ******************************************************************************
\
\ gstubs.asm - main-RAM stubs that page the graphics bank in around a call
\
\ Each G_xxx preserves A, X, Y and C into F_xxx, which lives in sideways RAM bank
\ GFXBANK; Elite's own bank (ELITEBANK) is paged back in afterwards. Must be
\ assembled below &3000 (it runs while ACCCON X may be set during FRAME).
\
\ ******************************************************************************


.gback
 LDA #ELITEBANK
 STA &F4
 STA &FE30
 RTS

.gA EQUB 0

.G_FRAME
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_FRAME
 JMP gback

.G_SHIP
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_SHIP
 JMP gback

.G_LINE
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_LINE
 JMP gback

.G_DOT
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_DOT
 JMP gback

.G_STAR
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_STAR
 JMP gback

.G_CHAR
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_CHAR
 JMP gback

.G_CLRTEXT
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_CLRTEXT
 JMP gback

.G_DIRECT
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_DIRECT
 JMP gback

.G_PLANET
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_PLANET
 JMP gback

.G_SHPPT
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_SHPPT
 JMP gback

.G_INIT
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_INIT
 JMP gback

.G_PCURVE
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_PCURVE
 JMP gback

.G_PPOINT
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_PPOINT
 JMP gback

.G_DELCHAR
 STA gA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA gA
 JSR F_DELCHAR
 JMP gback


\ Variables shared between Elite, the IRQ handler and the graphics bank

.GMODE   EQUB 0         \ bit 7 set: space mode (double buffered)
.GFRONT  EQUB 0         \ buffer displayed: 0 = main RAM (A), 1 = shadow (B)
.GFLIP   EQUB 0         \ non-zero: show buffer GPEND at the next vsync
.GPEND   EQUB 0
.GACCX   EQUB 0         \ ACCCON X bit wanted by the main code (0 or 4)
.GDRAWON EQUB &FF       \ 0: drawing primitives are erasing, ignore them
.GFORCE  EQUB 0         \ non-zero: draw directly even though QQ11 = 0
.GSIGHT  EQUB 0         \ non-zero: draw the laser sights
.GLASV   EQUB 0         \ non-zero: our laser beams are showing
.GLCOL   EQUB 3         \ colour index for recorded lines
.GDCOL   EQUB 4         \ colour index for recorded dots
.GNF     EQUB 0         \ faces / vertices of the ship being recorded
.GNV     EQUB 0
.GSUNON  EQUB 0         \ non-zero: SUN drew the sun this frame (LSO, SUNX valid)
.GSUNR   EQUB 0         \ the sun's radius this frame
.GZN     EQUB 0         \ LL9's halved z (XX18+6 at LL91) for the ship being recorded
