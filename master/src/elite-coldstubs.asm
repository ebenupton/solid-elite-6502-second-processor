\ ******************************************************************************
\
\ elite-coldstubs.asm - stubs out of the cold area
\
\ Port (master/src/elite-far.asm): at the start of the cold area's bank 7
\ part. x4_name calls name with bank 4 paged in (far4) and returns to the cold
\ area; j4_name jumps to name (far4j) for targets that never return.
\ ******************************************************************************

.j4_BAY
 JSR far4j
 EQUW BAY

.j4_FRCE
 JSR far4j
 EQUW FRCE

.x4_BEEP
 JSR far4
 EQUW BEEP

.x4_CLYNS
 JSR far4
 EQUW CLYNS

.x4_DASC
 JSR far4
 EQUW DASC

.x4_DELAY
 JSR far4
 EQUW DELAY


.x4_DORND
 JSR far4
 EQUW DORND



.x4_MULTU
 JSR far4
 EQUW MULTU

.x4_NLIN3
 JSR far4
 EQUW NLIN3

.x4_NLIN4
 JSR far4
 EQUW NLIN4



.x4_TT11
 JSR far4
 EQUW TT11


.x4_TT217
 JSR far4
 EQUW TT217

.x4_TT26
 JSR far4
 EQUW TT26



.x4_TT66
 JSR far4
 EQUW TT66




.x4_msblob
 JSR far4
 EQUW msblob

.x4_pr2
 JSR far4
 EQUW pr2

.x4_pr2_p2
 JSR far4
 EQUW pr2+2

.x4_pr5
 JSR far4
 EQUW pr5

.x4_prq
 JSR far4
 EQUW prq


.x4_BPRNT
 JSR far4
 EQUW BPRNT

.x4_BRIS
 JSR far4
 EQUW BRIS

.x4_FILEPR
 JSR far4
 EQUW FILEPR

.x4_MT16
 JSR far4
 EQUW MT16

.x4_MT23
 JSR far4
 EQUW MT23

.x4_MT26
 JSR far4
 EQUW MT26

.x4_MT29
 JSR far4
 EQUW MT29

.x4_OTHERFILEPR
 JSR far4
 EQUW OTHERFILEPR

.x4_PAUSE
 JSR far4
 EQUW PAUSE

.x4_PAUSE2
 JSR far4
 EQUW PAUSE2

.x4_BOOP
 JSR far4
 EQUW BOOP

.x4_CIRCLE2
 JSR far4
 EQUW CIRCLE2

.x4_DOVDU19
 JSR far4
 EQUW DOVDU19

.x4_FLFLLS
 JSR far4
 EQUW FLFLLS

.x4_FLKB
 JSR far4
 EQUW FLKB

.x4_HLOIN3
 JSR far4
 EQUW HLOIN3

.x4_LL5
 JSR far4
 EQUW LL5

.x4_LOIN
 JSR far4
 EQUW LOIN

.x4_NLIN
 JSR far4
 EQUW NLIN

.x4_NLIN5
 JSR far4
 EQUW NLIN5

.x4_PIXEL
 JSR far4
 EQUW PIXEL

.x4_SQUA2
 JSR far4
 EQUW SQUA2

.x4_SUN
 JSR far4
 EQUW SUN

.x4_T95
 JSR far4
 EQUW T95

.x4_TT67K
 JSR far4
 EQUW TT67K

.x4_WSCAN
 JSR far4
 EQUW WSCAN

.x4_pr6
 JSR far4
 EQUW pr6
