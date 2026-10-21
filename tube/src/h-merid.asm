\ ******************************************************************************
\
\ h-merid.asm - the host's meridian window (docs/TUBE-MAP.md): the beach ball
\ planet's colour boundaries, the Master port's gfx-merid.asm run by the host
\ (the parasite has no room for its 3K): the Master host's bank 7 (as the
\ Master port's MERIDBANK), the Model B host's bank D (NMOS, beside the disc
\ layer whose arrays it writes)
\
\ C_MERHOOK (G_MERHOOK on the parasite, from H_MERID in game context) brings
\ PM_HOOK's inputs: roofv and sidev (INWK+15..26), K3, K4 and MCNT into PM_IN,
\ the radius into PM_R; h_merin then runs PM_HOOK, which keeps the frame's
\ constants here. C_DISC with R_NDF = &81 (f_bounds' T_MERID on the parasite)
\ carries the planet's spans only; the host then runs PM_MERID, which makes
\ the rows' boundaries from them, before R_DISCROWS.
\
\ The quarter squares PM_HOOK multiplies with (QSL, QSH: Elite's, which the
\ host does not have) are here too.
\
\ ******************************************************************************

 ALIGN &100
.QSL
FOR n, 0, 511
 EQUB LO(n * n DIV 4)
NEXT
.QSH
FOR n, 0, 511
 EQUB HI(n * n DIV 4)
NEXT

.PM_IN SKIP 17          \ roofv, sidev (INWK+15..26), K3, K4 (words), MCNT

.h_merin                \ C_MERHOOK's operands, then PM_HOOK
 LDX #0
.hmi1
 HRX
 STA PM_IN,X
 INX
 CPX #17
 BNE hmi1
 HRX
 STA PM_R
 JMP PM_HOOK
