# tools/grind's game config for Elite (the beebgame dataflow tools' gamecfg.py format)
GAME_DIR = 'src'
# the interrupt: IRQ1 (main RAM; JMPs to LINSCN at vsync, JSRs H_VSYNC / H_SPLIT in
# HAZEL); it leaves through JMP (VEC) into the MOS's handler
ISR_ROOTS = ('IRQ1',)
ISR_EXITS = ('VEC',)
ISR_EXTRA_WRITES = (0xFC,)          # the MOS saves A in &FC
ISR_DATA_POINTERS = ()
INLINE_HELPERS = {}
SCREEN_POINTERS = ('SC',)           # Elite's screen pointer (SC, SCH)
# the rasteriser's bank 5 <-> bank 7 calls through HAZEL (raster_hz.asm)
CROSS_CALLS = {'r_call7': ('r_hzt7', 'B7'), 'r_call5': ('r_hzt5', 'B5')}
CROSS_SCRATCH = ('r_hza',)
# SED is used only locally (BCD printing), CLD before leaving: D = 0 at every entry
DECIMAL_ASSUME_CLEAR = True
OBJECTS = None
# JSR/JMP to &E000-&FFFF (no code of ours there): MOS calls (OSBYTE, OSWORD, OSWRCH ...)
MOS_LO = 0xE000
MOS_WRITES = ()
