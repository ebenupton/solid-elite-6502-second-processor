#!/usr/bin/env python3
"""Regenerates the r7_line block of src/raster7.asm (bank 7 line drawing:
setup, clipping walk and the 8 unrolled pixel loops).  Run after editing."""
import os
p=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src', 'raster7.asm')
s=open(p).read()
a=s.index("\\ ============================================================================\n\\ r7_line: R_LINE for 8-bit end points")
b=s.index('.r7_end\n')
sites=[]
def loop(name, major, sdir, clip):
    L=[]; A=L.append
    A('.%s' % name)
    A('  LDA (RZ_PP),Y'); A('  EOR r7_lct,Y'); A('  AND l_m'); A('  EOR (RZ_PP),Y'); A('  STA (RZ_PP),Y')
    A('  LDA l_x')
    for k,arr in enumerate('LLRR'):
        lab='%s_p%d' % (name,k); sites.append((lab,arr))
        if k==0: A('.^%s CMP R_DIRTY%s0,X' % (lab,arr)); A('  BCS %s_1' % name)
        if k==1: A('.^%s STA R_DIRTY%s0,X' % (lab,arr)); A('.%s_1' % name)
        if k==2: A('.^%s CMP R_DIRTY%s0,X' % (lab,arr)); A('  BCC %s_2' % name)
        if k==3: A('.^%s STA R_DIRTY%s0,X' % (lab,arr)); A('.%s_2' % name)
    A('  DEC l_n'); A('  BEQ %s_d' % name)
    def ydown():
        A('  INX')
        if clip: A('  CPX r7_cb1'); A('  BCS %s_d' % name)
        A('  INY'); A('  CPY #8'); A('  BNE %s_y' % name); A('  LDY #0'); A('  LDA RZ_PP+1'); A('  ADC #1'); A('  STA RZ_PP+1')
        A('.%s_y' % name)
    def yup():
        A('  DEX')
        if clip: A('  CPX R_CT'); A('  BCC %s_d' % name)
        A('  DEY'); A('  BPL %s_y' % name); A('  LDY #7'); A('  LDA RZ_PP+1'); A('  SEC'); A('  SBC #2'); A('  STA RZ_PP+1')
        A('.%s_y' % name)
    def xright(t):
        A('  INC l_x')
        if clip: A('  LDA l_x'); A('  CMP r7_cr1'); A('  BCS %s_d' % name)
        A('  LSR l_m'); A('  BCC %s' % t); A('  LDA #&88'); A('  STA l_m'); A('  LDA RZ_PP'); A('  ADC #7'); A('  STA RZ_PP')
        A('  BCC %s' % t); A('  INC RZ_PP+1'); A('  BRA %s' % t)
    def xleft(t):
        A('  DEC l_x')
        if clip: A('  LDA l_x'); A('  CMP R_CL'); A('  BCC %s_d' % name)
        A('  ASL l_m'); A('  BCC %s' % t); A('  LDA #&11'); A('  STA l_m'); A('  LDA RZ_PP'); A('  SEC'); A('  SBC #8'); A('  STA RZ_PP')
        A('  BCS %s' % t); A('  DEC RZ_PP+1'); A('  BRA %s' % t)
    if major=='y':
        ydown()
        A('  LDA l_e'); A('  CLC'); A('  ADC l_a'); A('  STA l_e'); A('  BCC %s' % name)
        A('  SBC l_b'); A('  STA l_e')
        (xright if sdir>0 else xleft)(name)
    else:
        A('  LDA l_e'); A('  CLC'); A('  ADC l_a'); A('  STA l_e'); A('  BCC %s_x' % name)
        A('  SBC l_b'); A('  STA l_e')
        (ydown if sdir>0 else yup)()
        A('.%s_x' % name)
        xright(name)
    A('.%s_d' % name); A('  RTS')
    return '\n'.join(L)+'\n'
loops=''
for clip,suf in ((False,''),(True,'c')):
    loops+=loop('lyl'+suf,'y',-1,clip)+loop('lyr'+suf,'y',1,clip)+loop('lxu'+suf,'x',-1,clip)+loop('lxd'+suf,'x',1,clip)
patchL=''.join('  STA %s+2\n' % l for l,a in sites if a=='L')
patchR=''.join('  STA %s+2\n' % l for l,a in sites if a=='R')
code=r'''\ ============================================================================
\ r7_line: R_LINE for 8-bit end points (0..255), R_LINE's pixels (Bresenham
\ along the major axis from the left / top end).  Pointer RZ_PP (+ Y = row
\ AND 7), pixel mask l_m, colour by row AND 7 (r7_lct); X = row; DIRTY[b][row]
\ extended per pixel; the buffer's row range per line.  r7_line: both ends
\ inside the window.  r7_linec: otherwise; the pixels before the first one
\ inside the window are stepped over, and the loops stop at the first one
\ past it (the pixels inside are one run: x and y are monotonic).
\ ============================================================================
l_x0 = &18
l_y0 = &19
l_x1 = &1A
l_y1 = &1B
l_e  = &1C
l_m  = &1D
l_n  = &1E
l_a  = &1F
l_b  = &20
l_x  = &21
l_k  = &22              \ kind (0..3)
l_c  = &23              \ 0: inside, 8: clipped

.r7_lct SKIP 8          \ colour byte by row AND 7
.r7_ldl EQUB HI(R_DIRTYL0), HI(R_DIRTYL1)
.r7_ldr EQUB HI(R_DIRTYR0), HI(R_DIRTYR1)
.r7_lbuf EQUB &FF       \ buffer the loops are patched for
.r7_cr1 EQUB 0          \ CR + 1
.r7_cb1 EQUB 0          \ CB + 1

.r7_linec
  LDA #8
  BRA r7_lgo
.r7_line
  LDA #0
.r7_lgo
{
  STA l_c
  LDX R_PRBUF
  CPX r7_lbuf
  BEQ pd
  STX r7_lbuf
  LDA r7_ldl,X
''' + patchL + '''  LDA r7_ldr,X
''' + patchR + r'''.pd
  LDY #6
.ct
  LDA R_COLE
  STA r7_lct,Y
  LDA R_COLO
  STA r7_lct+1,Y
  DEY
  DEY
  BPL ct
  LDA R_X0
  STA l_x0
  LDA R_Y0
  STA l_y0
  LDA R_X1
  STA l_x1
  LDA R_Y1
  STA l_y1
  SEC
  LDA l_x1
  SBC l_x0
  BCS a1
  EOR #&FF
  INC A
.a1
  STA l_a                 \ |dx|
  SEC
  LDA l_y1
  SBC l_y0
  BCS a2
  EOR #&FF
  INC A
.a2
  STA l_b                 \ |dy|
  CMP l_a
  BCC xm
  BEQ xm
  LDA l_y1                \ y major: from the top end
  CMP l_y0
  BCS y1
  JSR swap
.y1
  LDA l_b                 \ steps = dy, e = (dy DIV 2) - dy, a = |dx|, b = dy
  JSR start
  LDA l_x1
  CMP l_x0
  LDA #0
  ROL A                   \ 0: x decreases, 1: increases
  BRA go
.xm
  LDA l_x1                \ x major: from the left end
  CMP l_x0
  BCS x1
  JSR swap
.x1
  LDX l_a                 \ a = |dy|, b = |dx|
  LDY l_b
  STX l_b
  STY l_a
  TXA
  JSR start
  LDA l_y1
  CMP l_y0
  LDA #1
  ROL A                   \ 2: y decreases, 3: increases
.go
  STA l_k
  INC l_n                 \ pixels = steps + 1 (0: 256)
  LDX l_y0                \ X = row, l_x = x
  LDA l_c
  BEQ in
  JSR clip                \ clipped: to the first pixel inside (C = 1: none)
  BCC in
  RTS
.in
  LDA l_y0                \ the byte of (l_x, row X): RZ_PP + Y
  LSR A
  LSR A
  AND #&FE
  ORA #&40
  STA RZ_PP+1
  LDA l_x
  AND #&FC
  ASL A
  STA RZ_PP
  BCC s1
  INC RZ_PP+1
.s1
  LDA l_x
  AND #3
  TAY
  LDA r7_lm,Y             \ pixels x..3 AND pixels 0..x = pixel x
  AND r7_rm,Y
  STA l_m
  LDA l_k
  ORA l_c
  ASL A
  TAY
  LDA tab,Y
  STA jp+1
  LDA tab+1,Y
  STA jp+2
  TXA
  AND #7
  TAY
.jp
  JMP &FFFF
.tab
  EQUW lyl, lyr, lxu, lxd, 0, 0, 0, 0, lylc, lyrc, lxuc, lxdc
.swap
  LDX l_x1
  LDY l_x0
  STX l_x0
  STY l_x1
  LDX l_y1
  LDY l_y0
  STX l_y0
  STY l_y1
  RTS
\ start: A = steps: l_n = A, l_e = (A DIV 2) - l_b, l_x = x0, the buffer's
\ dirty rows += y0..y1 (in the window)
.start
  STA l_n
  LSR A
  SEC
  SBC l_b
  STA l_e
  LDA l_x0
  STA l_x
  LDX R_PRBUF
  LDA l_y0
  LDY l_y1
  CMP l_y1
  BCC t0
  TAY
  LDA l_y1
.t0
  CMP R_CT                \ A = top, Y = bottom (clamped to the window)
  BCS t1
  LDA R_CT
.t1
  CMP R_PRDYT,X
  BCS t2
  STA R_PRDYT,X
.t2
  TYA
  CMP R_CB
  BCC t3
  LDA R_CB
.t3
  CMP R_PRDYB,X
  BCC t4
  STA R_PRDYB,X
.t4
  RTS
\ clip: step from pixel 0 (l_x, row X) over the pixels outside the window
\ (l_n counting down, l_e as the loops); C = 1 if none is inside.  Then
\ l_y0 = the row.  Bounds for the loops: r7_cr1, r7_cb1.
.clip
  LDA R_CR
  INC A
  STA r7_cr1
  LDA R_CB
  INC A
  STA r7_cb1
.cl
  CPX R_CT                \ inside?
  BCC out
  CPX r7_cb1
  BCS out
  LDA l_x
  CMP R_CL
  BCC out
  CMP r7_cr1
  BCS out
  STX l_y0
  CLC
  RTS
.out
  DEC l_n
  BNE step
  SEC
  RTS
.step
  LDA l_k                 \ major step, then minor if the error carries
  CMP #2
  BCS sx
  INX                     \ y major: y + 1
  LDA l_e
  CLC
  ADC l_a
  STA l_e
  BCC cl
  SBC l_b
  STA l_e
  LDA l_k
  BEQ sxl
  INC l_x
  BRA cl
.sxl
  DEC l_x
  BRA cl
.sx
  INC l_x                 \ x major: x + 1
  LDA l_e
  CLC
  ADC l_a
  STA l_e
  BCC cl
  SBC l_b
  STA l_e
  LDA l_k
  CMP #3
  BEQ syd
  DEX
  BRA cl
.syd
  INX
  BRA cl
''' + loops + '}\n\n'
s=s[:a]+code+s[b:]
open(p,'w').write(s)
