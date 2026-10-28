\ ******************************************************************************
\
\ gfx-lowhooks.asm - the hooks that must live in main RAM below &3000 (the
\ low area, elite-low.asm): the text map's (CHPR runs as WRCHV with any ROM
\ paged and with ACCCON X set, which hides main RAM above &3000) and the
\ IRQ's (H_VSYNC, H_SPLIT); split from gfx-hooks.asm
\
\ ******************************************************************************

.hA EQUB 0                \ (also read by F_DSTAR in bank 6)

\ The text map: CHPR (WRCHV, so any ROM may be paged: the cold area, or DFS
\ printing a catalogue) and CLYNS keep the frame layer's text map up to date
\ in record and space mode, and outside them note what the screen's text does
\ to it (gfx-frame.asm's text map, gfx-frame_cold.asm's F_CHAR), and draw on
\ the screen only outside record mode. These stubs page bank 6 in and the
\ caller's bank (&F4, ANDY included) back, and live below &3000 as CHPR runs
\ with ACCCON X set. A, X, Y are not kept (F_DELCHAR keeps Y, F_CLRTEXT X and
\ Y)

IF _TPART <> 2 OR _TDUMB = FALSE   \ (the dumb host: no text map, the parasite's)
.G_CHAR
 LDA &F4
 PHA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 JSR F_CHAR
 BRA gtxt

.G_DELCHAR
 LDA &F4
 PHA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 JSR F_DELCHAR
 BRA gtxt

.G_CLRTEXT
 LDA &F4
 PHA
 LDA #GFXBANK
 STA &F4
 STA &FE30
 JSR F_CLRTEXT
.gtxt
 PLA
 STA &F4
 STA &FE30
 RTS

\ H_CHAR: CHPR (RR3) is about to draw the character in K3 at (XC-1, YC), with
\ A = YC: record it in the text map, and in record mode, or in space mode
\ (GMODE bit 7: the frames are running, as in the mission briefing, whose
\ text is printed in view types 13 and 1 while LL9B draws the ship as a
\ frame), return through RR4 instead of drawing it (A = YC and C clear
\ otherwise, as RR3 is entered)
ENDIF


.H_CHAR
 STA hA
IF _TPART <> 2 OR _TDUMB = FALSE   \ (the dumb host: no text map, the parasite's)
 JSR G_CHAR
ENDIF
 LDA QQ11
 ORA GFORCE
 BEQ hcr
 BIT GMODE
 BPL hcd
.hcr
 PLA
 PLA
 LDA hA                 \ leave SC(1 0), P(3 2) and W as RR3, RREN and RRL1 do
 ASL A
 ASL SC
 ADC #&40
 STA SC+1
 LDA SC
 CLC
 ADC #8
 STA P+2
 LDA SC+1
 STA P+3
 LDY #0
 LDA (P),Y
 AND #%00001111
 STA W
 JMP RR4
.hcd
 LDA hA
 CLC
 RTS

\ H_DEL: CHPR is deleting the character at (XC, YC) (after its DEC XC): the
\ text map too; in record mode return through RR4 instead of blanking it

.H_DEL
 PHA
IF _TPART <> 2 OR _TDUMB = FALSE   \ (the dumb host: no text map, the parasite's)
 JSR G_DELCHAR
ENDIF
 LDA QQ11
 ORA GFORCE
 BNE hdl9
 PLA
 PLA
 PLA
 JMP RR4
.hdl9
 PLA
 RTS


\ H_VSYNC: called by IRQ1 at vertical sync (A only): a pending flip makes
\ GPEND the front buffer; in direct mode the front buffer is shadow RAM
\ (buffer 1); ACCCON D shows it (the timer 1 interrupt at the dashboard sets
\ D = 1 again, as the dashboard is in shadow RAM). Only D is touched, so the
\ main code's ACCCON X is kept

IF _HOSTB = 0             \ (Model B: hb-irq.asm's)
IF _TDUMB AND _TPART = 2
.GVLAST EQUB 0          \ (H_SPLIT: non-zero if the last split flipped)

\ H_SPLIT: the Tube's Master host, called by IRQ1 at the panel's top (timer 1,
\ A only). The panel is single buffered, so the 3D view's front buffer is not
\ read again this field: a pending flip is decided here, GPEND becomes the
\ front buffer (shown from the next field: H_VSYNC sets ACCCON D from GFRONT
\ at the vsync) and the old front buffer is free to draw into at once
\ (GFLIP clear). 25 frames a second at most, as the Master port's cap: a flip
\ pending at the split straight after the last flip is held one field, so a
\ frame is on show for two fields at least

.H_SPLIT
 LDA GFLIP
 BEQ hsp0
 LDA GVLAST
 BNE hsp0
 LDA GPEND
.hv_flip                \ (tube/tools/tflips.mjs counts the flips here)
 STA GFRONT
 STZ GFLIP
 LDA #&FF               \ (this split flipped)
 STA GVLAST
 RTS
.hsp0
 STZ GVLAST             \ (no flip at this split)
 RTS
ENDIF
.H_VSYNC
IF _TDUMB AND _TPART = 2   \ (the Tube's host: a pending C_WSCAN answered, h4body)
 BIT hwsp
 BPL hv9
 STZ hwsp
 LDA #72
 HTX
.hv9
ENDIF
IF _TDUMB = FALSE OR _TPART <> 2   \ (the Tube's Master host: H_SPLIT flips)
 LDA GFLIP
 BEQ hv0
 LDA GPEND
.hv_flip                \ (tube/tools/tflips.mjs counts the flips here)
 STA GFRONT
 STZ GFLIP
.hv0
ENDIF
 BIT GMODE
 BMI hv1
 LDA #1
 STA GFRONT
.hv1
 LDA #1
 BIT GFRONT
 BEQ hv2
 TSB &FE34
 RTS
.hv2
 TRB &FE34
 RTS
ENDIF

