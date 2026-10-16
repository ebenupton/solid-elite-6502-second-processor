\ ******************************************************************************
\
\ elite-coldstubs.asm - stubs out of the cold area
\
\ Port (master/src/elite-far.asm): at the start of the cold area's bank 7
\ part. x4_name calls name with bank 4 paged in (far4) and returns to the cold
\ area; j4_name jumps to name (far4j) for targets that never return.
\ ******************************************************************************


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




.x4_BPRNT
 JSR far4
 EQUW BPRNT



.x4_MT16
 JSR far4
 EQUW MT16







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


.x4_CHPR
 JSR far4
 EQUW CHPR

.x4_ECMOF
 JSR far4
 EQUW ECMOF

.x4_FEED
 JSR far4
 EQUW FEED

.x4_LL9
 JSR far4
 EQUW LL9

.x4_MVEIT
 JSR far4
 EQUW MVEIT

.x4_NWSHP
 JSR far4
 EQUW NWSHP


.x4_RDKEY
 JSR far4
 EQUW RDKEY


.x4_SPBLB
 JSR far4
 EQUW SPBLB

.x4_WPSHPS
 JSR far4
 EQUW WPSHPS

.x4_ZEKTRAN
 JSR far4
 EQUW ZEKTRAN

.x4_ZINF
 JSR far4
 EQUW ZINF


.x4_t
 JSR far4
 EQUW t

\ (x4_RDFIRE, x4_SHIFT and x4_CTRLmc, used only by the Master Compact's code,
\ would be here: RDFIRE, SHIFT and CTRLmc are not assembled for SNG47)

.x4_BELL
 JSR far4
 EQUW BELL

.x4_ADD
 JSR far4
 EQUW ADD

.x4_BAD
 JSR far4
 EQUW BAD

.x4_CTRL
 JSR far4
 EQUW CTRL


.x4_HALL
 JSR far4
 EQUW HALL

.x4_LOOK1
 JSR far4
 EQUW LOOK1

.x4_MAS2
 JSR far4
 EQUW MAS2

.x4_MESS
 JSR far4
 EQUW MESS

.x4_NOISE
 JSR far4
 EQUW NOISE

.x4_NWSPS
 JSR far4
 EQUW NWSPS

.x4_NWSTARS
 JSR far4
 EQUW NWSTARS

.x4_TTX66
 JSR far4
 EQUW TTX66

.x4_Ze
 JSR far4
 EQUW Ze

.x4_m
 JSR far4
 EQUW m
