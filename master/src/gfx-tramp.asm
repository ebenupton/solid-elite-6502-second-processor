\ ******************************************************************************
\
\ tramp.asm - trampolines from the frame layer (bank GFXBANK) into the
\ rasteriser (bank RASTBANK). Lives in HAZEL (&C000-&DFFF), visible whichever
\ bank is paged. A, X, Y are passed through; nothing is returned.
\
\ ******************************************************************************

.tA EQUB 0

.tback
 STA tA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 LDA tA
 RTS

.T_SETBUF
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_SETBUF
 JMP tback

.T_RESETBUF
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_RESETBUF
 JMP tback

.T_STARERASE
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_STARERASE
 JMP tback

.T_DISCROWS
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_DISCROWS
 JMP tback

.T_SPAN
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_SPAN
 JMP tback

.T_MARKDIRTY
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_MARKDIRTY
 JMP tback

.T_POLY
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_POLY
 JMP tback

.T_LINE
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_LINE
 JMP tback

.T_DOT
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_DOT
 JMP tback

.T_STARPLOT
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_STARPLOT
 JMP tback

.T_INIT
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_INIT
 JMP tback
