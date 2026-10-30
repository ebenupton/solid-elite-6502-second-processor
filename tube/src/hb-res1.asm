\ hb-res1.asm - the Model B host's main RAM code (hb-res.asm): hb_fixed: at RUNP: the entry points banks D and P call

.runp                   \ (unused: bank D holds no code now) bank D's r_spc: the run at RUNPJ's target, in bank P,
 PHA                    \ with an RTS planted at (RZ_PP), which is then taken
 PAGE RASTPOLY          \ out; A = colour, Y = row (kept); back in bank D
 LDA RUNPJ+2
 JSR P_PGFIX            \ (the page for the buffer: keeps A, X, Y)
 LDX #0
 LDA #&60
 STA (&14,X)            \ (RZ_PP)
 PLA
.runpj
 JSR &FFFF              \ (patched: r_jsr's operand, bank D's code writes it)
 PHA
 LDX #0
 LDA #&99
 STA (&14,X)
 PAGE RASTBANK
 PLA
 RTS
.p_rowrepr              \ bank D's r7_crep: bank P's r7_rowrep (rows Y ..
 PAGE RASTPOLY          \ c_YE - 1)
 JSR P_ROWREP
 PAGE RASTBANK
 RTS
