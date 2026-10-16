\ ******************************************************************************
\
\ elite-stubs7.asm - stubs into the cold area
\
\ Port (master/src/elite-far.asm): at the end of the main code. Each cold routine that code
\ outside the cold area calls keeps its name here, as a far call (far7) or a
\ far jump (far7j, for routines that never return) to its cold copy (_C).
\ ******************************************************************************

.EQSHP
 JSR far7
 EQUW EQSHP_C

.MCASH
 JSR far7
 EQUW MCASH_C

.TT162
 JSR far7
 EQUW TT162_C

.TT167
 JSR far7
 EQUW TT167_C

.TT208
 JSR far7
 EQUW TT208_C

.TT213
 JSR far7
 EQUW TT213_C

.TT219
 JSR far7
 EQUW TT219_C

.hm
 JSR far7
 EQUW hm_C

.tnpr1
 JSR far7
 EQUW tnpr1_C

.var
 JSR far7
 EQUW var_C

.DETOK
 JSR far7
 EQUW DETOK_C

.MT13
 JSR far7
 EQUW MT13_C

.MT14
 JSR far7
 EQUW MT14_C

.MT15
 JSR far7
 EQUW MT15_C

.MT2
 JSR far7
 EQUW MT2_C

.PDESC
 JSR far7
 EQUW PDESC_C

.TT27
 JSR far7
 EQUW TT27_C

.TT68
 JSR far7
 EQUW TT68_C

.cpl
 JSR far7
 EQUW cpl_C

.ex
 JSR far7
 EQUW ex_C

.plf
 JSR far7
 EQUW plf_C

.DOXC
 JSR far7
 EQUW DOXC_C

.HME2
 JSR far7
 EQUW HME2_C

.STATUS
 JSR far7
 EQUW STATUS_C

.TRADEMODE2
 JSR far7
 EQUW TRADEMODE2_C

.TT103
 JSR far7
 EQUW TT103_C

.TT111
 JSR far7
 EQUW TT111_C

.TT146
 JSR far7
 EQUW TT146_C

.TT15
 JSR far7
 EQUW TT15_C

.TT16
 JSR far7
 EQUW TT16_C

.TT22
 JSR far7
 EQUW TT22_C

.TT23
 JSR far7
 EQUW TT23_C

.TT25
 JSR far7
 EQUW TT25_C

.TT67
 JSR far7
 EQUW TT67_C

.ping
 JSR far7
 EQUW ping_C
