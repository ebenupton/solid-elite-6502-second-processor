\ ******************************************************************************
\
\ gfx-planet7.asm - the planet's styles, its moon and its ring (sideways RAM
\ bank 7, in the meridian window after gfx-merid.asm and gfx-kept7.asm, paged
\ as ROMSEL MERIDBANK; docs/MASTER-MAP.md)
\
\ PF_HOOK, in game context (G_PFHOOK, from H_CIRC): the planet's class
\ (PF_CLS) and its style as a few circles on its sphere, each a record made
\ by gfx-merid.asm's pc_circ (which describes the method), and a base colour
\ (pc_inv):
\
\   * class 0, a meridian planet (TYPE 128): the beach ball, the great
\     circles normal to roofv and sidev, base 1 (colour B where the surface
\     is on the same side of both planes, as Elite's equator and meridian
\     divide it);
\
\   * class 1, a crater planet (TYPE 130): one to three craters, small caps
\     from the system's seed (pf_craters), base 0;
\
\   * class 2, a banded crater planet (a quarter of them, by the seed): two
\     latitude circles about the spin axis, EOR'd (pf_bands), base 0.
\
\ Then the moon (pf_moon, with its crater's record in slot PCMAX) and the
\ ring's dots (pf_ring), when the seed has them. Elite's state is not
\ touched: Elite's zero page &10-&28 (the engine's workspace) is saved and
\ restored, and A, X, Y and the flags are preserved. The frame layer makes
\ the rows through T_CAPS and T_MCAPS (gfx-merid.asm's PC_ROWS, PC_MROWS).
\ tools/planet_caps.py models it all bit for bit.
\
\ ******************************************************************************

.PF_HOOK
 PHP
 PHA
 PHX
 PHY
 STZ PC_N
 STZ MN_ON
 STZ RG_N
 LDA TYPE               \ the class: a crater planet (TYPE 130) 1, a meridian
 LSR A                  \ planet (128) 0
 AND #1
 STA PF_CLS
 BEQ pfh4
 LDA QQ2+3              \ s1_hi bits 0-1 both clear (a quarter of the crater
 AND #3                 \ planets): banded, class 2 (Lave is a meridian
 BNE pfh4               \ planet, so it keeps its beach ball)
 LDA #2
 STA PF_CLS
.pfh4
 LDA PF_CLS             \ the colour scheme (bits 2-4): 0 the beach ball's;
 BEQ pfh4a              \ a crater or banded planet's 1-4 from s1_lo bits 0-1
 LDA QQ2+2              \ (gfx-frame.asm's pf_cola, pf_colb)
 AND #3
 INC A
 ASL A
 ASL A
 TSB PF_CLS
.pfh4a
 LDA K+1                \ the detail only below a radius of 256, as PL9 has
 BNE pfh9               \ it, and from 6 up, as its meridians
 LDA K
 CMP #6
 BCC pfh9
 STA pcr
 STA pf_r
 LDX #24                \ (Elite's &10-&28: the engine's workspace)
.pfh0
 LDA &10,X
 STA pm_zsave,X
 DEX
 BPL pfh0
 LDA K3                 \ the centre (K3 and K4 are in &10-&28: read before
 STA pcbx               \ the workspace is used)
 LDA K3+1
 STA pcbx+1
 LDA K4
 STA pcby
 LDA K4+1
 STA pcby+1
 LDX #4                 \ (the planet's centre and radius, kept for pf_moon)
.pfh5
 LDA pcbx,X
 STA pf_cx,X
 DEX
 BPL pfh5
 STZ pc_inv
 LDA PF_CLS
 AND #3
 BNE pfh2
 INC pc_inv             \ (the beach ball: base 1)
 JSR pf_beach
 BRA pfh3
.pfh2
 CMP #2
 BNE pfh6
 JSR pf_bands
 BRA pfh3
.pfh6
 JSR pf_craters
.pfh3
 LDA PC_N               \ (records, or a base colour)
 ORA pc_inv
 BEQ pfh7
 LDA #&80
 TSB PF_CLS
.pfh7
 JSR pf_moon            \ (pf_moon first: it sets mn_h)
 JSR pf_ring
 LDX #24
.pfh1
 LDA pm_zsave,X
 STA &10,X
 DEX
 BPL pfh1
.pfh9
 PLY
 PLX
 PLA
 PLP
 RTS

\ pf_beach: a meridian planet's two great circles, normal to roofv and sidev
\ pf_one: a circle of cosine A (positive) about vector X (INWK offset) alone

.pf_beach
 LDX #15
 JSR pf_gc
 LDX #21
.pf_gc
 LDA #0
.pf_one
 PHA
 LDY #0
 TYA
 JSR pf_tilt
 PLA
 STA pcc
 STZ pcneg
 JMP pc_circ

\ pf_craters: a crater planet's caps, from the system's seed (QQ2): the
\ first on roofv, 30 degrees across (Elite's crater: at 222/256 of the radius
\ from the centre, half the radius across); then, as the seed has it, one on
\ nosev (either way) tilted towards sidev, and one on sidev tilted towards
\ roofv, each 15 to 30 degrees. No two axes are closer than 63 degrees, so
\ the craters never overlap.

.pf_craters
 LDX #15                \ roofv
 LDA #222
 JSR pf_one
 LDA QQ2+4              \ s2_lo bits 0-1: more caps (0, 1, 2, 1)
 AND #3
 BEQ pfc9
 PHA
 LDA QQ2+4              \ bits 2-4: the second's signs and tilt
 LSR A
 LSR A
 AND #7
 LDX #9                 \ nosev, tilted towards sidev
 LDY #21
 JSR pf_tilt
 LDA QQ2+5              \ s2_hi bits 0-1: its size
 JSR pf_size
 PLA
 CMP #2
 BNE pfc9
 LDA QQ2+4              \ bits 5-7: the third's
 LSR A
 LSR A
 LSR A
 LSR A
 LSR A
 LDX #21                \ sidev, tilted towards roofv
 LDY #15
 JSR pf_tilt
 LDA QQ2+5              \ s2_hi bits 2-3
 LSR A
 LSR A
.pf_size                \ a crater of A bits 0-1's size (15, 20, 25 or 30
 AND #3                 \ degrees) on pcv
 TAX
 LDA pfs_c,X
 STA pcc
 STZ pcneg
 JMP pc_circ
.pfc9
 RTS
.pfs_c EQUB 247, 241, 232, 222

\ pf_bands: a banded planet's two latitude circles, the edges of its belt,
\ about the axis the planet spins about. Its pitch and roll (MVEIT part 8:
\ pitch turns roofv and nosev, roll roofv and sidev, alike) turn it about
\ nosev - sidev, which stays put. North of the one edge (cosine c1) and
\ south of the other (-c2), EOR'd: the belt between them is colour B, the
\ two polar zones colour A. c1 and c2 from the seed (s2_hi bits 4-7)

.pf_bands
 LDX #9                 \ (nosev - sidev) / 2
 LDY #21
 LDA #%1010
 JSR pf_tilt
 LDA QQ2+5
 LSR A
 LSR A
 LSR A
 LSR A
 PHA
 AND #3
 TAX
 LDA pfb_n,X
 STA pcc
 STZ pcneg
 JSR pc_circ
 PLA
 LSR A
 LSR A
 TAX
 LDA pfb_s,X
 STA pcc
 LDA #&80
 STA pcneg
 JMP pc_circ
.pfb_n EQUB 64, 96, 128, 150    \ the north edge's latitude: 14 to 36 degrees
.pfb_s EQUB 32, 64, 96, 128     \ the south edge's: -7 to -30 degrees

\ pf_tilt: pcv = (+/- vector X) / 2 + (+/- vector Y) / 2^(k+1), as
\ sign-magnitude words (X, Y = 9 nosev, 15 roofv, 21 sidev; Y = 0: none), A
\ bits 0-3: bit 0 the first's sign, bit 1 the second's, bit 2 k = 2, else
\ k = 1 (a tilt of 14 or 27 degrees), bit 3 k = 0 (an equal weight); each
\ magnitude shifted before its sign is applied (so a vector alone is exactly
\ halved). Halved, as the sums must fit 15 bits (a circle depends on its
\ axis' direction only); pcn = 2^24 / the sum's nominal length (>> 3)

.pf_tilt
 STA pft_f
 STX pft_x
 STY pft_y
 LDX #0                 \ pcn: 1536 (a vector halved), 1536 sqrt(1 + 1/4) or
 CPY #0                 \ sqrt(1 + 1/16) (k = 1, 2), 1536 sqrt(2) (k = 0)
 BEQ pft0
 INX
 AND #12
 BEQ pft0
 INX
 CMP #4
 BEQ pft0
 INX
.pft0
 LDA pfn_lo,X
 STA pcn
 LDA pfn_hi,X
 STA pcn+1
 LDA pfn_k,X            \ (the second's shift)
 STA pft_k2
 LDY #4                 \ each component, Y = 4, 2, 0
.pft1
 STZ pft_r
 STZ pft_r+1
 LDX pft_y              \ a vector alone (a crater on roofv, the beach ball's
 BNE pft2               \ circles): its magnitude halved, its sign kept
 TYA
 CLC
 ADC pft_x
 TAX
 LDA INWK+1,X
 PHA
 AND #&7F
 LSR A
 STA pft_r+1
 LDA INWK,X
 ROR A
 STA pcv,Y
 PLA
 AND #&80
 ORA pft_r+1
 BRA pft5
.pft2
 LDX pft_x              \ the first, halved and signed
 LDA pft_f
 STA pft_n
 LDA #1
 JSR pft_add
 LDX pft_y              \ the second, shifted k + 1 times and signed
 LDA pft_f
 LSR A
 STA pft_n
 LDA pft_k2
 JSR pft_add
.pft4
 LDA pft_r+1            \ to sign-magnitude
 BPL pft4a
 LDA #0
 SEC
 SBC pft_r
 STA pft_r
 LDA #0
 SBC pft_r+1
 ORA #&80
.pft4a
 TAX
 LDA pft_r
 STA pcv,Y
 TXA
.pft5
 STA pcv+1,Y
 DEY
 DEY
 BPL pft1
 RTS

.pfn_lo EQUB LO(10923), LO(9770), LO(10596), LO(7723)
.pfn_hi EQUB HI(10923), HI(9770), HI(10596), HI(7723)
.pfn_k  EQUB 0, 2, 3, 1

\ pft_add: pft_r += the INWK word at X + Y, its magnitude shifted right A
\ times, negated if its sign EOR pft_n bit 0 is set (Y kept)

.pft_add
 STA pft_k
 STX pft_s
 TYA
 CLC
 ADC pft_s
 TAX
 LDA pft_n
 LSR A
 LDA INWK+1,X
 BCC P%+4
 EOR #&80
 STA pft_n
 AND #&7F
 STA pft_s+1
 LDA INWK,X
 STA pft_s
 LDX pft_k
.pfa1
 LSR pft_s+1
 ROR pft_s
 DEX
 BNE pfa1
 BIT pft_n
 BMI pfa2
 CLC
 LDA pft_r
 ADC pft_s
 STA pft_r
 LDA pft_r+1
 ADC pft_s+1
 STA pft_r+1
 RTS
.pfa2
 SEC
 LDA pft_r
 SBC pft_s
 STA pft_r
 LDA pft_r+1
 SBC pft_s+1
 STA pft_r+1
 RTS

\ ******************************************************************************
\
\ The ring's dots and the moon (game context, as PF_HOOK)
\
\ ******************************************************************************

\ prg_pt: P = (V +/- U) >> 8 (rg_neg bit 7: minus), P_z = z_s +/- z_c; the
\ dots at P and -P

.prg_pt
 LDX #0
.rgp1
 LDY rg_neg
 BMI rgp2
 CLC
 LDA rg_u+6,X
 ADC rg_u,X
 LDA rg_u+7,X
 ADC rg_u+1,X
 STA rg_p
 LDA rg_u+8,X
 ADC rg_u+2,X
 BRA rgp3
.rgp2
 SEC
 LDA rg_u+6,X
 SBC rg_u,X
 LDA rg_u+7,X
 SBC rg_u+1,X
 STA rg_p
 LDA rg_u+8,X
 SBC rg_u+2,X
.rgp3
 STA rg_p+1
 TXA                    \ (x: rg_p, y: rg_p+2)
 BEQ rgp4
 LDA rg_p
 STA rg_p+2
 LDA rg_p+1
 STA rg_p+3
 BRA rgp5
.rgp4
 LDA rg_p
 STA rg_px
 LDA rg_p+1
 STA rg_px+1
 LDX #3
 BRA rgp1
.rgp5
 LDA rg_px
 STA rg_p
 LDA rg_px+1
 STA rg_p+1
 LDY rg_neg             \ P_z
 BMI rgp6
 CLC
 LDA rg_zs
 ADC rg_zc
 STA rg_p+4
 LDA rg_zs+1
 ADC rg_zc+1
 BRA rgp7
.rgp6
 SEC
 LDA rg_zs
 SBC rg_zc
 STA rg_p+4
 LDA rg_zs+1
 SBC rg_zc+1
.rgp7
 STA rg_p+5
 JSR prg_dot
 LDX #4                 \ -P
.rgp8
 SEC
 LDA #0
 SBC rg_p,X
 STA rg_p,X
 LDA #0
 SBC rg_p+1,X
 STA rg_p+1,X
 DEX
 DEX
 BPL rgp8

\ prg_dot: a dot at the planet's centre + (P_x, -P_y) >> 4, if on the screen
\ (x 0-255, y 0-191) and RG_N < 64; behind if P_z < 0

.prg_dot
 LDA RG_N
 CMP #64
 BCS rgd9
 LDX #0                 \ x
 JSR prg_sh
 CLC
 ADC pf_cx
 STA rg_t
 TYA
 ADC pf_cx+1
 BNE rgd9
 LDX #2                 \ y = cy - (P_y >> 4)
 JSR prg_sh
 STA rg_t+1
 STY rg_y
 SEC
 LDA pf_cy
 SBC rg_t+1
 STA rg_t+1
 LDA pf_cy+1
 SBC rg_y
 BNE rgd9
 LDA rg_t+1
 CMP #192
 BCS rgd9
 LDX RG_N
 STA RG_Y,X
 LDA rg_t
 STA RG_X,X
 LDA rg_p+5             \ behind: P_z < 0
 AND #&80
 STA RG_F,X
 INC RG_N
.rgd9
 RTS

\ prg_sh: (Y A) = rg_p_X >> 4 (16-bit signed)

.prg_sh
 LDA rg_p,X
 STA rg_t+1
 LDA rg_p+1,X
 CMP #&80
 ROR A
 ROR rg_t+1
 CMP #&80
 ROR A
 ROR rg_t+1
 CMP #&80
 ROR A
 ROR rg_t+1
 CMP #&80
 ROR A
 ROR rg_t+1
 TAY
 LDA rg_t+1
 RTS

.pfr_r EQUB 102, 115, 128, 141  \ the ring's radius over the planet's, x 64
.pfr_sin                \ sin(i pi / 32) x 256, i = 0 to 16 (255 for 1)
 FOR I%, 0, 16
  N = INT(256 * SIN(I% * PI / 32) + 0.5)
  IF N > 255
   EQUB 255
  ELSE
   EQUB N
  ENDIF
 NEXT
.rg_st EQUB 0
.rg_i  EQUB 0
.rg_sn EQUB 0
.rg_cs EQUB 0
.rg_cg EQUB 0
.rg_s3 EQUW 0
.rg_s2 EQUW 0
.rg_al SKIP 6           \ A1, A2 (12.4 pixels): magnitudes, signs
.rg_ah SKIP 6
.rg_as SKIP 6
.rg_u  SKIP 12          \ U_x, U_y, V_x, V_y (24-bit signed)
.rg_zc SKIP 3           \ the z terms: cos A1z, sin A2z (16-bit signed;
.rg_zs EQUW 0           \ prg_f writes rg_zc + 3 for rg_zs)
.rg_px EQUW 0
.rg_p  SKIP 6           \ P (12.4, signed)
.rg_m  EQUB 0
.rg_x  EQUB 0
.rg_y  EQUB 0
.rg_t  EQUW 0
.rg_sg EQUB 0
.rg_neg EQUB 0

\ pf_moon: a moon, for the systems whose seed has one (h = s0_hi EOR s1_hi
\ EOR s2_hi, bits 0-1 = 1: a quarter of them), and planets of radius 16 up.
\ It is scenery: no ship slot, no random number, no saved state. It sits on
\ the axis the planet spins about (nosev - sidev, which its pitch and roll
\ leave where it is), on the side (h bit 4) and at the distance D (3 to 5.25
\ planet radii, h bits 2-3) the seed gives, with a radius rho (0.19 to 0.28
\ of the planet's, h bits 5-6). Its centre and radius on the screen follow
\ from the planet's (K3, K4, K) as Elite projects (x / z, and the radius
\ 24576 / z, both times 256): with e = D w (w the unit axis) its offset in
\ planet radii and q = 1 + e_z r / 256 (its depth over the planet's),
\
\   x = 128 + ((cx - 128) + e_x r) / q,  y = 96 + ((cy - 96) - e_y r) / q,
\   radius = rho r / q (at most 63),  z = the planet's z times q
\
\ It is behind the planet if e_z > 0, behind the sun (slot 1) if further than
\ it. Its crater (on roofv, 40 degrees across: radius 10 up) is pc_circ's, into
\ slot PCMAX (pc_circ). MN_ON (bit 7 on, 6 behind the planet, 5 behind the sun), MN_X,
\ MN_Y, MN_R, MN_Z (16 bits, &FFFF if further), MN_INV and MN_N (its crater)
\ are what the frame reads. tools/planet_caps.py's pf_moon models it.

.pfm9
 RTS
.pf_moon
 LDA QQ2+1              \ h
 EOR QQ2+3
 EOR QQ2+5
 STA mn_h
 AND #3
 CMP #1
 BNE pfm9
 LDA pcr                \ (r: 16 up)
 CMP #16
 BCC pfm9
 LDX #9                 \ w: the spin axis, (nosev - sidev) / 2
 LDY #21
 LDA #%1010
 JSR pf_tilt
 LDA mn_h               \ D (8.8)
 LSR A
 LSR A
 AND #3
 TAX
 LDA pfm_dl,X
 STA pm_b
 LDA pfm_dh,X
 STA pm_b+1
 LDX #4                 \ e_i = D |w_i| >> 8, its sign w_i's EOR h bit 4
.pfm1
 LDA pcv+1,X            \ |w_i| = (|v_i| >> 3) pcn >> 16 (at most 255)
 AND #&7F
 LSR A
 STA pm_a+1
 LDA pcv,X
 ROR A
 LSR pm_a+1
 ROR A
 LSR pm_a+1
 ROR A
 STA pm_a
 PHX
 LDA pm_b
 PHA
 LDA pm_b+1
 PHA
 LDA pcn
 STA pm_b
 LDA pcn+1
 STA pm_b+1
 JSR pm_mul16
 PLA
 STA pm_b+1
 PLA
 STA pm_b
 LDA pm_p+2              \ |w_i|
 LDY pm_p+3
 BEQ pfm2
 LDA #255
.pfm2
 STA pm_a
 STZ pm_a+1
 PHA
 JSR pm_mul16           \ D |w_i|
 PLA
 PLX
 LDA pm_p+1
 STA mn_e,X
 LDA pm_p+2
 STA mn_e+1,X
 LDA mn_h               \ (h bit 4 into bit 7)
 ASL A
 ASL A
 ASL A
 EOR pcv+1,X
 AND #&80
 STA mn_es,X
 DEX
 DEX
 BPL pfm1
 LDA mn_e+4             \ q = 256 +/- (|e_z| r) >> 8
 LDX mn_e+5
 JSR pfm_er
 LDA pm_p+1
 STA mn_q
 LDA pm_p+2
 STA mn_q+1             \ (|e_z| r >> 8: then q)
 STA mn_t+1
 LDA mn_q
 STA mn_t               \ (mn_t: |e_z| r >> 8, for the behind test)
 BIT mn_es+4
 BMI pfm3
 INC mn_q+1
 BRA pfm4
.pfm3
 SEC
 LDA #0
 SBC mn_q
 STA mn_q
 LDA #1
 SBC mn_q+1
 STA mn_q+1
 BMI pfm9a              \ (q < 0)
.pfm4
 LDA mn_q+1             \ q >= 64
 BNE pfm5
 LDA mn_q
 CMP #64
 BCS pfm5
.pfm9a
 RTS
.pfm5
 LDX #0                 \ x = 128 + ((cx - 128) 256 + e_x r) / q
 LDA pcbx
 SEC
 SBC #128
 TAY
 LDA pcbx+1
 SBC #0
 JSR pfm_xy
 BCS pfm9a
 STA MN_X+1
 STY MN_X
 LDX #2                 \ y = 96 + ((cy - 96) 256 - e_y r) / q
 LDA mn_es+2
 EOR #&80
 STA mn_es+2
 LDA pcby
 SEC
 SBC #96
 TAY
 LDA pcby+1
 SBC #0
 JSR pfm_xy
 BCS pfm9a
 STA MN_Y+1
 STY MN_Y
 LDA mn_h               \ radius = rho r / q
 LSR A
 LSR A
 LSR A
 LSR A
 LSR A
 AND #3
 TAX
 LDA pfm_rho,X
 LDX pcr
 JSR pm_mul8
 STA mn_n+1
 LDA pm_m8
 STA mn_n
 STZ mn_n+2
 JSR pfm_div
 LDA mn_n+1
 ORA mn_n+2
 BNE pfm6
 LDA mn_n
 CMP #2
 BCC pfm9a
 CMP #64
 BCC pfm7
.pfm6
 LDA #63
.pfm7
 STA MN_R
 LDA INWK+6             \ z = the planet's z q >> 8 (24-bit, saturated)
 STA pm_a
 LDA INWK+7
 STA pm_a+1
 LDA mn_q
 STA pm_b
 LDA mn_q+1
 STA pm_b+1
 JSR pm_mul16
 LDA pm_p+1
 STA mn_z
 LDA pm_p+2
 STA mn_z+1
 LDA pm_p+3
 STA mn_z+2
 LDA INWK+8
 AND #&7F
 LDX mn_q
 JSR pm_mul8            \ (z_sign q: A high, pm_m8 low, << 16 >> 8)
 TAY
 LDA pm_m8
 CLC
 ADC mn_z+1
 STA mn_z+1
 TYA
 ADC mn_z+2
 STA mn_z+2
 BCS pfm8
 LDA INWK+8
 AND #&7F
 LDX mn_q+1
 JSR pm_mul8            \ (z_sign q_hi: << 24 >> 8)
 BNE pfm8
 LDA pm_m8
 CLC
 ADC mn_z+2
 STA mn_z+2
 BCC pfm8a
.pfm8
 LDA #&FF
 STA mn_z
 STA mn_z+1
 STA mn_z+2
.pfm8a
 LDA mn_z               \ MN_Z: 16 bits, &FFFF if further
 STA MN_Z
 LDA mn_z+1
 STA MN_Z+1
 LDA mn_z+2
 BEQ pfm8b
 LDA #&FF
 STA MN_Z
 STA MN_Z+1
.pfm8b
 LDA #&80               \ on; behind the planet if e_z > 0 (and |e_z| r >> 8
 LDX mn_es+4            \ is not 0)
 BMI pfm10
 LDX mn_t
 BNE pfm9b
 LDX mn_t+1
 BEQ pfm10
.pfm9b
 ORA #&40
.pfm10
 STA MN_ON
 LDA FRIN+1             \ behind the sun: the sun in slot 1, in front of us,
 CMP #129               \ nearer than the moon
 BNE pfm11
 LDA K%+37+8
 BMI pfm11
 LDA K%+37+6
 CMP mn_z
 LDA K%+37+7
 SBC mn_z+1
 LDA K%+37+8
 SBC mn_z+2
 BCS pfm11
 LDA #&20
 TSB MN_ON
.pfm11
 LDA MN_R               \ its crater (radius 10 up)
 CMP #10
 BCC pfm12
 LDA PC_N
 PHA
 LDA pc_inv
 PHA
 LDA #PCMAX
 STA PC_N
 STZ pc_inv
 LDA MN_X
 STA pcbx
 LDA MN_X+1
 STA pcbx+1
 LDA MN_Y
 STA pcby
 LDA MN_Y+1
 STA pcby+1
 LDA MN_R
 STA pcr
 LDX #15
 LDA #MOON_C8
 JSR pf_one
 LDA PC_N
 STA MN_N
 LDA pc_inv
 STA MN_INV
 PLA
 STA pc_inv
 PLA
 STA PC_N
 RTS
.pfm12
 LDA #PCMAX
 STA MN_N
 STZ MN_INV
 RTS

\ pfm_er: pm_p = |e| r (A, X: |e|, 16-bit)

.pfm_er
 STA pm_a
 STX pm_a+1
 LDA pcr
 STA pm_b
 STZ pm_b+1
 JMP pm_mul16

\ pfm_xy: (A Y) = (c - centre) (16-bit signed); the moon's coordinate
\ centre + ((A Y) 256 +/- e_X r) / q in (A Y), C set if it is out of range

.pfm_xy
 STY mn_n+1             \ mn_n = (A Y) << 8 (24-bit signed)
 STA mn_n+2
 STZ mn_n
 PHX
 LDA mn_e,X
 PHA
 LDA mn_e+1,X
 TAX
 PLA
 JSR pfm_er             \ |e| r
 PLX
 LDA mn_es,X
 BMI pfx1
 CLC
 LDA mn_n
 ADC pm_p
 STA mn_n
 LDA mn_n+1
 ADC pm_p+1
 STA mn_n+1
 LDA mn_n+2
 ADC pm_p+2
 STA mn_n+2
 BRA pfx2
.pfx1
 SEC
 LDA mn_n
 SBC pm_p
 STA mn_n
 LDA mn_n+1
 SBC pm_p+1
 STA mn_n+1
 LDA mn_n+2
 SBC pm_p+2
 STA mn_n+2
.pfx2
 LDA mn_n+2             \ |n| / q, signed back
 STA mn_sg
 BPL pfx3
 SEC
 LDA #0
 SBC mn_n
 STA mn_n
 LDA #0
 SBC mn_n+1
 STA mn_n+1
 LDA #0
 SBC mn_n+2
 STA mn_n+2
.pfx3
 PHX
 JSR pfm_div
 PLX
 LDA mn_n+2             \ (at most 16383)
 BNE pfx9
 LDA mn_n+1
 CMP #&40
 BCS pfx9
 BIT mn_sg
 BPL pfx4
 SEC
 LDA #0
 SBC mn_n
 STA mn_n
 LDA #0
 SBC mn_n+1
 STA mn_n+1
.pfx4
 CLC                    \ + the screen's centre (128 or 96)
 LDA mn_n
 ADC pfm_ctr,X
 TAY
 LDA mn_n+1
 ADC #0
 CLC
 RTS
.pfx9
 SEC
 RTS

\ pfm_div: mn_n (24-bit) = mn_n / mn_q (16-bit), unsigned

.pfm_div
 STZ mn_r
 STZ mn_r+1
 LDX #24
.pmd1
 ASL mn_n
 ROL mn_n+1
 ROL mn_n+2
 ROL mn_r
 ROL mn_r+1
 LDA mn_r
 SEC
 SBC mn_q
 TAY
 LDA mn_r+1
 SBC mn_q+1
 BCC pmd2
 STA mn_r+1
 STY mn_r
 INC mn_n
.pmd2
 DEX
 BNE pmd1
 RTS

MOON_C8 = 196           \ the moon's crater: cos 40 degrees
.pfm_dl EQUB LO(768), LO(960), LO(1152), LO(1344)
.pfm_dh EQUB HI(768), HI(960), HI(1152), HI(1344)
.pfm_rho EQUB 48, 56, 64, 72
.pfm_ctr EQUB 128, 0, 96
.mn_h  EQUB 0
.mn_t  EQUW 0
.mn_e  SKIP 6           \ |e| (8.8) for x, y, z
.mn_es SKIP 6           \ their signs (bit 7, by 2)
.mn_q  EQUW 0
.mn_n  SKIP 3
.mn_r  EQUW 0
.mn_sg EQUB 0
.mn_z  SKIP 3

\ pf_ring: a ring, for the systems whose seed has one (h bits 4-6 = 4: an
\ eighth of them) and planets of radius 8 up: a dotted ellipse in the plane of
\ the planet's equator, normal to the axis it spins about (nosev - sidev), so
\ its shape on the screen stays put as the planet turns. With no angle and no
\ table of them: two conjugate radii, roofv and (nosev + sidev) / sqrt(2),
\ scaled to the ring's radius on the screen (1.6 to 2.2 planet radii, h bits
\ 2-3) give its points P(t) = cos t A1 + sin t A2, t = k pi / N (N = 16, or
\ 32 for a ring of radius 120 pixels or more), and -P(t); a point is behind the
\ planet if its z is negative. The dots on the screen go into RG_X, RG_Y and
\ RG_F (bit 7: behind), RG_N of them, for the frame layer's f_ring.
\ tools/planet_caps.py's pf_ring models it.

.prg9
 RTS
.pf_ring
 LDA mn_h               \ (h: pf_moon's)
 LSR A
 LSR A
 LSR A
 LSR A
 AND #7
 CMP #4
 BNE prg9
 LDA pf_r
 CMP #8
 BCC prg9
 LDA mn_h               \ S = the ring's radius x 64 / the planet's, times r
 LSR A
 LSR A
 AND #3
 TAX
 LDA pfr_r,X
 LDX pf_r
 JSR pm_mul8
 STA pm_a+1
 LDY #1                 \ (step 1: N = 32 if S >= 120 x 64, else 2: N = 16)
 CMP #&1E
 BCS P%+3
 INY
 STY rg_st
 LDA pm_m8
 STA pm_a
 LDA #LO(21845)         \ S3 = S / 3 = S 21845 >> 16
 STA pm_b
 LDA #HI(21845)
 STA pm_b+1
 JSR pm_mul16
 LDA pm_p+2
 STA rg_s3
 STA pm_a
 LDA pm_p+3
 STA rg_s3+1
 STA pm_a+1
 LDA #LO(27146)         \ S3r2 = S3 sqrt(2) = S3 + S3 27146 >> 16
 STA pm_b
 LDA #HI(27146)
 STA pm_b+1
 JSR pm_mul16
 CLC
 LDA pm_p+2
 ADC rg_s3
 STA rg_s2
 LDA pm_p+3
 ADC rg_s3+1
 STA rg_s2+1
 LDX #4                 \ A1 = S3 roofv >> 15 (12.4 pixels)
.rgr1
 LDA INWK+15,X
 STA pcv,X
 LDA INWK+16,X
 STA pcv+1,X
 DEX
 DEX
 BPL rgr1
 LDA rg_s3
 LDX rg_s3+1
 LDY #0
 JSR prg_a
 LDX #9                 \ A2 = S3r2 (nosev + sidev) / 2 >> 15
 LDY #21
 LDA #%1000
 JSR pf_tilt
 LDA rg_s2
 LDX rg_s2+1
 LDY #3
 JSR prg_a
 STZ RG_N
 STZ rg_i
.rgr2
 LDX rg_i               \ i = 0 to 16 in steps: t = i pi / 32, and pi - t
 LDA pfr_sin,X          \ U = cos(t) A1, V = sin(t) A2 (x, y: 24-bit; z from
 STA rg_sn              \ A's high bytes: 16-bit)
 TXA
 EOR #&FF
 SEC
 ADC #16
 TAY
 LDA pfr_sin,Y
 STA rg_cs
 LDX #0
 LDY #0
 JSR prg_f              \ U_x
 LDX #1
 LDY #3
 JSR prg_f              \ U_y
 LDA rg_sn
 STA rg_cs
 LDX #3
 LDY #6
 JSR prg_f              \ V_x
 LDX #4
 LDY #9
 JSR prg_f              \ V_y
 STZ rg_neg             \ P(t) = (V + U) >> 8 and -P(t)
 JSR prg_pt
 LDA rg_i               \ P(pi - t) = (V - U) >> 8 and -P(pi - t), for 0 <
 BEQ rgr6               \ t < pi / 2
 CMP #16
 BEQ rgr6
 DEC rg_neg
 JSR prg_pt
.rgr6
 LDA rg_i
 CLC
 ADC rg_st
 STA rg_i
 CMP #17
 BCC rgr2
 RTS

\ prg_a: the radii A1 (Y = 0) or A2 (Y = 3) = (X A) |pcv_j| >> 15 (12.4
\ pixels): their magnitudes (rg_al, rg_ah) and signs (rg_as, bit 7)

.prg_a
 STA pm_b
 STX pm_b+1
 LDX #0
.rga1
 LDA pcv+1,X
 STA rg_as,Y
 AND #&7F
 STA pm_a+1
 LDA pcv,X
 STA pm_a
 PHX
 PHY
 JSR pm_mul16
 PLY
 PLX
 LDA pm_p+1              \ (>> 15: the top 17 bits' 16)
 ASL A
 LDA pm_p+2
 ROL A
 STA rg_al,Y
 LDA pm_p+3
 ROL A
 STA rg_ah,Y
 INY
 INX
 INX
 CPX #6
 BNE rga1
 RTS

\ prg_f: rg_u + Y (three bytes) = rg_cs A_X (A_X: X = 0-5: A1 x, y, z, A2 x, y,
\ z), signed; and the z terms, rg_cs (A_Z's high byte), into rg_zc (X = 0)
\ or rg_zs (X = 3)

.prg_f
 STX rg_x
 STY rg_y
 LDA rg_al,X
 LDX rg_cs
 JSR pm_mul8
 LDY rg_y
 STA rg_u+1,Y
 LDA pm_m8
 STA rg_u,Y
 LDX rg_x
 LDA rg_ah,X
 LDX rg_cs
 JSR pm_mul8
 LDY rg_y
 TAX
 LDA pm_m8
 CLC
 ADC rg_u+1,Y
 STA rg_u+1,Y
 TXA
 ADC #0
 STA rg_u+2,Y
 LDX rg_x
 LDA rg_as,X
 BPL rgf1
 SEC
 LDA #0
 SBC rg_u,Y
 STA rg_u,Y
 LDA #0
 SBC rg_u+1,Y
 STA rg_u+1,Y
 LDA #0
 SBC rg_u+2,Y
 STA rg_u+2,Y
.rgf1
 CPX #0                 \ (with A1x and A2x: the z terms)
 BEQ rgf2
 CPX #3
 BNE rgf9
.rgf2
 LDA rg_ah+2,X          \ (A_z's high byte)
 LDX rg_cs
 JSR pm_mul8
 LDX rg_x
 STA rg_zc+1,X
 LDA pm_m8
 STA rg_zc,X
 LDA rg_as+2,X
 BPL rgf9
 SEC
 LDA #0
 SBC rg_zc,X
 STA rg_zc,X
 LDA #0
 SBC rg_zc+1,X
 STA rg_zc+1,X
.rgf9
 RTS

.pf_cx EQUW 0           \ the planet's centre and radius (PF_HOOK)
.pf_cy EQUW 0
.pf_r  EQUB 0
.pft_f EQUB 0           \ pf_tilt's
.pft_x EQUB 0
.pft_y EQUB 0
.pft_k EQUB 0
.pft_k2 EQUB 0
.pft_n EQUB 0
.pft_r EQUW 0
.pft_s EQUW 0
