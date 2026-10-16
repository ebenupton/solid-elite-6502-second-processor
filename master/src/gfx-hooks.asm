\ ******************************************************************************
\
\ gfx-hooks.asm - the glue between Master Elite's drawing code and the frame
\ layer (after the Demonstration Disc port's src/hooks.asm)
\
\ Lives in HAZEL (&C000-&DFFF, always visible once the loader has set ACCCON
\ bit Y). Elite's drawing routines call these with a single JSR at their
\ start. "Record mode" is QQ11 = 0 (a view that draws ships) and GFORCE = 0:
\ drawing is then recorded for FRAME instead of being done. A hook that takes
\ over pulls its return address (PLA : PLA) so its RTS returns from the hooked
\ routine itself.
\
\ ******************************************************************************

.hA EQUB 0
