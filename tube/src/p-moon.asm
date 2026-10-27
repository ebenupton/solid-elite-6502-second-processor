\ ******************************************************************************
\
\ p-moon.asm - the moon drawn incrementally (overlay S, with p-rast.asm): only
\ the rows that changed since the buffer's last frame are drawn
\
\ The frame layer's f_moon (gfx-frame.asm) works out each row of the moon as
\ pieces (its span less the planet and the sun where they are in front) and
\ the crater's boundaries; on the Master port it draws every row and marks it
\ dirty, so that the buffer's next frame blacks it and draws it again. Here
\ each buffer keeps the moon it holds (mb_v ...: its centre, radius, rows and
\ whether it is in front of or behind the discs, p-rast.asm's state) and the
\ kind of each of its rows (2 bits of R_BST: 1 all light grey, 2 all dark
\ grey, 0 anything else), and the moon's rows are never marked dirty:
\
\   * T_MPRE, before the disc layer: if the moon has moved, changed size, gone
\     in front of or behind a disc, or gone, the old moon's rows are marked
\     dirty over its width, so that the disc layer's repair blacks them (and
\     draws a disc there again, as for any dirty extent), and the new rows'
\     kinds are unknown (0);
\
\   * T_MROW, for each row f_moon is about to draw: C set (not drawn) if the
\     row is one colour, as the buffer holds it, and nothing has been drawn
\     over its span this frame (R_WL/R_WR: the repair and the disc layer; the
\     dirty extent: the other disc, f_disc2).
\
\ So a still moon's one-colour rows are not drawn again; a row with the
\ crater's boundaries (which turn with the planet every frame) or cut by a
\ disc in front of it, and every row of a moon that moves, is drawn each frame.
\ Each frame's pixels are as the Master port's
\
\ ******************************************************************************

.T_MPRE
 LDX r_buf
 STX mq_b
 BIT mb_v,X             \ the moon this buffer holds, if any, as it was?
 BPL mpr2
 BIT MN_ON
 BPL mpr1
 LDA R_NDT
 CMP R_NDB
 BEQ P%+4
 BCS mpr1
 LDA MN_X
 CMP mb_xl,X
 BNE mpr1
 LDA MN_X+1
 CMP mb_xh,X
 BNE mpr1
 LDA MN_Y
 CMP mb_yl,X
 BNE mpr1
 LDA MN_Y+1
 CMP mb_yh,X
 BNE mpr1
 LDA MN_R
 CMP mb_r,X
 BNE mpr1
 LDA MN_ON
 AND #&60
 CMP mb_f,X
 BNE mpr1
 RTS                    \ (the same: its rows' kinds kept)
.mpr1
 LDA mb_xl,X            \ the old moon's rows dirty over its width: centre x
 SEC                    \ - r .. + r, clamped to 0 .. 255
 SBC mb_r,X
 STA R_XL
 LDA mb_xh,X
 SBC #0
 BEQ mpr1a
 BPL mpr2               \ (left of it past 255: none)
 STZ R_XL
.mpr1a
 LDA mb_xl,X
 CLC
 ADC mb_r,X
 STA R_XR
 LDA mb_xh,X
 ADC #0
 BMI mpr2               \ (right of it below 0: none)
 BEQ mpr1b
 LDA #255
 STA R_XR
.mpr1b
 LDA mb_b,X
 STA mq_e
 LDY mb_t,X
.mpr1c
 JSR T_MARKDIRTY
 CPY mq_e
 INY
 BCC mpr1c
.mpr2
 LDX mq_b               \ the new moon, if any: its rows' kinds unknown
 STZ mb_v,X
 BIT MN_ON
 BPL mpr9
 LDY R_NDT
 CPY R_NDB
 BEQ P%+4
 BCS mpr9
 LDA MN_X
 STA mb_xl,X
 LDA MN_X+1
 STA mb_xh,X
 LDA MN_Y
 STA mb_yl,X
 LDA MN_Y+1
 STA mb_yh,X
 LDA MN_R
 STA mb_r,X
 LDA MN_ON
 AND #&60
 STA mb_f,X
 TYA
 STA mb_t,X
 LDA R_NDB
 STA mb_b,X
 LDA #&80
 STA mb_v,X
 LDA mq_m,X
 STA mq_k
.mpr3
 LDA R_BST,Y
 AND mq_k
 STA R_BST,Y
 CPY R_NDB
 INY
 BCC mpr3
.mpr9
 RTS
.mq_m EQUB &FC, &CF     \ (a buffer's moon bits clear)

\ T_MROW: row fm_y of the moon, its pieces as f_moon made them: its kind into
\ the buffer's bits of R_BST, and C set if it need not be drawn

.T_MROW
 LDY fm_y
 LDX fm_n               \ the kind: 0 (cut by a disc, or the crater's)
 CPX #1
 BNE mrw0
 LDA fm_pa
 CMP R_NDISCL,Y
 BNE mrw0
 LDA fm_pb
 CMP R_NDISCR,Y
 BNE mrw0
 LDA R_NDN,Y
 BNE mrw0
 LDA R_NDP,Y            \ else 1 + its one colour
 AND #1
 INC A
 BNE mrw1
.mrw0
 LDA #0
.mrw1
 LDX mq_b
 BEQ mrw2
 ASL A                  \ (buffer 1: bits 4-5)
 ASL A
 ASL A
 ASL A
.mrw2
 STA mq_k
 LDA R_BST,Y            \ the old kind
 AND mq_n,X
 CMP mq_k
 PHP
 EOR R_BST,Y            \ the new one
 ORA mq_k
 STA R_BST,Y
 PLP
 BNE mrw8
 LDA mq_k                \ (a crater's row, or a cut one: drawn, as the crater
 BEQ mrw8               \ turns with the planet and the discs move)
 BIT KMODE              \ (K mode, p-kept.asm: every row drawn, so that T_SPAN
 BMI mrw8               \ keeps no row under the moon)
 LDA R_WR,Y             \ anything written over the span this frame?
 BEQ mrw3
 CMP R_NDISCL,Y
 BCC mrw3
 LDA R_WL,Y
 CMP R_NDISCR,Y
 BEQ mrw8
 BCC mrw8
.mrw3
 LDA (pr_dr),Y          \ (the dirty extent: drawn since the repair)
 CMP (pr_dl),Y
 BCC mrw9
 CMP R_NDISCL,Y
 BCC mrw9
 LDA (pr_dl),Y
 CMP R_NDISCR,Y
 BEQ mrw8
 BCS mrw9
.mrw8
 CLC                    \ drawn
 RTS
.mrw9
 SEC                    \ unchanged: not drawn
 RTS
.mq_n EQUB &03, &30     \ (a buffer's moon bits)


.mq_b EQUB 0            \ the buffer
.mq_e EQUB 0
.mq_k EQUB 0

.F_HW3 SKIP 64          \ the moon's half-widths (its radius is at most 63): only
                        \ ever used with overlay S in, so here (p-ovl.asm
                        \ forgets the radius it was built for when S comes in)
