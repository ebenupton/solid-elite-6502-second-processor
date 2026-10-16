\ ******************************************************************************
\
\ far7.asm - calls between Elite's bank (4) and its cold code in bank 7
\
\ INCLUDEd in the main code (it must be outside &8000-&BFFF). Elite's cold code
\ (docked screens, charts, title, equipment, ...: src/cold7.asm) lives in
\ sideways RAM bank 7 after the rasteriser's cold code. Every entry point keeps
\ its original name as a 5-byte stub where the code used to be:
\
\   .TT22 JSR far7 : EQUW TT22_7
\
\ and bank 7 code reaches anything outside bank 7 through stubs of its own
\ (in cold7.asm):
\
\   .x4_TT27 JSR far4 : EQUW TT27       call, then page bank 7 back in
\   .j4_FRCE JSR far4j : EQUW FRCE      jump (the target never returns here)
\
\ far7 / far4 page the target's bank in and call it, then page the caller's bank
\ (&F4 at the call) back in; far7j / far4j jump to it (the stub's return address
\ is dropped). A, X, Y and all the flags reach the target as they were at the
\ stub, and come back from it unchanged. While a called target runs, the stack
\ holds three more bytes than a plain JSR would (the caller's bank and one
\ return address into farc), so no target may pull its caller's return
\ address (the H_ hooks that take over by PLA : PLA are never called through
\ these stubs). &F4 always matches ROMSEL (MOS calls from bank 7 code restore
\ bank 7).
\
\ ******************************************************************************

FAR_HOME = 4            \ Elite's bank (ELITEBANK)
FAR_COLD = 7            \ the cold code's bank

.fA     EQUB 0          \ A, X, the bank to page in (and flags on the way back)
.fX     EQUB 0
.fB     EQUB 0
.ft     EQUW 0          \ the target

.far7
 PHP
 STA fA
 LDA #FAR_COLD
 BNE farc

.far4
 PHP
 STA fA
 LDA #FAR_HOME

.farc
 STA fB
 STX fX
 TSX                    \ &101,X = flags, &102,X / &103,X = the stub's return
 LDA &102,X             \ address (the JSR's last byte)
 STA fpc+1
 LDA &103,X
 STA fpc+2
 LDA &101,X             \ the flags and the caller's bank replace it:
 STA &102,X             \ the stack is (caller's return), bank, flags
 LDA &F4
 STA &103,X
 PLA
 LDX #1
.fpc
 LDA &FFFF,X            \ (patched) the EQUW after the JSR, read while the
 STA ft-1,X             \ caller's bank is still paged in
 INX
 CPX #3
 BNE fpc
 LDA fB
 STA &F4
 STA &FE30
 LDA fA
 LDX fX
 PLP
 JSR fjmp
 STA fA
 PHP
 PLA
 STA fB
 PLA                    \ the caller's bank
 STA &F4
 STA &FE30
 LDA fB
 PHA
 LDA fA
 PLP
 RTS

.fjmp
 JMP (ft)

.far7j
 PHP
 STA fA
 LDA #FAR_COLD
 BNE farj

.far4j
 PHP
 STA fA
 LDA #FAR_HOME

.farj
 STA fB
 STX fX
 TSX
 LDA &102,X
 STA fpj+1
 LDA &103,X
 STA fpj+2
 LDA &101,X             \ drop the stub's return address
 STA &103,X
 PLA
 PLA
 LDX #1
.fpj
 LDA &FFFF,X
 STA ft-1,X
 INX
 CPX #3
 BNE fpj
 LDA fB
 STA &F4
 STA &FE30
 LDA fA
 LDX fX
 PLP
 JMP (ft)
