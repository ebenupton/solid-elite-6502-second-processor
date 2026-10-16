\ ******************************************************************************
\
\ elite-stubs7.asm - stubs into the cold area
\
\ Port (master/src/elite-far.asm): in bank 4. Each cold routine that code
\ outside the cold area calls keeps its name here, as a far call (far7) or a
\ far jump (far7j, for routines that never return) to its cold copy (_C).
\ ******************************************************************************

