\ gfx-crater_c.asm - f_zerobounds: the crater's rows cleared
\ (included by gfx-frame.asm; on the Tube parasite, see the IFs there)

.f_zerobounds           \ rows R_NDT..R_NDB: no boundaries yet (only caller
                        \ fbd1, where f_bounds has checked R_NDT <= R_NDB)
 LDA R_NDB
 INC A
 STA fnb_e+1
 STA fsg_cb+1           \ (and f_segment's row range: rows NDT..NDB)
 EOR R_NDT              \ C = bit 0 of (R_NDB+1) EOR R_NDT: an odd row count
 LDY R_NDT
 STY fsg_ct+1
 LSR A
 LDA #0
 BCS fnb2               \ odd: one row first, then pairs
.fnb1                   \ two rows per pass
 STA R_NDN,Y
 STA R_NDP,Y
 INY
.fnb2
 STA R_NDN,Y
 STA R_NDP,Y
 INY
.fnb_e
 CPY #0                 \ patched: R_NDB+1
 BNE fnb1
IF _TPART <> 1
.fnb9
ENDIF
 RTS

