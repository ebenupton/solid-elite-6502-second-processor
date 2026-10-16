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

.BAY
 JSR far7j
 EQUW BAY_C

.DEATH2
 JSR far7j
 EQUW DEATH2_C

.JAMESON
 JSR far7
 EQUW JAMESON_C

.QU5
 JSR far7
 EQUW QU5_C

.RES2
 JSR far7
 EQUW RES2_C

.SVE
 JSR far7
 EQUW SVE_C

.getzp
 JSR far7
 EQUW getzp_C

.setzp
 JSR far7
 EQUW setzp_C

.TT170
 JSR far7j
 EQUW TT170_C

.BRIEF
 JSR far7
 EQUW BRIEF_C

.BRIEF2
 JSR far7
 EQUW BRIEF2_C

.BRIEF3
 JSR far7
 EQUW BRIEF3_C

.DEBRIEF
 JSR far7
 EQUW DEBRIEF_C

.DEBRIEF2
 JSR far7
 EQUW DEBRIEF2_C

.DKS3
 JSR far7
 EQUW DKS3_C

.DOENTRY
 JSR far7
 EQUW DOENTRY_C

.GTHG
 JSR far7
 EQUW GTHG_C

.TT110
 JSR far7
 EQUW TT110_C

.TT18
 JSR far7
 EQUW TT18_C

.WARP
 JSR far7
 EQUW WARP_C

.ee3
 JSR far7
 EQUW ee3_C

.hyp
 JSR far7
 EQUW hyp_C

.BAD
 JSR far7
 EQUW BAD_C

.ESCAPE
 JSR far7
 EQUW ESCAPE_C

.HLOIN2
 JSR far7
 EQUW HLOIN2_C

.MESS
 JSR far7
 EQUW MESS_C

.OUCH
 JSR far7
 EQUW OUCH_C

.TT66
 JSR far7
 EQUW TT66_C

.t
 JSR far7
 EQUW t_C
