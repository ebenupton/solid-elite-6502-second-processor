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

.irqm                   \ IRQ1V: register 4's requests (bank F's h4body, while
 BIT h4on               \ h4on), timer 1 or vsync are ours (bank F's hb_irq,
 BPL irq0               \ with the bank kept); anything else is the MOS's
 BIT HR4S
 BMI irq4
.irq0
 LDA &FE4D
 AND #%01000010
 BNE irq1
 JMP (hbirqv)
.irq1
 TXA
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
.hbs1
FOR p, &0300, &0C00, &100
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
