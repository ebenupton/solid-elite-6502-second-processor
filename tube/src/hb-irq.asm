\ ******************************************************************************
\
\ hb-irq.asm - the Model B host's interrupts (bank F, through hb-res.asm's
\ irqm), NMOS: the dashboard split by a CRTC vertical rupture
\ (tube/spike/rupture.asm), the flip, the sound and the joystick.
\
\ Each 312-line field is two CRTC frames: frame A, 24 character rows (192
\ lines) of the buffer shown, with no vsync, then frame B, 15 rows of which 7
\ (56 lines) show the panel, with vsync at its row 10. The 6845 latches its
\ start address at each frame's start, so timer 1, free running and firing
\ twice a field (latches PA and PB in turn), sets each frame's registers
\ while the other runs:
\   point 2, line 8 (frame A has started): frame A's R4, R6, R7, and the
\     panel's address for frame B;
\   point 1, line 196 (frame B has started): frame B's, and the address of
\     the buffer to show next (GFRONT: 0 BUF0, 1 &4000), which is where a flip
\     takes effect. Frame A has ended, and the panel is single buffered, so
\     the old front buffer is not read again this field: GFLIP is cleared
\     here, and the host draws into it at once.
\ The vsync interrupt (CA1) does what the Master port's does: the sound
\ (SOINT), DL, and one joystick channel (the Model B's ADC at &FEC0).
\
\ ******************************************************************************

HB_LINE = 64            \ us per line
HB_PA = 188 * HB_LINE - 2   \ point 2 to point 1 (the latch counts N+2 us)
HB_PB = 124 * HB_LINE - 2   \ point 1 to point 2

.hb_irq
 LDA &FE4D
 AND #%01000000
 BNE hbi_t
 LDA &FE41              \ vsync: clear CA1's flag
 LDA #72                \ (VSCAN+1, as the Master port's LINSCN)
 STA DL
 BIT hwsp               \ a pending C_WSCAN answered (h4body)
 BPL hbi_w
 LDA #0
 STA hwsp
 LDA #72
 HTX
.hbi_w
 LDA &FEC0              \ the joystick: the finished channel's value, then
 AND #3                 \ the next channel's conversion (8-bit)
 TAY
 LDA &FEC1
 STA JOPOS,Y
 INY
 CPY #3
 BCC P%+4
 LDY #0
 STY &FEC0
 JMP SOINT              \ (bank F; returns to irqm)

.hb_vl EQUB 0           \ (point 1: non-zero if the last field flipped)
.hbi_t
 LDA hb_phase
 EOR #1
 STA hb_phase
 BEQ hbi_p1
 LDX #4                 \ point 2
 LDA hb_r6a
 LDY #23
 JSR hb_regs
 LDA #12
 STA &FE00
 LDA #HI(PANEL DIV 8)
 STA &FE01
 LDA #13
 STA &FE00
 LDA #LO(PANEL DIV 8)
 STA &FE01
 LDA #LO(HB_PB)
 STA &FE46
 LDA #HI(HB_PB)
 STA &FE47
 LDA &FE44              \ (clears timer 1's flag)
 RTS
.hbi_p1                 \ point 1: frame B, then the buffer to show next
 LDA #7
 LDY #14
 JSR hb_regs
 LDA GFLIP              \ (a pending flip, as the Master host's H_SPLIT; 25
 BEQ hbi_1n             \ frames a second at most, as the Master port's cap: a
 LDA hb_vl              \ flip pending at the field straight after the last
 BNE hbi_1n             \ flip is held one field)
 LDA GPEND
.hbi_flip               \ (tube/tools/tflips.mjs counts the flips here)
 STA GFRONT
 LDA #0                 \ (the old front buffer is free now)
 STA GFLIP
 LDA #1
 STA hb_vl
 BNE hbi_1a
.hbi_1n
 LDA #0
 STA hb_vl
.hbi_1a
 BIT GMODE              \ not double buffered: buffer 1, the direct screen
 BMI hbi_1b
 LDA #1
 STA GFRONT
.hbi_1b
 LDX GFRONT
 LDA #12
 STA &FE00
 LDA hb_sah,X
 STA &FE01
 LDA #13
 STA &FE00
 LDA hb_sal,X
 STA &FE01
 LDA #LO(HB_PA)
 STA &FE46
 LDA #HI(HB_PA)
 STA &FE47
 LDA &FE44
 RTS

.hb_regs                \ R4 = Y, R6 = A, R7 = 127 (frame A, A = 24 or less)
 PHA                    \ or 10 (frame B, A = 7)
 LDA #4
 STA &FE00
 STY &FE01
 LDA #6
 STA &FE00
 PLA
 STA &FE01
 LDA #7
 STA &FE00
 CPY #23
 LDA #127
 BCS P%+4
 LDA #10
 STA &FE01
 RTS

.hb_t1init              \ start the rupture (interrupts off; leaves them on)
 LDY #23                \ (a field as one frame, vsync at row 34, whatever state a
 LDA #31                \ disc command left the rupture in: R4 = 38 via hb_regs'
 JSR hb_regs            \ frame A case, then R4, R7 by hand)
 LDA #4
 STA &FE00
 LDA #38
 STA &FE01
 LDA #7
 STA &FE00
 LDA #34
 STA &FE01
 LDA #8                 \ no interlace (fields of 312 lines exactly: the timer's
 STA &FE00              \ period) and no vertical adjust
 LDA #0
 STA &FE01
 LDA #5
 STA &FE00
 LDA #0
 STA &FE01
 LDA #%01111111         \ System VIA: timer 1 and CA1 (vsync) only, none from
 STA &FE4E              \ the User VIA
 LDA #%11000010
 STA &FE4E
 LDA #%01111111
 STA &FE6E
 LDA #%00000010         \ wait for vsync
 STA &FE4D
.hbt1
 BIT &FE4D
 BEQ hbt1
 LDA #LO(48*HB_LINE-200) \ point 2 next: 48 lines on (line 8)
 STA &FE44
 LDA #HI(48*HB_LINE-200)
 STA &FE45
 LDA #LO(HB_PA)         \ then point 1, 188 lines on
 STA &FE46
 LDA #HI(HB_PA)
 STA &FE47
 LDA #0
 STA hb_phase
 CLI
 RTS

.hb_phase EQUB 0
.hb_r6a   EQUB 24       \ frame A's R6 (DET1's)
.hb_sah EQUB HI(BUF0 DIV 8), HI(&4000 DIV 8)
.hb_sal EQUB LO(BUF0 DIV 8), LO(&4000 DIV 8)

.hwprint                \ hwrch's printing in the MOS (a catalogue): CHPR with
 JSR hctxsw             \ its zero page swapped for the command's (hctx)
 LDA hwa
 JSR CHPR
 JSR hwpos
 JMP hctxsw
