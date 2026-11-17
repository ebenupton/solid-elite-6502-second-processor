\ ******************************************************************************
\
\ h-joy.asm - the hosts' answer to the parasite's JOPOS request (both hosts:
\ the Master host's kernel and the Model B host's bank 7 include it last in
\ their code, after the recursive tokens, so that it moves nothing they run
\ often). The request is a C_DKS whose key has bit 7 set (no key has: the
\ parasite's p_dks sends internal key numbers, 0-&7F): hdks_body's first
\ instructions jump here, and on bit 7 (N, from h4body's LDA HR4D) the host
\ sends its JOPOS, the ADC's high bytes as its IRQ samples them (the Master
\ host's IRQ1 at timer 1, the Model B host's hb_irq at the vsync): the
\ joystick's x and y and the Bitstik's twist (tube/src/p-io.asm's p_keyq)
\
\ ******************************************************************************

.hdkx
 BMI hjoy               \ (a key with bit 7: JOPOS)
 LDX #3                 \ hdks_body's first instructions, then the rest of it
 PHP
 JMP hdks_body + 3
.hjoy
 LDA JOPOS
 HTX
 LDA JOPOS+1
 HTX
 LDA JOPOS+2
 HTX
 RTS
