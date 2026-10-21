\ Phase 0 spike: register 3 (parasite to host) with the parasite's NMI: the
\ Tube raises the parasite's NMI while M is set and R3's parasite-to-host
\ FIFO is empty, so the parasite's NMI handler sends the next byte of its
\ buffer each time the host takes one, while its main code runs on.
NB = 4096
CPU 0
ORG &3000
.hstart
 SEI
 LDA #&88               \ set M: the parasite's NMI from R3
 STA &FEE0
 LDX #0
 LDY #0
.h1
 BIT &FEE4
 BPL h1
 LDA &FEE5
 STA &3400,X
 INX
 BNE h1
 INY
 CPY #NB DIV 256
 BNE h1
 LDA #&08               \ clear M
 STA &FEE0
.hdone
 JMP hdone
SAVE "build/spike-r3-host.bin", hstart, P%

CPU 1
ORG &2000
.pstart
 SEI
 LDX #0
.pfill                  \ the buffer: 0, 1, 2, ...
 TXA
 STA &4000,X
 INX
 BNE pfill
 LDA #LO(pnmi)
 STA &FFFA
 LDA #HI(pnmi)
 STA &FFFB
 STZ pcnt               \ the main code: count, to see how much time is left
 STZ pcnt+1
 STZ pcnt+2
.ploop
 INC pcnt
 BNE ploop
 INC pcnt+1
 BNE ploop
 INC pcnt+2
 BRA ploop
.pnmi
 PHA
.pnl
 LDA &4000              \ (patched: the next byte)
 STA &FEFD
 INC pnl+1
 PLA
 RTI
.pcnt EQUB 0, 0, 0
SAVE "build/spike-r3-par.bin", pstart, P%
PRINT "r3 hdone ", ~hdone, " pcnt ", ~pcnt, " ploop ", ~ploop
