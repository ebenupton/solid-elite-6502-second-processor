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

.x4_DETOK
 JSR far4
 EQUW DETOK

.x4_DORND
 JSR far4
 EQUW DORND

.x4_DOXC
 JSR far4
 EQUW DOXC

.x4_DOYC
 JSR far4
 EQUW DOYC

.x4_MULTU
 JSR far4
 EQUW MULTU

.x4_NLIN3
 JSR far4
 EQUW NLIN3

.x4_NLIN4
 JSR far4
 EQUW NLIN4

.x4_TRADEMODE
 JSR far4
 EQUW TRADEMODE

.x4_TT103
 JSR far4
 EQUW TT103

.x4_TT11
 JSR far4
 EQUW TT11

.x4_TT111
 JSR far4
 EQUW TT111

.x4_TT217
 JSR far4
 EQUW TT217

.x4_TT26
 JSR far4
 EQUW TT26

.x4_TT27
 JSR far4
 EQUW TT27

.x4_TT60
 JSR far4
 EQUW TT60

.x4_TT66
 JSR far4
 EQUW TT66

.x4_TT67
 JSR far4
 EQUW TT67

.x4_TT69
 JSR far4
 EQUW TT69

.x4_fwl
 JSR far4
 EQUW fwl

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

.x4_spc
 JSR far4
 EQUW spc
