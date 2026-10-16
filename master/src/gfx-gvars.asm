\ ******************************************************************************
\
\ gfx-gvars.asm - the frame layer's HAZEL part of the stubs (G_MERID, called
\ from bank 6 while ACCCON X is set) and the variables shared between Elite,
\ the IRQ handler and the graphics bank (split from gfx-gstubs.asm)
\
\ ******************************************************************************

.G_MERID                \ (from bank 6) PM_MERID in bank 4 (planet4.asm, not
 JMP tback              \ yet in the build), then back to 6


\ Variables shared between Elite, the IRQ handler and the graphics bank

.GMODE   EQUB 0         \ bit 7 set: space mode (double buffered)
.GFRONT  EQUB SINGLEBUF \ buffer displayed: 0 = main RAM (A), 1 = shadow (B)
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
.GTYPE   EQUB 0         \ the type whose faces the ship being recorded uses
.GSUNON  EQUB 0         \ non-zero: SUN drew the sun this frame (LSO, SUNX valid)
.GSUNR   EQUB 0         \ the sun's radius this frame
