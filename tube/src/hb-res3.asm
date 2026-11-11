\ hb-res3.asm - the Model B host's main RAM code (hb-res.asm): hb_pers: at &7E00, beyond the panel, which no disc command touches

.hwrch                  \ WRCHV while the MOS's Tube code runs the host: &FE
 CMP #&FE               \ from the parasite starts the command loop; anything
 BNE hwr1               \ else is printed (CHPR, bank 7)
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

.irqm                   \ IRQ1V: register 4's requests (bank 7's h4body, while
 BIT h4on               \ h4on), timer 1 or vsync are ours (bank 7's hb_irq,
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
.hbi_p1m                \ point 1: bank 7's hbi_p1 (the flip's state is there)
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

.hrw                    \ register 1 empty: ring the parasite's doorbell (h-main.asm's
 BIT HR1S               \ Master copy says how): here, as banks 7 and 4 both call it
 BMI hrw9
 BVC hrw
 STA HR1D
 BVS hrw
.hrw9
 RTS
