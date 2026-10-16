\ ******************************************************************************
\
\ gfx-gstubs.asm - main-RAM stubs that page the graphics bank in around a call
\
\ Each G_xxx preserves A, X, Y and C into F_xxx, which lives in sideways RAM bank
\ GFXBANK; Elite's own bank (ELITEBANK) is paged back in afterwards. Master
\ port: assembled with the main code (elite-flight.asm), as they are only
\ ever called from game code, with ACCCON X clear (the frame sets X itself,
\ inside F_FRAME); G_MERID, which bank 6 calls during the frame, and the
\ variables shared with the IRQ and the frame are in HAZEL (gfx-gvars.asm).
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


.G_PCURVE               \ (F_PCURVE and F_PPOINT do not read A, and both
 LDA #GFXBANK           \ callers, H_PCURVE and H_BPT, enter with A = 0 and
 STA &F4                \ reload A afterwards, so A need not be kept in gA)
 STA &FE30
 JSR F_PCURVE
 JMP gback

.G_PPOINT
 LDA #GFXBANK
 STA &F4
 STA &FE30
 JSR F_PPOINT
 JMP gback

 SKIP 12                \ Padding: keeps everything after (stubs, hooks,
                        \ raster_hz and the unaligned HAZEL tables) at the
                        \ same addresses


.G_DSTAR                \ (C preserved both ways)
 LDA #GFXBANK
 STA &F4
 STA &FE30
 JSR F_DSTAR
 JMP gback


