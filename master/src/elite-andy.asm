\ ******************************************************************************
\
\ elite-andy.asm - cold code in ANDY (&8000-&8FFF)
\
\ Port (docs/MASTER-MAP.md, master/src/elite-far.asm): the first part of the
\ cold area, paged in as ROMSEL = &87 (ANDY over bank 7's &8000-&8FFF). Labels
\ have the suffix _C; code outside the cold area calls them through the stubs
\ in elite-stubs7.asm, and they call out through elite-coldstubs.asm.
\ ******************************************************************************

