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
PR2S = &FEFA            \ register 2 status: bit 6 room
PR2D = &FEFB
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
C_DISC     = 10         \ R_DISCROWS: rows, colours, spans, boundaries (R_NDF =
                        \ 1), or none (0: a plain disc; &81: a beach ball, whose
                        \ boundaries the host's meridian window makes)
C_DDIRTY   = 12         \ f_discdirty: fold this buffer's disc into its dirty
C_SPAN     = 14         \ R_SPAN: Y, XL, XR, COLE, COLO
C_MARK     = 16         \ R_MARKDIRTY: Y, XL, XR
C_POLY     = 18         \ R_POLY's rows (phase 3: p-polya.asm): COLE, COLO, COL2,
                        \ COL3, xclip, ystart, ylast, then left and right per row
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
C_MERHOOK  = 62         \ H_MERID (a beach ball, gfx-hooks.asm): roofv and sidev
                        \ (INWK+15..26), K3, K4, MCNT, PM_R: the host's meridian
                        \ window computes the frame's constants (PM_HOOK), and
                        \ C_DISC with R_NDF = &81 has it make the rows
                        \ (PM_MERID) from the spans that C_DISC carries
C_OVLGET   = 64         \ request: an overlay's image (p-ovl.asm): the number;
                        \ the host sends its whole pages through register 4
C_PDIALS   = 66         \ the panel (p-dash.asm, the host's dashboard routines): DIALS'
                        \ inputs (DELTA, ALP1, ALP2, BETA, BET1, MCNT, ENERGY,
                        \ FSH, ASH, QQ14, CABTMP, GNTMP, ALTIT, FLH)
C_PDOT     = 68         \ the compass dot: COMX, COMY, COMC
C_PSCAN    = 70         \ a ship on the scanner: dX1, Y1, Y2, TYPE
C_PMSBAR   = 72         \ a missile indicator: X, Y (MSBAR's)
C_PBULB    = 74         \ a bulb: 0 E.C.M., 1 space station
\ the dumb host's primitives (p-rast.asm, h-prim.asm): the parasite decides,
\ the host draws
C_BUF      = 76         \ the frame's buffer: b (the host waits for the last flip,
                        \ then draws into b)
C_FLIP     = 78         \ show the frame's buffer at the next vsync
C_SPANS    = 80         \ polygon rows: COLE, COLO, COL2, COL3, first and last
                        \ row, then left and right (exclusive) per row
C_ORSPAN   = 82         \ the lens flare: y, xl, xr, mask: OR the mask over the span
C_STARS    = 84         \ R_SCOL, R_SN, then x, y, size each: plot (on black only);
                        \ the host sends back its records (count, 4 bytes each)
C_STARERASE = 86        \ the records' count, then the records: black those pixels
C_GLYPH    = 88         \ a text cell: the character, its column, its text row
C_ENTERB   = 90         \ space mode: buffer 1's border to buffer 0, buffer 1 on show
C_CLRBUF   = 92         \ clear buffer b's screen
C_EORDOT   = 94         \ EOR a directly drawn star away (buffer 1): x, y, size
C_DIRECTD  = 96         \ direct mode (the display: shadow RAM, buffer 1, on show)
C_OVLPUT   = 98         \ an overlay's (S's state's) pages to the host to keep: the
                        \ number, then its pages (p-ovl.asm)
C_LOIN     = 100        \ a line (Master's LOINQ, the direct-mode screen): X1, Y1,
                        \ X2, Y2, COL
C_STARGET  = 102        \ request (register 2): buffer b's star records (the count,
                        \ then 4 bytes each), as the host's last C_STARS for it left them
C_HLOIN    = 104        \ a horizontal line (Master's HLOIN3, the direct-mode
                        \ screen): X1, X2 (X1 < X2), Y1, COL
C_PIXEL    = 106        \ a point (Master's PIXEL, the direct-mode screen): x,
                        \ y, ZZ, COL
C_DSPANS   = 108        \ the disc layer's spans (R_DISCROWS): per row, the row,
                        \ the spans' count, then XL, XR, COLE, COLO each; &FF ends
C_MAX      = 110

DASHV_B = &BF80         \ (the Model B host: the dashboard's variables, bank F)

TUBE_HIGH = TRUE        \ the parasite's &F800-&FEEF holds code (p-layout.asm's
                        \ PHIGH), swapped with the client OS's copy (C_SWAP)

\ the host's Tube I/O

MACRO HRX               \ A = the next byte from the parasite (register 1)
 BIT HR1S
 BPL P%-3
 LDA HR1D
ENDMACRO

MACRO HTX               \ send A to the parasite (register 4)
 BIT HR4S
 BVC P%-3
 STA HR4D
ENDMACRO


MACRO HR2X              \ A = the next byte from the parasite's register 2 (a
 BIT HR2S               \ request's operand)
 BPL P%-3
 LDA HR2D
ENDMACRO
