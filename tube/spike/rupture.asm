\ Phase 0 spike: the dashboard split on a host with no shadow RAM, by a CRTC
\ vertical rupture. Each 312-line field is two CRTC frames: frame A, 24
\ character rows (192 lines) from the space-view buffer, with no vsync, and
\ frame B, 15 rows (120 lines) of which 7 (56 lines) show the panel, with
\ vsync at its row 10 (line 272, as MODE 1's row 34). The 6845 latches its
\ start address (R12/R13) at the start of each CRTC frame, so the buffer
\ shown in frame A and the panel in frame B each come from their own address.
\ Timer 1 runs freely and fires twice a field, alternating its latch:
\   point 2, line 8 (frame A, row 1): R4 = 23, R6 = 24 (all of frame A shown),
\     R7 = 127 (no vsync in frame A), R12/R13 = the panel (latched when
\     frame A ends);
\   point 1, line 196 (frame B, row 0): R4 = 14, R6 = 7, R7 = 10, R12/R13 =
\     the buffer to show next (latched when frame B ends).
\ Buffers: A at &1200, B at &4200 (12K each), the panel at &7200 (3.5K).
\ NMOS 6502 code (runs on a Model B).
CPU 0
VIA = &FE40
IRQ1V = &204
LINE = 64               \ us per line
PA = 188 * LINE - 2     \ point 2 to point 1 (the latch counts N+2 us)
PB = 124 * LINE - 2     \ point 1 to point 2
ORG &0E00
.start
 LDA #22                \ MODE 1 first (the ULA and the palette), from the MOS
 JSR &FFEE
 LDA #1
 JSR &FFEE
 SEI
 LDA #LO(irq)
 STA IRQ1V
 LDA #HI(irq)
 STA IRQ1V+1
 LDA #%01111111         \ System VIA: only timer 1 and CA1 (vsync)
 STA VIA+&E
 LDA #%11000010
 STA VIA+&E
 LDA #%01111111         \ (none from the User VIA)
 STA &FE6E
 LDA #%00000010         \ wait for vsync
 STA VIA+&D
.w1
 BIT VIA+&D
 BEQ w1
 LDA #LO(48*LINE-200)   \ point 2 next: 48 lines on (line 8), less the time to here
 STA VIA+4
 LDA #HI(48*LINE-200)
 STA VIA+5
 LDA #LO(PA)            \ then point 1, 188 lines on
 STA VIA+6
 LDA #HI(PA)
 STA VIA+7
 LDA #0
 STA phase
 CLI
.idle
 JMP idle

.irq
 LDA VIA+&D
 AND #%01000000
 BNE tim
 LDA VIA+1              \ vsync: clear its flag, count fields
 INC fields
 LDA &FC
 RTI
.tim
 TXA
 PHA
 LDA phase
 EOR #1
 STA phase
 BEQ p1
 \ point 2 (frame A has started): frame A's rows, then the panel's address
 LDX #0
.p2l
 STX &FE00
 LDA rega,X
 STA &FE01
 INX
 CPX #14
 BCC p2l
 LDA #LO(PB)            \ (the latch after next: point 2 to point 1 again)
 STA VIA+6
 LDA #HI(PB)
 STA VIA+7
 JMP tdone
.p1                     \ point 1 (frame B has started): frame B's rows, then
 LDX #0                 \ the next buffer's address
.p1l
 STX &FE00
 LDA regb,X
 STA &FE01
 INX
 CPX #14
 BCC p1l
 LDA front              \ R12/R13: the buffer to show
 BEQ fa
 LDA #12
 STA &FE00
 LDA #HI(&4200 DIV 8)
 STA &FE01
 LDA #13
 STA &FE00
 LDA #LO(&4200 DIV 8)
 STA &FE01
 JMP fb
.fa
 LDA #12
 STA &FE00
 LDA #HI(&1200 DIV 8)
 STA &FE01
 LDA #13
 STA &FE00
 LDA #LO(&1200 DIV 8)
 STA &FE01
.fb
 LDA #LO(PA)
 STA VIA+6
 LDA #HI(PA)
 STA VIA+7
.tdone
 LDA VIA+4              \ clear timer 1's flag
 PLA
 TAX
 LDA &FC
 RTI

\ R0-R13 for each CRTC frame (R0-R3, R8-R11 as MODE 1 but 64 characters
\ wide, as the Master port's screen: R1 = 64, R2 = 90)
.rega EQUB 127, 64, 90, &28, 23, 0, 24, 127, 0, 7, &20, 0, HI(&7200 DIV 8), LO(&7200 DIV 8)
.regb EQUB 127, 64, 90, &28, 14, 0, 7, 10, 0, 7, &20, 0, HI(&1200 DIV 8), LO(&1200 DIV 8)
.phase EQUB 0
.front EQUB 0
.fields EQUB 0
SAVE "build/spike-rupture.bin", start, P%
PRINT "rupture front ", ~front, " fields ", ~fields, " phase ", ~phase
