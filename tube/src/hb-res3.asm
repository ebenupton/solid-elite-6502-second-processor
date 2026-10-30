\ hb-res3.asm - the Model B host's main RAM code (hb-res.asm): hb_pers: at MR_E, not swapped for disc commands

.hwrch                  \ WRCHV while the MOS's Tube code runs the host: &FE
 CMP #&FE               \ from the parasite starts the command loop; anything
 BNE hwr1               \ else is printed (CHPR, bank F)
 PAGE GFXBANK
 JMP hstart
.hwr1
 STA hwa
 TXA
 PHA
 TYA
 PHA
 LDA &F4
 PHA
 PAGE GFXBANK
 LDA hwa
 JSR hwprint
 PLA
 STA &F4
 STA &FE30
 PLA
 TAY
 PLA
 TAX
 LDA hwa
 RTS
.hwa EQUB 0

.hdbrk                  \ (BRKV during h_disc's OSCLI: the bank of h_derr)
 PAGE GFXBANK
 JMP h_derr

.irqm                   \ IRQ1V: register 4's requests (bank F's h4body, while
 BIT h4on               \ h4on), timer 1 or vsync are ours (bank F's hb_irq,
 BPL irq0               \ with the bank kept); anything else is the MOS's
 BIT HR4S
 BPL P%+5
 JMP irq4
.irq0
 LDA &FE4D
 AND #%01000010
 BNE irq1
 JMP (hbirqv)
.irq1
 AND #%01000000         \ timer 1: the rupture (hbi_t), A only
 BNE hbi_t
 TXA                    \ vsync
 PHA
 TYA
 PHA
 LDA &F4
 PHA
 PAGE GFXBANK
 JSR hb_irq
.irq9
 PLA
 STA &F4
 STA &FE30
 PLA
 TAY
 PLA
 TAX
 LDA &FC
 RTI

\ hbi_t: timer 1, twice a field, the CRTC vertical rupture (hb-irq.asm): A
\ only, and point 2 with no paging. Each point writes the registers that
\ differ between the two frames, R4, R6, R7 and R12 (R13 is 0 for every
\ start address, hb_t1init's), and the latch's high byte (the low bytes of
\ HB_PA and HB_PB are the same, hb_t1init's)
.hbi_t
 LDA hb_phase
 EOR #1
 STA hb_phase
 BEQ hbi_p1m
 LDA #4                 \ point 2, line 8 (frame A has started): frame A's
 STA &FE00              \ R4, R6, R7, and the panel's address for frame B
 LDA #23
 STA &FE01
 LDA #6
 STA &FE00
 LDA #24
 STA &FE01
 LDA #7
 STA &FE00
 LDA #127
 STA &FE01
 LDA #12
 STA &FE00
 LDA #HI(PANEL DIV 8)
 STA &FE01
 LDA #HI(HB_PB)
 STA &FE47
 LDA &FE44              \ (clears timer 1's flag)
 LDA &FC
 RTI
.hbi_p1m                \ point 1: bank F's hbi_p1 (the flip's state is there)
 LDA &F4
 PHA
 PAGE GFXBANK
 JMP hbi_p1
.hbi_px                 \ (hbi_p1's way back)
 PLA
 STA &F4
 STA &FE30
 LDA &FC
 RTI
.hb_phase EQUB 0
.hbirqv EQUW 0          \ the MOS's IRQ1V, as hstart found it
.h4on EQUB 0            \ bit 7: register 4's requests are ours (h4body)
.irq4
 TXA
 PHA
 TYA
 PHA
 LDA &F4
 PHA
 PAGE GFXBANK
 JSR h4body
 JMP irq9

.hbswap                 \ exchange main RAM's &0236-&0CFF, &0E00-&10FF with the
 PAGE STASHBANK         \ stash bank's copy (the MOS's while the game runs,
 LDX #0                 \ ours while a disc command does). Interrupts off.
.hbs1                   \ After the first (hstart's), &0400-&06FF is left out
FOR p, &0300, &0300, &100  \ (hbsk: the MOS's Tube code, which the MOS no longer
 LDA p,X
 LDY HBS_IMG + (p - &0236),X
 STA HBS_IMG + (p - &0236),X
 TYA
 STA p,X
NEXT
.hbsk                   \ calls once hstart has cleared &027A)
 BIT hbs4               \ (JMP hbs4 after the first)
FOR p, &0400, &0600, &100
 LDA p,X
 LDY HBS_IMG + (p - &0236),X
 STA HBS_IMG + (p - &0236),X
 TYA
 STA p,X
NEXT
.hbs4
FOR p, &0700, &0C00, &100
 LDA p,X
 LDY HBS_IMG + (p - &0236),X
 STA HBS_IMG + (p - &0236),X
 TYA
 STA p,X
NEXT
FOR p, &0E00, &1000, &100
 LDA p,X
 LDY HBS_IMG + &0ACA + (p - &0E00),X
 STA HBS_IMG + &0ACA + (p - &0E00),X
 TYA
 STA p,X
NEXT
 INX
 BEQ hbs2
 JMP hbs1
.hbs2
 LDX #&CA - 1           \ and &0236-&02FF
.hbs3
 LDA &0236,X
 LDY HBS_IMG,X
 STA HBS_IMG,X
 TYA
 STA &0236,X
 DEX
 CPX #&FF
 BNE hbs3
 PAGE GFXBANK
 RTS
