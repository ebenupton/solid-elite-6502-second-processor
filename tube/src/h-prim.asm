\ ******************************************************************************
\
\ h-prim.asm - the dumb host's drawing commands (docs/TUBE-MAP.md), in the
\ resting bank (the Master host's bank 6, the Model B host's bank F): the
\ parasite decides everything (p-rast.asm); these draw what it sends, with the
\ Master port's own drawing code (the rasteriser's row runs, phase B's fill,
\ R_SPAN, R_LINE, R_DOT, R_STARPLOT and R_STARERASE, the frame layer's
\ f_glyph and its screen copies), and keep no state about what the screen
\ holds
\
\ ******************************************************************************

.h_buf                  \ C_BUF: the frame's buffer: wait for the last flip, then
 HRX                    \ draw into it
 STA F_BACK
 JSR f_bufpatch         \ (the Model B host's screen bases)
 LDA #2                 \ the clip window inside the border
 STA zR_CL
 LDA #253
 STA zR_CR
 LDA #1
 STA zR_CT
 LDA #191
 STA zR_CB
 LDA F_BACK
 JSR T_SETBUF           \ (the row runs' and the star records' buffer)
.hbf1
 LDA GFLIP
 BNE hbf1
IF _HOSTB = 0
 LDA F_BACK             \ (the Master host: ACCCON X shows the CPU the buffer)
 BEQ hbf2
 LDA #4
 TSB &FE34
.hbf2
ENDIF
 JMP hloop

.h_flip                 \ C_FLIP: show the frame's buffer at the next vsync
IF _HOSTB = 0
 LDA #4                 \ CPU back to main RAM
 TRB &FE34
ENDIF
 LDA #%00000010
 STA &FE4E
 LDA F_BACK
 STA GPEND
 LDA #&FF
 STA GFLIP
 LDA #%10000010
 STA &FE4E
 LDA #&80
 STA GMODE
 JMP hloop

.h_glyph                \ C_GLYPH: the character, its column, its text row:
 HRX                    \ f_glyph (the ink on the glyph's pixels, in the clip
 PHA                    \ window)
 HRX
 TAY
 HRX
 STA fz_i
 PLA
 JSR f_glyph
 JMP hloop

.h_enterb               \ C_ENTERB: space mode: buffer 1's border copied to buffer
 JSR f_enter            \ 0, buffer 1 on show (f_enter: the rest of what it does
 JMP hloop              \ is the host's own bookkeeping, unused here)

.h_clrbuf               \ C_CLRBUF: clear buffer 0 (f_b0new's screen)
 HRX
 JSR f_b0new
 JMP hloop

.h_eordot               \ C_EORDOT: x, y, size: f_unstar's EOR of one star
 HRX
 STA F_DSX
 HRX
 STA F_DSY
 HRX
 STA F_DSS
 JSR f_unstar
 JMP hloop

.h_directd              \ C_DIRECTD: direct mode's display (f_direct0's)
 JSR f_direct0
 JMP hloop

.h_stars                \ C_STARS: R_SCOL, R_SN, then x, y, size each: R_STARPLOT,
 HRX                    \ then its records back to the parasite (r_stout)
 STA R_SCOL
 HRX
 STA R_SN
 LDX #0
 CPX R_SN
 BEQ hps2
.hps1
 HRX
 STA R_SX,X
 HRX
 STA R_SY,X
 HRX
 STA R_SS,X
 INX
 CPX R_SN
 BNE hps1
.hps2
 JSR T_STARPLOT
 JSR T_STOUT
 JMP hloop

.h_starerase            \ C_STARERASE: the records, then R_STARERASE (r_stin)
 JSR T_STIN
 JMP hloop

\ h_orspan: C_ORSPAN: y, xl, xr, mask: OR the mask over pixels xl..xr of row y
\ of the frame's buffer (the lens flare's fl_or)

.h_orspan
 HRX
 STA hos_y
 HRX
 STA hos_l
 HRX
 STA hos_r
 HRX
 STA hos_m
 LDA hos_y              \ the row's first byte: base + (y DIV 8) * &200 + y MOD 8
 AND #7
 STA hsp
 LDA hos_y
 LSR A
 LSR A
 AND #&FE
 CLC
IF _HOSTB
 LDX F_BACK             \ (the Model B host: the buffer's base)
 ADC hos_base,X
ELSE
 ADC #&40
ENDIF
 STA hsp+1
 LDA hos_l              \ + 8 * (xl DIV 4)
 AND #&FC
 ASL A
 BCC P%+5
 INC hsp+1
 CLC
 ADC hsp
 STA hsp
 LDA hos_l              \ the first byte's mask, the last's, and the bytes
 AND #3
 TAX
 LDA hos_lmt,X
 STA hos_lq
 LDA hos_r
 AND #3
 TAX
 LDA hos_rmt,X
 STA hos_rq
 LDA hos_r
 AND #&FC
 SEC
 SBC #0
 STA hos_n
 LDA hos_l
 AND #&FC
 STA hos_t
 LDA hos_n
 SEC
 SBC hos_t
 ASL A                  \ 8 * (bytes - 1)
 TAY
 BNE hor2
 LDA hos_lq             \ one byte: both masks
 AND hos_rq
 STA hos_lq
 BRA hor9
.hor2
 LDA hos_rq             \ the last byte
 AND hos_m
 ORA (hsp),Y
 STA (hsp),Y
 BRA hor4
.hor3
 LDA (hsp),Y            \ the middle bytes
 ORA hos_m
 STA (hsp),Y
.hor4
 TYA
 SEC
 SBC #8
 TAY
 BNE hor3
.hor9
 LDA hos_lq             \ the first byte
 AND hos_m
 ORA (hsp),Y
 STA (hsp),Y
 JMP hloop
.hos_y EQUB 0
.hos_l EQUB 0
.hos_r EQUB 0
.hos_m EQUB 0
.hos_lq EQUB 0
.hos_rq EQUB 0
.hos_n EQUB 0
.hos_t EQUB 0
.hos_lmt EQUB &FF, &77, &33, &11     \ pixels x AND 3..3 of a byte
.hos_rmt EQUB &88, &CC, &EE, &FF     \ pixels 0..x AND 3
IF _HOSTB
.hos_base EQUB HI(BUF0), &40
ENDIF
