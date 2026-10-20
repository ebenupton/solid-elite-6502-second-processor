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
# (the rasteriser makes no calls between banks: its bank 5 and ANDY parts call
# each other directly, R_LINE in bank 7 calls nothing outside it)
CROSS_CALLS = {}
CROSS_SCRATCH = ()
# the far calls between the home bank and the cold area (elite-far.asm):
# JSR far7 : EQUW target (ROMSEL COLDBANK, from elite-far.asm), JSR far4 : EQUW target (bank 4)
import os as _os, re as _re
_COLD = int(_re.search(r'^COLDBANK\s*=\s*&?([0-9A-Fa-f]+)', open(_os.path.join(
    _os.path.dirname(_os.path.abspath(__file__)), '..', '..', 'src', 'elite-far.asm')).read(), _re.M).group(1), 16)
FAR_CALLS = {'far7': _COLD, 'far7j': _COLD, 'far4': 0x04, 'far4j': 0x04}
FAR_SCRATCH = ('fA', 'fX', 'fB', 'ft', 'ft+1', 0xF4)
# SED is used only locally (BCD printing), CLD before leaving: D = 0 at every entry
DECIMAL_ASSUME_CLEAR = True
OBJECTS = None
# JSR/JMP to &E000-&FFFF (no code of ours there): MOS calls (OSBYTE, OSWORD, OSWRCH ...)
MOS_LO = 0xE000
MOS_WRITES = ()
