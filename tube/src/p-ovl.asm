\ ******************************************************************************
\
\ p-ovl.asm - the parasite's overlay region (docs/TUBE-MAP.md): one region of
\ the parasite's memory, from OVL_START to &F800, holds one of the overlays
\ whose images the host keeps (storage only):
\
\   * overlay D, the direct-mode overlay: the cold blocks that run only on
\     the screens drawn directly (tube/src/ovl-d.txt), with the extended
\     tokens they print;
\
\ Code outside an overlay reaches it only through stubs, which streams.py
\ writes at its routines' places (as the Master port's far calls into bank 7):
\
\   .TT22 JSR povd : EQUW TT22_C        call
\   .TT170 JSR povdj : EQUW TT170_C     jump (the target never returns)
\
\ povd loads the overlay if the region does not hold it, then calls the
\ target with A, X, Y and the flags as they were at the stub, and returns them
\ as the target left them; if the overlay that was in before the call has
\ routines on the stack, it is loaded back first. While a target runs, the
\ stack holds, from the top: the return address into povd, the overlay that
\ was in, then the caller's return address (one byte more than a plain JSR),
\ so no target may pull its caller's return address (as with the Master
\ port's far calls, which these routines are reached by there too).
\
\ ******************************************************************************

OVL_D = 1               \ the overlays, by number (ovl_cur, C_OVLGET, C_OVLPUT)
OVL_S = 2
OVL_SS = 3              \ (overlay S's state, saved by the host)

.ovl_cur EQUB OVL_D     \ the overlay in the region (0: none; the parasite's
                        \ image starts with overlay D in)
.ovl_dn  EQUB 0         \ calls into overlay D that have not returned
.ovl_sn  EQUB 0         \ (overlay S's: none yet)

.oA EQUB 0              \ A, X, the target
.oX EQUB 0
.ot EQUW 0

.povd
 PHP
 STA oA
 STX oX
 TSX                    \ &101,X = flags, &102,X / &103,X = the stub's return
 LDA &102,X             \ address (the JSR's last byte)
 STA opc+1
 LDA &103,X
 STA opc+2
 LDA &101,X             \ the stack becomes (caller's return), the overlay that
 STA &102,X             \ was in, flags
 LDA ovl_cur
 STA &103,X
 PLA
 LDX #1
.opc
 LDA &FFFF,X            \ (patched) the EQUW after the JSR
 STA ot-1,X
 INX
 CPX #3
 BNE opc
 LDA #OVL_D
 JSR ovl_need
 INC ovl_dn
 LDA oA
 LDX oX
 PLP
 JSR ojmp
.povret                 \ (the target has returned: A, X, Y and the flags are
 PHP                    \ its)
 STA oA
 STX oX
 DEC ovl_dn
 TSX                    \ &101,X = flags, &102,X = the overlay that was in
 LDA &102,X
 BEQ ovr1
 CMP ovl_cur
 BEQ ovr1
 TAX                    \ back in if its routines are on the stack (ovl_dn for
 LDA ovl_dn-1,X         \ D, ovl_sn for S)
 BEQ ovr1
 TXA
 JSR ovl_need
.ovr1
 TSX
 LDA &101,X             \ the flags over the overlay's byte
 STA &102,X
 PLA
 LDA oA
 LDX oX
 PLP
 RTS
 ASSERT ovl_sn = ovl_dn + 1

.ojmp
 JMP (ot)

\ ovl_dact: C set if overlay D's routines are on the stack (calls through
\ povd that have not returned: their frames hold povret's return address).
\ ovl_dn counts them, but the game resets the stack (BEGIN, DEATH ...), so
\ when it is not zero the stack is searched, and ovl_dn cleared if there are
\ none. Keeps Y

.ovl_dact
 CLC
 LDA ovl_dn
 BEQ oda9
 TSX
.oda1
 INX
 BEQ oda8
 LDA &100,X
 CMP #LO(povret - 1)
 BNE oda1
 LDA &101,X
 CMP #HI(povret - 1)
 BNE oda1
 SEC                    \ (found)
 RTS
.oda8
 STZ ovl_dn
 CLC
.oda9
 RTS

.povdj                  \ a jump into overlay D (the stub's return address is
 PHP                    \ dropped)
 STA oA
 STX oX
 TSX
 LDA &102,X
 STA opj+1
 LDA &103,X
 STA opj+2
 LDA &101,X
 STA &103,X
 PLA
 PLA
 LDX #1
.opj
 LDA &FFFF,X
 STA ot-1,X
 INX
 CPX #3
 BNE opj
 LDA #OVL_D
 JSR ovl_need
 LDA oA
 LDX oX
 PLP
 JMP (ot)

\ ovl_need: A = an overlay: load it into the region from the host's copy
\ (C_OVLGET: the host sends its image, OVL_START up, whole pages) if the
\ region does not hold it. Overlay S's state (its first part, to S_STATE_END)
\ is the rasteriser's: when S goes out in space mode (GMODE bit 7) the host
\ keeps it (C_OVLPUT), and it comes back with S; when S goes out in direct
\ mode it is not kept, and with S back the next space-mode frame starts
\ buffer 0 afresh (GSTASH, f_enter2's f_b0new), as after a disc command.
\ Keeps Y; A and X are not kept (the callers above restore theirs)

.ovl_need
 CMP ovl_cur
 BEQ ovn9
 PHY
 PHA
 LDA ovl_cur            \ S going out in space mode: its state to the host
 CMP #OVL_S
 BNE ovn2
 BIT GMODE
 BPL ovn2
 LDA #C_OVLPUT
 JSR ptx
 LDA #OVL_SS
 JSR ptx
 LDY #0
 LDX #HI(OVL_START)
 STX ovp1+2
.ovp1
 LDA OVL_START,Y        \ (patched: the page)
 JSR ptx
 INY
 BNE ovp1
 INC ovp1+2
 LDA ovp1+2
 CMP #HI(S_STATE_END + 255)
 BNE ovp1
 LDA #&FF
 STA ovl_ssv
.ovn2
 PLA
 STA ovl_cur
 JSR ovl_get            \ the overlay in
 LDA ovl_cur
 CMP #OVL_S
 BNE ovn8
 BIT ovl_ssv            \ S: its state back, or buffer 0 afresh
 BPL ovn7
 STZ ovl_ssv
 LDA #OVL_SS
 JSR ovl_get
 BRA ovn8
.ovn7
 LDA #&80
 STA GSTASH
.ovn8
 PLY
.ovn9
 RTS

.ovl_ssv EQUB 0         \ bit 7: the host keeps overlay S's state

\ ovl_get: A = an overlay (or S's state): C_OVLGET, then its pages from the
\ host into the region. Clobbers A, X, Y

.ovl_get
 TAX
 LDA #C_OVLGET
 JSR ptx
 TXA
 JSR ptx
 LDA ovlen-1,X          \ its end, as a page (whole pages are sent)
 STA ovn_n+1
 LDA #HI(OVL_START)
 STA ovn_d+2
 LDY #0
.ovn1
 BIT PR4S               \ (prx inlined)
 BPL ovn1
 LDA PR4D
.ovn_d
 STA OVL_START,Y        \ (patched: the page)
 INY
 BNE ovn1
 INC ovn_d+2
 LDA ovn_d+2
.ovn_n
 CMP #0                 \ (patched: the last page + 1)
 BNE ovn1
 RTS
 ASSERT LO(OVL_START) = 0

.ovlen                  \ each overlay's end, as a page (OVL_START is page aligned)
 EQUB HI(OVL_D_END + 255), HI(OVL_S_END + 255), HI(S_STATE_END + 255)
