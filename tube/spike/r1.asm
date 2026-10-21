\ Phase 0 spike: register 1 (parasite to host) throughput.
\ The parasite writes NP pages of bytes to R1, polling its status (bit 6:
\ not full); the host reads them, polling R1's status (bit 7: data), and
\ stores them. Host code is NMOS 6502.
NP = 16
CPU 0
ORG &3000
.hstart
 SEI
 LDX #0
 LDY #0
.h1
 BIT &FEE0
 BPL h1
 LDA &FEE1
 STA &3400,X
 INX
 BNE h1
 INY
 CPY #NP
 BNE h1
.hdone
 JMP hdone
\ variant 2: a command loop: read a byte, dispatch through a table (the
\ shape of the real host: an opcode then its operands)
.h2start
 SEI
.h2l
 BIT &FEE0
 BPL h2l
 LDA &FEE1
 TAX
 LDA h2tab,X
 STA h2j+1
.h2j
 JMP h2op
.h2op               \ op: three operand bytes
 BIT &FEE0
 BPL h2op
 LDA &FEE1
 STA &70
.h2o2
 BIT &FEE0
 BPL h2o2
 LDA &FEE1
 STA &71
.h2o3
 BIT &FEE0
 BPL h2o3
 LDA &FEE1
 STA &72
 INC &73
 BNE h2l
 INC &74
 LDA &74
 CMP #NP/4
 BNE h2l
.h2done
 JMP h2done
ALIGN 256
.h2tab
 FOR i, 0, 255 : EQUB LO(h2op) : NEXT
SAVE "build/spike-r1-host.bin", hstart, P%

CPU 1
ORG &2000
.pstart
 SEI
 LDX #0
 LDY #0
.p1
 BIT &FEF8
 BVC p1
 STX &FEF9
 INX
 BNE p1
 INY
 CPY #NP
 BNE p1
.pdone
 BRA pdone
SAVE "build/spike-r1-par.bin", pstart, P%
PRINT "hstart ", ~hstart, " hdone ", ~hdone, " h2start ", ~h2start, " h2done ", ~h2done, " pstart ", ~pstart, " pdone ", ~pdone
