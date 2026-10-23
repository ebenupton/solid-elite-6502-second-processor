\ ******************************************************************************
\
\ p-rast.asm - the parasite's rasteriser (docs/TUBE-MAP.md: the dumb host)
\
\ The Master port's rasteriser (gfx-raster.asm and its windows) as far as it
\ decides anything: its interface (R_INIT, R_SETBUF, R_RESETBUF, R_SPAN,
\ R_MARKDIRTY, R_DOT, R_LINE, R_POLY's phase B, R_DISCROWS, R_STARERASE,
\ R_STARPLOT), its per-buffer state (the dirty extents, the disc spans, the
\ star records) and this frame's written extents (R_WL, R_WR). What it would
\ write to the screen goes to the host as spans, lines and dots, which the
\ host draws as the Master port's rasteriser draws them (h-prim.asm): the
\ screen is the host's, everything about what it holds is here.
\
\ Each frame's pixels are the Master port's: the disc layer writes the disc
\ colour on the new span less the intact part of the old one (old span less
\ old dirty extent) and black on the old span and dirty extent less the new
\ span, as R_DISCROWS does (only the bytes it rewrites whole at a moving end
\ differ, and those hold black then); a two-colour row (a beach ball, a
\ crater) is repainted whole every frame, so no boundaries are kept; the
\ dirty rows outside the disc rows are blacked over their extent widened to
\ whole bytes (but in the border's columns), as r7_rowrep does. A line's
\ dirty extent is a bound on its pixels (at most a pixel either side of them
\ in each row), which only means a little more repair.
\
\ In the overlay S (p-ovl.asm): F_FRAME loads it before its first call here.
\
\ ******************************************************************************

\ zero page: the rasteriser's &06-&27 (F_FRAME saves and restores them), and
\ these, which the game leaves free

pr_dl  = &E4            \ (2) this buffer's R_DIRTYL, R_DIRTYR, R_DISCL, R_DISCR
pr_dr  = &E6
pr_sl  = &E8
pr_sr  = &EA
pr_a   = &EC            \ scratch
pr_b   = &ED
pr_c   = &EE
pr_d   = &EF
pr_y   = &F0            \ the row
pr_ce  = &F1            \ the colours of the spans sent (even, odd rows)
pr_co  = &F2
pr_wl  = &F3            \ the extent written in the row (R_WL, R_WR)
pr_wr  = &F4
pr_e   = &F5
pr_f   = &F6
pr_g   = &F7
pr_h   = &F8

R_PCOL2 = R_COL2        \ (the polygon colours for rows y AND 3 = 2, 3)

\ ------------------------------------------------------------------------------
\ The state (the per-buffer arrays: empty L = 255, R = 0)
\ ------------------------------------------------------------------------------

.R_DIRTYL0 SKIP 192
.R_DIRTYR0 SKIP 192
.R_DISCL0  SKIP 192
.R_DISCR0  SKIP 192
.R_DIRTYL1 SKIP 192
.R_DIRTYR1 SKIP 192
.R_DISCL1  SKIP 192
.R_DISCR1  SKIP 192
.R_WL      SKIP 192     \ this frame's written extents (R_WR = 0: none)
.R_WR      SKIP 192
ASSERT LO(R_DIRTYL0) = LO(R_DIRTYL1) AND LO(R_DIRTYR0) = LO(R_DIRTYR1)
ASSERT LO(R_DISCL0) = LO(R_DISCL1) AND LO(R_DISCR0) = LO(R_DISCR1)

.r_buf   EQUB 0         \ the current buffer
.r_dyt   EQUB 255, 255  \ per buffer: rows that may have a dirty extent
.r_dyb   EQUB 0, 0
.r_dst   EQUB 255, 255  \ per buffer: the rows of its disc
.r_dsb   EQUB 0, 0
.r_bmode EQUB 0, 0      \ per buffer: its disc rows may hold boundaries
.r_wt    EQUB 255       \ rows of R_WL/R_WR that may be non-empty
.r_wb    EQUB 0
.r_nt    EQUB 0         \ R_DISCROWS: the new disc rows
.r_nb    EQUB 0
.r_bt    EQUB 0         \ the band (old and new disc rows)
.r_bb    EQUB 0

\ the star records: the host's record bytes of the stars it set in a buffer
\ (R_STARPLOT, h_stars), fetched and sent back to it to be blacked
\ (R_STARERASE), through R_NDX2 (r_srec): free then, before the frame's
\ discs (the beach ball's boundaries are made afresh each frame)
STREC = 4 * 48          \ (at most 48 records of 4 bytes)
r_srec = R_NDX2
ASSERT STREC <= 192 AND MERIDHOLD = 0
.S_STATE_END             \ (the state: what p-ovl.asm saves when S goes out in space
                        \ mode)

.pr_bat  EQUB 0          \ R_DISCROWS's batch (C_DSPANS): bit 7 on, bit 6 sent
.pr_sy   EQUB 0          \ the row buffered, its spans' bytes, the spans (a, b, ce,
.pr_sn   EQUB 0          \ co each)
PSBUF = 4 * 16
.pr_sb   SKIP PSBUF

\ ------------------------------------------------------------------------------
\ R_INIT, R_SETBUF, R_RESETBUF
\ ------------------------------------------------------------------------------

.T_INIT
.R_INIT
 LDA #1                 \ (the clip window, as the Master port's R_INIT)
 STA R_CL
 STA R_CT
 LDA #254
 STA R_CR
 LDA #191
 STA R_CB
 LDA #&FF
 STA R_SCOL
 STA R_NDT
 STZ R_NDB
 STZ R_NDF
 STZ R_SN
 STZ R_PN
 LDY #191
.pin1
 LDA #&FF
 STA R_DIRTYL0,Y
 STA R_DISCL0,Y
 STA R_DIRTYL1,Y
 STA R_DISCL1,Y
 STA R_WL,Y
 LDA #0
 STA R_DIRTYR0,Y
 STA R_DISCR0,Y
 STA R_DIRTYR1,Y
 STA R_DISCR1,Y
 STA R_WR,Y
 DEY
 CPY #&FF
 BNE pin1
 LDX #1
.pin2
 JSR r_reset1
 DEX
 BPL pin2
 LDA #&FF
 STA r_wt
 STZ r_wb
 LDA #0                 \ (falls into R_SETBUF)

.T_SETBUF
.R_SETBUF               \ A = the buffer: its arrays (pr_dl ...)
 AND #1
 STA r_buf
 TAX
 LDA #LO(R_DIRTYL0)
 STA pr_dl
 LDA #LO(R_DIRTYR0)
 STA pr_dr
 LDA #LO(R_DISCL0)
 STA pr_sl
 LDA #LO(R_DISCR0)
 STA pr_sr
 LDA rsb_dl,X
 STA pr_dl+1
 LDA rsb_dr,X
 STA pr_dr+1
 LDA rsb_sl,X
 STA pr_sl+1
 LDA rsb_sr,X
 STA pr_sr+1
 RTS
.rsb_dl EQUB HI(R_DIRTYL0), HI(R_DIRTYL1)
.rsb_dr EQUB HI(R_DIRTYR0), HI(R_DIRTYR1)
.rsb_sl EQUB HI(R_DISCL0), HI(R_DISCL1)
.rsb_sr EQUB HI(R_DISCR0), HI(R_DISCR1)

.T_RESETBUF
.R_RESETBUF             \ the current buffer's state (not the screen)
 LDY #191
.zprs1
 LDA #&FF
 STA (pr_dl),Y
 STA (pr_sl),Y
 LDA #0
 STA (pr_dr),Y
 STA (pr_sr),Y
 DEY
 CPY #&FF
 BNE zprs1
 LDX r_buf
.r_reset1               \ buffer X's scalars (keeps X)
 LDA #&FF
 STA r_dyt,X
 STA r_dst,X
 STZ r_dyb,X
 STZ r_dsb,X
 STZ r_bmode,X
 RTS

\ ------------------------------------------------------------------------------
\ R_MARKDIRTY: Y = row, extend this buffer's dirty extent by R_XL..R_XR (keeps
\ Y, R_XL, R_XR)
\ ------------------------------------------------------------------------------

.T_MARKDIRTY
.R_MARKDIRTY
 LDA R_XL
 CMP (pr_dl),Y
 BCS pmd1
 STA (pr_dl),Y
.pmd1
 LDA R_XR
 CMP (pr_dr),Y
 BCC pmd2
 STA (pr_dr),Y
.pmd2
 LDX r_buf
 TYA
 CMP r_dyt,X
 BCS pmd3
 STA r_dyt,X
.pmd3
 CMP r_dyb,X
 BCC pmd4
 STA r_dyb,X
.pmd4
 RTS

\ ------------------------------------------------------------------------------
\ R_SPAN: Y = row, R_XL..R_XR in R_COLE/R_COLO (pure drawing: C_SPAN). Keeps
\ Y, R_XL, R_XR
\ ------------------------------------------------------------------------------

.T_SPAN
.R_SPAN
 LDA R_XR
 CMP R_XL
 BCC psp9
 LDA #C_SPAN
 JSR ptx
 TYA
 JSR ptx
 LDA R_XL
 JSR ptx
 LDA R_XR
 JSR ptx
 LDA R_COLE
 JSR ptx
 LDA R_COLO
 JMP ptx
.psp9
 RTS

\ pspan: the span pr_a..pr_b on row pr_y in pr_ce/pr_co (pr_a <= pr_b), and
\ R_WL/R_WR's extent for the row (pr_wl, pr_wr). Keeps X, Y

.pspan
 BIT pr_bat             \ (R_DISCROWS: into the row's batch)
 BMI psb
 LDA #C_SPAN
 JSR ptx
 LDA pr_y
 JSR ptx
 LDA pr_a
 JSR ptx
 CMP pr_wl
 BCS P%+4
 STA pr_wl
 LDA pr_b
 JSR ptx
 CMP pr_wr
 BCC P%+4
 STA pr_wr
 LDA pr_ce
 JSR ptx
 LDA pr_co
 JMP ptx

\ pdiff: the span pr_a..pr_b less pr_c..pr_d (pr_a <= pr_b; pr_c > pr_d: no
\ subtrahend), each piece by pspan. Keeps X, Y

.pdiff
 LDA pr_d
 CMP pr_c
 BCC pspan              \ nothing taken away
 LDA pr_c               \ disjoint: all of it
 CMP pr_b
 BEQ pdf1
 BCS pspan
.pdf1
 LDA pr_a
 CMP pr_d
 BEQ pdf2
 BCS pspan
.pdf2
 LDA pr_b               \ the right piece, pr_d + 1 .. pr_b
 CMP pr_d
 BEQ pdf3
 BCC pdf3
 LDA pr_a
 PHA
 LDA pr_d
 INC A
 STA pr_a
 JSR pspan
 PLA
 STA pr_a
.pdf3
 LDA pr_c               \ the left piece, pr_a .. pr_c - 1
 CMP pr_a
 BEQ pdf9
 BCC pdf9
 LDA pr_b
 PHA
 LDA pr_c
 DEC A
 STA pr_b
 JSR pspan
 PLA
 STA pr_b
.pdf9
 RTS

\ ------------------------------------------------------------------------------
\ R_DOT: X = x, Y = y, A = size: the host draws it (C_DOT, as R_DOT); its
\ pixels inside the clip window extend the dirty extents, as r_pclip's
\ ------------------------------------------------------------------------------

.psb                    \ the span into the batch's row buffer (another row's,
 PHX                    \ or a full one: sent first)
 LDX pr_sn
 LDA pr_y
 CMP pr_sy
 BNE psb1
 CPX #PSBUF
 BCC psb2
.psb1
 JSR psflush
 LDA pr_y
 STA pr_sy
 LDX #0
.psb2
 LDA pr_a
 STA pr_sb,X
 CMP pr_wl
 BCS P%+4
 STA pr_wl
 LDA pr_b
 STA pr_sb+1,X
 CMP pr_wr
 BCC P%+4
 STA pr_wr
 LDA pr_ce
 STA pr_sb+2,X
 LDA pr_co
 STA pr_sb+3,X
 TXA
 CLC
 ADC #4
 STA pr_sn
 PLX
 RTS

\ psflush: send the batch's buffered row, if any: the row, the spans' count,
\ the spans (C_DSPANS first if the batch has sent nothing). Keeps Y

.psflush
 LDX pr_sn
 BEQ psf9
 BIT pr_bat
 BVS psf1
 LDA #C_DSPANS
 JSR ptx
 LDA #%11000000
 STA pr_bat
.psf1
 LDA pr_sy
 JSR ptx
 TXA
 LSR A
 LSR A
 JSR ptx
 LDX #0
.psf2
 LDA pr_sb,X
 JSR ptx
 INX
 CPX pr_sn
 BNE psf2
 STZ pr_sn
.psf9
 RTS

.T_DOT
.R_DOT
 STA pr_e
 STX pr_f
 STY pr_g
 LDA #C_DOT
 JSR ptx
 LDA R_COLE
 JSR ptx
 LDA R_COLO
 JSR ptx
 TXA
 JSR ptx
 TYA
 JSR ptx
 LDA pr_e
 JSR ptx
 JSR pdclip             \ (x, y)
 LDA pr_e
 CMP #2
 BCC pdo9
 LDX pr_f               \ (x + 1, y)
 INX
 BEQ pdo2
 LDY pr_g
 JSR pdclip
.pdo2
 LDA pr_e
 CMP #3
 BCC pdo9
 LDY pr_g               \ (x, y + 1), (x + 1, y + 1)
 INY
 BEQ pdo9
 LDX pr_f
 JSR pdclip
 LDX pr_f
 INX
 BEQ pdo9
 LDY pr_g
 INY
 JMP pdclip
.pdo9
 RTS

.pdclip                 \ X, Y: dirty if inside the clip window
 CPX R_CL
 BCC pdo9
 CPX R_CR
 BEQ P%+4
 BCS pdo9
 CPY R_CT
 BCC pdo9
 CPY R_CB
 BEQ P%+4
 BCS pdo9
 STX R_XL
 STX R_XR
 JMP R_MARKDIRTY

\ ------------------------------------------------------------------------------
\ R_LINE: R_X0, R_Y0, R_X1, R_Y1 (signed words), R_COLE/R_COLO/R_COL2/R_COL3:
\ the host draws it (C_LINE, as R_LINE); the dirty extents take a bound on
\ its pixels: in each row of its clipped rows, its x there (stepped in 8.8)
\ with half the slope and a pixel either side; with any end outside 0..255,
\ its bounding box (clipped)
\ ------------------------------------------------------------------------------

.T_LINE
.R_LINE
 LDA #C_LINE
 JSR ptx
 LDA R_COLE
 JSR ptx
 LDA R_COLO
 JSR ptx
 LDA R_COL2
 JSR ptx
 LDA R_COL3
 JSR ptx
 LDX #0
.pli1
 LDA R_X0,X
 JSR ptx
 INX
 CPX #8
 BNE pli1
 LDA R_X0+1             \ any end outside 0..255: the box
 ORA R_Y0+1
 ORA R_X1+1
 ORA R_Y1+1
 BEQ pli8
 JMP plbox
.pli8
 LDA R_Y0               \ (x0, y0) the upper end
 CMP R_Y1
 BCC pli2
 LDX R_X0               \ swap
 LDY R_Y0
 LDA R_X1
 STA R_X0
 LDA R_Y1
 STA R_Y0
 STX R_X1
 STY R_Y1
.pli2
 LDA R_X0               \ the x range of the line: pr_c .. pr_d
 CMP R_X1
 BCC pli3
 LDX R_X1
 STX pr_c
 STA pr_d
 BCS pli4
.pli3
 STA pr_c
 LDA R_X1
 STA pr_d
.pli4
 LDA R_Y1               \ dy = y1 - y0 (>= 0)
 SEC
 SBC R_Y0
 STA pr_e
 BNE pli5
 LDY R_Y0               \ one row
 LDA pr_c
 STA R_XL
 LDA pr_d
 STA R_XR
 JMP plmark
.pli5
 LDA R_X1               \ |dx|, and the sign of dx
 SEC
 SBC R_X0
 STA pr_f
 LDA #0
 STA pr_h               \ (0: dx >= 0)
 BCS pli6
 DEC pr_h
 LDA pr_f
 EOR #&FF
 INC A
 STA pr_f
.pli6
 JSR pldiv              \ pr_a(lo).pr_b(hi) = |dx| * 256 / dy, the step
 LDA pr_b               \ half the step plus two pixels: the margin pr_g
 LSR A
 CLC
 ADC #2
 STA pr_g
 LDA R_X0               \ x = x0 (8.8: pr_c... no: pr_wl.pr_wr)
 STA pr_wr
 LDA #&80
 STA pr_wl
 LDY R_Y0
.pli7
 LDA pr_wr              \ this row: x - margin .. x + margin, within the
 SEC                    \ line's x range
 SBC pr_g
 BCS P%+4
 LDA #0
 CMP pr_c
 BCS P%+4
 LDA pr_c
 STA R_XL
 LDA pr_wr
 CLC
 ADC pr_g
 BCC P%+4
 LDA #255
 CMP pr_d
 BCC P%+4
 LDA pr_d
 STA R_XR
 JSR plmark
 CPY R_Y1
 BEQ pli9
 INY
  LDA pr_h               \ x += step (or -=)
 BMI pli10
 LDA pr_wl
 CLC
 ADC pr_a
 STA pr_wl
 LDA pr_wr
 ADC pr_b
 STA pr_wr
 BRA pli7
.pli10
 LDA pr_wl
 SEC
 SBC pr_a
 STA pr_wl
 LDA pr_wr
 SBC pr_b
 STA pr_wr
 BRA pli7
.pli9
 RTS

\ plmark: row Y's extent R_XL..R_XR, if inside the clip window (clipped).
\ Keeps Y

.plmark
 CPY R_CT
 BCC plm9
 CPY R_CB
 BEQ P%+4
 BCS plm9
 LDA R_XL
 CMP R_CL
 BCS P%+6
 LDA R_CL
 STA R_XL
 LDA R_XR
 CMP R_CR
 BCC P%+6
 LDA R_CR
 STA R_XR
 LDA R_XR
 CMP R_XL
 BCC plm9
 JMP R_MARKDIRTY
.plm9
 RTS

\ pldiv: pr_b.pr_a = pr_f * 256 / pr_e (pr_e > 0), 8.8 (16-bit shift and
\ subtract)

.pldiv
 LDA #0                 \ remainder
 STZ pr_a               \ the dividend pr_f.0, shifted into the quotient
 LDX pr_f
 STX pr_b
 LDX #16
.pld1
 ASL pr_a
 ROL pr_b
 ROL A
 BCS pld2
 CMP pr_e
 BCC pld3
.pld2
 SBC pr_e
 INC pr_a
.pld3
 DEX
 BNE pld1
 RTS

\ plbox: a line with an end outside 0..255: its bounding box, clipped

.plbox
 LDA R_Y0               \ rows: max(min(y), CT) .. min(max(y), CB)
 LDX R_Y0+1
 JSR plcy
 STA pr_a
 LDA R_Y1
 LDX R_Y1+1
 JSR plcy
 STA pr_b
 CMP pr_a
 BCS P%+8
 LDX pr_a
 STA pr_a
 STX pr_b
 LDA R_X0               \ x: the same
 LDX R_X0+1
 JSR plcx
 STA R_XL
 LDA R_X1
 LDX R_X1+1
 JSR plcx
 STA R_XR
 CMP R_XL
 BCS P%+8
 LDX R_XL
 STA R_XL
 STX R_XR
 LDY pr_a
.plb1
 JSR plmark
 CPY pr_b
 INY
 BCC plb1
 RTS

.plcy                   \ A = (X A) clamped to CT..CB
 CPX #0
 BMI plcy1
 BNE plcy2
 CMP R_CT
 BCC plcy1
 CMP R_CB
 BCC plcy3
 BEQ plcy3
.plcy2
 LDA R_CB
 RTS
.plcy1
 LDA R_CT
.plcy3
 RTS

.plcx                   \ A = (X A) clamped to CL..CR
 CPX #0
 BMI plcx1
 BNE plcx2
 CMP R_CL
 BCC plcx1
 CMP R_CR
 BCC plcx3
 BEQ plcx3
.plcx2
 LDA R_CR
 RTS
.plcx1
 LDA R_CL
.plcx3
 RTS

\ ------------------------------------------------------------------------------
\ R_POLY's phase B for 16-bit polygons (p_spans, after phase A: p-polya.asm,
\ p-polyb.asm): the left table, then each row's span, clipped, to the host as
\ it is read (p_emit, p-emit.asm, which also takes the dirty extents), as the
\ one-pass generator sends the 8-bit polygons' rows
\ ------------------------------------------------------------------------------

.p_spans
 LDA r_ystart           \ which table is the left one?
 CLC
 ADC r_ylast
 ROR A
 TAY
 LDA r_ta,Y
 CMP r_tb,Y
 BCC pps2               \ ta: left
 BNE pps1
 LDY r_ystart
.pps0
 LDA r_ta,Y
 CMP r_tb,Y
 BCC pps2
 BNE pps1
 INY
 CPY r_yend
 BCC pps0
 RTS                    \ no pixels
.pps1
 LDY r_ystart           \ tb is the left one: swap the tables' rows
.pps3
 LDA r_ta,Y
 LDX r_tb,Y
 STA r_tb,Y
 TXA
 STA r_ta,Y
 INY
 CPY r_yend
 BCC pps3
.pps2
 LDY r_ystart           \ each row with pixels to the host (p_emit), clipped to
 LDA r_xclip            \ CL..CR+1 if some x is outside it
 BNE ppc
.ppn
 LDA r_tb,Y
 CMP r_ta,Y
 BEQ ppn1
 BCC ppn1
 LDX r_ta,Y
 JSR p_emit
.ppn1
 INY
 CPY r_yend
 BCC ppn
 JMP p_spend
.ppc
 LDA r_ta,Y
 CMP R_CL
 BCS P%+4
 LDA R_CL
 CMP r_cr1
 BCC P%+5
 LDA r_cr1
 STA pr_a
 LDA r_tb,Y
 CMP R_CL
 BCS P%+4
 LDA R_CL
 CMP r_cr1
 BCC P%+5
 LDA r_cr1
 CMP pr_a
 BEQ ppc1
 BCC ppc1
 LDX pr_a
 JSR p_emit
.ppc1
 INY
 CPY r_yend
 BCC ppc
 JMP p_spend

\ ------------------------------------------------------------------------------
\ R_DISCROWS: the disc layer for this buffer (R_NDT, R_NDB, R_NDISCL/R, R_DCE
\ and R_DCO; with R_NDF, R_NDN, R_NDP, R_NDX0-3, R_DBE and R_DBO): see above
\ ------------------------------------------------------------------------------

.T_DISCROWS
.R_DISCROWS
 LDA #%10000000         \ (its spans batched: C_DSPANS)
 STA pr_bat
 STZ pr_sn
 JSR pdr0
 JSR psflush
 BIT pr_bat
 STZ pr_bat
 BVC pdr00
 LDA #&FF               \ (the batch's end)
 JMP ptx
.pdr00
 RTS
.pdr0
 LDA R_NDT              \ the new rows, clamped to the window
 CMP R_CT
 BCS P%+4
 LDA R_CT
 STA r_nt
 LDA R_NDB
 CMP R_CB
 BCC P%+4
 LDA R_CB
 STA r_nb
 CMP r_nt
 BCS pdr1
 LDA #&FF
 STA r_nt
 STZ r_nb
.pdr1
 LDY r_wb               \ last frame's R_WL/R_WR rows cleared
 CPY r_wt
 BCC pdr3
.pdr2
 LDA #0
 STA R_WR,Y
 LDA #&FF
 STA R_WL,Y
 CPY r_wt
 BEQ pdr3
 DEY
 BRA pdr2
.pdr3
 LDA #&FF
 STA r_wt
 STZ r_wb
 LDX r_buf              \ the band: the old disc rows and the new ones
 LDA r_dst,X
 CMP r_nt
 BCC P%+5
 LDA r_nt
 STA r_bt
 LDA r_dsb,X
 CMP r_nb
 BCS P%+5
 LDA r_nb
 STA r_bb
 LDA r_dyb,X            \ the dirty rows outside the band: blacked (rowrep)
 STA pr_g
 LDY r_dyt,X
.pdr4
 CPY pr_g
 BEQ P%+4
 BCS pdr6
 LDA r_bb
 CMP r_bt
 BCC pdr5               \ (no band)
 CPY r_bt
 BCC pdr5
 CPY r_bb
 BEQ pdr5a
 BCC pdr5a
.pdr5
 LDA (pr_dr),Y
 BEQ pdr5a
 JSR prep
.pdr5a
 INY
 BNE pdr4
.pdr6
 LDX r_buf
 LDA r_nt               \ the buffer's new disc rows, no dirty rows
 STA r_dst,X
 LDA r_nb
 STA r_dsb,X
 LDA #&FF
 STA r_dyt,X
 STZ r_dyb,X
 LDA R_NDF              \ a two-colour frame, this time or last time
 ORA r_bmode,X
 STA pr_h
 LDA R_NDF
 STA r_bmode,X
 LDY r_bt               \ the band's rows
 LDA r_bb
 CMP r_bt
 BCC pdr9
.pdr7
 JSR prow
 CPY r_bb
 BEQ pdr9
 INY
 BNE pdr7
.pdr9
 RTS

\ prep: row Y, dirty, no disc row: black its extent widened to whole bytes
\ (in the border's columns, the pixels only), R_WL/R_WR that, no dirty.
\ Keeps Y

.prep
 STY pr_y
 STZ pr_ce
 STZ pr_co
 LDA (pr_dl),Y
 STA pr_a
 AND #&FC
 STA R_WL,Y
 CMP #4
 BCC P%+4
 STA pr_a
 LDA (pr_dr),Y
 STA pr_b
 ORA #3
 STA R_WR,Y
 CMP #252
 BCS P%+4
 STA pr_b
 LDA #&FF
 STA pr_wl              \ (pspan's extent: unused here)
 STA (pr_dl),Y
 LDA #0
 STA pr_wr
 STA (pr_dr),Y
 JSR pspan
.prw                    \ row Y written: r_wt..r_wb
 CPY r_wt
 BCS P%+5
 STY r_wt
 CPY r_wb
 BCC P%+5
 STY r_wb
 RTS

\ prow: row Y of the band. Keeps Y

.prow
 STY pr_y
 LDA #&FF               \ the new span (empty: 255, 0), clamped to the window
 STA pr_e
 STZ pr_f
 CPY r_nt
 BCC prw2
 CPY r_nb
 BEQ P%+4
 BCS prw2
 LDA R_NDISCL,Y
 CMP R_CL
 BCS P%+4
 LDA R_CL
 STA pr_a
 LDA R_NDISCR,Y
 CMP R_CR
 BCC P%+4
 LDA R_CR
 CMP pr_a
 BCC prw2
 STA pr_f
 LDA pr_a
 STA pr_e
.prw2
 LDA pr_h
 BNE prw3               \ (two colours: always)
 LDA (pr_dr),Y          \ one colour: unchanged, with no dirty extent?
 BNE prw3
 LDA pr_e
 CMP (pr_sl),Y
 BNE prw3
 LDA pr_f
 CMP (pr_sr),Y
 BNE prw3
 RTS
.prw3
 LDA #&FF
 STA pr_wl
 STZ pr_wr
 STZ pr_ce              \ black: (old span + dirty extent) less the new span
 STZ pr_co
 LDA pr_e
 STA pr_c
 LDA pr_f
 STA pr_d
 LDA (pr_sl),Y
 STA pr_a
 LDA (pr_sr),Y
 STA pr_b
 CMP pr_a
 BCC prw4
 JSR pdiff
.prw4
 LDA (pr_dl),Y
 STA pr_a
 LDA (pr_dr),Y
 STA pr_b
 CMP pr_a
 BCC prw5
 JSR pdiff
.prw5
 LDA pr_f               \ the new span, if any
 CMP pr_e
 BCC prw9
 LDA pr_h
 BNE prw8
 LDA R_DCE              \ one colour: the new span less the intact old span,
 STA pr_ce              \ i.e. (new less old) and (new and dirty)
 LDA R_DCO
 STA pr_co
 LDA pr_e
 STA pr_a
 LDA pr_f
 STA pr_b
 LDA (pr_sl),Y
 STA pr_c
 LDA (pr_sr),Y
 STA pr_d
 JSR pdiff
 LDA (pr_dr),Y          \ new and dirty
 CMP (pr_dl),Y
 BCC prw9
 CMP pr_f
 BCC P%+4
 LDA pr_f
 STA pr_b
 LDA (pr_dl),Y
 CMP pr_e
 BCS P%+4
 LDA pr_e
 STA pr_a
 LDA pr_b
 CMP pr_a
 BCC prw9
 JSR pspan
 BRA prw9
.prw8
 JSR pseg               \ two colours: the whole new span, segment by segment
.prw9
 LDA pr_e               \ the buffer's disc span: the new one; no dirty extent
 STA (pr_sl),Y
 LDA pr_f
 STA (pr_sr),Y
 LDA #&FF
 STA (pr_dl),Y
 LDA #0
 STA (pr_dr),Y
 LDA pr_wr              \ R_WL/R_WR: what was written
 BEQ prw10
 STA R_WR,Y
 LDA pr_wl
 STA R_WL,Y
 JMP prw
.prw10
 RTS

\ pseg: the new span pr_e..pr_f of row Y in colours A (R_DCE, R_DCO) and B
\ (R_DBE, R_DBO): pixel x takes colour R_NDP EOR the number of boundaries
\ (R_NDX0-3, R_NDN of them, at most 4) <= x, as r_segw. Keeps Y

.pseg
 LDA #0                 \ (rows outside the new disc rows, or a frame with no
 STA pr_g               \ boundaries, R_NDF = 0: none)
 STZ pr_c
 LDA R_NDF
 BEQ pseg1
 CPY r_nt
 BCC pseg1
 CPY r_nb
 BEQ P%+4
 BCS pseg1
 LDA R_NDN,Y
 CMP #5
 BCC P%+4
 LDA #4
 STA pr_g
 LDA R_NDP,Y
 AND #1
 STA pr_c               \ the colour now
.pseg1
 LDA pr_e
 STA pr_a               \ the segment's start
 LDX #0
.pseg2
 CPX pr_g
 BCS pseg5
 LDA psx_l,X            \ boundary X of row Y
 STA pseg3+1
 LDA psx_h,X
 STA pseg3+2
.pseg3
 LDA &FFFF,Y            \ (patched: R_NDXx)
 CMP pr_e
 BEQ pseg4
 BCC pseg4
 CMP pr_f
 BEQ P%+4
 BCS pseg5
 CMP pr_a
 BEQ pseg4              \ an empty segment
 PHA
 DEC A
 STA pr_b
 JSR psegc
 PLA
 STA pr_a
.pseg4
 LDA pr_c
 EOR #1
 STA pr_c
 INX
 BRA pseg2
.pseg5
 LDA pr_f
 STA pr_b
.psegc                  \ pr_a..pr_b in colour pr_c (keeps X, Y)
 LDA pr_c
 BNE psgc1
 LDA R_DCE
 STA pr_ce
 LDA R_DCO
 STA pr_co
 JMP pspan
.psgc1
 LDA R_DBE
 STA pr_ce
 LDA R_DBO
 STA pr_co
 JMP pspan
.psx_l EQUB LO(R_NDX0), LO(R_NDX1), LO(R_NDX2), LO(R_NDX3)
.psx_h EQUB HI(R_NDX0), HI(R_NDX1), HI(R_NDX2), HI(R_NDX3)

\ ------------------------------------------------------------------------------
\ The stars: the host plots them (C_STARS: R_SCOL, R_SN, then x, y and size
\ each, as R_STARPLOT: a star's pixels in a byte only where they are all
\ black) and sends back its records of the bytes it set (the count, then 4
\ bytes each, h_stars), which this buffer keeps; R_STARERASE sends them back
\ (C_STARERASE), and the host blacks those pixels
\ ------------------------------------------------------------------------------

.T_STARERASE
.R_STARERASE            \ this buffer's records from the host (C_STARGET, where
 LDA #C_STARGET         \ C_STARS left them), then back to it to black those
 JSR preq               \ pixels (C_STARERASE)
 LDA r_buf
 JSR preq
 JSR prx
 STA pr_d
 ASL A
 ASL A
 STA pr_c
 BEQ pse2
 LDY #0
.pse0
 JSR prx
 STA r_srec,Y
 INY
 CPY pr_c
 BNE pse0
.pse2
 LDA #C_STARERASE
 JSR ptx
 LDA pr_d
 JSR ptx
 LDA pr_c
 BEQ pse9
 LDY #0
.pse1
 LDA r_srec,Y
 JSR ptx
 INY
 CPY pr_c
 BNE pse1
.pse9
 RTS

.T_STARPLOT
.R_STARPLOT
 LDA #C_STARS
 JSR ptx
 LDA R_SCOL
 JSR ptx
 LDA R_SN
 JSR ptx
 LDX #0
 CPX R_SN
 BEQ pst2
.pst1
 LDA R_SX,X
 JSR ptx
 LDA R_SY,X
 JSR ptx
 LDA R_SS,X
 JSR ptx
 INX
 CPX R_SN
 BNE pst1
.pst2
 RTS                    \ (the host keeps the records until C_STARGET)
