\ ******************************************************************************
\
\ elite-bank4.asm - Elite's game code in its home bank (sideways RAM bank 4)
\
\ Port (docs/MASTER-MAP.md): INCLUDEd by elite-source.asm after the game data
\ that elite-data.asm puts at the start of bank 4. Bank 4 is paged in whenever
\ the game's code runs, so code here and in main RAM call each other and read
\ each other's data directly. Nothing here may be reached by an interrupt or
\ from a MOS vector (the IRQ, WRCHV and BRKV handlers are in main RAM), or
\ called directly from the cold area (it uses far4 stubs).
\
\ ******************************************************************************

