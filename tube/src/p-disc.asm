\ ******************************************************************************
\
\ p-disc.asm - the parasite's incremental discs (overlay S, with p-rast.asm):
\ the disc heap, the planet's surface detail drawn as changes, and the second
\ disc drawn as changes. Every disc is incremental: each buffer remembers what
\ it shows of each disc row, and a frame sends the host only what changed.
\
\ The disc heap (HEAP, HEAPN bytes in overlay S's state) holds the
\ per-row state that only some rows need, by body:
\
\   * body 0, the surface (HB_S): for the disc layer when it has two colours
\     (a beach ball, craters, bands), per row one byte for both buffers, a
\     nibble each (buffer 0's the low one) holding n = 2 * the boundary
\     count + the colour at the span's left end (R_NDN rotated left), 0-5,
\     or 15 for unknown (a row with three or more), and per buffer and row
\     the first two boundaries;
\
\   * body 1, the second disc (HB_D): per buffer and row its span, left and
\     right (empty: 255, 0).
\
\ A body has a capacity of cap rows and a window of rows wt .. wt + cap - 1
\ (one for both buffers), and holds an array of cap bytes per item and
\ buffer, at hb_base + (buffer * items + item) * cap; row y is entry y - wt,
\ read through a pointer to the array less wt, (p),Y with Y the row. The
\ surface's arrays are at the heap's start, the second disc's at its end, so
\ each grows into the room between them. Before a body's rows are read, its
\ window must hold every row either buffer holds of it and the frame's new
\ rows (hp_fit): it slides when they fit its capacity (the entries moved,
\ hp_move), and grows (the arrays moved apart) when they do not, by half as
\ much again (16 rows at least, the screen's 192 at most), into the room the
\ other body leaves. Only if that is not enough are both bodies' states
\ dropped and the heap partitioned again (hp_drops counts it): the
\ surface's rows become unknown (each buffer repaints them whole once), and
\ the second disc's old pixels are repaired (its box marked dirty in each
\ buffer, the current one's blacked now when the second disc itself is
\ drawn). A body that cannot hold its rows even alone is drawn whole each
\ frame, without state (hp_whole counts those frames). The moon, the sun and
\ the planet are never all large at once, so the heap is sized for one large
\ body and a smaller one (the surface's 192 rows and a second disc of
\ HD_ROWS), not for all of them full-screen.
\
\ ******************************************************************************

\ (HB_S, HB_D and HEAPN: p-rast.asm, with the state; the scratch: p-ws.asm)

\ (its zero page: p-ws.asm)

\ ------------------------------------------------------------------------------
\ hp_ptr: body hq_k's pointers for buffer r_buf: each array less the window's
\ top, so that (p),Y with Y = the row reads it. The surface: hp_n (its
\ shared array: per row, buffer 0's count and colour in the low nibble,
\ buffer 1's in the high), hp_0 and hp_1 (the buffer's boundaries); the
\ second disc: hd_l and hd_r (the buffer's span). A body's arrays: its shared
\ ones (hb_sh), then two for buffer 0, then two for buffer 1, cap apart
\ ------------------------------------------------------------------------------

.hp_ptr
 LDX hq_k
 LDA hb_base,X          \ base less the window's top
 SEC
 SBC hb_wt,X
 STA hq_s
 LDA hb_baseh,X
 SBC #0
 STA hq_s+1
 LDA hq_s               \ (the surface's shared array: hp_n)
 STA hp_n
 LDA hq_s+1
 STA hp_n+1
 LDA r_buf              \ the buffer's first array: shared + 2 * buffer
 ASL A
 ADC hb_sh,X
 BEQ hpp2
 TAY
.hpp1
 JSR hp_addc            \ (+ cap)
 DEY
 BNE hpp1
.hpp2
 LDY hb_zp,X            \ its two pointers, cap apart
 JSR hpp3
.hpp3
 LDA hq_s
 STA &00,Y
 LDA hq_s+1
 STA &01,Y
 INY
 INY
.hp_addc                \ hq_s += body X's capacity (keeps X, Y)
 CLC
 LDA hq_s
 ADC hb_cap,X
 STA hq_s
 BCC P%+4
 INC hq_s+1
 RTS

.hb_sh   EQUB 1, 0      \ per body: its shared arrays, the place of its two
.hb_zp   EQUB hp_0, hd_l   \ pointers a buffer, and its bytes a row (both buffers)
.hb_rb   EQUB 5, 4

\ ------------------------------------------------------------------------------
\ hp_fit: body hq_k's window to hold rows hq_lo .. hq_hi: C clear, and its
\ pointers set for this buffer (hp_ptr); or C set, no room (the body holds
\ nothing then)
\ ------------------------------------------------------------------------------

.hp_fit
 LDX hq_k
 LDA hq_hi
 SEC
 SBC hq_lo
 INC A
 STA hq_n               \ the rows, 1 .. 192
 LDA hb_cap,X
 CMP hq_n
 BCC hf_grow            \ more than its capacity
 STA hq_c
 LDA hq_n               \ a capacity over 2n + 32: shrunk to fit again (as
 CMP #112               \ it grows), leaving the room to the other body
 BCS hfk1
 ASL A
 ADC #32
 CMP hq_c
 BCC hf_grow
.hfk1
 LDA hq_lo              \ inside the window?
 CMP hb_wt,X
 BCC hf_slide
 LDA hb_wt,X
 CLC
 ADC hb_cap,X
 CMP hq_hi
 BEQ hf_slide
 BCC hf_slide
.hf_ok
 JSR hp_ptr
 CLC
 RTS
.hf_slide               \ the same capacity and base, a new window
 LDA hb_base,X
 STA hq_b
 LDA hb_baseh,X
 STA hq_b+1
 JSR hf_top
 JSR hp_move
 BRA hf_ok

.hf_grow                \ a capacity of n + max(16, n / 2), at most 192 ...
                        \ (or, from above, the same smaller)
 LDA hq_n
 LSR A
 CMP #16
 BCS P%+4
 LDA #16
 CLC
 ADC hq_n
 BCS hfg1
 CMP #193
 BCC P%+4
.hfg1
 LDA #192
 STA hq_c
 JSR hf_room            \ ... at most the room the other body leaves
 BCC hfg3
 LDA hq_t               \ (that much not, but n: then all the room)
 CMP hq_n
 BCC hfg2
 STA hq_c
 BRA hfg3
.hfg2
 JSR hp_drop            \ not even n: both bodies dropped, all the heap
 LDX hq_k
 JSR hf_room
 BCC hfg3
 LDA hq_t
 CMP hq_n
 BCC hfg9               \ (not even alone: no room)
 STA hq_c
.hfg3
 LDX hq_k               \ the new base: the surface at the heap's start, the
 LDA #LO(HEAP)          \ second disc at its end
 STA hq_b
 LDA #HI(HEAP)
 STA hq_b+1
 CPX #HB_D
 BNE hfg4
 JSR hf_size            \ (HEAP + HEAPN - its size)
 SEC
 LDA #LO(HEAP + HEAPN)
 SBC hq_s
 STA hq_b
 LDA #HI(HEAP + HEAPN)
 SBC hq_s+1
 STA hq_b+1
.hfg4
 JSR hf_top
 JSR hp_move
 JMP hf_ok
.hfg9
 LDX hq_k               \ no room: the body holds nothing
 STZ hb_cap,X
 SEC
 RTS

\ hf_top: hq_w = the window's top for capacity hq_c holding hq_lo .. hq_hi:
\ lo - (c - n) / 2, within 0 .. 192 - c (keeps X)

.hf_top
 LDA hq_c
 SEC
 SBC hq_n
 LSR A
 STA hq_w
 LDA hq_lo
 SEC
 SBC hq_w
 BCS P%+4
 LDA #0
 STA hq_w
 LDA #192
 SEC
 SBC hq_c
 CMP hq_w
 BCS P%+4
 STA hq_w
 RTS

\ hf_size: hq_s = the size of body X with capacity hq_c (hb_rb bytes a row)

.hf_size
 LDA hq_c               \ 4c
 STA hq_s
 STZ hq_s+1
 ASL hq_s
 ROL hq_s+1
 ASL hq_s
 ROL hq_s+1
 LDA hb_rb,X            \ (5c: + c)
 CMP #5
 BNE hfs1
 CLC
 LDA hq_s
 ADC hq_c
 STA hq_s
 BCC hfs1
 INC hq_s+1
.hfs1
 RTS

\ hf_room: does body X with capacity hq_c fit beside the other? C clear if
\ so; else C set and hq_t = the most rows it could have (keeps X)

.hf_room
 TXA                    \ the room: HEAPN less the other body's size
 EOR #1
 TAY
 LDA hb_cap,Y
 STA hq_i
 PHX
 TYA
 TAX
 LDA hq_c
 PHA
 LDA hq_i
 STA hq_c
 JSR hf_size
 PLA
 STA hq_c
 PLX
 SEC
 LDA #LO(HEAPN)
 SBC hq_s
 STA hq_d
 LDA #HI(HEAPN)
 SBC hq_s+1
 STA hq_d+1
 JSR hf_size            \ this body's size, against it
 LDA hq_d
 CMP hq_s
 LDA hq_d+1
 SBC hq_s+1
 BCC hfr1
 CLC
 RTS
.hfr1
 LDA #0                 \ the most rows: room DIV (2 * items), by subtraction
 STA hq_t
.hfr2
 LDA hq_t
 CMP #192
 BCS hfr4
 LDA hb_rb,X            \ (bytes a row)
 STA hq_i
 LDA hq_d
 SEC
 SBC hq_i
 TAY
 LDA hq_d+1
 SBC #0
 BCC hfr4
 STA hq_d+1
 STY hq_d
 INC hq_t
 BRA hfr2
.hfr4
 SEC
 RTS

\ ------------------------------------------------------------------------------
\ hp_move: body X to capacity hq_c, window hq_w, base hq_b, its entries kept
\ where the old window and the new one share rows, the rest empty (the
\ surface: unknown; the second disc: no span). Arrays and rows in an order
\ that never reads what has been written (the surface grows upwards from the
\ heap's start and shrinks downwards, the second disc the other way from its
\ end: arrays last to first when they move up)
\ ------------------------------------------------------------------------------

.hp_move
 ASSERT HB_S = 0 AND HB_D = 1
 STX hq_k
 LDA hb_rb,X
 STA hq_n               \ arrays, both buffers
 LDA hb_cap,X           \ the old capacity (0: nothing to keep)
 STA hq_t
 LDA hq_c               \ up (hp_dir 1): the surface growing, the second disc
 CMP hq_t               \ shrinking (HB_S 0, HB_D 1: X + grown is 1)
 TXA
 ADC #0
 AND #1
 STA hp_dir
 BEQ hpm2               \ (down: arrays first to last)
 LDA hq_n               \ (up: last to first)
 DEC A
.hpm2
 STA hq_i               \ the array
.hpm3
 JSR hpm_ptrs           \ hq_s, hq_d: its old and new entries, row-indexed
 LDA hq_d               \ upwards (the destination above the source): rows
 CMP hq_s               \ last to first, else first to last
 LDA hq_d+1
 SBC hq_s+1
 BCC hpm6
 LDA hq_w
 CLC
 ADC hq_c
 TAY
.hpm4
 DEY
 JSR hpm_one
 CPY hq_w
 BNE hpm4
 BRA hpm7
.hpm6
 LDY hq_w
.hpm5
 JSR hpm_one
 INY
 TYA
 SEC
 SBC hq_w
 CMP hq_c
 BCC hpm5
.hpm7
 LDX hq_k
 LDA hp_dir
 BNE hpm8
 INC hq_i
 LDA hq_i
 CMP hq_n
 BCC hpm3
 BRA hpm9
.hpm8
 DEC hq_i
 BPL hpm3
.hpm9
 LDX hq_k
 LDA hq_c
 STA hb_cap,X
 LDA hq_w
 STA hb_wt,X
 LDA hq_b
 STA hb_base,X
 LDA hq_b+1
 STA hb_baseh,X
 RTS

\ hpm_one: row Y: its entry kept if the old window held it, else empty

.hpm_one
 LDX hq_k
 LDA hq_t               \ (no old capacity)
 BEQ hpo1
 TYA
 SEC
 SBC hb_wt,X
 BCC hpo1
 CMP hq_t
 BCS hpo1
 LDA (hq_s),Y
 STA (hq_d),Y
 RTS
.hpo1
 LDA hq_i               \ empty: by the array
 CPX #HB_S
 BEQ hpo2
 AND #1
 BNE hpo3               \ (the second disc's right ends: 0)
 LDA #255               \ (its left ends: 255)
 BRA hpo4
.hpo2
 CMP #0                 \ (the surface: unknown in both nibbles)
 BNE hpo3
 LDA #&FF
 BRA hpo4
.hpo3
 LDA #0
.hpo4
 STA (hq_d),Y
 RTS

\ hpm_ptrs: array hq_i's old entries (hq_s: base + i * cap - wt) and new
\ ones (hq_d: the new base + i * the new capacity - the new top)

.hpm_ptrs
 LDX hq_k
 LDA hb_base,X
 STA hq_s
 LDA hb_baseh,X
 STA hq_s+1
 LDA hq_b
 STA hq_d
 LDA hq_b+1
 STA hq_d+1
 LDY hq_i
 BEQ hmp2
.hmp1
 CLC
 LDA hq_s
 ADC hq_t
 STA hq_s
 BCC P%+4
 INC hq_s+1
 CLC
 LDA hq_d
 ADC hq_c
 STA hq_d
 BCC P%+4
 INC hq_d+1
 DEY
 BNE hmp1
.hmp2
 SEC
 LDA hq_s
 SBC hb_wt,X
 STA hq_s
 BCS P%+4
 DEC hq_s+1
 SEC
 LDA hq_d
 SBC hq_w
 STA hq_d
 BCS P%+4
 DEC hq_d+1
 RTS

\ (hp_drop: p-disc0.asm, resident)

\ hd_box: buffer X's second disc forgotten, its box (rows R_S2T .. R_S2B,
\ x hd_xl .. hd_xr) added to the buffer's dirty extents (keeps X)

.hd_box
 LDA R_S2T,X
 CMP R_S2B,X
 BEQ hdb1
 BCS hdb9
.hdb1
 LDA rsb_dl,X           \ the buffer's dirty arrays
 STA hq_s+1
 LDA rsb_dr,X
 STA hq_d+1
 LDA #LO(R_DIRTYL0)
 STA hq_s
 LDA #LO(R_DIRTYR0)
 STA hq_d
 LDY R_S2T,X
.hdb2
 LDA hd_xl,X
 CMP (hq_s),Y
 BCS P%+4
 STA (hq_s),Y
 LDA hd_xr,X
 CMP (hq_d),Y
 BCC P%+4
 STA (hq_d),Y
 TYA
 CMP R_S2B,X
 INY
 BCC hdb2
 LDA R_S2T,X            \ the buffer's dirty rows
 CMP r_dyt,X
 BCS P%+5
 STA r_dyt,X
 LDA R_S2B,X
 CMP r_dyb,X
 BCC P%+5
 STA r_dyb,X
.hdb9
 LDA #255
 STA R_S2T,X
 STZ R_S2B,X
 STZ R_S2C,X
 RTS

\ ------------------------------------------------------------------------------
\ ps_fit: (R_DISCROWS, before its rows) the surface for this buffer's
\ two-colour frame (pr_h set): its window to hold the band (r_bt .. r_bb)
\ and the other buffer's rows if it shows two colours; ps_ok set if it has
\ room (else every row is repainted whole and nothing is kept: hp_whole).
\ This buffer's rows from a one-colour frame have no boundaries, in colour A
\ (count 0). With neither buffer two-colour after this frame, the surface
\ gives up its room
\ ------------------------------------------------------------------------------

.ps_fit
 STZ ps_ok
 LDA r_bb
 CMP r_bt
 BCC psf8               \ (no rows)
 STA hq_hi
 LDA r_bt
 STA hq_lo
 LDA r_buf
 EOR #1
 TAX
 LDA r_bmode,X          \ the other buffer's rows, if two-colour
 BEQ psf1
 LDA r_dsb,X
 CMP r_dst,X
 BCC psf1
 CMP hq_hi
 BCC P%+4
 STA hq_hi
 LDA r_dst,X
 CMP hq_lo
 BCS P%+4
 STA hq_lo
.psf1
 LDA #HB_S
 STA hq_k
 JSR hp_fit
 BCS psf9
 DEC ps_ok
 LDA #&0F               \ (this buffer's nibble of the surface's shared array
 LDY #LO(ps_tk0)        \ and its table: ps_rows)
 LDX r_buf
 BEQ P%+6
 LDA #&F0
 LDY #LO(ps_tk1)
 STA ps_msk
 STA psm_a+1
 STA psm_b+1
 STY pst_a+1
 STY pst_b+1
 LDA r_bmode,X          \ one-colour last time: its rows count 0, colour A
 BNE psf8
 LDY r_bt
.psf2
 LDA ps_msk             \ (this buffer's nibble 0)
 EOR #&FF
 AND (hp_n),Y
 STA (hp_n),Y
 CPY r_bb
 INY
 BCC psf2
.psf8
 RTS
.psf9
 INC hp_whole           \ (no room: repainted whole, nothing kept)
 BNE P%+5
 INC hp_whole+1
 RTS

.ps_end                 \ (R_DISCROWS' end) neither buffer two-colour now:
 LDA r_bmode            \ the surface's room given up
 ORA r_bmode+1
 BNE P%+5
 STZ hb_cap+HB_S
 RTS

\ ------------------------------------------------------------------------------
\ ps_rows: R_DISCROWS' band (rows r_bt .. r_bb, r_bt <= r_bb) for a
\ two-colour frame, this one or this buffer's last (pr_h set). A row's new
\ span is R_NDISCL/R on the new rows (f_discspans has clamped them to the
\ window: empty 255, 0), else empty; its count and colour R_NDN's (a
\ one-colour frame's: none, colour A). The surface keeps them for this
\ buffer as n = 2 count + colour (R_NDN rotated left), 0-5, in its nibble of
\ the shared byte (15: unknown, three or more), with the first two
\ boundaries. A row not written over (no dirty) is drawn as changes:
\
\   * nothing if its span, n and boundaries are the same (a few compares);
\   * with the same n (the same count, two at most, and colour) and both
\     spans there, each edge's strip, old .. new, in the colour on the side
\     it moved from, cut short where a neighbour's new place has passed into
\     it, as the Master port's (ps_strips);
\   * else, if the new span holds the old (or there is no old), the new span
\     segment by segment;
\
\ else (and a dirty row) the old span and the dirty extent black less the
\ new span, then the new span segment by segment (ps_gen). Then the row's
\ new state. With no room for the surface (ps_ok 0) every row is drawn so
\ and nothing is kept. Y = r_bt
\ ------------------------------------------------------------------------------

.ps_rows
 JSR ps_nd0             \ (a one-colour frame: its new rows' counts none)
 LDA #255               \ (the rows written: none yet)
 STA pe_wt
 STZ pe_wb
 LDA ps_ok
 BNE psw3
 JSR ps_whole           \ (no room: p-disc0.asm)
 BRA psw9
.psw3
 LDA r_nb               \ the rows above the new ones, the new ones (none:
 CMP r_nt               \ the band's rows all outside them), the rows below
 BCC psw8
 STA psi_e+1            \ (the new rows' loop ends at r_nb)
 LDA r_nt
 STA ps_e
 JSR ps_outs
 JSR psi
.psw8
 LDA r_bb
 INC A
 STA ps_e
 JSR ps_outs
.psw9
 LDA pe_wt              \ R_WL/R_WR's rows: r_wt .. r_wb
 CMP r_wt
 BCS P%+5
 STA r_wt
 LDA pe_wb
 CMP r_wb
 BCC P%+5
 STA r_wb
 RTS

\ ps_outs: rows Y .. ps_e - 1, outside the new rows (the new span empty):
\ only those with an old span or a dirty extent change (ps_gen)

.ps_outs
 CPY ps_e
 BCS pso9
.pso1
 LDA (pr_dr),Y
 BNE pso2
 LDA (pr_sl),Y
 CMP #255
 BEQ pso3
.pso2
 JSR ps_spo
 JSR ps_gen
 JSR ps_fin0
.pso3
 INY
 CPY ps_e
 BCC pso1
.pso9
 RTS

\ psi: the new rows, Y = r_nt .. r_nb (psi_e)

.psi
 LDA (pr_dr),Y          \ dirty: repainted
 BNE psi_d
 LDA R_NDN,Y            \ the same count and colour? (n: three or more, 6 and
 ASL A                  \ above, never)
 ADC #0
 CMP #6
 BCS psi_k
 TAX
.pst_a
 LDA ps_tk0,X           \ (patched: this buffer's n in its nibble)
 EOR (hp_n),Y
.psm_a
 AND #&0F               \ (patched: this buffer's nibble)
 BNE psi_k
 LDA R_NDISCL,Y         \ the same span?
 CMP (pr_sl),Y
 BNE psi_s
 LDA R_NDISCR,Y
 CMP (pr_sr),Y
 BNE psi_s
 CPX #2                 \ the same boundaries?
 BCC psi_n
 LDA R_NDX0,Y
 CMP (hp_0),Y
 BNE psi_b
 CPX #4
 BCC psi_n
 LDA R_NDX1,Y
 CMP (hp_1),Y
 BNE psi_b
.psi_n
.psi_e
 CPY #0                 \ (patched: r_nb)
 INY
 BCC psi
 RTS

.psi_d                  \ dirty
 JSR ps_spin
 BRA psi_g
.psi_b                  \ the same span and n: the boundaries moved
 JSR ps_spin
 JSR ps_strips
.psi_x                  \ (the same n: only the boundaries and span kept)
 JSR ps_bnd
 JMP psi_n
.psi_k                  \ another count or colour
 JSR ps_spin
 BRA psi_f
.psi_s                  \ the same n, another span: its edges' strips, if
 JSR ps_spin            \ both spans are there
 LDA (pr_sl),Y
 CMP #255
 BEQ psi_sg
 LDA pr_f
 CMP pr_e
 BCC psi_g
 JSR ps_strips
 BRA psi_x
.psi_f                  \ the new span holds the old (or there is no old)?
 LDA (pr_sl),Y          \ segment by segment
 CMP #255
 BEQ psi_sg
 CMP pr_e
 BCC psi_g
 LDA pr_f
 CMP (pr_sr),Y
 BCS psi_sg
.psi_g
 JSR ps_gen
 BRA psi_w
.psi_sg
 JSR ps_sg
.psi_w
 JSR ps_fin
 JMP psi_n

\ ps_spin: row Y's new span from R_NDISCL/R (pr_e, pr_f), pr_y, no writes
\ yet (pr_wl, pr_wr); ps_spo: an empty span. Keep X, Y

.ps_spo
 LDA #255
 STA pr_e
 STZ pr_f
 BRA psn2
.ps_spin
 LDA R_NDISCL,Y
 STA pr_e
 LDA R_NDISCR,Y
 STA pr_f
.psn2
 STY pr_y
 LDA #&FF
 STA pr_wl
 STZ pr_wr
 RTS

\ ps_gen: row Y: the old span and the dirty extent black less the new span,
\ then the new span segment by segment (ps_sg); no dirty extent now. Keeps
\ Y

.ps_gen
 STZ pr_ce
 STZ pr_co
 LDA pr_e
 STA pr_col
 LDA pr_f
 STA pr_d
 LDA (pr_sl),Y
 STA pr_a
 LDA (pr_sr),Y
 STA pr_b
 CMP pr_a
 BCC psg1
 JSR pdiff
.psg1
 LDA (pr_dl),Y
 STA pr_a
 LDA (pr_dr),Y
 STA pr_b
 LDA #&FF
 STA (pr_dl),Y
 LDA #0
 STA (pr_dr),Y
 LDA pr_b
 CMP pr_a
 BCC ps_sg
 JSR pdiff
.ps_sg                  \ the new span, if any, segment by segment
 LDA pr_f
 CMP pr_e
 BCS ps_seg
 RTS

\ ps_fin: row Y's new state: the surface's n (6 and above: unknown), its
\ first two boundaries (ps_bnd: X = n), then (ps_fin0) the span and R_WL/R_WR
\ (the rows written: pe_wt .. pe_wb, rows in order). Keeps Y

.ps_fin
 LDA R_NDN,Y
 ASL A
 ADC #0
 CMP #6
 BCC P%+4
 LDA #6
 TAX
.pst_b
 LDA ps_tk0,X           \ (patched as pst_a)
 EOR (hp_n),Y
.psm_b
 AND #&0F               \ (patched as psm_a)
 EOR (hp_n),Y
 STA (hp_n),Y
.ps_bnd
 CPX #2
 BCC ps_fin0
 LDA R_NDX0,Y
 STA (hp_0),Y
 CPX #4
 BCC ps_fin0
 LDA R_NDX1,Y
 STA (hp_1),Y
.ps_fin0
 LDA pr_e
 STA (pr_sl),Y
 LDA pr_f
 STA (pr_sr),Y
 LDA pr_wr              \ R_WL/R_WR: what was written
 BEQ psfw9
 STA R_WR,Y
 LDA pr_wl
 STA R_WL,Y
 CPY pe_wt
 BCS P%+4
 STY pe_wt
 STY pe_wb
.psfw9
 RTS

\ (ps_tk0, ps_tk1: p-rast.asm, after the state)

\ ps_seg: the new span pr_e .. pr_f of row Y segment by segment: colour R_NDN's
\ (bit 7: B) at its left end, flipped at each boundary (R_NDX0-3, R_NDN's
\ count, at most 4; each inside the span, after its left end, as the circle
\ engine's pr_put places them). Keeps Y

.ps_seg
 LDA R_NDN,Y
 ASL A
 TAX                    \ (X = 2 count)
 LDA #0
 ROL A
 STA pr_col
 LDA pr_e
 STA pr_a               \ the segment's start
 CPX #2
 BCC pss5
 LDA R_NDX0,Y
 JSR pss1
 CPX #4
 BCC pss5
 LDA R_NDX1,Y
 JSR pss1
 CPX #6
 BCC pss5
 LDA R_NDX2,Y
 JSR pss1
 CPX #8
 BCC pss5
 LDA R_NDX3,Y
 JSR pss1
.pss5
 LDA pr_f
 STA pr_b
.ps_put                 \ pr_a .. pr_b in colour pr_col: 0 A, 1 B (keeps X, Y)
 LDA pr_col
 BNE psp1
 LDA R_DCE
 STA pr_ce
 LDA R_DCO
 STA pr_co
 JMP pspan
.psp1
 LDA R_DBE
 STA pr_ce
 LDA R_DBO
 STA pr_co
 JMP pspan

.pss1                   \ (a boundary at A: the segment before it, if not
 CMP pr_a               \ empty; then the other colour. Keeps X, Y)
 BEQ pss2
 PHA
 DEC A
 STA pr_b
 JSR ps_put
 PLA
 STA pr_a
.pss2
 LDA pr_col
 EOR #1
 STA pr_col
 RTS

\ ps_strips: row Y, its old and new spans there, not dirty, the same count
\ (two at most) and colour (X = n): its edges (the span's left end, the
\ boundaries, the end after its right end), old and new, each edge's strip
\ old .. new written in the colour on the side it moved from, cut short
\ where the edge before's new place (moving right) or the edge after's
\ (moving left) has passed into it, as the Master port's (raster_strips.asm):
\ exactly the pixels whose colour changed, as the old edges are in order
\ and so are the new (each boundary inside its span, after the left end),
\ in any order of the strips. Keeps X, Y

.ps_strips
 LDA (pr_sr),Y          \ the ends after the right ends, old and new
 INC A
 STA pe_or
 LDA pr_f
 INC A
 STA pe_nr
 STA pe_lo              \ the new edge after the left end ...
 TXA                    \ the left colour (0 A, 1 B)
 AND #1
 STA pe_lc
 LDA pr_e               \ ... and before the end after the right end
 CPX #2
 BCC pz1
 LDA R_NDX0,Y
 STA pe_lo
 CPX #4
 BCC pz1
 LDA R_NDX1,Y
.pz1
 STA pe_np
 LDA pr_e               \ the left end (right: black; left: the first
 CMP (pr_sl),Y          \ segment's colour, up to the next new edge)
 BEQ pse1
 BCC pse0
 DEC A
 STA pr_b
 LDA (pr_sl),Y
 STA pr_a
 JSR pe_blk
 BRA pse1
.pse0
 STA pr_a
 LDA (pr_sl),Y
 CMP pe_lo
 BCC pz2
 LDA pe_lo
.pz2
 CMP pr_a
 BEQ pse1
 DEC A
 STA pr_b
 LDA #0
 JSR pe_seg
.pse1
 CPX #2                 \ the first boundary (right: the first segment's,
 BCC pse5               \ from the left end's new place; left: the second's,
 LDA R_NDX0,Y           \ up to the next new edge)
 CMP (hp_0),Y
 BEQ pse3
 BCC pse2
 DEC A
 STA pr_b
 LDA (hp_0),Y
 CMP pr_e
 BCS pz3
 LDA pr_e
.pz3
 STA pr_a
 CMP R_NDX0,Y
 BCS pse3
 LDA #0
 JSR pe_seg
 BRA pse3
.pse2
 STA pr_a
 LDA (hp_0),Y
 CPX #4
 BCC pz4
 CMP R_NDX1,Y
 BCC pz4
 LDA R_NDX1,Y
.pz4
 CMP pe_nr
 BCC pz5
 LDA pe_nr
.pz5
 CMP pr_a
 BEQ pse3
 DEC A
 STA pr_b
 LDA #1
 JSR pe_seg
.pse3
 CPX #4                 \ the second (right: the second segment's, from the
 BCC pse5               \ first's new place; left: the third's)
 LDA R_NDX1,Y
 CMP (hp_1),Y
 BEQ pse5
 BCC pse4
 DEC A
 STA pr_b
 LDA (hp_1),Y
 CMP R_NDX0,Y
 BCS pz6
 LDA R_NDX0,Y
.pz6
 STA pr_a
 CMP R_NDX1,Y
 BCS pse5
 LDA #1
 JSR pe_seg
 BRA pse5
.pse4
 STA pr_a
 LDA (hp_1),Y
 CMP pe_nr
 BCC pz7
 LDA pe_nr
.pz7
 DEC A
 STA pr_b
 LDA #0
 JSR pe_seg
.pse5
 LDA pe_nr              \ the end after the right end (right: the last
 CMP pe_or              \ segment's colour, from the last edge's new place;
 BEQ pse7               \ left: black)
 BCC pse6
 DEC A
 STA pr_b
 LDA pe_or
 CMP pe_np
 BCS pz8
 LDA pe_np
.pz8
 STA pr_a
 CMP pe_nr
 BCS pse7
 TXA
 LSR A
 JSR pe_seg
 BRA pse7
.pse6
 STA pr_a
 LDA pe_or
 DEC A
 STA pr_b
 JSR pe_blk
.pse7
 RTS

\ pe_seg: pr_a .. pr_b in segment A's colour (the left colour flipped A
\ times); pe_blk: in black. Keep X, Y

.pe_seg
 EOR pe_lc
 AND #1
 STA pr_col
 JMP ps_put
.pe_blk
 STZ pr_ce
 STZ pr_co
 JMP pspan

\ ------------------------------------------------------------------------------
\ R_DISC2 (T_DISCROWS with C set: f_disc2): the second disc, the smaller of
\ the sun and the planet, behind the layer, after R_DISCROWS, for the
\ current buffer, as the Master port's (gfx-raster_disc2.asm): its new spans
\ in R_NDISCL/R on rows R_NDT .. R_NDB (none: 255, 0), and empty spans on
\ the buffer's old rows (R_S2T .. R_S2B) outside them (f_disc2 fills them);
\ its colour pair in R_COLE/R_COLO. Row y shows its span a..b less the
\ layer's span L..R (this buffer's R_DISCL/R as R_DISCROWS has just left
\ them; L 0 or 255: none, p-kept.asm). Each buffer remembers the spans it
\ drew (the heap, body 1), their rows (R_S2T .. R_S2B), its colour (R_S2C)
\ and its box's x (hd_xl, hd_xr: for a drop). On each row, with the old span
\ a0..b0 and the new a1..b1, R_WL..R_WR being all that this frame has
\ written over the old pieces (the repair, the layer):
\
\   * the same span, nothing written over it: nothing;
\   * the same span, written over: max(a, WL) .. min(b, WR) again;
\   * the spans overlap: the ends that shrank black, the ends that grew (and
\     what was written over) in the disc's colour;
\   * apart, one empty, or the colour changed (the sun and the planet
\     swapped): the old span black, then the new span whole.
\
\ Its writes are spans to the host (in R_DISCROWS' batch), added to R_WL/R_WR
\ (and r_wt .. r_wb), never to the dirty extents; in K mode a row is settled
\ first (pk_y)
\ ------------------------------------------------------------------------------

.pd2
 LDX r_buf
 STZ pd_fl              \ recoloured (or none before: a reset buffer)?
 LDA R_COLE
 CMP R_S2C,X
 BEQ pd2a
 DEC pd_fl
.pd2a
 LDA R_S2T,X            \ the rows: this buffer's old and the new (lo .. hi)
 STA pd_ot
 LDA R_S2B,X
 STA pd_ob
 LDA R_NDT
 CMP pd_ot
 BCC P%+5
 LDA pd_ot
 STA hq_lo
 STA pd_lo
 LDA R_NDB
 CMP pd_ob
 BCS P%+5
 LDA pd_ob
 STA hq_hi
 STA pd_hi
 CMP hq_lo
 BCS pd2b
 JMP pd_none            \ no rows, old or new
.pd2b
 TXA                    \ the heap: the other buffer's rows too
 EOR #1
 TAX
 LDA R_S2B,X
 CMP R_S2T,X
 BCC pd2c
 CMP hq_hi
 BCC P%+4
 STA hq_hi
 LDA R_S2T,X
 CMP hq_lo
 BCS P%+4
 STA hq_lo
.pd2c
 LDA #HB_D
 STA hq_k
 STZ hp_dfl
 JSR hp_fit
 PHP
 BIT hp_dfl             \ (dropped: this buffer's old pixels blacked, by its
 BPL pd2d               \ box, so none now, and the new rows whole)
 LDA #255
 STA pd_ot
 STZ pd_ob
 DEC pd_fl
.pd2d
 PLP
 BCC pd_inc
 INC hp_whole           \ no room even alone: the new whole and dirty,
 BNE P%+5               \ nothing kept
 INC hp_whole+1
 JMP pd_whole

.pd_inc                 \ rows lo .. hi
 LDA pd_lo
 CMP r_wt
 BCS P%+5
 STA r_wt
 LDA pd_hi
 CMP r_wb
 BCC P%+5
 STA r_wb
 LDA #255               \ the new box's x
 STA pd_xl
 STZ pd_xr
 LDY pd_lo
.pdl
 LDA #255               \ the new span (empty outside NDT .. NDB)
 STA pd_a1
 STZ pd_b1
 CPY R_NDT
 BCC pdl1
 CPY R_NDB
 BEQ P%+4
 BCS pdl1
 LDA R_NDISCR,Y
 STA pd_b1
 LDA R_NDISCL,Y
 STA pd_a1
 CMP pd_b1
 BEQ P%+4
 BCS pdl1
 CMP pd_xl
 BCS P%+5
 STA pd_xl
 LDA pd_b1
 CMP pd_xr
 BCC P%+5
 STA pd_xr
.pdl1
 LDA #255               \ the old span (empty outside ot .. ob, or recoloured
 STA pd_a0              \ from none: a reset buffer)
 STZ pd_b0
 CPY pd_ot
 BCC pdl2
 CPY pd_ob
 BEQ P%+4
 BCS pdl2
 LDA (hd_l),Y
 STA pd_a0
 LDA (hd_r),Y
 STA pd_b0
.pdl2
 LDA pd_a1              \ the new one remembered
 STA (hd_l),Y
 LDA pd_b1
 STA (hd_r),Y
 JSR pd_row
 CPY pd_hi
 INY
 BCC pdl
 LDX r_buf              \ held now: the new rows, colour and box
 LDA R_NDT
 STA R_S2T,X
 LDA R_NDB
 STA R_S2B,X
 LDA pd_xl
 STA hd_xl,X
 LDA pd_xr
 STA hd_xr,X
 LDA R_COLE
 STA R_S2C,X
 LDA R_NDB
 CMP R_NDT
 BCS pd_rel
.pd_none
 LDX r_buf              \ (none now: nothing held)
 LDA #255
 STA R_S2T,X
 STZ R_S2B,X
.pd_rel                 \ neither buffer holding it: its room given up
 LDA R_S2B
 CMP R_S2T
 BCS pd_r9
 LDA R_S2B+1
 CMP R_S2T+1
 BCS pd_r9
 STZ hb_cap+HB_D
.pd_r9
 RTS

\ pd_row: row Y, old span a0..b0, new a1..b1 (empty: L > R). Keeps Y

.pd_row
 LDA pd_a1              \ the same span?
 CMP pd_a0
 BNE pdr_ch
 LDA pd_b1
 CMP pd_b0
 BNE pdr_ch
 BIT pd_fl
 BMI pdr_ch
 LDA R_WR,Y             \ written over this frame? (then max(a, WL) ..
 BNE pdr_wo             \ min(b, WR) again)
 RTS
.pdr_wo
 CMP pd_b1
 BCC P%+5
 LDA pd_b1
 STA pr_b
 LDA R_WL,Y
 CMP pd_a1
 BCS P%+5
 LDA pd_a1
 STA pr_a
 JSR pd_set
 JSR pd_col
 JSR pd_put
 JMP pd_fin
.pdr_ch                 \ changed, or recoloured
 JSR pd_set
 BIT pd_fl
 BMI pdr_aj
 LDA pd_b1
 CMP pd_a1
 BCC pdr_aj             \ the new span empty
 LDA pd_b0
 CMP pd_a0
 BCC pdr_aj             \ the old one empty
 CMP pd_a1
 BCC pdr_aj             \ b0 < a1: apart
 LDA pd_b1
 CMP pd_a0
 BCS pdr_ov             \ b1 < a0
.pdr_aj
 JMP pdr_all
.pdr_ov
 JSR pd_blk             \ overlapping: the ends that shrank black, a0 .. a1-1
 LDA pd_a1
 CMP pd_a0
 BEQ pdg2
 BCC pdg2
 DEC A
 STA pr_b
 LDA pd_a0
 STA pr_a
 JSR pd_put
.pdg2
 LDA pd_b0              \ and b1+1 .. b0
 CMP pd_b1
 BEQ pdg3
 BCC pdg3
 STA pr_b
 LDA pd_b1
 INC A
 STA pr_a
 JSR pd_put
.pdg3
 JSR pd_col             \ then in the disc's colour what grew: the left end,
 LDA pd_a1              \ a1 .. a0-1 ...
 CMP pd_a0
 BCS pdh1
 STA pr_a
 LDA pd_a0
 DEC A
 STA pr_b
 JSR pd_put
.pdh1
 LDA pd_b0              \ ... the right, b0+1 .. b1 ...
 CMP pd_b1
 BCS pdh2
 INC A
 STA pr_a
 LDA pd_b1
 STA pr_b
 JSR pd_put
.pdh2
 LDA R_WR,Y             \ ... and what was written over, max(a1, WL) ..
 BEQ pd_fin             \ min(b1, WR), if any (its overlap with the ends
 CMP pd_b1              \ written again, harmlessly)
 BCC P%+5
 LDA pd_b1
 STA pr_b
 LDA R_WL,Y
 CMP pd_a1
 BCS P%+5
 LDA pd_a1
 STA pr_a
 JSR pd_put
 JMP pd_fin
.pdr_all                \ the old span black, then the new whole
 JSR pd_blk
 LDA pd_a0
 STA pr_a
 LDA pd_b0
 STA pr_b
 JSR pd_put
 JSR pd_col
 LDA pd_a1
 STA pr_a
 LDA pd_b1
 STA pr_b
 JSR pd_put

\ pd_fin: the row's writes (pr_wl .. pr_wr) into R_WL/R_WR

.pd_fin
 LDA pr_wr
 CMP pr_wl
 BCC pdfn9               \ (none)
 LDA R_WR,Y
 BNE pdfn1
 LDA #255               \ (none written yet: no left end)
 STA R_WL,Y
.pdfn1
 LDA pr_wr
 CMP R_WR,Y
 BCC P%+5
 STA R_WR,Y
 LDA pr_wl
 CMP R_WL,Y
 BCS P%+5
 STA R_WL,Y
.pdfn9
 RTS

\ pd_put: pr_a .. pr_b (none if pr_a > pr_b) less the layer's span on the
\ row (pr_col .. pr_d), in pr_ce/pr_co; the row settled first in K mode.
\ Keeps Y

.pd_put
 LDA pr_b
 CMP pr_a
 BCC pdp9
 BIT pd_wr
 BMI pdp1
 LDA pr_a               \ (all of it behind the layer: nothing to settle)
 CMP pr_col
 BCC pdp0
 LDA pr_d
 CMP pr_b
 BCS pdp9
.pdp0
 DEC pd_wr
 JSR pk_y               \ (K mode: row Y not kept, settled)
.pdp1
 JMP pdiff
.pdp9
 RTS

\ pd_set: row Y about to be written: pr_y, the layer's span (pr_col ..
\ pr_d: none, 255 .. 0, if R_DISCL is 0 or 255), no writes yet

.pd_set
 STY pr_y
 LDA (pr_sl),Y
 STA pr_col
 BEQ pds1               \ (0: a pending kept row)
 CMP #255
 BEQ pds1
 LDA (pr_sr),Y
 STA pr_d
 BRA pds2
.pds1
 LDA #255
 STA pr_col
 STZ pr_d
.pds2
 LDA #255
 STA pr_wl
 STZ pr_wr
 STZ pd_wr
 RTS

.pd_blk                 \ black, or the disc's colour pair
 STZ pr_ce
 STZ pr_co
 RTS
.pd_col
 LDA R_COLE
 STA pr_ce
 LDA R_COLO
 STA pr_co
 RTS

\ pd_black: (a drop) this buffer's old second disc black, by its box (rows
\ R_S2T .. R_S2B, x hd_xl .. hd_xr) less the layer, as its spans are lost;
\ then it holds none (X = r_buf)

.pd_black
 LDA R_S2B,X
 CMP R_S2T,X
 BCC pdb9
 LDY R_S2T,X
.pdb1
 JSR pd_set
 JSR pd_blk
 LDX r_buf
 LDA hd_xl,X
 STA pr_a
 LDA hd_xr,X
 STA pr_b
 JSR pd_put
 JSR pd_fin
 JSR prw
 LDX r_buf
 TYA
 CMP R_S2B,X
 INY
 BCC pdb1
.pdb9
 LDX r_buf
 LDA #255
 STA R_S2T,X
 STZ R_S2B,X
 STZ R_S2C,X
 RTS

\ pd_whole: (no room) the new spans whole less the layer, as written and as
\ dirty, so that the buffer's next frame repairs them (the old way)

.pd_whole
 LDY R_NDT
.pdw1
 CPY R_NDB
 BEQ P%+4
 BCS pdw9
 JSR pd_set
 JSR pd_col
 LDA R_NDISCL,Y
 STA pr_a
 LDA R_NDISCR,Y
 STA pr_b
 JSR pd_put
 JSR pd_fin
 LDA pr_wr
 CMP pr_wl
 BCC pdw2
 STA R_XR
 LDA pr_wl
 STA R_XL
 JSR prw
 JSR R_MARKDIRTY        \ (keeps Y)
.pdw2
 INY
 BNE pdw1
.pdw9
 RTS

