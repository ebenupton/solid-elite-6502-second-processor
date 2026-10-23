# master/tools/grind's game config for full Master Elite (the beebgame dataflow tools'
# gamecfg.py format; see df/gamecfg.py)
GAME_DIR = 'master/src'
# the interrupt: IRQ1 (main RAM, IRQ1V): timer 1 (ACCCON D, the ADC) and, at vsync,
# LINSCN, which calls H_VSYNC (HAZEL: the renderer's flip) and SOINT (the sound);
# both paths leave with RTI.  The MOS saves A in &FC before IRQ1V.
ISR_ROOTS = ('IRQ1',)
ISR_EXITS = ()
ISR_EXTRA_WRITES = (0xFC,)
ISR_DATA_POINTERS = ()
INLINE_HELPERS = {}
SCREEN_POINTERS = ('SC',)           # Elite's screen pointer (SC, SCH)
# (the rasteriser makes no calls between banks: its bank 5 and ANDY parts,
# R_LINE's included, call each other directly)
CROSS_CALLS = {}
CROSS_SCRATCH = ()
# the stubs between the passes (elite-stubs.asm, build/elite-stubs.asm) are
# ordinary code, one per target (JSR to7 : JSR TT22_C : JMP to4): to7 and to4
# page the bank (STA VIA+&30), and the JSR names its target, which the model
# resolves by the label's segment; so there are no far calls of the inline
# form (JSR helper : EQUW target) left to model
FAR_CALLS = {}
FAR_SCRATCH = ()
# SED is used only locally (BCD printing), CLD before leaving: D = 0 at every entry
DECIMAL_ASSUME_CLEAR = True
OBJECTS = None
# JSR/JMP to &E000-&FFFF (no code of ours there): MOS calls (OSBYTE, OSWORD, OSWRCH ...)
MOS_LO = 0xE000
MOS_WRITES = ()
