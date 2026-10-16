\ ******************************************************************************
\
\ gfx-hooks.asm - the glue between Master Elite's drawing code and the frame
\ layer (after the Demonstration Disc port's src/hooks.asm)
\
\ Lives in HAZEL (&C000-&DFFF, always visible once the loader has set ACCCON
\ bit Y). Elite's drawing routines call these with a single JSR at their
\ start. "Record mode" is QQ11 = 0 (a view that draws ships) and GFORCE = 0:
\ drawing is then recorded for FRAME instead of being done. A hook that takes
\ over pulls its return address (PLA : PLA) so its RTS returns from the hooked
\ routine itself.
\
\ ******************************************************************************

.hA EQUB 0

\ H_MFRAME: a main-loop iteration (M%), then the frame (TT100, and DEATH's
\ two M% calls)

.H_MFRAME
 JSR M%
                        \ fall through into hframe

\ hframe: the frame (bank 4 paged), preserving A, X, Y and the flags (the main
\ loop carries on with what M% left). LL9F (bank 4: LL9 then the frame, for
\ the title screen's rotating ship) jumps here.

.hframe
 PHP
 PHA
 PHX
 PHY
 JSR G_FRAME
 PLY
 PLX
 PLA
 PLP
 RTS

\ H_CIRC: CIRCLE in record mode records the planet disc instead (PL9 is about
\ to draw the planet's circle) and returns from CIRCLE as CIRCLE2 would:
\ C clear, LSX2 = 0 (the ball line heap in use), FLAG = 0, STP = 8, 4 or 2
\ by the radius and CNT = the first multiple of STP above 64. If the circle
\ isn't on screen (CHKON), C set as CIRCLE returns

.H_CIRC
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA
 PLA
 JSR CHKON
 BCC P%+3
 RTS
 JSR G_PLANET
 LDA #0
 STA LSX2
 STA FLAG
 LDX K
 LDA #8
 LDY #72
 CPX #8
 BCC hci1
 LDA #4
 LDY #68
 CPX #60
 BCC hci1
 LDA #2
 LDY #66
.hci1
 STA STP
 STY CNT
 CLC
 RTS

\ H_WPLS2: in record mode the planet's lines are not on screen: just reset the
\ ball line heap (WP1)

.H_WPLS2
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA
 PLA
 JMP WP1

\ H_BLOIN: BLINE's line (planet meridians, craters, the hyperspace rings):
\ drawn only outside record mode (in record mode the frame layer fills the
\ planet's detail from BLINE's points instead). Y preserved, as LOIN

.H_BLOIN
 LDA QQ11
 ORA GFORCE
 BEQ P%+5
 JMP LOIN
 RTS

\ H_PCURVE: PLS22 is about to compute an ellipse (TGT segments): start a new
\ curve. H_BPT: BLINE has the next point in K6(1 0), K6(3 2): record it.
\ Both preserve X, Y and C (the callers set A and the other flags straight
\ after)

.H_PCURVE
 LDA QQ11
 ORA GFORCE
 BNE hpc9
 JMP G_PCURVE

.H_BPT
 LDA QQ11
 ORA GFORCE
 BNE hpc9
 JMP G_PPOINT
.hpc9
 RTS
