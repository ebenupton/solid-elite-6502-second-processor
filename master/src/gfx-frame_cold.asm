\ ******************************************************************************
\
\ frame_cold.asm - the frame layer's bookkeeping for screens drawn directly
\ (outside record mode, i.e. QQ11 or GFORCE non-zero) that then carry on in
\ record mode without a TT66: DEATH prints "GAME OVER" and nWq draws the
\ stardust while QQ11 = 6, then sets QQ11 = 0 and runs the main loop. FRAME
\ must know what text main RAM (buffer 0) already shows, and the directly
\ drawn stars must go (in record mode STARS1 only records new positions, so
\ nothing else would ever remove them from buffer 0).
\
\ INCLUDEd at the end of bank 6 (after its data), wrapping the text-map entry points of
\ frame.asm (f_char0, f_delchar0, f_clrtext0, f_direct0, f_enter), so that
\ none of the per-frame code moves.
\
\ ******************************************************************************

\ F_CHAR: TT26's character K3 at (XC-1, YC) (see f_char0)

.F_CHAR
 JSR f_sync
 LDA K3
 JMP f_char0

\ F_DELCHAR: clear the text map cell at (XC, YC) (TT26's delete)

.F_DELCHAR
 LDX XC
 LDY YC
 JSR f_sync
 JMP f_delchar0

\ F_CLRTEXT: clear text map rows 21-23 (CLYNS). Preserves X and Y (CLYNS
\ leaves X alone).

.F_CLRTEXT
 PHX
 PHY
 JSR f_sync
 LDX #21
 LDY #23
 JSR f_clrtext0
 PLY
 PLX
 RTS

\ F_DIRECT: TT66 is about to blank main RAM and draw directly (f_direct0
\ clears the text map and buffer 0's shown map): no direct text or stars

.F_DIRECT
 JSR f_direct0
 LDA #0
 STA f_dtext
 LDX #NDSTAR-1
.fdr1
 STA F_DSS,X
 DEX
 BPL fdr1
 RTS

\ f_enter2: the first record-mode frame since F_DIRECT. Main RAM is visible
\ (X = 0): remove the directly drawn stars before f_enter copies the border
\ to shadow RAM, then give buffer 0's shown map (which f_enter clears) the
\ text drawn directly, if any.

.f_enter2
 JSR f_unstar
 JSR f_enter
                        \ fall through into f_sync (QQ11 = 0 here)

\ f_sync: called before each change to the text map. Outside record mode
\ TT26 and CLYNS also draw the change into main RAM, so between F_DIRECT
\ (which blanks main RAM and clears both maps) and the first change made in
\ record mode, buffer 0 shows exactly the text map: just note that here
\ (f_dtext), and at that first record-mode change (or the first frame) copy
\ the text map to buffer 0's shown map. Preserves X and Y.

.f_sync
 LDA QQ11
 ORA GFORCE
 BEQ fsy1
 STA f_dtext            \ direct: buffer 0 = the text map, as far as text goes
 RTS
.fsy1
 LDA f_dtext
 BEQ fsy9
 STZ f_dtext
 PHX
 LDX #0
.fsy2
 LDA F_TM,X
 STA F_SH0,X
 LDA F_TM+256,X
 STA F_SH0+256,X
 LDA F_TM+512,X
 STA F_SH0+512,X
 INX
 BNE fsy2
 LDX #23
.fsy3
 LDA F_TMR,X
 STA F_SHR0,X
 DEX
 BPL fsy3
 JSR f_tchall
 PLX
.fsy9
 RTS

.f_dtext EQUB 0

\ f_unstar: EOR away the stars PIXEL drew directly into main RAM since
\ F_DIRECT (F_DSTAR noted them), exactly as PIXEL drew
\ them, so any text drawn over them stays intact. Main RAM must be visible.

.f_unstar
 LDY #NDSTAR-1
.fus1
 LDA F_DSS,Y
 BEQ fus9
 STA f_tmp              \ size 1-3
 LDA #0
 STA F_DSS,Y
 STY f_ysav2
 LDA F_DSY,Y            \ fz_nm = &4000 + (y DIV 8) * &200 + (x DIV 4) * 8
 LSR A
 LSR A
 AND #%11111110
 ORA #&40
 STA fz_nm+1
 LDA F_DSX,Y
 AND #%11111100
 ASL A
 STA fz_nm
 BCC P%+4
 INC fz_nm+1
 LDA F_DSX,Y
 AND #3
 TAX
 LDA F_DSY,Y
 AND #7
 TAY
 LDA f_tmp
 CMP #2
 BCS fus2
 LDA f_twos,X           \ size 1: one pixel
 BCC fus4
.fus2
 LDA f_twos2,X          \ size 2: a dash
 EOR (fz_nm),Y
 STA (fz_nm),Y
 LDA f_tmp
 CMP #3
 BCC fus8
 DEY                    \ size 3: and the row above (below on a cell's top row)
 BPL P%+4
 LDY #1
 LDA f_twos2,X
.fus4
 EOR (fz_nm),Y
 STA (fz_nm),Y
.fus8
 LDY f_ysav2
.fus9
 DEY
 BPL fus1
 RTS

.f_ysav2 EQUB 0
.f_twos  EQUB %10001000, %01000100, %00100010, %00010001
.f_twos2 EQUB %11001100, %01100110, %00110011, %00110011 \ (AND DUSTC = &FF)

\ F_DSTAR: outside record mode PIXEL2 draws star Y straight into main RAM;
\ H_STAR (C set: hA = y, X = x, ZZ = distance) and H_STAROFF (C clear: off
\ screen) come here (via G_DSTAR) to note it, so that f_unstar can remove it.
\ Preserves X and Y; returns C set if it was clear.

NDSTAR = NOST+1         \ stars 1..NOSTM (Master port: NOSTM <= NOST = 20)

.F_DSTAR
 BCC fdzo
 CPY #NDSTAR
 BCS fdz9
 LDA hA
 STA F_DSY,Y
 TXA
 STA F_DSX,Y
 LDA ZZ                 \ size 1-3 as PIXEL draws it (non-zero: noted)
 CMP #144
 LDA #1
 BCS fdz1
 LDA ZZ
 CMP #80
 LDA #2
 BCS fdz1
 LDA #3
.fdz1
 STA F_DSS,Y
.fdz9
 RTS
.fdzo
 CPY #NDSTAR
 BCS fdzo9
 LDA #0
 STA F_DSS,Y
.fdzo9
 SEC
 RTS

.F_DSS SKIP NDSTAR      \ size (0 = none)
.F_DSX SKIP NDSTAR
.F_DSY SKIP NDSTAR

\ f_sgs: f_sight2's rare case, out of line (frame.asm's fsg2 loop found bit 7
\ set in rows SGY-SGOUT+Y or SGY-SGOUT-1+Y, Y = 1-41 odd): f_wcov with A = X =
\ SGX for each of the two rows (ignoring row SGY+SGOUT+1, outside the sight);
\ either covered -> fsg3 (redraw), else carry on at fsg8

.f_sgs
 PHY
 TYA
 CLC
 ADC #SGY-SGOUT         \ Y = the upper row of the pair, SGY-SGOUT+Y
 TAY
 CPY #SGY+SGOUT+1
 BCS fsgs1              \ row SGY+SGOUT+1: not part of the sight
 LDA #SGX
 TAX
 JSR f_wcov             \ A = X = SGX (fz_t = fz_u = SGX, as before)
 BCS fsgs3
.fsgs1
 DEY                    \ the lower row, SGY-SGOUT-1+Y
 LDA #SGX
 TAX
 JSR f_wcov
 BCS fsgs3
 PLY
 JMP fsg8
.fsgs3
 PLY
 JMP fsg3
