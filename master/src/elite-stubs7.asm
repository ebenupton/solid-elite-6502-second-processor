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
