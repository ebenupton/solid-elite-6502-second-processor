\ ******************************************************************************
\
\ h-cold.asm - the host's rarely run code, in bank 6 (the resting bank, so
\ the command loop reaches it directly): the command loop's start (from
\ hwrch, which pages bank 6), the disc command's way into the MOS and back,
\ and the exchange of the parasite's high area
\
\ ******************************************************************************

.hstart
 LDX #&FF
 TXS
 SEI
 LDA hzpk               \ the first time, keep the MOS's Tube code's zero page
 BNE hst1               \ (its transfer state and idle loop) for the disc
 LDX #&4F               \ commands
.hst0
 LDA &00,X
 STA hzps,X
 DEX
 BPL hst0
 DEC hzpk
.hst1
 BIT hmos               \ back from a disc command: quieten the 1770, put the
 BPL hst2               \ minimal NMI handler back (DFS installed its own), and
 JSR HNMI               \ return the printing's zero page to the parasite
 LDX #0
.hst3
 LDA hctx,X
 HTX
 INX
 CPX #HCTXN+1
 BNE hst3
 LDA CATF
 HTX
 STZ hmos
.hst2
 LDA #%00111001         \ as SETINTS: no CB1, CB2, CA2 or T2 interrupts from the
 STA VIA+&4E            \ System VIA, none from the User VIA, IRQ1V = IRQ1
 LDA #%01111111
 STA &FE6E
 LDA #LO(IRQ1)
 STA IRQ1V
 LDA #HI(IRQ1)
 STA IRQ1V+1
 LDA #GFXBANK           \ (the resting bank: the frame layer's host part)
 STA &F4
 STA &FE30
 CLD
 JSR T1SYNC             \ (CLIs)
 JMP hloop

.hzps SKIP &50          \ the MOS's Tube code's zero page (&00-&4F), as the host
                        \ took over from it
.hzpk EQUB 0            \ non-zero: hzps holds it

.h_oscli
 HRX
 STA QQ11
 STZ GFORCE
 HRX
 STA GMODE
 LDX #0
.hos1
 HRX
 STA hctx,X
 INX
 CPX #HCTXN+1
 BNE hos1
 HRX
 STA CATF
 SEI
 LDX #&4F
.hos2
 LDA hzps,X
 STA &00,X
 DEX
 BPL hos2
 LDA #&FF
 STA hmos
 LDA #0                 \ (ready)
 HTX
 JMP &0032              \ (the MOS's Tube idle loop: LDX #&FF : TXS : CLI ...)
.hmos EQUB 0

\ HNMI: after a disc command, as the Master port's DOSNMI: 1770 Force
\ Interrupt, then the minimal NMI handler at &0D00 (RTI, then its body, then
\ PHA): the one write the host makes to page &0D

.HNMI
 SEI
 LDA #&D0
 STA &FE28
 LDA #8
.hnm1
 DEC A
 BNE hnm1
 LDA &FE28
 LDA #&40
 STA &0D00
 LDA #&AD
 STA &0D01
 LDA #&28
 STA &0D02
 LDA #&FE
 STA &0D03
 LDA #&68
 STA &0D04
 LDA #&40
 STA &0D05
 LDA #&48
 STA &0D00
 RTS
.HNMI_END


\ h_swap: C_SWAP: exchange the parasite's &F800-&FEEF with HSW (bank 6, the
\ resting bank), a byte at a time: the parasite's byte in, ours out

.h_swap
 LDA #HI(HSW)
 STA hsw1+2
 STA hsw2+2
 LDY #0
.hsw0
 HRX
 TAX
.hsw1
 LDA HSW AND &FF00,Y    \ (patched)
 HTX
 TXA
.hsw2
 STA HSW AND &FF00,Y    \ (patched)
 INY
 BNE hsw3
 INC hsw1+2
 INC hsw2+2
.hsw3
 LDA hsw1+2             \ the last page's &F0 bytes
 CMP #HI(HSW) + 6
 BNE hsw0
 CPY #&F0
 BNE hsw0
 JMP hloop
