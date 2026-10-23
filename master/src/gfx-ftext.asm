\ gfx-ftext.asm - the frame layer's text overlay and laser sights (gfx-frame.asm
\ INCLUDEs it there; the Tube's dumb host's parasite assembles it in its
\ overlay S, tube/src/p-layout.asm)

\ ------------------------------------------------------------------------------
\ Text overlay
\ ------------------------------------------------------------------------------

F_TCOL = &FF            \ text ink: yellow (logical colour 3)

IF _TPART <> 2             \ (the Tube's dumb host: f_glyph and f_nib only)
\ f_rowptr: X = text row -> fz_p = F_TM + 32*row, fz_q = F_ST + 32*row

.f_rowptr
 TXA
 LSR A
 LSR A
 LSR A
 STA fz_p+1
 TXA
 ASL A
 ASL A
 ASL A
 ASL A
 ASL A
 CLC
 ADC #LO(F_TM)
 STA fz_p
 STA fz_q
 LDA fz_p+1
 ADC #HI(F_TM)
 STA fz_p+1
 ADC #3                 \ (C = 0) F_ST = F_TM + &300
 STA fz_q+1
 RTS

\ f_text1: cells shown in this buffer that must change: give them back their
\ background by marking them dirty before R_DISCROWS repaints

.f_text1
 LDA F_BACK             \ this buffer's bit in F_TCH, and its M bit in F_ST
 INC A                  \ (into the text steps' masks)
 STA f_tbit
 STA ft_e1+1
 ASL A                  \ its N bit
 ASL A
 STA ft_n2+1
 ORA f_tbit             \ both
 STA ft_n1+1
 STA ft_m1+1
 STA ft_b2+1
 EOR #&FF               \ neither
 STA ft_c1+1
 LDX #23                \ rows 23..0 (each row is independent)
.ft11
.ft_sr1
 LDA F_SHR0,X           \ patched
 BEQ ft18x              \ X = row still
 LDA F_TCH,X            \ shown row = text map row: nothing to remove
 AND f_tbit
 BEQ ft18x
 STX fz_i
 JSR f_rowptr
 LDY #31
.ft12
 LDA (fz_q),Y           \ a character shown (N) that is not the cell's (not
.ft_n1                  \ M), or the cell is empty (M is never set without N)
 AND #0                 \ patched: N and M
 BEQ ft17a
.ft_m1
 CMP #0                 \ patched: N and M
 BNE ft15
 LDA (fz_p),Y
 BEQ ft15
 BMI ft15
.ft17a
 DEY
 BPL ft12
 BMI ft18
.ft15
 LDA (fz_q),Y           \ this cell goes: it shows nothing, and is marked
.ft_c1                  \ dirty
 AND #0                 \ patched: neither N nor M
 STA (fz_q),Y
 LDX fz_i
.ft_sr2
 DEC F_SHR0,X           \ patched
 STY fz_u
 TYA
 ASL A
 ASL A
 ASL A
 STA R_XL
 ORA #7
 STA R_XR
 JSR f_clipx
 BCC ft16
 LDA fz_i               \ lines 8r..8r+7 within the clip window
 ASL A
 ASL A
 ASL A
 STA fz_t
 CLC
 ADC #8
 STA fz_n
 LDY fz_t
.ft13                   \ Y = row (T_MARKDIRTY preserves Y, R_XL, R_XR)
 CPY R_CT
 BCC ft14
 CPY R_CB
 BEQ P%+4
 BCS ft16
 JSR T_MARKDIRTY
.ft14
 INY
 CPY fz_n
 BCC ft13
.ft16
 LDY fz_u
.ft17
 DEY
 BPL ft12
.ft18
 LDX fz_i
.ft18x
 DEX
 BPL ft11
 RTS

.f_clipx                \ clamp R_XL..R_XR to the clip window; C set if empty
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
 RTS                    \ C clear if XR < XL... invert below

\ f_text2: draw the text map's cells that this buffer doesn't show yet, or
\ whose pixels something overwrote this frame

.f_text2
 LDX #23                \ rows 23..0 (each row is independent)
.ft21
 LDA F_TMR,X            \ skip empty rows in a tight loop
 BNE ft2r
.ft29
 DEX
 BPL ft21
 RTS
.ft2r
 STX fz_i
 JSR f_rowptr
 LDA #255               \ W = union of R_WL/R_WR and DIRTY over the 8 lines
 STA f_wl
 LDA #0
 STA f_wr
 TXA                    \ X = fz_i (f_rowptr preserves X)
 ASL A
 ASL A
 ASL A
 TAY
 ADC #8                 \ C = 0: row <= 23, so 8*row < 256
 STA fz_n
.ft22
 LDA R_WR,Y
 BEQ ft23
 CMP f_wr
 BCC P%+5
 STA f_wr
 LDA R_WL,Y
 CMP f_wl
 BCS ft23
 STA f_wl
.ft23
.ft_wd2
 LDA R_DIRTYR0,Y        \ patched
 BEQ ft24
 CMP f_wr
 BCC P%+5
 STA f_wr
.ft_wd1
 LDA R_DIRTYL0,Y        \ patched
 CMP f_wl
 BCS ft24
 STA f_wl
.ft24
 INY
 CPY fz_n
 BCC ft22
 LDA f_wl               \ as cell columns: wl DIV 8 .. wr DIV 8
 LSR A
 LSR A
 LSR A
 STA f_wl
 LDA f_wr
 BEQ ft25
 LSR A
 LSR A
 LSR A
 STA f_wr
 JMP ft26
.ft25
 LDA #255               \ nothing written in this row
 STA f_wl
 LDA #0
 STA f_wr
.ft26
 LDX fz_i               \ row unchanged for this buffer: only the cells
 LDA F_TCH,X            \ written over (columns f_wl..f_wr)
 AND f_tbit
 BNE ft2f
 LDY f_wr
 CPY f_wl
 BCC ft2x
 LDA f_wl
 STA ft_end
 BRA ft27
.ft2x
 JMP ft29
.ft2f
 EOR F_TCH,X            \ whole row (then it is unchanged)
 STA F_TCH,X
 STZ ft_end
 LDY #31
.ft27
 LDA (fz_p),Y
 BEQ ft28
 BMI ft28
 LDA (fz_q),Y
.ft_e1
 AND #0                 \ patched: M (f_text1 has erased the other characters,
 BEQ ft2d               \ so M = N here): not shown yet
 CPY f_wl
 BCC ft28
 CPY f_wr
 BEQ ft2d
 BCS ft28
.ft2d
 LDA (fz_q),Y
.ft_n2
 AND #0                 \ patched: N
 BNE ft2e
 LDX fz_i
.ft_sr3
 INC F_SHR0,X           \ patched
.ft2e
 LDA (fz_q),Y           \ shown now
.ft_b2
 ORA #0                 \ patched: E and N
 STA (fz_q),Y
 LDA (fz_p),Y
 STY fz_u
 JSR f_glyph
 LDY fz_u
.ft28
 CPY ft_end
 BEQ ft2e9
 DEY
 JMP ft27
.ft2e9
 LDX fz_i
 JMP ft29

.f_wl EQUB 0
.f_wr EQUB 0
.ft_end EQUB 0

ENDIF
\ f_glyph: draw character A at column Y, text row fz_i, ink F_TCOL, only on
\ the glyph's pixels and only inside the clip window

.f_glyph
IF _TPART <> 2            \ (the Tube's host: no kept rows, they are the parasite's)
 BIT KMODE              \ K mode: the cell's rows are not kept
 BPL fgk
 PHA
 PHY
 LDA fz_i               \ (rows 8 * row .. + 7)
 ASL A
 ASL A
 ASL A
 PHA
 ADC #7                 \ (C = 0)
 TAX
 PLA
 JSR T_KROWS
 PLY
 PLA
.fgk
ENDIF
IF _TPART = 1             \ (Tube: the host draws it: C_GLYPH, the character, the
 PHA                    \ column, the text row; keeps Y)
 LDA #C_GLYPH
 JSR ptx
 PLA
 JSR ptx
 TYA
 JSR ptx
 LDA fz_i
 JMP ptx
ELSE
 SEC
 SBC #32                 \ glyph address = F_FONT + 8 * (char - 32)
 PHA
 ASL A
 ASL A
 ASL A
 ASSERT LO(F_FONT) = 0
 STA fgl1+1
 STA fglr+1             \ (the second load of the same row, for the low nibble)
 PLA
 LSR A
 LSR A
 LSR A
 LSR A
 LSR A
 CLC
 ADC #HI(F_FONT)
 STA fgl1+2
 STA fglr+2
 TYA                    \ screen: &4000 + row*&200 + 16*col
 ASL A
 ASL A
 ASL A
 ASL A
 STA fz_nm               \ low byte (16*col, may carry)
 ORA #8                  \ fz_v3 = fz_nm + 8, the right byte of the cell (low
 STA fz_v3               \ nibble 0: no carry; ORA keeps C for the ROL)
 LDA fz_i                \ high byte = 2*row + carry + &40 (row <= 23, so
 ROL A                   \ ROL leaves C = 0 and the ADC cannot carry)
IF _HOSTB
.fgl_b                    \ (Model B: the back buffer's base, f_bufpatch's)
ENDIF
 ADC #&40
 STA fz_nm+1
 STA fz_v3+1
 LDA #&FF               \ masks for the border columns (patched into the loop)
 STA fglm+1
 STA fgrm+1
 CPY #0
 BNE P%+7
 LDA #&33               \ pixels 0-1 of column 0 are the border
 STA fglm+1
 CPY #31
 BNE P%+7
 LDA #&CC               \ pixels 254-255 are the border
 STA fgrm+1
 ASSERT F_TCOL = &FF    \ ink is all-ones: (m AND ink) OR (NOT m AND s) = m OR s
 LDA fz_i               \ first line y = 8*row
 ASL A
 ASL A
 ASL A
 STA f_gy               \ (C = 0: row <= 23)
 LDA R_CT               \ the lines inside the clip window vertically:
 SBC f_gy               \ Y from max(0, R_CT - 8*row) (minus 1 here: the
 BCS P%+4               \ loop is entered at its INY)
 LDA #&FF
 TAY
 LDA R_CB               \ to min(7, R_CB - 8*row), none if R_CB < 8*row
 SEC
 SBC f_gy
 CLV                    \ V = 0 on exit, as before
 BCC fgl9
 CMP #7
 BCC P%+4
 LDA #7
 INC A
 STA fgl4+1
 BRA fgl3
.fgl0
.fgl1
 LDA F_FONT,Y           \ patched
 BEQ fgl3
 LSR A
 LSR A
 LSR A
 LSR A
 TAX
 LDA f_nib,X
.fglm
 AND #&FF               \ patched (left border mask)
 ORA (fz_nm),Y
 STA (fz_nm),Y
.fglr
 LDA F_FONT,Y           \ patched (the same address as fgl1)
 AND #15
 TAX
 LDA f_nib,X
.fgrm
 AND #&FF               \ patched (right border mask)
 ORA (fz_v3),Y
 STA (fz_v3),Y
.fgl3
 INY
.fgl4
 CPY #8                 \ patched (last line + 1)
 BCC fgl0
.fgl9
 RTS
ENDIF

.f_gy EQUB 0

.f_nib                  \ 4 font bits (bit 3 = leftmost) -> MODE 1 pixel mask
FOR n, 0, 15
 EQUB n * &11
NEXT

F_FONT = FONT% * 256      \ Master port: Elite's own font in main RAM (the same
ASSERT _HOSTB OR F_FONT + 768 <= &3000 \ 768 bytes), visible while ACCCON X is set


\ ------------------------------------------------------------------------------
\ Laser sights: four short arms about (128, 96), drawn after everything else
\ and only redrawn when something was written over them (like the text)
\ ------------------------------------------------------------------------------

IF _TPART <> 2             \ (the Tube's dumb host: the sights are the parasite's)
SGX = 128
SGY = 96
SGIN = 11               \ arms run from SGIN to SGOUT pixels from the centre
SGOUT = 20

.F_SGS EQUB 0, 0        \ per buffer: the sights are drawn in it

\ f_sight1: sights shown in this buffer but no longer wanted: mark them dirty

.f_sight1
 LDX F_BACK
 LDA F_SGS,X
 BEQ fsg9
 LDA GSIGHT
 BNE fsg9
 LDA #0
 STA F_SGS,X
 LDA #SGX-SGOUT
 STA R_XL
 LDA #SGX+SGOUT
 STA R_XR
 LDY #SGY
 JSR T_MARKDIRTY
 LDA #SGX
 STA R_XL
 STA R_XR
 LDY #SGY-SGOUT
.fsg1
 STY fz_i
 JSR T_MARKDIRTY
 LDY fz_i
 INY
 CPY #SGY+SGOUT+1
 BCC fsg1
.fsg9
 RTS

\ f_wcov: does anything written this frame in row Y cover x = A .. X?
\ (R_WL/R_WR, or this buffer's new dirty extent). C set if so. Keeps Y.

.f_wcov
 STA fz_t
 STX fz_u
 LDA R_WR,Y             \ written: WL..WR (WR = 0: none)
 BEQ fwc2
 CMP fz_t
 BCC fwc2
 LDA fz_u
 CMP R_WL,Y
 BCS fwc9
.fwc2
.fsw_d2
 LDA R_DIRTYR0,Y        \ patched
 BEQ fwc8
 CMP fz_t
 BCC fwc8
 LDA fz_u
.fsw_d1
 CMP R_DIRTYL0,Y        \ patched
 BCS fwc9
.fwc8
 CLC
.fwc9
 RTS

.f_sight2
 LDA GSIGHT
 BEQ fsg9
 LDX F_BACK
 LDA F_SGS,X
 BEQ fsg3               \ not drawn yet
 LDY #SGY               \ overwritten anywhere?
 LDA #SGX-SGOUT
 LDX #SGX+SGOUT
 JSR f_wcov
 BCS fsg3
 LDA fsw_d2+2           \ this buffer's R_DIRTYR (f_bufpatch), high byte, +1
 INC A                  \ for the +SGY-SGOUT(-1) bases below
 STA fsg_or+2           \ (the low bytes are equal)
 STA fsg_or2+2
 ASSERT LO(R_DIRTYR0) = LO(R_DIRTYR1)
 ASSERT HI(R_DIRTYR0+SGY-SGOUT-1) = HI(R_DIRTYR0)+1 AND HI(R_DIRTYR1+SGY-SGOUT-1) = HI(R_DIRTYR1)+1
 ASSERT HI(R_DIRTYR0+SGY-SGOUT-1) = HI(R_DIRTYR0+SGY+SGOUT+1)   \ no page crossings in the loop
 LDY #2*SGOUT+1         \ two rows a pass: SGY-SGOUT+Y and SGY-SGOUT-1+Y, Y = 41,
.fsg2                   \ 39 .. 1 (row SGY+SGOUT+1 is read too; f_sgs ignores it).
 LDA R_WR+SGY-SGOUT,Y   \ f_wcov with A = X = SGX: WR, DIRTYR >= SGX (= &80,
.fsg_or                 \ so <> 0) <=> bit 7 set; usually neither is
 ORA R_DIRTYR0+SGY-SGOUT,Y \ patched (high byte, above)
 ORA R_WR+SGY-SGOUT-1,Y
.fsg_or2
 ORA R_DIRTYR0+SGY-SGOUT-1,Y \ patched (high byte, above)
 BMI fsgs
.fsg8
 DEY
 DEY
 BPL fsg2
 RTS
.fsgs
 JMP f_sgs              \ (frame_cold.asm: rare, and nothing after here moves)
.fsg3
 LDX F_BACK
 LDA #&FF
 STA F_SGS,X
 LDA F_CPE+FC_SIGHT     \ horizontal arms (row SGY is even)
 STA R_COLE
 STA R_COLO
 LDA #SGX-SGOUT
 STA R_XL
 LDA #SGX-SGIN
 STA R_XR
 LDY #SGY
 JSR T_SPAN
 LDA #SGX+SGIN
 STA R_XL
 LDA #SGX+SGOUT
 STA R_XR
 LDY #SGY
 JSR T_SPAN
IF _TPART = 1             \ (Tube: two lines to the host, x = 128, rows 76-85 and
 LDX #0                 \ 107-116, which set those pixels to the sights' colour
.fsgv1                  \ as below)
 LDA #C_LINE
 JSR ptx
 LDY #4
 LDA F_CPE+FC_SIGHT
.fsgv2
 JSR ptx
 DEY
 BNE fsgv2
 LDY #0
.fsgv3
 LDA fsgvt,X
 JSR ptx
 INX
 INY
 CPY #8
 BNE fsgv3
 CPX #16
 BNE fsgv1
 BEQ fsgv9
.fsgvt
 EQUW SGX, SGY-SGOUT, SGX, SGY-SGIN
 EQUW SGX, SGY+SGIN, SGX, SGY+SGOUT
.fsgv9
ELSE
 LDA F_CPE+FC_SIGHT     \ vertical arms: pixel 0 of byte column 32
 AND #&88               \ (loop-invariant colour bits)
 STA fz_t
 ASSERT SGY-SGOUT = 76 AND SGY-SGIN = 85   \ byte = &4000 + (y DIV 8)*&200 + &100 + (y MOD 8)
 ASSERT SGY+SGIN = 107 AND SGY+SGOUT = 116
 LDY #3                 \ rows 76..79: &5304..&5307
.fsg4
IF _HOSTB
.fsv1
ENDIF
 LDA &5304,Y
 AND #&77
 ORA fz_t
IF _HOSTB
.fsv2
ENDIF
 STA &5304,Y
 DEY
 BPL fsg4
 LDY #5                 \ rows 80..85: &5500..&5505
.fsg5
IF _HOSTB
.fsv3
ENDIF
 LDA &5500,Y
 AND #&77
 ORA fz_t
IF _HOSTB
.fsv4
ENDIF
 STA &5500,Y
 DEY
 BPL fsg5
 LDY #4                 \ rows 107..111: &5B03..&5B07, rows 112..116: &5D00..&5D04
.fsg6
IF _HOSTB
.fsv5
ENDIF
 LDA &5B03,Y
 AND #&77
 ORA fz_t
IF _HOSTB
.fsv6
ENDIF
 STA &5B03,Y
IF _HOSTB
.fsv7
ENDIF
 LDA &5D00,Y
 AND #&77
 ORA fz_t
IF _HOSTB
.fsv8
ENDIF
 STA &5D00,Y
 DEY
 BPL fsg6
ENDIF
 SEC                    \ C = 1 on exit, as before
 RTS
ENDIF
