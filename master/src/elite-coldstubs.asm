\ ******************************************************************************
\
\ elite-coldstubs.asm - stubs out of the cold area
\
\ Port (master/src/elite-far.asm): at the start of the cold area's bank 7
\ part. x4_name calls name with bank 4 paged in (far4) and returns to the cold
\ area; j4_name jumps to name (far4j) for targets that never return.
\ ******************************************************************************

