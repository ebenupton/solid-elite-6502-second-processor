\ ******************************************************************************
\
\ elite-stubs7.asm - stubs into the cold area
\
\ Port (master/src/elite-far.asm): in main RAM at &7E00-&7FFF. Each cold routine that code
\ outside the cold area calls keeps its name here, as a far call (far7) or a
\ far jump (far7j, for routines that never return) to its cold copy (_C).
\ ******************************************************************************

.EQSHP
 JSR far7
 EQUW EQSHP_C

.MCASH
 JSR far7
 EQUW MCASH_C

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

.cpl
 JSR far7
 EQUW cpl_C

.ex
 JSR far7
 EQUW ex_C

.HME2
 JSR far7
 EQUW HME2_C

.STATUS
 JSR far7
 EQUW STATUS_C

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

.TT170
 JSR far7j
 EQUW TT170_C

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

.DOSNMI                 \ Port: the minimal NMI handler back after a disc error
 JSR far7               \ (NEWBRK; elite-cold7.asm)
 EQUW DOSNMI_C

.HANGER
 JSR far7
 EQUW HANGER_C

\ Port: far6, as far7 (elite-far.asm) for the cold code in bank 6
\ (elite-cold6.asm), and the stubs into it

.far6
 PHP
 STA fA
 LDA #6
 JMP farc

.BOMBOFF
 JSR far6
 EQUW BOMBOFF_C

.BOMBEFF2
 JSR far6
 EQUW BOMBEFF2_C

.BOMBON
 JSR far6
 EQUW BOMBON_C

.OOPS
 JSR far6
 EQUW OOPS_C

.FLIP
 JSR far6
 EQUW FLIP_C

.MAS1
 JSR far6
 EQUW MAS1_C

.MAS3
 JSR far6
 EQUW MAS3_C

