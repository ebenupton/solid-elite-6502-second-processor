\ ******************************************************************************
\
\ p-disc.asm - the parasite's incremental discs (overlay S, with p-rast.asm):
\ the disc heap, the planet's surface detail drawn as changes, and the second
\ disc drawn as changes. Every disc is incremental: each buffer remembers what
\ it shows of each disc row, and a frame sends the host only what changed.
\
\ The disc heap (HEAP, HEAPN bytes in overlay S's saved state) holds the
\ per-row state that only some rows need, by body:
\
\   * body 0, the surface (HB_S): for the disc layer when it has two colours
\     (a beach ball, craters, bands), per row one byte for both buffers, a
\     nibble each (buffer 0's the low one: the boundary count, 0-2, in bits
\     0-1, bit 2 for unknown, a row with three or more, bit 3 the colour at
\     the span's left end), and per buffer and row the first two boundaries;
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
 CMP #0                 \ (the surface: the counts unknown in both nibbles)
 BNE hpo3
 LDA #&44
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
 LDA #&0F               \ (this buffer's nibble of the counts: ps_row)
 LDX r_buf
 BEQ P%+4
 LDA #&F0
 STA ps_msk
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
\ ps_row: R_DISCROWS' row Y (pr_y) of a two-colour frame (this frame's or
\ this buffer's last): the new span pr_e .. pr_f (empty: 255, 0), the new
\ boundaries (R_NDN's count and colour, R_NDX0-3, on the new rows, else
\ none in colour A), the old span (pr_sl/pr_sr) and the old boundaries (the
\ surface, ps_ok), and the dirty extent. A row not written over (no dirty)
\ is drawn as changes: nothing if the same; else each edge's strip (the
\ span's ends and the boundaries, old .. new) in the colour on the side it
\ moved from, as the Master port's r_dpe, when the edges stay in order (and
\ the counts differ by one at most, at an end); else the new span segment
\ by segment, after the old span less the new black (none if the new span
\ holds the old). A dirty row: the old span and the dirty extent black less
\ the new span, then the new span segment by segment. Then the row's new
\ state. Keeps Y
\ ------------------------------------------------------------------------------

.ps_row
 LDA #&FF
 STA pr_wl
 STZ pr_wr
 STZ ps_nn              \ the new count and colour (none, colour A, outside
 CPY r_nt               \ the new rows or with no boundaries this frame)
 BCC psr1
 CPY r_nb
 BEQ P%+4
 BCS psr1
 LDA R_NDF
 BEQ psr1
 LDA R_NDN,Y
 STA ps_nn
.psr1
 JSR ps_nib             \ (ps_nx: the new nibble)
 LDA ps_ok              \ no state: unknown, repainted
 BEQ psr_gen
 LDA (pr_dr),Y          \ dirty: repainted
 BNE psr_gen
 LDA (pr_sl),Y          \ the same span, count, colour and boundaries? (the
 CMP pr_e               \ count and colour against this buffer's nibble,
 BNE psr_ch             \ ps_msk, as the new pair would be stored: the count
 LDA (pr_sr),Y          \ 0-2 in bits 0-1, the colour in bit 3)
 CMP pr_f
 BNE psr_ch
 LDA ps_nn
 AND #&7F
 CMP #3
 BCS psr_ch             \ (three boundaries or more: never the same)
 LDA ps_nx
 EOR (hp_n),Y
 AND ps_msk
 BNE psr_ch
 LDA ps_nn
 AND #3
 BEQ psr_same
 LDA (hp_0),Y
 CMP R_NDX0,Y
 BNE psr_ch
 LDA ps_nn
 AND #2
 BEQ psr_same
 LDA (hp_1),Y
 CMP R_NDX1,Y
 BNE psr_ch
.psr_same
 RTS
.psr_ch
 JSR ps_getn            \ (ps_on: the old count and colour)
 JSR ps_edges           \ as changes, if the edges allow
 BCC psr_st
 LDA (pr_sl),Y          \ else: the new span holds the old (or no old):
 CMP #255               \ the new one segment by segment
 BEQ psr_seg
 CMP pr_e
 BCC psr_gen
 LDA pr_f
 CMP pr_e
 BCC psr_gen
 CMP (pr_sr),Y
 BCS psr_seg
.psr_gen                \ the old span and the dirty extent black less the
 STZ pr_ce              \ new span
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
 CMP pr_a
 BCC psr_seg
 JSR pdiff
.psr_seg
 LDA pr_f               \ the new span, segment by segment
 CMP pr_e
 BCC psr_st
 JSR ps_seg
.psr_st                 \ the row's new state: the span (R_DISCROWS' caller),
 LDA ps_ok              \ the count and colour (three or more: unknown), the
 BEQ psr9               \ first two boundaries
 LDA ps_msk
 EOR #&FF
 AND (hp_n),Y
 ORA ps_nx
 STA (hp_n),Y
 LDA R_NDX0,Y
 STA (hp_0),Y
 LDA R_NDX1,Y
 STA (hp_1),Y
.psr9
 RTS

\ ps_nib: A = ps_nx = the row's new count and colour as this buffer's nibble
\ of the surface's shared array (bit 3 the colour, bit 2 unknown: three
\ boundaries or more, bits 0-1 the count), in its place (ps_msk: buffer 1's
\ the high nibble). Keeps X, Y

.ps_nib
 LDA ps_nn
 BEQ psn9               \ (none, colour A: 0, the commonest)
 AND #&7F
 CMP #3
 LDA ps_nn
 AND #3
 BCC P%+4
 LDA #4
 BIT ps_nn
 BPL P%+4
 ORA #8
 BIT ps_msk
 BPL P%+6
 ASL A
 ASL A
 ASL A
 ASL A
.psn9
 STA ps_nx
 RTS

\ ps_seg: the new span pr_e .. pr_f of row Y segment by segment: colour ps_nn
\ (bit 7: B) at its left end, flipped at each boundary (R_NDX0-3, ps_nn's
\ count, at most 4) inside it. Keeps Y

.ps_seg
 LDA ps_nn
 AND #&7F
 CMP #5
 BCC P%+4
 LDA #4
 STA pr_g
 LDA ps_nn
 ASL A
 LDA #0
 ROL A
 STA pr_col
 LDA pr_e
 STA pr_a               \ the segment's start
 LDX #0
.pss2
 CPX pr_g
 BCS pss5
 LDA psx_l,X            \ boundary X of row Y
 STA pss3+1
 LDA psx_h,X
 STA pss3+2
.pss3
 LDA &FFFF,Y            \ (patched: R_NDXx)
 CMP pr_e
 BEQ pss4
 BCC pss4
 CMP pr_f
 BEQ P%+4
 BCS pss5
 CMP pr_a
 BEQ pss4               \ an empty segment
 PHA
 DEC A
 STA pr_b
 JSR ps_put
 PLA
 STA pr_a
.pss4
 LDA pr_col
 EOR #1
 STA pr_col
 INX
 BRA pss2
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
.psx_l EQUB LO(R_NDX0), LO(R_NDX1), LO(R_NDX2), LO(R_NDX3)
.psx_h EQUB HI(R_NDX0), HI(R_NDX1), HI(R_NDX2), HI(R_NDX3)

\ ps_edges: row Y as changes, the Master port's r_dpe: its edges (the
\ span's left end, the boundaries, the end after its right end), old and
\ new, each edge's strip old .. new written in the colour on the side it
\ moved from, if the old span is not empty, the old and new counts are the
\ same with the same left colour, or differ by one at an end, the spans are
\ not apart, and the strips are in order. C clear: done; C set: not (nothing
\ written). Keeps Y

.ps_edges
 LDA (pr_sl),Y
 CMP #255
 BEQ pse_no             \ (no old span)
 STA pe_o
 LDA pr_f
 CMP pr_e
 BCC pse_no             \ (no new span)
 LDA pr_e
 STA pe_n
 LDA ps_on              \ the old colour at bit 7 (ps_t)
 ASL A
 ASL A
 ASL A
 ASL A
 STA ps_t
 LDA ps_on              \ the counts: old (at most 2, or unknown) and new
 AND #7
 CMP #3
 BCS pse_no
 STA pe_oc
 LDA ps_nn
 AND #&7F
 CMP #4
 BCS pse_no
 STA pe_nc
 LDA R_NDX0,Y           \ the boundaries: new at pe_n+1, old at pe_o+1
 STA pe_n+1
 LDA R_NDX1,Y
 STA pe_n+2
 LDA R_NDX2,Y
 STA pe_n+3
 LDA (hp_0),Y
 STA pe_o+1
 LDA (hp_1),Y
 STA pe_o+2
 LDA ps_nn              \ the left colour (0 A, 1 B), new
 ASL A
 LDA #0
 ROL A
 STA pe_c
 LDA pe_nc
 SEC
 SBC pe_oc
 BEQ pse_same
 CMP #1
 BEQ pse_more
 CMP #&FF
 BEQ pse_fewer
.pse_no
 SEC
 RTS
.pse_same
 LDA ps_nn              \ the same count: the same left colour too
 EOR ps_t
 BMI pse_no
 BRA pse_ends
.pse_more               \ one more: it came in at the right (the same left
 LDA ps_nn              \ colour; old gets one at its right end + 1) or at
 EOR ps_t               \ the left (old gets one at its left end)
 BMI pse_ml
 LDX pe_oc
 LDA (pr_sr),Y
 INC A
 STA pe_o+1,X
 BRA pse_m1
.pse_ml
 LDA pe_o+2             \ (old: left, b0, b1 -> left, left, b0, b1)
 STA pe_o+3
 LDA pe_o+1
 STA pe_o+2
 LDA pe_o
 STA pe_o+1
.pse_m1
 LDA pe_nc              \ (the count: the new one)
 STA pe_oc
 BRA pse_ends
.pse_fewer              \ one fewer: it left at the right (new gets one at
 LDA ps_nn              \ its right end + 1) or at the left (new gets one at
 EOR ps_t               \ its left end, and the left colour is the old one)
 BMI pse_fl
 LDX pe_nc
 LDA pr_f
 INC A
 STA pe_n+1,X
 BRA pse_f1
.pse_fl
 LDA pe_c
 EOR #1
 STA pe_c
 LDA pe_n+2             \ (new: left, b0, b1 -> left, left, b0, b1)
 STA pe_n+3
 LDA pe_n+1
 STA pe_n+2
 LDA pe_n
 STA pe_n+1
.pse_f1
 LDA pe_oc              \ (the count: the old one)
 STA pe_nc
.pse_ends
 LDX pe_nc              \ the ends after the right ends: index count + 1
 INX
 STX pe_ns
 LDA pr_f
 INC A
 STA pe_n,X
 LDA (pr_sr),Y
 INC A
 STA pe_o,X
 LDA pe_n,X             \ the spans apart (a gap between them): no
 CMP pe_o
 BCC pse_n2
 LDA pe_o,X
 CMP pe_n
 BCC pse_n2
 LDX #0                 \ the strips in order (each starting at or after the
 STZ pe_t               \ last's end), first checked, then written
.pse_c1
 LDA pe_n,X
 CMP pe_o,X
 BEQ pse_c2
 BCC pse_c3
 LDA pe_o,X             \ (right: o .. n-1)
 CMP pe_t
 BCC pse_n2
 LDA pe_n,X
 STA pe_t
 BRA pse_c4
.pse_n2
 SEC
 RTS
.pse_c3
 CMP pe_t               \ (left: n .. o-1)
 BCC pse_n2
 LDA pe_o,X
 STA pe_t
 BRA pse_c4
.pse_c2
 CMP pe_t
 BCC pse_n2
 STA pe_t
.pse_c4
 INX
 CPX pe_ns
 BCC pse_c1
 BEQ pse_c1
 LDX #0                 \ the strips
.pse_w1
 STX pe_i
 LDA pe_n,X
 CMP pe_o,X
 BEQ pse_w9
 BCC pse_w3
 DEC A                  \ moved right: o .. n-1, the colour left of the edge
 STA pr_b               \ (index X-1: X = 0, outside the span: black)
 LDA pe_o,X
 STA pr_a
 DEX
 BMI pse_bk
 BRA pse_cx
.pse_w3
 STA pr_a               \ moved left: n .. o-1, the colour right of the edge
 LDA pe_o,X             \ (index X: the right end's, outside: black)
 DEC A
 STA pr_b
 CPX pe_ns
 BEQ pse_bk
.pse_cx
 TXA
 EOR pe_c
 AND #1
 STA pr_col
 JSR ps_put
 BRA pse_w9
.pse_bk
 STZ pr_ce
 STZ pr_co
 JSR pspan
.pse_w9
 LDX pe_i
 INX
 CPX pe_ns
 BCC pse_w1
 BEQ pse_w1
 CLC
 RTS

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

