\ ******************************************************************************
\
\ elite-far.asm - far calls between Elite's home bank and the cold area
\
\ Port (docs/MASTER-MAP.md): INCLUDEd in the main code, below &3000, so that it
\ is visible whatever is paged at &8000-&BFFF and whatever ACCCON X is.
\
\ Elite's game code runs with its home bank (HOMEBANK, sideways RAM bank 4)
\ paged in at &8000-&BFFF; main RAM and bank 4 code call each other directly.
\ The cold code (docked screens, text, charts, title, save and load, and the
\ flight-rare routines) lives in the cold area, ANDY at &8000-&8FFF plus bank 7
\ above &9000, which is paged in as ROMSEL = COLDBANK (&87). Every cold entry
\ point that code outside the cold area calls keeps its name as a 5-byte stub
\ outside the cold area, and its cold copy has the suffix _C:
\
\   .TT22 JSR far7 : EQUW TT22_C        call (A, X, Y, flags pass both ways)
\   .DEATH JSR far7j : EQUW DEATH_C     jump (the target never returns)
\
\ and cold code reaches everything outside the cold area through stubs of its
\ own, in the cold area:
\
\   .x4_TT26 JSR far4 : EQUW TT26       call, then page the cold area back in
\   .j4_TT100 JSR far4j : EQUW TT100    jump (the target never returns here)
\
\ far7 / far4 page the target's bank in and call it, then page the caller's
\ bank (&F4 at the call) back in. So far4 also works from code that runs with
\ any ROM paged (CHPR as WRCHV with DFS paged): the caller gets its ROM back.
\ far7j / far4j jump to the target (the stub's return address is dropped).
\ A, X, Y and all the flags reach the target as they were at the stub, and come
\ back from it unchanged. &F4 always matches ROMSEL (the MOS restores ROMSEL
\ from &F4, bit 7 included, after paged ROM calls).
\
\ While a called target runs, the stack holds, from the top: the return
\ address into this code (farret - 1), the caller's ROMSEL, and the caller's
\ return address (three bytes more than a plain JSR), so no target may pull
\ its caller's return address or look at the stack above it. The harness
\ (harness/mlib.mjs) sees through these frames by the label farret.
\
\ This is the demo port's src/far7.asm with the banks changed.
\
\ ******************************************************************************

COLDBANK = &87          \ ROMSEL for the cold area: bank 7 with ANDY over
                        \ &8000-&8FFF

.fA     EQUB 0          \ A, X, the bank to page in (and flags on the way back)
.fX     EQUB 0
.fB     EQUB 0
.ft     EQUW 0          \ the target

.far7
 PHP
 STA fA
 LDA #COLDBANK
 BNE farc

.far4
 PHP
 STA fA
 LDA #HOMEBANK

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
 STA VIA+&30
 LDA fA
 LDX fX
 PLP
 JSR fjmp
.farret
 STA fA
 PHP
 PLA
 STA fB
 PLA                    \ the caller's bank
 STA &F4
 STA VIA+&30
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
 LDA #COLDBANK
 BNE farj

.far4j
 PHP
 STA fA
 LDA #HOMEBANK

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
 STA VIA+&30
 LDA fA
 LDX fX
 PLP
 JMP (ft)
