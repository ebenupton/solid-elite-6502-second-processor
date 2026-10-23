\ ******************************************************************************
\
\ gfx-tramp.asm - trampolines from the frame layer (bank GFXBANK) into the
\ rasteriser (bank RASTBANK, and ANDY over it, RASTPOLY, for R_POLY and
\ R_LINE). Lives in the low area (main RAM below &3000, elite-low.asm),
\ visible whichever bank is paged and whatever ACCCON X is. A, X, Y are
\ passed through; nothing is returned.
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

IF _TDUMB = FALSE          \ (the Tube's dumb host: the parasite's)
.T_RESETBUF
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_RESETBUF
 JMP tback
ENDIF

.T_STARERASE
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_STARERASE
 JMP tback

IF _TDUMB = FALSE          \ (the Tube's dumb host: the parasite's)
.T_DISCROWS
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_DISCROWS
 JMP tback
ENDIF

.T_SPAN
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_SPAN
 JMP tback

IF _TDUMB = FALSE          \ (the Tube's dumb host: the parasite's)
.T_FLARE                \ (the lens flare, gfx-flare.asm; X and Y passed)
 LDA #RASTBANK
 STA &F4
 STA &FE30
 JSR R_FLARE
 JMP tback
ENDIF

IF _TDUMB = FALSE          \ (the Tube's dumb host: the parasite's)
.T_MARKDIRTY
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_MARKDIRTY
 JMP tback
ENDIF

IF _TDUMB = FALSE          \ (the Tube's dumb host: the parasite's)
.T_MERID                \ (the meridian window's row loop, gfx-merid.asm: bank 7;
 BIT PM_OK              \ not when PM_HOOK has kept the last rows, PM_OK = &C0)
 BVS tmer9
 LDA #MERIDBANK
 STA &F4
 STA &FE30
 JSR PM_MERID
 LDA #&80               \ (the rows are for PM_HOOK's last constants)
 STA PS_VALID
 JMP tback
.tmer9
 RTS
ENDIF

IF _TDUMB = FALSE          \ (the Tube's dumb host: the parasite's)
.T_POLY                 \ (R_POLY is in the rasteriser's polygon window, ANDY)
 STA tA
 LDA #RASTPOLY
 STA &F4
 STA &FE30
 LDA tA
 JSR R_POLY
 JMP tback
ENDIF

.T_LINE                 \ (R_LINE is in the polygon window, ANDY, too)
 STA tA
 LDA #RASTPOLY
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

IF _TDUMB = FALSE          \ (the Tube's dumb host: h-main.asm's h_init)
.T_INIT
 STA tA
 LDA #RASTBANK
 STA &F4
 STA &FE30
 LDA tA
 JSR R_INIT
 JMP tback
ENDIF
