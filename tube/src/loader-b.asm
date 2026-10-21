\ ******************************************************************************
\
\ loader-b.asm - the Tube version's loader for a BBC Micro Model B host with
\ 64K of sideways RAM (docs/TUBE-MAP.md), NMOS, run at &1900 (above DFS's
\ workspace): the screen mode, the host's images into the first four
\ sideways RAM banks found (D, P, F and the stash bank S, their bank numbers
\ patched in: build/hb-patch.asm), the panel to &7000, hb-res3.asm's part to
\ &7E00, the parasite's code, then WRCHV = hwrch and the parasite started
\ through the MOS's Tube code (as the Master host's loader.asm does).
\
\ ******************************************************************************

 INCLUDE "build/tube-addresses.asm"
 INCLUDE "build/hb-addresses.asm"

 CPU 0
OSWRCH = &FFEE
OSBYTE = &FFF4
OSCLI = &FFF7
BUF = &1C00             \ where each image is loaded before its copy

 ORG &70
.ZP SKIP 2
.PP SKIP 2
.LEN SKIP 2
.PT SKIP 2
.T  SKIP 1
.N  SKIP 1

 ORG &1900
.B%                     \ the screen: as the Master port's (loader.asm), mode 1
 EQUB 22, 1
 EQUB 19, 1, 6, 0, 0, 0
 EQUB 19, 2, 5, 0, 0, 0
 EQUB 19, 3, 3, 0, 0, 0
 EQUB 23, 0, 6, 31, 0, 0, 0, 0, 0, 0
 EQUB 23, 0, 1, 64, 0, 0, 0, 0, 0, 0
 EQUB 23, 0, 2, 90, 0, 0, 0, 0, 0, 0
 EQUB 23, 0, 10, 32, 0, 0, 0, 0, 0, 0
.BEND

.ENTRY
 LDA #16                \ the ADC: no channels sampled by the MOS
 LDX #0
 JSR OSB
 LDA #200               \ ESCAPE off, no memory clearing on BREAK
 LDX #1
 JSR OSB
 LDA #13                \ events off
 LDX #0
 JSR OSB
 LDA #225               \ SHIFT-function keys + 128
 LDX #128
 JSR OSB
 LDA #13
 LDX #2
 JSR OSB
 LDA #4                 \ cursor editing off
 LDX #1
 JSR OSB
 LDA #9                 \ no flashing colours
 LDX #0
 JSR OSB
 LDY #0
.vl
 LDA B%,Y
 JSR OSWRCH
 INY
 CPY #BEND-B%
 BNE vl

 LDX #0                 \ the sideways RAM banks: the first four slots, from 0,
 STX N                  \ where a byte written reads back (a ROM's does not)
.sr1
 SEI
 STX &FE30
 LDA &8008
 EOR #&FF
 STA &8008
 CMP &8008
 PHP
 EOR #&FF               \ (put it back)
 STA &8008
 LDA &F4
 STA &FE30
 CLI
 PLP
 BNE sr2
 TXA
 LDY N
 STA SLOTS,Y
 INY
 STY N
 CPY #4
 BEQ sr9
.sr2
 INX
 CPX #16
 BNE sr1
 LDX #0                 \ fewer than four: say so, and stop
.sr3
 LDA NORAM,X
 BEQ P%+8
 JSR OSWRCH
 INX
 BNE sr3
 JMP P%
.sr9

 LDX #LO(MESSB)         \ the panel first (its file runs on to &7EFF, where
 LDY #HI(MESSB)         \ HBE goes after)
 JSR OSCLI
 LDX #0                 \ the images
.ld1
 STX T
 LDA FTAB+1,X
 BEQ ld9
 TAY
 LDA FTAB,X
 TAX
 JSR OSCLI              \ *LOAD it at BUF
 LDX T
 LDA FTAB+2,X           \ its patch table
 STA PT
 LDA FTAB+3,X
 STA PT+1
 JSR PATCH
 LDX T
 LDA FTAB+6,X           \ the length
 STA LEN
 LDA FTAB+7,X
 STA LEN+1
 LDA FTAB+4,X           \ the destination: a bank (its index) or main RAM
 STA PP+1
 LDA #0
 STA PP
 LDY FTAB+5,X
 BMI ld2
 LDA SLOTS,Y
 SEI
 STA &FE30
.ld2
 LDA #LO(BUF)
 STA ZP
 LDA #HI(BUF)
 STA ZP+1
 LDY #0
.ld3
 LDA (ZP),Y
 STA (PP),Y
 INY
 BNE ld4
 INC ZP+1
 INC PP+1
.ld4
 LDA LEN
 BNE P%+4
 DEC LEN+1
 DEC LEN
 LDA LEN
 ORA LEN+1
 BNE ld3
 LDA &F4
 STA &FE30
 CLI
 LDA T
 CLC
 ADC #8
 TAX
 BNE ld1
.ld9
 LDX #LO(MESSP)         \ the parasite's code, the panel, then DIR E
 LDY #HI(MESSP)
 JSR OSCLI
 LDX #LO(MESS3)
 LDY #HI(MESS3)
 JSR OSCLI
 SEI
 LDA #LO(hwrchB)        \ WRCHV = hwrch (&7E00's part), which starts the
 STA &020E              \ command loop when the parasite sends &FE
 LDA #HI(hwrchB)
 STA &020F
 CLI
.lc1
 LDA #&C0+TUBEID        \ claim the Tube, then start the parasite at p_start
 JSR &0406
 BCC lc1
 LDA #4
 LDX #LO(PSTB)
 LDY #HI(PSTB)
 JMP &0406
.PSTB EQUD PSTART

.OSB
 LDY #0
 JMP OSBYTE

\ PATCH: the image at BUF, its table at (PT): each entry, bank kind (bits 14-15)
\ and offset, gets the bank's number
.PATCH
 LDY #0
 LDA (PT),Y
 STA ZP
 INY
 LDA (PT),Y
 CMP #&FF
 BEQ pa9
 PHA
 AND #&3F
 CLC
 ADC #HI(BUF)
 STA ZP+1
 PLA
 LSR A
 LSR A
 LSR A
 LSR A
 LSR A
 LSR A
 TAX
 LDA SLOTS,X
 LDY #0
 STA (ZP),Y
 LDA PT
 CLC
 ADC #2
 STA PT
 BCC PATCH
 INC PT+1
 JMP PATCH
.pa9
 RTS

.SLOTS SKIP 4

.FTAB                   \ command, patch table, destination high byte, bank
 EQUW MESSD, PT_HBD     \ index (&FF: main RAM), length
 EQUB &80, 0
 EQUW &4000
 EQUW MESSPB, PT_HBP
 EQUB &80, 1
 EQUW &4000
 EQUW MESSF, PT_HBF
 EQUB &80, 2
 EQUW HBF_LEN
 EQUW MESSS, PT_HBS
 EQUB &80, 3
 EQUW HBS_LEN
 EQUW MESSE, PT_HBE
 EQUB &7E, &FF
 EQUW &0200
 EQUW 0

.MESSD  EQUS "L.HBD FFFF", STR$~(BUF) : EQUB 13
.MESSPB EQUS "L.HBP FFFF", STR$~(BUF) : EQUB 13
.MESSF  EQUS "L.HBF FFFF", STR$~(BUF) : EQUB 13
.MESSS  EQUS "L.HBS FFFF", STR$~(BUF) : EQUB 13
.MESSE  EQUS "L.HBE FFFF", STR$~(BUF) : EQUB 13
.MESSB  EQUS "L.BDATA FFFF7000" : EQUB 13
.MESS3  EQUS "DIR E" : EQUB 13
.MESSP  EQUS "L.PCODE 0000", STR$~(PCODEAT) : EQUB 13
.NORAM  EQUS "Elite (Tube) needs 64K of sideways RAM.", 13, 10, 0

 INCLUDE "build/hb-patch.asm"
.LEND
 PRINT "Model B loader: &1900-&", ~LEND-1
 ASSERT LEND <= BUF
 SAVE "build/LOADB.bin", &1900, LEND, ENTRY
