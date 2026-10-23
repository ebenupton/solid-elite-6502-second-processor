\ ******************************************************************************
\
\ p-onepass.asm - R_POLY in one pass, exactly as the two-phase path (the dumb
\ host's parasite, docs/TUBE-MAP.md)
\
\ Every polygon's rows go to the host (p_emit, p-emit.asm) as they are made:
\ the two chains are walked in lockstep, one row at a time, with no per-row
\ edge tables. The spans are the two-phase path's exactly (the Master port's
\ R_POLY: phase A's tables, r_pcbd's orientation, clip and trim), for every
\ polygon, the self-crossing and the degenerate ones included:
\
\   * The orientation. The two-phase path takes the left table to be the one
\     that is smaller at the middle row, Ym = (ystart + ylast) / 2, or, if
\     the tables are equal there, at the first row from ystart where they
\     differ; a row where the other table is the smaller one is empty (so a
\     bow tie's other lobe is not filled). That decision needs only each
\     chain's x at Ym, not the rows before it: oo_ori finds each chain's edge
\     at Ym by walking the vertices (no rows), and compares the two edges'
\     x ranges; only if they overlap does it work out the two x values
\     exactly (r7_esgen: x0 + ceil(dx * k / dy), the DDA's own value). If
\     they are equal there, the first row whose ends differ decides, which
\     the row loop sees before it sends anything (all the rows before it are
\     empty either way: dund, dswap).
\   * 8-bit polygons (r_pf8's set-up) compare the chains' x unclipped and
\     clip each span to CL..CR+1 as it is sent; 16-bit polygons (r7_pf16's
\     set-up) clamp each chain's x into CL..CR+1 as phase A's 16-bit path
\     writes its tables, and compare those, as the two-phase path did.
\   * The chains. Phase A's tables hold, at each row, the x of the last edge
\     in the chain's walk that covers it. For a chain that is monotone in y
\     (the walk's edges never go up) that is simply the next edge with rows
\     (oo_seq); for one that is not (rounding makes tiny faces so, now and
\     then), oo_win finds the covering edge that comes last in the walk, and
\     the row where another takes over, by a scan of the chain's edges at
\     each such row (the vertices only).
\
\ Each chain's x comes from a DDA: an 8-bit one inline in the row loop (x, t
\ in zero page, a, b, dy patched; r_e8's own set-up, diverted at its DDA
\ entries, fz and fsh), or for a 16-bit polygon's edge that starts or ends
\ outside CL..CR+1, a 16-bit one (o16adv, o16cur: phase A's r7_e16 per row)
\ that turns into the 8-bit one once x is inside for good, or into a
\ constant (the 8-bit one with a = b = 0) once it is outside for good. The
\ side's step in the row loop is patched to a JMP while it is 16-bit.
\
\ Only the polygon's vertices are looked at ahead of its rows; no row is held
\ back from the host.
\
\ ******************************************************************************

f_x0 = &1C              \ side 0 (chain A, forward): x, error
f_t0 = &1D
f_x1 = &1E              \ side 1 (chain B, backward): x, error
f_t1 = &1F
fseg = &24              \ the row at which an edge (or the polygon) ends
ftmp = &25

\ the variables: in R_NDX2, free while the ships are drawn (the disc layer's
\ boundaries have gone to the host), as the two-phase path's tables were
fside  = R_NDX2         \ bit 7: the side being set up is side 1
ofch    = R_NDX2 + 1     \ the chain being set up (0, 1)
fcur   = R_NDX2 + 2     \ per chain: its current vertex, edges left, end row
fcc    = R_NDX2 + 4
fe     = R_NDX2 + 6
frow   = R_NDX2 + 8     \ the row where a chain's next edge starts
fev    = R_NDX2 + 9     \ (owalk: the winner's end row)
fk     = R_NDX2 + 10
fsv    = R_NDX2 + 11    \ (2: oo_win keeps r_ystart, r_yend)
fgen   = R_NDX2 + 13    \ bit 7: the polygon's y is not unimodal (oo_win)
op16   = R_NDX2 + 14    \ bit 7: a 16-bit polygon
oymL   = R_NDX2 + 15    \ the polygon's lowest y (its chains' end)
oymH   = R_NDX2 + 16
oym    = R_NDX2 + 17    \ the middle row
oyr    = R_NDX2 + 18    \ the row owalk looks for
ow     = R_NDX2 + 19    \ (2) per chain: its edge at the middle row (first vertex)
ock    = R_NDX2 + 21    \ the row loop's ck branch when decided
ov     = R_NDX2 + 22    \ (2) oo_ori's scratch
olast  = R_NDX2 + 24    \ oo_scan: the last edge's direction, the first's,
ofirst = R_NDX2 + 25    \ the changes of direction
ochg   = R_NDX2 + 26
owi    = R_NDX2 + 27    \ owalk: the winner (i0, i1)
owj    = R_NDX2 + 28
oi0    = R_NDX2 + 29    \ oo_val's scratch
odx    = R_NDX2 + 30
ok     = R_NDX2 + 31
opl    = R_NDX2 + 32
oph    = R_NDX2 + 33
odv    = R_NDX2 + 34
O16    = R_NDX2 + 36    \ per side (side 1 at + 11), a 16-bit edge: a, b, x,
o16al  = O16            \ error, dy (2 bytes each, as r7_esgen leaves them),
o16ah  = O16 + 1        \ and bit 7: its far end is inside CL..CR+1 and dy <
o16bl  = O16 + 2        \ 256
o16bh  = O16 + 3
o16sl  = O16 + 4
o16sh  = O16 + 5
o16tl  = O16 + 6
o16th  = O16 + 7
o16dl  = O16 + 8
o16dh  = O16 + 9
o16t4  = O16 + 10
OCY    = R_NDX3         \ (17) oo_scan: the vertices' y clamped into 0..192
ASSERT O16 + 22 <= R_NDX2 + 192 AND HI(O16) = HI(O16 + 21)

\ ------------------------------------------------------------------------------
\ The entries: op_16 from r7_pf16 (gfx-raster_polyb.asm: r7_n, r7_top,
\ r7_ymaxL/H, r_ystart, r_ylast, r_yend), op_8 from r_pf8 (gfx-raster_poly.asm:
\ r_n, r_top, r_ymaxL, the rows, r_xclip, r_cr1). Both return to R_POLY, which
\ ends the host's stream (p_spend)
\ ------------------------------------------------------------------------------

.op_16
 LDA r7_n
 STA r_n
 LDA r7_top
 STA r_top
 LDA r7_ymaxL
 STA oymL
 LDA r7_ymaxH
 STA oymH
 LDA R_CR
 INC A
 STA r_cr1
 STZ r_xclip            \ (the chains' x are clamped: no clip when sent)
 LDA #&80
 BNE oopc

.op_8
 LDA r_ymaxL
 STA oymL
 STZ oymH
 LDA #0
.oopc
 STA op16
 LDA r_ystart           \ the middle row (as r_pcbd: a 9-bit sum, halved)
 CLC
 ADC r_ylast
 ROR A
 STA oym
 STA oyr
 STZ fgen
 LDA #&FF
 STA ow
 STA ow+1
 LDA r_n                \ a triangle (or less) is simple: the first row whose
 CMP #4                 \ ends differ decides, as at the middle row
 BCC opu
 JSR oo_scan            \ y unimodal: each chain's edge at the middle row
 BIT fgen
 BPL opm
 LDX #0                 \ not: each chain's edge there by its walk
 JSR owalk
 STX ow
 LDX #1
 JSR owalk
 STX ow+1
.opm
 LDA oym                \ the middle row is the first: the first row whose
 CMP r_ystart           \ ends differ decides
 BEQ opu
 JSR oo_ori             \ the orientation: the row loop's patches
 BRA ops
.opu
 JSR ooo_u
.ops
 LDA r_n                \ each chain's first edge with rows: both "end" at
 STA fcc                \ ystart, where fnext starts them
 STA fcc+1
 LDA r_top
 STA fcur
 STA fcur+1
 LDY r_ystart
 STY fe
 STY fe+1
 JMP fnext

\ owalk: chain X's walk (as phase A's: from the top vertex, forward for chain
\ 0, backward for 1, to the first vertex at the lowest y, at most n edges):
\ the last edge in it that covers row oyr (phase A's tables hold its x
\ there): X = its first vertex (owi, owj; X = &FF: none), fev = the row where
\ it ends or a later edge in the walk starts (if before r_yend). Rows by OCY
\ (oo_scan)

.owalk
 STX ofch
 LDA #&FF
 STA owi
 LDA r_n
 STA fk
 LDY r_top
.owk1
 LDA R_PYL,Y            \ at the lowest y: done
 CMP oymL
 BNE owk2
 LDA R_PYH,Y
 CMP oymH
 BEQ owk8
.owk2
 DEC fk
 BMI owk8
 STY ftmp               \ (i0)
 TYA
 JSR fnxt
 TAY                    \ (i1)
 LDX ftmp
 LDA oyr
 CMP OCY,X              \ y0 <= oyr ?
 BCC owk4
 CMP OCY,Y              \ oyr < y1: this edge covers it
 BCS owk1
 STX owi
 STY owj
 LDA r_yend
 STA fev
 BRA owk1
.owk4                   \ y0 > oyr: if it goes down, it takes over at y0
 LDA OCY,X
 CMP OCY,Y
 BCS owk1
 CMP fev
 BCS owk1
 STA fev
 BRA owk1
.owk8
 LDX owi
 BMI owk9
 LDY owj                \ the winner's own end
 LDA OCY,Y
 CMP fev
 BCS owk9
 STA fev
.owk9
 RTS

\ fnxt: A = the vertex after vertex A in chain ofch's walk. Keeps Y

.fnxt
 LDX ofch                \ (0: forward, 1: backward)
 BNE fnx1
 INC A
 CMP r_n
 BCC fnx9
 LDA #0
 RTS
.fnx1
 DEC A
 BPL fnx9
 LDA r_n
 DEC A
.fnx9
 RTS

\ oo_ori: the orientation, as the two-phase path decides it, from the chains'
\ edges at the middle row; sets the row loop's patches

.oo_ori
 LDA ow                 \ (no edge at the middle row: undecided)
 ORA ow+1
 BMI ooo_u
 LDX #0                 \ the x values at the middle row
 JSR oo_val
 STA ov
 LDX #1
 JSR oo_val
 CMP ov
 BEQ ooo_u
 BCS ooo_a
.ooo_b
 LDX #f_x1
 LDY #f_x0
 BRA ooo_s
.ooo_a
 LDX #f_x0
 LDY #f_x1
.ooo_s
 STX dl+1
 STY dc+1
 STY dr+1
 STY dr2+1
 LDA #dempty-(dcb+2)    \ decided: a row whose sides are the other way is empty
 STA dcb+1
 JSR ooo_k
 STA ck+1
 RTS
.ooo_u                  \ undecided: the first row whose sides differ decides
 JSR ooo_k              \ (dswap, dund)
 LDX #f_x0
 LDY #f_x1
 STX dl+1
 STY dc+1
 STY dr+1
 STY dr2+1
 LDA #dswap-(dcb+2)
 STA dcb+1
 LDA #dund-(ck+2)
 STA ck+1
 RTS
.ooo_k                  \ ock, A = ck's branch once decided: dcl if clipping
 LDA #dnc-(ck+2)
 LDX r_xclip
 BEQ P%+4
 LDA #dcl-(ck+2)
 STA ock
 RTS

\ oclamp: A = (X A), a 16-bit x, clamped into CL..CR+1

.oclamp
 CPX #0
 BMI oxcl
 BNE oxcr
 CMP R_CL
 BCC oxcl
 CMP r_cr1
 BCC oxc9
.oxcr
 LDA r_cr1
 RTS
.oxcl
 LDA R_CL
.oxc9
 RTS

\ oo_val: A = chain X's x at the middle row: its edge's DDA value there,
\ x0 + ceil(dx * k / dy) with k = oym - y0 (r_e8's, r7_esgen's); for a
\ 16-bit polygon by r7_esgen, clamped

.oo_val
 STX ofch
 LDA ow,X
 STA oi0
 JSR fnxt
 TAX                    \ X = i1, Y = i0
 LDY oi0
 BIT op16
 BPL P%+5
 JMP oov16
 LDA oym                \ k = oym - y0: 0, x0
 SEC
 SBC R_PYL,Y
 BNE oovk
.oov0
 LDA R_PXL,Y
 RTS
.oovk
 STA ok
 LDA R_PYL,X            \ dy
 SEC
 SBC R_PYL,Y
 STA odv
 LDA R_PXL,X            \ |dx| (odx bit 7: dx < 0)
 SEC
 SBC R_PXL,Y
 STZ odx
 BCS oov1
 DEC odx
 EOR #&FF
 INC A
.oov1
 STA ftmp
 CLC                    \ |dx| * k = QS(|dx| + k) - QS(||dx| - k|)
 ADC ok
 TAX
 BCS oov2
 LDA QSL,X
 STA opl
 LDA QSH,X
 BCC oov3
.oov2
 LDA QSL+256,X
 STA opl
 LDA QSH+256,X
.oov3
 STA oph
 LDA ftmp
 SEC
 SBC ok
 BCS P%+6
 EOR #&FF
 ADC #1
 TAX
 LDA opl
 SEC
 SBC QSL,X
 STA opl
 LDA oph
 SBC QSH,X
 LDX #8                 \ / dy: opl = the quotient, A = the remainder
.oov4
 ASL opl
 ROL A
 BCS oov5
 CMP odv
 BCC oov6
.oov5
 SBC odv
 INC opl
.oov6
 DEX
 BNE oov4
 BIT odx
 BMI oov7
 CMP #1                 \ dx >= 0: x0 + q + (r > 0)
 LDA R_PXL,Y
 ADC opl
 RTS
.oov7
 LDA R_PXL,Y            \ dx < 0: x0 - q
 SEC
 SBC opl
 RTS
.oov16
 LDA oym
 STA RZ_Y
 STZ r7_side4
 JSR r7_esgen
 LDA RZ_SA              \ (clamped into CL..CR+1)
 LDX RZ_SA+1
 JMP oclamp

\ ------------------------------------------------------------------------------
\ fadv: chain A's next edge with rows (from row frow); C = 1 if it has none
\ ------------------------------------------------------------------------------

.fadv
 STA ofch
 LSR A                  \ fside bit 7: side 1
 ROR A
 STA fside
 BIT fgen
 BMI oo_win

\ oo_seq: a monotone chain: its next edge with rows (they follow on)

.oo_seq
 LDX ofch
 LDY fcur,X
 LDA R_PYL,Y            \ at the lowest y: none
 CMP oymL
 BNE oqs1
 LDA R_PYH,Y
 CMP oymH
 BEQ oqs9
.oqs1
 DEC fcc,X
 BMI oqs9
 STY r_i0
 TYA
 JSR fnxt
 LDX ofch
 STA fcur,X
 STA r_i1
 JSR fedge
 BCS oo_seq
 RTS
.oqs9
 SEC
 RTS

\ oo_win: a chain that is not monotone: at row frow, the edge that covers it
\ last in the walk (phase A's tables hold that one's x), until the row where
\ it ends or a later edge in the walk starts

.oo_win
 LDA frow
 STA oyr
 LDX ofch
 JSR owalk
 TXA
 BMI oqs9               \ (none: the chain ends)
 STX r_i0
 LDA owj
 STA r_i1
 LDA r_ystart           \ its rows frow .. fev - 1
 STA fsv
 LDA r_yend
 STA fsv+1
 LDA frow
 STA r_ystart
 LDA fev
 STA r_yend
 JSR fedge
 LDA fsv
 STA r_ystart
 LDA fsv+1
 STA r_yend
 RTS

\ fedge: edge r_i0 -> r_i1 into side fside's DDA, rows max(y0, r_ystart) ..
\ min(y1, r_yend) - 1; C = 1 if it has none

.fedge
 BIT op16
 BPL P%+5
 JMP oe16
 LDX r_i1
 JSR r_e8               \ (its DDA entries, fz and fsh, return from fedge
 SEC                    \ with C = 0)
 RTS

\ o16adv: side X's 16-bit DDA to the next row (t -= b; a borrow: t += dy and
\ x += a + 1, else x += a)

.o16adv
 SEC
 LDA o16tl,X
 SBC o16bl,X
 STA o16tl,X
 LDA o16th,X
 SBC o16bh,X
 STA o16th,X
 BCS o16a1
 LDA o16tl,X            \ (C = 0)
 ADC o16dl,X
 STA o16tl,X
 LDA o16th,X
 ADC o16dh,X
 STA o16th,X            \ (C = 1)
 BRA o16a2
.o16a1
 CLC
.o16a2
 LDA o16sl,X
 ADC o16al,X
 STA o16sl,X
 LDA o16sh,X
 ADC o16ah,X
 STA o16sh,X
 RTS

\ fz, fsh: r_e8's edge, diverted at its DDA entry (gfx-raster_polyb.asm under
\ OPTUBE): start row RZ_T3, end row RZ_T2 (exclusive), x RZ_T0, A = a; fsh
\ also X = b, error RZ_TA, dy RZ_T1 (fz: b = 0, x moves by a every row).
\ They load side fside's DDA and return from fedge with C = 0

.fz
 STZ RZ_TA
 LDX #0
.fsh
 JSR fload
 LDX ofch
 LDA RZ_T2
 STA fe,X
 PLA                    \ (r_e8's return into fedge)
 PLA
 CLC
 RTS

\ fload: side fside's 8-bit DDA: x RZ_T0, error RZ_TA, dy RZ_T1, A = a,
\ X = b; the side's step back to the inline 8-bit one

.fload
 BIT fside
 BMI fld1
 STA fa0+1              \ a (+1 with the borrow's carry)
 STA fn0+1              \ a
 STX fb0+1              \ b
 LDA RZ_T1
 STA fd0+1              \ dy
 LDA RZ_T0
 STA f_x0
 LDA RZ_TA
 STA f_t0
 LDA #&A5               \ (s0: LDA f_t0 : SEC)
 STA s0
 LDA #f_t0
 STA s0+1
 LDA #&38
 STA s0+2
 RTS
.fld1
 STA fa1+1
 STA fn1+1
 STX fb1+1
 LDA RZ_T1
 STA fd1+1
 LDA RZ_T0
 STA f_x1
 LDA RZ_TA
 STA f_t1
 LDA #&A5               \ (s1: LDA f_t1 : SEC)
 STA s1
 LDA #f_t1
 STA s1+1
 LDA #&38
 STA s1+2
 RTS


\ ------------------------------------------------------------------------------
\ The row loop: Y = row
\ ------------------------------------------------------------------------------

.drow
.dl
 LDX f_x0               \ (patched: the left side's x)
.dc
 CPX f_x1               \ (patched: the right side's x)
 BEQ dempty
.dcb
 BCS dswap              \ (patched: decided, to dempty: the sides the other way)
.ck
 BRA dnc                \ (patched: dcl when clipping in x; dund undecided)
.dnc
.dr
 LDA f_x1               \ (patched with dc)
 JSR p_emit             \ Y = row, X = xl, A = xr + 1 (p-emit.asm)
.dempty
.s0
 LDA f_t0               \ side 0: t -= b; borrow: t += dy, x += a + 1
 SEC                    \ (patched: JMP o16s0 while it is 16-bit)
.fb0
 SBC #0
 BCS n0
.fd0
 ADC #0
 STA f_t0
 LDA f_x0
.fa0
 ADC #0                 \ (C = 1)
 STA f_x0
 BRA ost1
.n0
 STA f_t0
 LDA f_x0
 CLC
.fn0
 ADC #0
 STA f_x0
.ost1
.s1
 LDA f_t1               \ side 1, the same
 SEC                    \ (patched: JMP o16s1)
.fb1
 SBC #0
 BCS n1
.fd1
 ADC #0
 STA f_t1
 LDA f_x1
.fa1
 ADC #0
 STA f_x1
 BRA ost2
.n1
 STA f_t1
 LDA f_x1
 CLC
.fn1
 ADC #0
 STA f_x1
.ost2
 INY
 CPY fseg
 BCC drow
 JMP fnext
.dswap                  \ undecided, and the right side is the left: swap them,
 LDA dl+1               \ decided from here; redo the row
 LDX dc+1
 STA dc+1
 STA dr+1
 STA dr2+1
 STX dl+1
 LDA #dempty-(dcb+2)
 STA dcb+1
 JMP drow
.dund                   \ undecided, and this row has pixels: decided from here
 LDA #dempty-(dcb+2)
 STA dcb+1
 LDA ock
 STA ck+1
 JMP ck
.dcl                    \ clipping in x: X = xl
 CPX R_CL
 BCS cl1
 LDX R_CL
.cl1
.dr2
 LDA f_x1               \ (patched with dc)
 CMP r_cr1
 BCC cl2
 LDA r_cr1
.cl2
 STA ftmp
 CPX ftmp
 BCS dempty
 JSR p_emit
 JMP dempty

\ fnext: Y = fseg: the polygon's end, or a side's next edge

.fnext
 CPY r_yend
 BCS fnx0
 STY frow
 CPY fe
 BNE fnn1
 LDA #0
 JSR fadv
 BCS fnx0
.fnn1
 LDA fe+1
 CMP frow
 BNE fnn2
 LDA #1
 JSR fadv
 BCS fnx0
.fnn2
 LDA fe                 \ fseg = the nearer of the two sides' end rows
 CMP fe+1
 BCC P%+5
 LDA fe+1
 STA fseg
 LDY frow
 JMP drow
.fnx0
 RTS

ASSERT fb1 - fb0 = s1 - s0 AND fd1 - fd0 = s1 - s0 AND fa1 - fa0 = s1 - s0 AND fn1 - fn0 = s1 - s0
ASSERT f_t0 = f_x0 + 1 AND f_t1 = f_x1 + 1
