\ ******************************************************************************
\
\ cmds.asm - the Tube protocol's commands (docs/TUBE-MAP.md), shared by the
\ parasite (which sends them) and the host (which executes them)
\
\ During play the game owns the Tube. The parasite sends commands through
\ register 1 (parasite to host, a 24-byte FIFO), polling its status (bit 6:
\ room); the host reads them, polling register 1's status (bit 7: data), in
\ its command loop. A command is its opcode (an even number: the host
\ dispatches through a table of words) and its operands. The host answers
\ the requests (keys, a key test, a wait for vsync) through register 4 (host
\ to parasite), which the parasite polls (bit 7: data). The parasite runs with
\ interrupts off.
\
\ ******************************************************************************

\ Tube registers, as the parasite sees them
PR1S = &FEF8            \ register 1 status: bit 7 data from the host, bit 6 room
PR1D = &FEF9
PR4S = &FEFE            \ register 4 status: bit 7 data from the host
PR4D = &FEFF

\ and as the host sees them
HR1S = &FEE0            \ register 1 status: bit 7 data from the parasite
HR1D = &FEE1
HR2S = &FEE2
HR2D = &FEE3
HR4S = &FEE6            \ register 4 status: bit 6 room for the parasite
HR4D = &FEE7

\ The commands (opcode = 2 * n)
C_SYNC     = 0          \ the end of a main-loop iteration's frame (hframe):
                        \ nothing to do (the harness's frame marker)
C_INIT     = 2          \ F_INIT: the rasteriser's and the text map's state
C_FB       = 4          \ frame begin: F_BACK, GSIGHT
C_FE       = 6          \ frame end: R_SN, the stars (x, y, size each), flip
C_ENTER    = 8          \ the first space-mode frame since the screen was drawn
                        \ directly (f_enter2): GSTASH
C_DISC     = 10         \ R_DISCROWS: rows, colours, spans, boundaries
C_DDIRTY   = 12         \ f_discdirty: fold this buffer's disc into its dirty
C_SPAN     = 14         \ R_SPAN: Y, XL, XR, COLE, COLO
C_MARK     = 16         \ R_MARKDIRTY: Y, XL, XR
C_POLY     = 18         \ R_POLY: n, COLE, COLO, COL2, COL3, the vertices
C_LINE     = 20         \ R_LINE: COLE, COLO, X0, Y0, X1, Y1 (words)
C_DOT      = 22         \ R_DOT: COLE, COLO, x, y, size
C_FLARE    = 24         \ R_FLARE: fl_dx, fl_dy
C_DIRECT   = 26         \ F_DIRECT: TT66 is about to draw directly
C_CHAR     = 28         \ CHPR: the character and the cursor
C_KEYS     = 30         \ request: the keys held (FILLKL)
C_DKS      = 32         \ request: is this key held (DKS4, DKS5)
C_WSCAN    = 34         \ request: wait for the next vsync
C_NOISE    = 36         \ NOISE: a sound
C_SOFLUSH  = 38         \ SOFLUSH: stop the sounds
C_DSTAR    = 40         \ F_DSTAR: C, star Y, x, y, ZZ (a star drawn directly)
C_SCEOR    = 42         \ Master's drawing: EOR a byte into the screen (address,
                        \ value)
C_SCSTA    = 44         \ and store one
C_CLS      = 46         \ TTX66: clear the screen (the direct-mode buffer)
C_BOXC     = 48         \ BOX: its two corners, in COL
C_CLYNS    = 50         \ CLYNS: clear text rows 20-23 on the screen
C_CLRTEXT  = 52         \ G_CLRTEXT: the text map's rows 21-23 (QQ11 OR GFORCE,
                        \ GMODE)
C_DET1     = 54         \ DET1: 6845 R6 = X
C_IRB      = 56         \ request: the System VIA's port B
C_OSCLI    = 58         \ OSCLI (DOSCLI): the host's MOS runs the command
C_SWAP     = 60         \ exchange the parasite's &F800-&FEEF with the host's copy
                        \ (the client OS's and the high code: byte for byte)
C_MAX      = 62

TUBE_HIGH = FALSE       \ the parasite's &F800-&FEEF holds code (p-layout.asm's
                        \ PHIGH), swapped with the client OS's copy (C_SWAP)
