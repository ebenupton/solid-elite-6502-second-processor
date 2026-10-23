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
IF _HOSTB
 LDA IRQ1V              \ (Model B: the MOS's IRQ1V, for what is not ours)
 STA hbirqv
 LDA IRQ1V+1
 STA hbirqv+1
ENDIF
.hst1
IF _HOSTB
 JSR hbswap             \ (Model B: our main RAM in, the MOS's out)
ENDIF
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
 LDA #&81               \ the Tube's Q: the host's IRQ from register 4's data
 STA HR1S               \ (the fast requests, h4body), and those on (h4on)
 LDA #&80
 STA h4on
IF _HOSTB
 LDA #LO(irqm)          \ (Model B: the rupture, hb-irq.asm)
 STA IRQ1V
 LDA #HI(irqm)
 STA IRQ1V+1
 CLD
 JSR hb_t1init
 JMP hloop
ELSE
 LDA #%00111001         \ as SETINTS: no CB1, CB2, CA2 or T2 interrupts from the
 STA VIA+&4E            \ System VIA, none from the User VIA, IRQ1V = IRQ1
 LDA #%01111111
 STA &FE6E
 LDA #LO(h4irq)         \ (register 4's requests first, h-main.asm)
 STA IRQ1V
 LDA #HI(h4irq)
 STA IRQ1V+1
 LDA #GFXBANK           \ (the resting bank: the frame layer's host part)
 STA &F4
 STA &FE30
 CLD
 JSR T1SYNC             \ (CLIs)
 JMP hloop
ENDIF

.hzps SKIP &50          \ the MOS's Tube code's zero page (&00-&4F), as the host
                        \ took over from it
.hzpk EQUB 0            \ non-zero: hzps holds it

\ h_disc: C_DISC (p_oscli): the printing's context (QQ11 OR GFORCE, GMODE,
\ CHPR's zero page and W, CATF), the mode (1 SAVE, 2 LOAD, else 0), for those
\ the parasite's commbuf (256 bytes, into HDBUF), then the command to its CR
\ (into HDSTR): the host's MOS runs it as the host's own I/O (OSCLI, from
\ here, with HDBUF named in the SAVE and LOAD commands: FFFF3F00). Then
\ through register 4: 0, or &FF and the MOS's error (number, message, 0:
\ BRKV's hdbrk, main RAM, brings it to h_derr); the context back; for a load
\ HDBUF back. The client OS on the parasite takes no part

HDBUF = &3F00           \ (main RAM on both hosts: the Master's free &3000-&3FFF
HDSTR = &3E00           \ with ACCCON X clear, the Model B's buffer 0, not on
HDERR = &3E80           \ show in direct mode)

.h_disc
 LDA #0                 \ (the MOS's register 4 while it runs: h4body off)
 STA h4on
 HRX
 STA QQ11
 STZ GFORCE
 HRX
 STA GMODE
 LDX #0
.hds1
 HRX
 STA hctx,X
 INX
 CPX #HCTXN+1
 BNE hds1
 HRX
 STA CATF
IF _HOSTB = 0
 LDA #4                 \ (main RAM at &3000-&3FFF)
 TRB &FE34
ENDIF
 HRX                    \ the mode
 STA hdm
 BEQ hds3
 LDX #0                 \ commbuf into HDBUF
.hds2
 HRX
 STA HDBUF,X
 INX
 BNE hds2
.hds3
 LDX #0                 \ the command
.hds4
 HRX
 STA HDSTR,X
 INX
 CMP #13
 BNE hds4
 TSX                    \ (the error's way back: hdbrk, h_derr)
 STX hdsp
 LDA BRKV
 STA hdbv
 LDA BRKV+1
 STA hdbv+1
 LDA #LO(hdbrk)
 STA BRKV
 LDA #HI(hdbrk)
 STA BRKV+1
IF _HOSTB
 SEI
 JSR hbswap             \ (Model B: the MOS's main RAM in, ours kept)
 CLI
ENDIF
 LDX #LO(HDSTR)
 LDY #HI(HDSTR)
 JSR OSCLI
 LDA #0                 \ done
.hdret                  \ (A = 0, or &FF from h_derr)
 STA hdst
 LDA #GFXBANK           \ (the bank after the MOS's call)
 STA &F4
 STA &FE30
 SEI
 LDA hdbv
 STA BRKV
 LDA hdbv+1
 STA BRKV+1
IF _HOSTB
 JSR hbswap             \ (Model B: ours back)
ENDIF
 JSR HNMI               \ (quieten the 1770, the minimal NMI handler back)
 JSR hdints             \ (the interrupts as hstart sets them: the MOS's command
 LDA hdst               \ may have changed the VIAs' timers and enables)
 HTX
 BEQ hdr2
 LDX #0                 \ the error: number, message, 0
.hdr1
 LDA HDERR,X
 HTX
 INX
 CPX #1
 BEQ hdr1
 CMP #0
 BNE hdr1
.hdr2
 LDX #0                 \ the context back
.hdr3
 LDA hctx,X
 HTX
 INX
 CPX #HCTXN+1
 BNE hdr3
 LDA CATF
 HTX
 LDA hdm                \ a load: HDBUF back (also after an error)
 CMP #2
 BNE hdr5
 LDX #0
.hdr4
 LDA HDBUF,X
 HTX
 INX
 BNE hdr4
.hdr5
 LDA #&80
 STA h4on
 JMP hloop

\ h_derr: the MOS's BRK in the disc command (hdbrk, main RAM, has paged this
\ bank): its error (number, message, 0, from (&FD)) into HDERR, then back

.h_derr
 LDY #0
.hde1
 LDA (&FD),Y
 STA HDERR,Y
 INY
 CPY #1
 BEQ hde1
 CMP #0
 BEQ hde2
 CPY #120
 BCC hde1
 LDA #0
 STA HDERR,Y
.hde2
 LDX hdsp
 TXS
 LDA #&FF
 JMP hdret

.hdints
IF _HOSTB
 JSR hb_t1init
 CLI
 RTS
ELSE
 LDA #%00111001
 STA VIA+&4E
 LDA #%01111111
 STA &FE6E
 JMP T1SYNC             \ (CLIs)
ENDIF

.hdm  EQUB 0
.hdst EQUB 0
.hdsp EQUB 0
.hdbv EQUW 0
.hmos EQUB 0

\ HNMI: after a disc command, as the Master port's DOSNMI: 1770 Force
\ Interrupt, then the minimal NMI handler at &0D00 (RTI, then its body, then
\ PHA): the one write the host makes to page &0D

.HNMI
IF _HOSTB
 RTS                    \ (Model B: DFS 1.2's 8271, no 1770 to quieten)
ENDIF
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
