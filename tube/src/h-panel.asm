\ ******************************************************************************
\
\ h-panel.asm - the host's panel commands (docs/TUBE-MAP.md), in the resting
\ bank (the Master host's bank 6, the Model B host's bank F)
\
\ ******************************************************************************

\ The panel (p-dash.asm): the Master port's dashboard routines, which are the
\ host's (elite-source.asm's blocks tagged "Tube: hostb", in this bank), from
\ the values the parasite sends

.h_pdials               \ C_PDIALS: DIALS' inputs, then DIALS (which returns
 LDX #0                 \ here: the compass is the parasite's)
.hpd1
 LDA pdtl,X
 STA hpd2+1
 LDA pdth,X
 STA hpd2+2
 HRX
.hpd2
 STA &FFFF              \ (patched)
 INX
 CPX #14
 BNE hpd1
 JSR DIALS
 JMP hloop
.pdtl
 EQUB LO(DELTA), LO(ALP1), LO(ALP2), LO(BETA), LO(BET1), LO(MCNT), LO(ENERGY)
 EQUB LO(FSH), LO(ASH), LO(dQQ14), LO(dCABTMP), LO(dGNTMP), LO(dALTIT), LO(FLH)
.pdth
 EQUB HI(DELTA), HI(ALP1), HI(ALP2), HI(BETA), HI(BET1), HI(MCNT), HI(ENERGY)
 EQUB HI(FSH), HI(ASH), HI(dQQ14), HI(dCABTMP), HI(dGNTMP), HI(dALTIT), HI(FLH)

.h_pdot                 \ C_PDOT: COMX, COMY, COMC, then DOT
 HRX
 STA dCOMX
 HRX
 STA dCOMY
 HRX
 STA COMC
 JSR DOT
 JMP hloop

.h_pscan                \ C_PSCAN: dX1, Y1, Y2, TYPE, then SCAN's drawing
 HRX
 STA dX1
 HRX
 STA Y1
 HRX
 STA Y2
 HRX
 STA TYPE
 JSR SCAND
 JMP hloop

.h_pmsbar               \ C_PMSBAR: X, Y, then MSBAR
 HRX
 TAX
 HRX
 TAY
 JSR MSBAR
 JMP hloop

.h_pbulb                \ C_PBULB: 0 (the E.C.M.'s) or 1 (the space station's)
 HRX
 BNE hpb1
 JSR ECBLB
 JMP hloop
.hpb1
 JSR SPBLB
 JMP hloop


.h_loin                 \ C_LOIN: X1, Y1, X2, Y2, COL, then Master's LOINQ (in
 HRX                    \ this bank, elite-source.asm's "Tube: hostb" blocks), into
 STA X1                 \ shadow RAM (the direct-mode screen, as LOIN and TTX66
 HRX                    \ draw it)
 STA Y1
 HRX
 STA X2
 HRX
 STA Y2
 HRX
 STA COL
IF _HOSTB = 0
 LDA #4
 TSB &FE34
ENDIF
 JSR LOINQ
IF _HOSTB = 0
 LDA #4
 TRB &FE34
ENDIF
 JMP hloop

.h_hloin                \ C_HLOIN: X1, X2, Y1, COL, then Master's HLOIN3 (in
 HRX                    \ this bank, "Tube: bothb"), into shadow RAM
 STA X1
 HRX
 STA X2
 HRX
 STA Y1
 HRX
 STA COL
IF _HOSTB = 0
 LDA #4
 TSB &FE34
ENDIF
 JSR HLOIN3
.hhl9
IF _HOSTB = 0
 LDA #4
 TRB &FE34
ENDIF
 JMP hloop

.h_pixel                \ C_PIXEL: x, y, ZZ, COL, then Master's PIXEL (in this
 HRX                    \ bank, "Tube: bothb"), into shadow RAM
 PHA
 HRX
 PHA
 HRX
 STA ZZ
 HRX
 STA COL
IF _HOSTB = 0
 LDA #4
 TSB &FE34
ENDIF
 PLA
 TAY
 PLA
 TAX
 TYA
 JSR PIXEL
 JMP hhl9
