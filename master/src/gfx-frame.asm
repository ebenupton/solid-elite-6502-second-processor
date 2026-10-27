\ ******************************************************************************
\
\ frame.asm - the double-buffered filled renderer's frame layer
\
\ Lives in sideways RAM bank GFXBANK (paged in only for the duration of a call,
\ via GCALL in main RAM). Elite's drawing primitives, when QQ11 = 0 (the space
\ view, the title screen and the death screen: the only screens that draw
\ ships), record what they would have drawn into the display list here; FRAME
\ (called once per main-loop iteration) renders the list into the back buffer
\ and asks the IRQ to show it at the next vertical sync.
\
\ Entry points are reached through the jump table at the start of the bank,
\ GT_* indices below, by LDX #GT_xxx : JSR GCALL.
\
\ ******************************************************************************

\ Entry points are called from main RAM through the G_* stubs (see
\ gstubs.asm), which page this bank in and Elite's bank back afterwards,
\ preserving A, X, Y and C on entry.

FZ = &D2                \ &D2-&E1
fz_p    = FZ            \ general pointer (2)
fz_q    = FZ+2          \ second pointer (2)
fz_dl   = FZ+4          \ ship's XX2 copy (2)
fz_v3   = FZ+6          \ ship's XX3 copy (2)
fz_ft   = FZ+8          \ face list pointer (2)
fz_nm   = FZ+10         \ general pointer (2), used by the text overlay
fz_dt   = FZ+10         \ ship's fin / detail list pointer (2)
fz_i    = FZ+12
fz_n    = FZ+13
fz_t    = FZ+14
fz_u    = FZ+15

\ ------------------------------------------------------------------------------
\ State
\ ------------------------------------------------------------------------------

\ Shared with the IRQ handler and Elite (in the low area, gfx-gvars.asm):
\ GMODE (bit 7 set = space mode, double buffered), GFRONT (0/1 buffer
\ displayed), GFLIP (non-zero = flip pending to GPEND), GPEND, GDRAWON
\ (0 = primitives are erasing, so ignore them), GFORCE (non-zero = draw
\ directly even though QQ11 = 0), GSIGHT, GLASV.

.F_BACK     EQUB 1      \ the buffer being drawn (the one not displayed)

.F_NSHIP    EQUB 0      \ ships recorded this frame
.F_SZH      SKIP MAXSH  \ ship z (hi, lo) for sorting
.F_SZL      SKIP MAXSH
.F_STYP     SKIP MAXSH  \ ship type
.F_SNF      SKIP MAXSH  \ number of faces
.F_SPL      SKIP MAXSH  \ pointer into F_DL: XX2 copy (nf bytes) then XX3 copy
.F_SPH      SKIP MAXSH
.F_ORD      SKIP MAXSH  \ draw order (indices, far to near)
.F_SX4      SKIP MAXSH  \ LL9's XX4 (vertex visibility cut-off)
.F_DLP      EQUW 0      \ next free byte in F_DL

.F_NLINE    EQUB 0      \ lines recorded this frame (planet features, enemy lasers)
.F_LX0      SKIP MAXLN
.F_LY0      SKIP MAXLN
.F_LX1      SKIP MAXLN
.F_LY1      SKIP MAXLN
.F_LC       SKIP MAXLN  \ colour index

.F_NDOT     EQUB 0      \ dots recorded this frame (particles, distant ships)
.F_DX       SKIP MAXDT
.F_DY       SKIP MAXDT
.F_DS       SKIP MAXDT  \ size 1..3
.F_DC       SKIP MAXDT  \ colour index


.F_PLON     EQUB 0      \ planet disc recorded this frame
.F_PLX      EQUW 0      \ centre x (16-bit signed screen)
.F_PLY      EQUW 0      \ centre y
.F_PLR      EQUB 0      \ radius
.F_PLT      EQUB 0      \ planet type

.F_DCOL     EQUB 0, 0   \ disc colour index currently in each buffer's disc layer

\ ------------------------------------------------------------------------------
\ Fixed colours (even-row byte, odd-row byte), by index
\ ------------------------------------------------------------------------------

FC_BLACK = 0
FC_LASER = 1            \ our laser beams
FC_ELASER = 2           \ enemy laser beams
FC_PLINE = 3            \ planet meridians / craters
FC_PART = 4             \ explosion particles
FC_SIGHT = 5            \ laser sights
FC_STAR = 6             \ stardust (logical colour; stars use a solid ink)

.F_CPE
 EQUB &00, &FF, &F0, &0F, &FF, &0F, &FF
F_CPO = F_CPE           \ (the odd rows' bytes are the even rows')

\ F_INIT: one-off initialisation (called by the loader / startup) is in F_DL
\ (elite-gfx.asm), which it leaves to the ship records.

IF _TPART <> 1 OR _TDUMB  \ (Tube: the host's part; the dumb host's parasite's too)
\ ------------------------------------------------------------------------------
\ Text map: 24 rows x 32 columns of desired characters (F_TM), and for each
\ cell what each buffer shows (F_ST, at F_TM + &300). A cell of F_TM is its
\ character (&20-&7F), or 0, or, once cleared, &80 + the character it had
\ (empty, remembering the character). For buffer b, bit b+2 of F_ST (F_STN)
\ says it shows a character in the cell, and bit b (F_STM) that this is the
\ cell's character, or the one it remembers: so a cell cleared and given
\ its character back (TT66 and a view's title) is shown as it was, as with
\ the original's shown maps. The text steps erase a cell where a buffer shows
\ a character that is not the cell's (N, and not M or the cell empty), and
\ draw a non-empty cell where it shows none (not N). F_TMR counts the
\ non-empty cells of each text map row, F_SHR0/F_SHR1 those each buffer
\ shows, so empty rows cost nothing.
\ ------------------------------------------------------------------------------

F_STM = 1               \ F_ST: buffer 0 shows the cell's character
F_STN = 4               \ F_ST: buffer 0 shows a character (buffer 1: x 2)
IF _TPART <> 2 OR _TDUMB = FALSE   \ (the dumb host: none of the text map's)

.f_tmclear              \ clear the text map and buffer 1's shown cells (Master
 LDX #0                 \ port: buffer 1, shadow RAM, is the direct-mode screen,
.ftc1                   \ which TTX66 blanks; buffer 0 keeps its own: it still
 LDA F_TM,X             \ holds that picture)
 BEQ P%+7
 ORA #&80
 STA F_TM,X
 LDA F_TM+256,X
 BEQ P%+7
 ORA #&80
 STA F_TM+256,X
 LDA F_TM+512,X
 BEQ P%+7
 ORA #&80
 STA F_TM+512,X
 INX
 BNE ftc1
 LDA #5*F_STM           \ buffer 1 shows nothing
 JSR f_stand
 LDX #23
.ftc2
 STA F_TMR,X
 STA F_SHR1,X
 DEX
 BPL ftc2
 JMP f_tchall

\ f_stand: every cell's F_ST AND A: a buffer's shown cells cleared (f_tmclear,
\ f_enter, f_b0new). Returns A = 0

.f_stand
 STA fsa1+1
 STA fsa2+1
 STA fsa3+1
 LDX #0
.fsa0
 LDA F_ST,X
.fsa1
 AND #0                 \ patched
 STA F_ST,X
 LDA F_ST+256,X
.fsa2
 AND #0                 \ patched
 STA F_ST+256,X
 LDA F_ST+512,X
.fsa3
 AND #0                 \ patched
 STA F_ST+512,X
 INX
 BNE fsa0
 TXA
 RTS

\ f_stset: every cell's F_ST = (F_ST AND A) OR (X if the text map's cell is
\ empty, Y if not): buffer 1's shown cells set from the text map (f_sync)

.f_stset
 STA fss_k+1
 STX fss_z+1
 STY fss_n+1
 LDA #HI(F_TM)
 STA fss_t+2
 LDA #HI(F_ST)
 STA fss_s+2
 STA fss_d+2
 LDX #0
.fss_t
 LDA F_TM,X             \ patched
 BEQ fss_z
 BMI fss_z
.fss_n
 LDA #0                 \ patched
 BRA fst2
.fss_z
 LDA #0                 \ patched
.fst2
 STA fss_o+1
.fss_s
 LDA F_ST,X             \ patched
.fss_k
 AND #0                 \ patched
.fss_o
 ORA #0                 \ patched
.fss_d
 STA F_ST,X             \ patched
 INX
 BNE fss_t
 INC fss_t+2
 INC fss_s+2
 INC fss_d+2
 LDA fss_t+2
 CMP #HI(F_TM)+3
 BNE fss_t
 RTS

\ f_cell: X = column, Y = row -> f_ptr = row*32 + column (offset into a map)
\ Returns the offset in f_off (2 bytes) and also patches the map accessors
\ f_tmld/f_tmst and f_stld/f_stst.

.f_cell
 TYA
 LSR A
 LSR A
 LSR A
 STA f_off+1            \ row DIV 8 = high byte of row*32
 TYA
 ASL A
 ASL A
 ASL A
 ASL A
 ASL A                  \ (row MOD 8) * 32
 STA f_off
 TXA
 ORA f_off
 STA f_off
 CLC
 ADC #LO(F_TM)
 STA f_tmld+1
 STA f_tmst+1
 STA f_stld+1
 STA f_stst+1
 LDA f_off+1
 ADC #HI(F_TM)
 STA f_tmld+2
 STA f_tmst+2
 ADC #3                 \ (C = 0) F_ST = F_TM + &300
 STA f_stld+2
 STA f_stst+2
 RTS

.f_off  EQUW 0
.f_row  EQUB 0
.F_TCH  SKIP 24         \ per text row: bit b set = buffer b's shown row may
                        \ differ from the text map (f_text1/f_text2 scan it whole)
.f_tbit EQUB 0          \ this frame's buffer bit (1 or 2): its M bit in F_ST

.f_tchall               \ every row changed, for both buffers (keeps X; A = 0)
 PHX
 LDX #23
 LDA #3
.fta1
 STA F_TCH,X
 DEX
 BPL fta1
 PLX
 LDA #0
 RTS

\ f_char0 (F_CHAR, frame_cold.asm): A = character, (XC-1, YC) = cell. EOR
\ semantics like the original: printing the same character again removes it.

.f_char0
 STY f_ysav
 PHA
 LDX XC
 DEX
 LDY YC
 CPY #24
 BCS fch9
 CPX #32
 BCS fch9
 STY f_row
 JSR f_cell
 PLA
 JSR f_tmget            \ X = current content
 BEQ fch1               \ empty: store the character
 BMI fch1
 STA f_tmp
 CPX f_tmp
 BEQ fch2               \ same character: remove it
 JSR f_tmstore          \ different: replace
 JMP fch8
.fch1
 JSR f_tmstore
 LDX f_row
 INC F_TMR,X
 JMP fch8
.fch2
 JSR f_tmclr
 LDX f_row
 DEC F_TMR,X
.fch8
 LDX f_row
 LDA #3
 STA F_TCH,X
 LDY f_ysav
 RTS
.fch9
 PLA
 LDY f_ysav
 RTS

.f_tmstore              \ A = the new character, X = the cell's content (not
 STA f_tmp              \ A): if it is not A's, or A's remembered, neither
 TXA                    \ buffer shows the cell's character now (M = 0)
 AND #&7F
 CMP f_tmp
 BEQ fts1
.f_stld
 LDA F_ST               \ patched
 AND #3*F_STN
.f_stst
 STA F_ST               \ patched
.fts1
 LDA f_tmp
.f_tmst
 STA F_TM               \ patched
 RTS

.f_tmclr                \ the cell (not empty) cleared: it remembers its
 JSR f_tmget            \ character, which each buffer shows or not as before
 TXA
 ORA #&80
 BNE f_tmst             \ (always)

.f_tmget
.f_tmld
 LDX F_TM               \ patched; sets Z and N on the content
 RTS

.f_ysav EQUB 0
.f_tmp  EQUB 0

\ f_delchar0 (F_DELCHAR, frame_cold.asm): clear the text map cell at X =
\ column, Y = row

.f_delchar0
 STY f_ysav
 CPY #24
 BCS fdc9
 CPX #32
 BCS fdc9
 STY f_row
 JSR f_cell
 JSR f_tmget
 BEQ fdc9
 BMI fdc9
 JSR f_tmclr
 LDX f_row
 DEC F_TMR,X
 LDA #3
 STA F_TCH,X
.fdc9
 LDY f_ysav
 RTS

\ f_clrtext0 (F_CLRTEXT, frame_cold.asm): clear text map rows X to Y inclusive
\ (each cell remembers its character; F_ST is unchanged)

.f_clrtext0
 STY f_ysav
 STY f_tmp
.fct1
 STX f_row
 LDA F_TMR,X            \ (an empty row is clear already)
 BEQ fct6
 LDY f_row
 LDX #0
 JSR f_cell             \ f_tmst -> start of row
 LDA f_tmst+1
 STA fct3+1
 STA fct4+1
 LDA f_tmst+2
 STA fct3+2
 STA fct4+2
 LDY #31
.fct3
 LDA F_TM,Y             \ patched
 BEQ fct5
 ORA #&80
.fct4
 STA F_TM,Y             \ patched
.fct5
 DEY
 BPL fct3
 LDA #0
 LDX f_row
 STA F_TMR,X
.fct6
 LDA #3
 STA F_TCH,X
 INX
 CPX #24
 BCS fct9
 CPX f_tmp
 BCC fct1
 BEQ fct1
.fct9
 LDY f_ysav
 RTS

ENDIF
\ ------------------------------------------------------------------------------
\ f_direct0 (F_DIRECT, frame_cold.asm): the screen is about to be cleared and
\ drawn directly (TT66): cancel double buffering, show and access main RAM.
\ ------------------------------------------------------------------------------

.f_direct0              \ (Master port: direct mode shows shadow RAM, where
IF _TPART = 1             \ (Tube: the display is the host's: C_DIRECTD)
 LDA #C_DIRECTD
 JSR ptx
 LDA #0
 STA GMODE
 STA GFLIP
 STA GSIGHT
 STA GLASV
ELSE
 SEI                    \ Master's own drawing goes, buffer 1)
 LDA #0
 STA GMODE
 STA GFLIP
 STA GSIGHT
 STA GLASV
 LDA #1
 STA GFRONT
IF _HOSTB = 0             \ (Model B: the IRQ shows buffer GFRONT)
 TSB &FE34              \ ACCCON D = 1: show shadow RAM (X as it is)
ENDIF
 CLI
ENDIF
IF _TPART <> 2 OR _TDUMB = FALSE
 JSR f_tmclear          \ (A = 0; X only, so Y is kept)
ELSE
 LDA #0                 \ (the dumb host: no text map)
ENDIF
 LDX #NDSTAR-1          \ the stars will be re-recorded too (and no
.fdi1                   \ direct-mode stars noted: F_DSS)
 STA R_SS,X
 STA F_DSS,X
 DEX
 BPL fdi1
 RTS

ENDIF
IF _TPART = 1 AND _TDUMB = FALSE
.f_ysav EQUB 0          \ (the text map's, which is the host's, but F_FRAME's too)
.f_tmp  EQUB 0
ENDIF
IF _TPART = 2 AND _TDUMB
.f_ysav EQUB 0          \ (the dumb host: f_unstar's)
.f_tmp  EQUB 0
ENDIF
IF _TPART <> 2             \ (Tube: the parasite's part; docs/TUBE-MAP.md)
\ ------------------------------------------------------------------------------
\ Recorders (called during the main loop; must only touch Elite variables they
\ are documented to read, and preserve Y)
\ ------------------------------------------------------------------------------

\ F_SHIP: record the ship being drawn by LL9. Inputs: TYPE, GNF (faces),
\ GNV (vertices), XX2 (face visibility), XX3 (projected vertices), INWK+6/7 (z),
\ and the orientation vectors' high bytes (L_REC: the record's XX2 copy holds
\ each face's lighting level, see gfx-light.asm).

.F_SHIP
 STY f_ysav
 LDX F_NSHIP
 CPX #MAXSH
 BCC P%+5
 JMP fsh9
 LDA GNV
 ASL A
 ASL A
 STA f_nv4
 CLC
 ADC GNF
 ADC F_DLP              \ room for nf + 4 * nv bytes?
 LDA F_DLP+1
 ADC #0
 CMP #HI(F_DLEND)
 BCC P%+5
 JMP fsh9
 LDA F_DLP
 STA F_SPL,X
 STA fsh2+1
 LDA F_DLP+1
 STA F_SPH,X
 STA fsh2+2
 LDA INWK+7
 STA F_SZH,X
 LDA INWK+6
 STA F_SZL,X
 LDA GTYPE              \ (Master port: TYPE, or DOD for the Dodo station)
 STA F_STYP,X
 LDA GNF
 STA F_SNF,X
 LDA XX4
 STA F_SX4,X
 LDY #0
 LDX GNF
 BEQ fsh3
.fsh1
 LDA XX2,Y
.fsh2
 STA &FFFF,Y            \ patched
 INY
 DEX
 BNE fsh1
 LDA GTYPE              \ Master port: the alloy plate's one face has no
 CMP #PLT               \ normal, so LL9 never marks it visible: fill it from
 BNE fsh3               \ both sides (no winding cull)
 LDA fsh2+1
 STA fsh8+1
 LDA fsh2+2
 STA fsh8+2
 LDA #1
.fsh8
 STA &FFFF              \ patched: the XX2 copy's first byte
.fsh3
 JSR L_REC              \ the faces' levels into the XX2 copy (gfx-light.asm,
                        \ main RAM: game context; Y is kept)
 TYA                    \ advance the destination past the XX2 copy
 CLC
 ADC fsh2+1             \ d = lo0 (C = carry into hi)
 STA fsh5+1             \ patch d+0, d+1, d+2, d+3 into the unrolled loop
 INC A                  \ (INC A leaves C alone)
 STA fsh5a+1
 INC A
 STA fsh5b+1
 INC A
 STA fsh5c+1
 LDA fsh2+2
 ADC #0
 STA fsh5+2
 STA fsh5a+2
 STA fsh5b+2
 STA fsh5c+2
 LDA fsh5+1             \ rare: d+k wrapped into the next page
 CMP #&FD
 BCC fsh7
 INC fsh5c+2
 CMP #&FE
 BCC fsh7
 INC fsh5b+2
 CMP #&FF
 BCC fsh7
 INC fsh5a+2
.fsh7
 LDA f_nv4              \ 4 * nv bytes, a multiple of 4
 BEQ fsh6
 SEC
 SBC #4
 TAY                    \ Y = f_nv4-4 .. 0 step -4, C = 1 in the loop
.fsh4
 LDA XX3+3,Y
.fsh5c
 STA &FFFF,Y            \ patched: d+3
 LDA XX3+2,Y
.fsh5b
 STA &FFFF,Y            \ patched: d+2
 LDA XX3+1,Y
.fsh5a
 STA &FFFF,Y            \ patched: d+1
 LDA XX3,Y
.fsh5
 STA &FFFF,Y            \ patched: d
 TYA
 SBC #4
 TAY
 BCS fsh4
.fsh6
 LDA f_nv4
 CLC
 ADC fsh5+1
 STA F_DLP
 LDA fsh5+2
 ADC #0
 STA F_DLP+1
 INC F_NSHIP
.fsh9
 LDY f_ysav
 RTS

.f_nv4 EQUB 0

\ F_LINE: record a line X1,Y1 -> X2,Y2 in colour GLCOL (8-bit screen coords)

.F_BOMB                 \ Master port: a new energy bomb bolt: drop the lines of
 BIT f_bomb             \ the bolt recorded earlier in this frame, if any
 BPL fbo1
 LDA f_bmark
 STA F_NLINE
 RTS
.fbo1
 LDA F_NLINE
 STA f_bmark
 LDA #&FF
 STA f_bomb
 RTS
.f_bomb  EQUB 0
.f_bmark EQUB 0

.F_LINE
 LDX F_NLINE
 CPX #MAXLN
 BCS fli9
 LDA X1
 STA F_LX0,X
 LDA Y1
 STA F_LY0,X
 LDA X2
 STA F_LX1,X
 LDA Y2
 STA F_LY1,X
 LDA GLCOL
 STA F_LC,X
 INC F_NLINE
.fli9
 RTS

\ F_DOT: record a dot at X = x, A = y, size from ZZ as PIXEL does, colour GDCOL

.F_DOT
 STY f_ysav
 LDY F_NDOT
 CPY #MAXDT
 BCS fdo9
 STA F_DY,Y
 TXA
 STA F_DX,Y
 LDA GDCOL
 STA F_DC,Y
 LDX #2                 \ (Master port: a dash for ZZ >= 80, a double-
 LDA ZZ                 \ height dash below, as Master's PIXEL)
 CMP #80
 BCS fdo1
 INX
.fdo1
 TXA
 STA F_DS,Y
 INC F_NDOT
.fdo9
 LDY f_ysav
 RTS

\ F_PLANET: record the planet: centre (K3, K4) 16-bit, radius K, TYPE

.F_PLANET
 LDA TYPE
 LSR A
 BCS fpl1
 LDA K3
 STA F_PLX
 LDA K3+1
 STA F_PLX+1
 LDA K4
 STA F_PLY
 LDA K4+1
 STA F_PLY+1
 LDA K
 STA F_PLR
 LDA TYPE
 STA F_PLT
 LDA INWK+8             \ the planet's z is 24-bit, and a ship drawn with
 BEQ P%+4               \ faces is nearer than 4096: a planet 65536 or more
 LDA #&FF               \ away is held as z_hi = &FF, further than any such
 ORA INWK+7             \ ship (with INWK+7 alone, a planet 65536-69631 away
                        \ hid the station in front of it on a docking run)
 STA F_PLZH
 LDA INWK+6
 STA F_PLZL
 LDA #&FF
 STA F_PLON
 RTS

.F_PLZH EQUB 0          \ the planet's z (hi, lo), for hiding ships behind it
.F_PLZL EQUB 0
.fpl1                   \ the sun
 LDA K3
 STA F_SUX
 LDA K3+1
 STA F_SUX+1
 LDA K4
 STA F_SUY
 LDA K4+1
 STA F_SUY+1
 LDA K
 STA GSUNR
 LDA #&FF
 STA GSUNON
 RTS

.F_SUX EQUW 0
.F_SUY EQUW 0

\ F_SHPPT: record a distant ship as a 2x2 dot at (K3, K4), in its hue

.F_SHPPT
 STY f_ysav
 LDY F_NDOT
 CPY #MAXDT
 BCS fsp9
 LDA K3
 STA F_DX,Y
 LDA K4
 STA F_DY,Y
 LDA #3
 STA F_DS,Y
 LDA TYPE
 ORA #&80               \ bit 7: ship type (bits 0-6), drawn in its dot colour
 STA F_DC,Y
 INC F_NDOT
.fsp9
 LDY f_ysav
 RTS

\ ------------------------------------------------------------------------------
\ F_FRAME: render this frame's display list into the back buffer and queue a
\ flip. Called once per main-loop iteration (after M%), and per title-screen
\ iteration.
\ ------------------------------------------------------------------------------

.F_FRAME
 STY f_ysav
 LDA QQ11
 BEQ ff1
 JSR T_KOFF             \ (no kept rows: SOLIDSPAN-REPORT.md)
 JMP f_reset            \ not a space view: just forget what was recorded

.ff1
IF _TDUMB
 LDA #OVL_S             \ (Tube: the rasteriser's overlay in, p-ovl.asm)
 JSR ovl_need
ENDIF
 JSR L_SUN              \ the light for the next iteration's ships (gfx-light.asm,
                        \ main RAM: game context, before ACCCON X is set below)

 \ save the zero page the rasteriser uses (&06-&27) and the frame layer's
 \ (&D2-&E1), unrolled
 FOR z, &06, &27        \ (on the stack: LDA zp/PHA is a cycle cheaper than
  LDA z                 \ LDA zp/STA abs; PLA/STA zp costs what LDA abs/STA zp
  PHA                   \ did)
 NEXT
 FOR z, 0, 15
  LDA FZ + z
  PHA
 NEXT

 BIT GMODE
 BMI ff5
 JSR f_enter2           \ first space-mode frame since the screen was cleared
                        \ (f_enter, with frame_cold.asm's direct-mode fix-ups)

.ff5                    \ (what touches no screen memory goes before the wait)
IF _TPART = 0 OR _TDUMB
 JSR f_bufpatch
ENDIF
 LDA #2                 \ the clip window inside the border (the zero page
 STA R_CL               \ copy is Elite's between frames)
 LDA #253
 STA R_CR
 LDA #1
 STA R_CT
 LDA #191
 STA R_CB
IF _TPART = 1 AND _TDUMB = FALSE
 JSR p_fb               \ (Tube: the host does all of that's screen work, as
                        \ below, up to the stars' erasure: tube/src/h-frame.asm)
ELSE
 LDA F_BACK              \ K mode: kept solid rows (gfx-raster_kept.asm)
 JSR T_KFRAME
 LDA F_BACK
 JSR T_SETBUF
 JSR f_text1            \ text cells to be erased: background them (old dirty)
 JSR f_sight1           \ and the sights, if they have gone

IF _TDUMB
 LDA F_BACK             \ (Tube: C_BUF: the host draws into the back buffer from
 JSR p_buf              \ here, once the last flip is done)
ELSE
.ff2
 LDA GFLIP              \ wait for the previous flip, so the back buffer is
 BNE ff2                \ no longer on screen

 LDA F_BACK             \ let the CPU see the back buffer at &4000-&6FFF
 BEQ ffb0               \ (Master port: ACCCON X only, D is the IRQ's: the
 LDA #4                 \ front buffer, and shadow RAM for the dashboard)
 TSB &FE34
.ffb0
ENDIF

 JSR T_STARERASE        \ undo last time's stars in this buffer
ENDIF
IF _TPART = 1 AND _TDUMB
 JSR f_mpre             \ (Tube: the moon's old rows that change, dirty first)
ENDIF
 JSR f_discs            \ the disc layer (sun or planet), incremental
 JSR f_disc2            \ the other disc, if both are on screen (full spans)
 JSR f_moon             \ the moon, if any (full spans)
IF _PLANET_RINGS
 JSR f_ring             \ the ring, if any (dots: RINGS=on, master/build.sh)
ENDIF
.ff_lin                 \ (F_HANGAR points this call at f_hback for its frame)
 JSR f_lines            \ planet meridians, craters, enemy lasers
 JSR f_ships            \ filled ships, far to near
 JSR T_KCOMMIT          \ (K mode: the kept rows still pending blacked)
 JSR f_dots             \ particles, distant ships
 JSR f_lasers           \ our laser beams and the sights
 JSR f_flt              \ the lens flare (gfx-flare6.asm), then the text on top
IF _TPART = 1 AND _TDUMB = FALSE
                        \ (Tube: the text, the sights, the stars and the flip
                        \ are the host's, after p_fe has sent the stars)
ELSE
 JSR f_sight2           \ and the sights
 JSR f_stars            \ stardust, on black only (last: erasing it next
                        \ time restores black, so it needs no WL/WR)
ENDIF

 FOR z, 15, 0, -1        \ restore the zero page (pushed at ff1)
  PLA
  STA FZ + z
 NEXT
 FOR z, &27, &06, -1
  PLA
  STA z
 NEXT

IF _TPART = 1 AND _TDUMB = FALSE
 JSR p_fe               \ (Tube: the text, the sights, the stars, then the flip:
 LDA F_BACK             \ the host's)
 EOR #1
 STA F_BACK
ELIF _TDUMB
 JSR p_flip             \ (Tube: the host shows the buffer at the next vsync)
 LDA F_BACK
 EOR #1
 STA F_BACK
 JSR ovl_dact           \ (overlay D's routines on the stack: D back in)
 BCC ffd9
 LDA #OVL_D
 JSR ovl_need
.ffd9
ELSE
 LDA #4                 \ CPU back to main RAM, and flip at the next vsync
 TRB &FE34
 LDA #%00000010         \ (Master port: with only the vsync interrupt masked
 STA &FE4E              \ in IER, as H_VSYNC reads GPEND and GFLIP; the timer 1
 LDA F_BACK             \ interrupt at the dashboard split must not be held
 STA GPEND              \ off)
 EOR #1
 STA F_BACK
 LDA #&FF
 STA GFLIP
 LDA #%10000010
 STA &FE4E
ENDIF

.f_reset
 LDA #0                 \ empty the per-frame lists
 STA GLASV              \ (Master port: the beams show for one frame per LASLI)
 STA f_bomb             \ (and no bomb bolt yet)
 STA F_NSHIP
 STA F_NLINE
 STA F_NDOT
 STA F_PLON
 STA GSUNON
 STA MN_ON
 STA RG_N
 LDA #LO(F_DL)
 STA F_DLP
 LDA #HI(F_DL)
 STA F_DLP+1
 LDY f_ysav
 RTS
ENDIF
IF _TPART <> 1 OR _TDUMB  \ (Tube: the host's part; the dumb host's parasite's too)


\ f_enter: switch from direct drawing to double buffering. Main RAM (buffer
\ 0) has just been cleared by TT66 and holds the border; shadow RAM (buffer 1)
\ still holds the last frame of the previous space-mode session, which its
\ rasteriser state, disc colour and shown-text map still describe exactly
\ (direct mode only ever writes main RAM), so it is left alone and repaired
\ incrementally by its next frame. Only the border is copied across.

.f_enter
                        \ Master port: direct mode draws into shadow RAM (buffer
                        \ 1), which TTX66 has just cleared and given its border:
                        \ forget buffer 1's state. Main RAM (buffer 0) still
                        \ holds the last frame of the previous space-mode
                        \ session, which its rasteriser state, disc colour and
                        \ shown-text map still describe (direct mode never
                        \ writes main RAM), so it is left alone and repaired
                        \ incrementally by its next frame; only the border is
                        \ copied across (main RAM has none after F_INIT)
IF _TPART = 1             \ (Tube: the screen is the host's: C_ENTERB)
 LDA #C_ENTERB
 JSR ptx
ELSE
IF _HOSTB                 \ (Tube, Model B host: buffer 1 is at &4000, buffer 0 at
 LDA #&40                 \ BUF0: copy straight across)
 STA fmb1+2
 LDA #&41
 STA fmb3+2
 LDA #HI(BUF0)
 STA fmb2+2
 LDA #HI(BUF0)+1
 STA fmb4+2
.fmb0
 LDX #7
.fmb1
 LDA &4000,X            \ column 0, lines 0-7 of this character row
.fmb2
 STA BUF0,X
.fmb3
 LDA &41F8,X            \ column 63
.fmb4
 STA BUF0+&1F8,X
 DEX
 BPL fmb1
 CLC
 LDA fmb1+2
 ADC #2
 STA fmb1+2
 ADC #1
 STA fmb3+2
 LDA fmb2+2
 ADC #2
 STA fmb2+2
 ADC #1
 STA fmb4+2
 LDA fmb1+2
 CMP #&70
 BNE fmb0
 LDX #0                 \ line 0: every 8th byte of the first two pages
.fmb5
 LDA &4000,X
 STA BUF0,X
 LDA &4100,X
 STA BUF0+&100,X
 TXA
 CLC
 ADC #8
 TAX
 BNE fmb5
ELSE
 LDA #HI(&4000)         \ copy byte columns 0 and 63 of every line, and the
 STA fen1+2             \ whole of line 0, from shadow RAM to main RAM
 STA fen2+2
 LDA #HI(&41F8)
 STA fen5+2
 STA fen6+2
.fen0
 LDA #4
 TSB &FE34              \ X = 1: shadow RAM
 LDX #7
.fen1
 LDA &4000,X            \ column 0, lines 0-7 of this character row
 STA F_HW,X
.fen5
 LDA &41F8,X            \ column 63
 STA F_HW+8,X
 DEX
 BPL fen1
 LDA #4
 TRB &FE34              \ X = 0: main RAM
 LDX #7
.fen3
 LDA F_HW,X
.fen2
 STA &4000,X
 LDA F_HW+8,X
.fen6
 STA &41F8,X
 DEX
 BPL fen3
 LDA fen1+2
 CLC
 ADC #2
 STA fen1+2
 STA fen2+2
 ADC #1
 STA fen5+2
 STA fen6+2
 CMP #&71
 BNE fen0
 LDA #4
 TSB &FE34
 LDX #0                 \ line 0: bytes 0, 8, 16, ... (every 8th byte of
.fen7                   \ pages &40 and &41)
 LDA &4000,X
 STA F_HW,X
 LDA &4100,X
 STA F_HW2,X            \ (F_HW, F_HW2: 512 bytes; rebuilt after)
 TXA
 CLC
 ADC #8
 TAX
 BNE fen7
 LDA #4
 TRB &FE34
.fen8
 LDA F_HW,X
 STA &4000,X
 LDA F_HW2,X
 STA &4100,X
 TXA
 CLC
 ADC #8
 TAX
 BNE fen8

ENDIF
ENDIF
 LDA #1                 \ buffer 1's state: empty (TTX66 blacked it)
 STA F_BACK
IF _TPART <> 2 OR _TDUMB = FALSE   \ (the dumb host keeps no state of the screen)
 STZ F_SGS+1
ENDIF
 JSR T_SETBUF
IF _TPART <> 2 OR _TDUMB = FALSE
 JSR T_RESETBUF
 LDA #&FF
 STA F_DCOL+1
 LDA #5*F_STM           \ buffer 1 shows nothing
 JSR f_stand
 LDX #23
.fen9
 STA F_SHR1,X
 DEX
 BPL fen9
 JSR f_tchall
ENDIF
 STZ F_BACK             \ buffer 1 is on show: draw into buffer 0 first
 STZ GFLIP
 LDA #&80
 STA GMODE
 RTS


\ ------------------------------------------------------------------------------
\ Zero page used by the frame layer during F_FRAME (saved and restored along
\ with the rasteriser's &06-&27): Elite's XX2/K3/K4 workspace, dead between
\ main-loop iterations.
\ ------------------------------------------------------------------------------


\ ------------------------------------------------------------------------------
\ Buffer-dependent operands: f_bufpatch points this layer's accesses to the
\ current buffer's rasteriser arrays (R_DIRTYLb etc.) and shown-text map.
\ ------------------------------------------------------------------------------

MACRO FPATCH lab, a0, a1
 LDA F_BACK
 BNE P%+14
 LDA #LO(a0)
 STA lab+1
 LDA #HI(a0)
 STA lab+2
 BNE P%+12
 LDA #LO(a1)
 STA lab+1
 LDA #HI(a1)
 STA lab+2
ENDMACRO

.f_bufpatch             \ (each array's two copies differ only in the high byte)
 LDX F_BACK
IF _TPART <> 2 OR _TDUMB = FALSE   \ (the dumb host: the glyphs' base only)
 LDA fbp_dl,X
 STA fdc_dl1+2
 STA fdc_dl2+2
 STA ft_wd1+2
 STA fsw_d1+2
 LDA fbp_dr,X
 STA fdc_dr1+2
 STA fdc_dr2+2
 STA ft_wd2+2
 STA fsw_d2+2
 LDA fbp_ol,X
 STA fdc_ol+2
 LDA fbp_or,X
 STA fdc_or+2
 LDA fbp_sr,X
 STA ft_sr1+2
 STA ft_sr2+2
 STA ft_sr3+2
 LDA fbp_srl,X
 STA ft_sr1+1
 STA ft_sr2+1
 STA ft_sr3+1
ENDIF
IF _HOSTB                 \ (Model B: the back buffer's screen, BUF0 or &4000)
 LDA fbp_b,X
 STA fgl_b+1
IF _TDUMB = FALSE
 LDA fbp_d,X
 STA fz_t
 CLC
 LDA #&53
 ADC fz_t
 STA fsv1+2
 CLC
 LDA #&53
 ADC fz_t
 STA fsv2+2
 CLC
 LDA #&55
 ADC fz_t
 STA fsv3+2
 CLC
 LDA #&55
 ADC fz_t
 STA fsv4+2
 CLC
 LDA #&5B
 ADC fz_t
 STA fsv5+2
 CLC
 LDA #&5B
 ADC fz_t
 STA fsv6+2
 CLC
 LDA #&5D
 ADC fz_t
 STA fsv7+2
 CLC
 LDA #&5D
 ADC fz_t
 STA fsv8+2
ENDIF
 ENDIF
 RTS
IF _HOSTB
.fbp_b EQUB HI(BUF0), &40
.fbp_d EQUB HI(BUF0) - &40, 0
ENDIF
IF _TPART <> 2 OR _TDUMB = FALSE   \ (the dumb host: the glyphs' base only)
.fbp_dl EQUB HI(R_DIRTYL0), HI(R_DIRTYL1)
.fbp_dr EQUB HI(R_DIRTYR0), HI(R_DIRTYR1)
.fbp_ol EQUB HI(R_DISCL0), HI(R_DISCL1)
.fbp_or EQUB HI(R_DISCR0), HI(R_DISCR1)
.fbp_sr EQUB HI(F_SHR0), HI(F_SHR1)
.fbp_srl EQUB LO(F_SHR0), LO(F_SHR1)
ASSERT LO(R_DIRTYL0) = LO(R_DIRTYL1) AND LO(R_DIRTYR0) = LO(R_DIRTYR1)
ASSERT LO(R_DISCL0) = LO(R_DISCL1) AND LO(R_DISCR0) = LO(R_DISCR1)
ENDIF

ENDIF
IF _TPART <> 2             \ (Tube: the parasite's part; docs/TUBE-MAP.md)
\ ------------------------------------------------------------------------------
\ The disc layer
\ ------------------------------------------------------------------------------

\ f_discs: choose which of the sun and planet is the incremental disc layer
\ (the bigger one), fill R_NDISCL/R and run R_DISCROWS. f_disc2 then draws the
\ other, if any, as plain spans.

.f_discs
 LDA #0
 STA f_lay
 STA f_sec
 LDA GSUNON             \ sun drawn by SUN this frame?
 BEQ fds2
 LDA F_PLON
 BEQ fds1               \ sun only
 LDA GSUNR
 CMP F_PLR
 BCC fds3               \ planet bigger: planet layer, sun secondary
 LDA #2
 STA f_sec              \ sun layer, planet secondary
.fds1
 LDA #1
 STA f_lay
 BNE fds4
.fds2
 LDA F_PLON
 BEQ fds4               \ neither
 LDA #2
 STA f_lay
 BNE fds4
.fds3
 LDA #2
 STA f_lay
 LDA #1
 STA f_sec
.fds4
 LDA f_lay              \ if the layer's colour differs from what this buffer
 LDX F_BACK             \ holds, nothing of the old disc is intact: fold the
 CMP F_DCOL,X           \ old disc spans into the old dirty extents
 BEQ fds5
 STA F_DCOL,X
IF _TPART = 1 AND _TDUMB = FALSE
 LDA #C_DDIRTY          \ (Tube: the host's)
 JSR ptx
ELSE
 JSR f_discdirty
ENDIF
.fds5
 LDA f_lay
 BEQ fds9
 CMP #1
 BEQ fds6
 LDA #FC_PLANE          \ (the planet's colour A: the beach ball's sea)
 STA R_DCE
 LDA #FC_PLANO
 STA R_DCO
 JSR f_plrows           \ planet spans into R_NDISCL/R, R_NDT/R_NDB
 JSR f_bounds           \ and its surface detail as colour boundaries
 JMP T_DISCROWS
.fds6
 LDA #FC_SUNE
 STA R_DCE
 LDA #FC_SUNO
 STA R_DCO
 JSR f_sunrows
 JSR f_nobounds
 JMP T_DISCROWS
.fds9
 LDA #1                 \ no disc
 STA R_NDT
 LDA #0
 STA R_NDB
 JMP T_DISCROWS

.f_lay EQUB 0           \ disc layer: 0 none, 1 sun, 2 planet
.f_sec EQUB 0           \ secondary disc

ENDIF
IF _TPART <> 1 OR _TDUMB
.f_discdirty            \ DIRTY[b][y] |= DISC[b][y] for all rows
 LDY #191
.fdd1
.fdc_ol
 LDA R_DISCL0,Y         \ patched
.fdc_dl1
 CMP R_DIRTYL0,Y        \ patched
 BCS fdd2
.fdc_dl2
 STA R_DIRTYL0,Y        \ patched
.fdd2
.fdc_or
 LDA R_DISCR0,Y         \ patched
.fdc_dr1
 CMP R_DIRTYR0,Y        \ patched
 BCC fdd3
.fdc_dr2
 STA R_DIRTYR0,Y        \ patched
.fdd3
 DEY
 CPY #&FF
 BNE fdd1
 RTS

ENDIF
IF _TPART <> 2             \ (Tube: the parasite's part; docs/TUBE-MAP.md)
\ f_sunrows / f_plrows: a disc's spans into R_NDISCL/R and R_NDT/R_NDB, from
\ its centre (16-bit screen coordinates) and radius (8-bit), using a cached
\ half-width table per disc (rebuilt only when the radius changes)

.f_sunrows
 LDA F_SUX
 STA f_cx
 LDA F_SUX+1
 STA f_cxh
 LDA F_SUY
 STA f_cy
 LDA F_SUY+1
 STA f_cy+1
 LDA GSUNR
 STA f_r
 CMP f_hw2r
 BEQ fsu1
 STA f_hw2r
 LDA #LO(F_HW2)
 STA fhw_st+1
 LDA #HI(F_HW2)
 STA fhw_st+2
 JSR f_hwbuild
.fsu1
 LDA #LO(F_HW2)
 STA fpr_ld+1
 STA fpr_ld2+1
 LDA #HI(F_HW2)
 STA fpr_ld+2
 STA fpr_ld2+2
 JMP f_discspans

.f_plrows
 LDA F_PLX
 STA f_cx
 LDA F_PLX+1
 STA f_cxh
 LDA F_PLY
 STA f_cy
 LDA F_PLY+1
 STA f_cy+1
 LDA F_PLR
 STA f_r
 CMP f_hwr
 BEQ fpr1
 STA f_hwr
 LDA #LO(F_HW)
 STA fhw_st+1
 LDA #HI(F_HW)
 STA fhw_st+2
 JSR f_hwbuild
.fpr1
 LDA #LO(F_HW)
 STA fpr_ld+1
 STA fpr_ld2+1
 LDA #HI(F_HW)
 STA fpr_ld+2
 STA fpr_ld2+2
 JMP f_discspans

.fds_none
 LDA #1
 STA R_NDT
 STZ R_NDB
 RTS

.f_discspans            \ rows of the disc (f_cx, f_cy, f_r) within the window
                        \ (every exit sets R_NDT and R_NDB)
 LDA f_cy               \ fz_p = top row = cy - r, fz_q = bottom row = cy + r
 SEC
 SBC f_r
 STA fz_p
 LDA f_cy+1
 SBC #0
 STA fz_p+1
 LDA f_cy
 CLC
 ADC f_r
 STA fz_q
 LDA f_cy+1
 ADC #0
 STA fz_q+1
 BMI fds_none           \ bottom above the screen
 BNE fdx1               \ bottom below row 255: clamp
 LDA fz_q
 CMP R_CB
 BCC fdx2
.fdx1
 LDA R_CB
 STA fz_q
.fdx2
 LDA fz_p+1             \ top
 BMI fdx3               \ above row 0: clamp
 BNE fds_none           \ below row 255
 LDA fz_p
 CMP R_CT
 BCS fdx4
.fdx3
 LDA R_CT
 STA fz_p
.fdx4
 LDA fz_q               \ empty if top > bottom
 CMP fz_p
 BCC fds_none
 STA R_NDB
 LDA fz_p
 STA R_NDT
 SEC                    \ d = top - cy (16-bit signed, |d| <= r)
 SBC f_cy
 STA fz_t
 LDA #0
 SBC f_cy+1
 STA fz_u
 LDA f_cxh             \ fast path if the whole disc is inside the window
 BEQ fds_z              \ horizontally: cx - r >= CL and cx + r <= CR
 LDA #&80               \ high byte of cx nonzero: fpr_b1 and fpr_b2 become
 BRA fds_pat            \ BRA
.fds_z
 LDA f_cx
 SEC
 SBC f_r
 BCC fds_slow
 CMP R_CL
 BCC fds_slow
 LDA f_cx
 CLC
 ADC f_r
 BCS fds_slow
 SBC R_CR               \ (C = 0) borrow iff cx + r <= CR
 BCS fds_slow
 JMP fds_fast           \ (the fast path follows the slow one, out of
                        \ branch range)
.fds_slow               \ (the disc crosses the window's side, or the screen's)
 LDA #&89               \ high byte of cx zero: fpr_b1 and fpr_b2 become
.fds_pat                \ BIT #imm (no-ops: they keep X and C)
 STA fpr_b1
 STA fpr_b2
 LDY R_NDT
 LDX #&E8               \ X = |d| through the loop, stepped by fpr_id: INX
 LDA fz_u               \ (&E8) if d >= 0, else DEX (&CA) until d reaches 0
 BPL fpr4
 EOR fz_t               \ (d < 0: fz_u = &FF as |d| <= r <= 255, so A = NOT d)
 INC A
 STA fz_t
 LDX #&CA
.fpr4
 STX fpr_id
 LDX fz_t               \ |d|
.fpr2
.fpr_ld2
 LDA F_HW,X             \ patched: half-width
 STA fz_n
 CLC                    \ right = cx + n, clamped: < CL (or
.fpr_cx
 ADC #0                 \ patched: f_cx (the low byte of cx lives in this
                        \ operand); negative): empty; > CR (or > 255): CR
.fpr_b1
 BRA fpr10              \ patched: BRA if the high byte of cx is nonzero (out
                        \ of line), else BIT #imm (a no-op)
 BCS fpr5               \ high byte of cx + n = 1
.fpr11
 CMP R_CL
 BCC fpr8
 CMP R_CR
 BCC fpr6
.fpr5
 LDA R_CR
.fpr6
 STA R_NDISCR,Y
 LDA f_cx               \ left = cx - n: negative: CL; > 255 or > CR: empty;
 SEC                    \ < CL: CL
 SBC fz_n
.fpr_b2
 BRA fpr13              \ patched as fpr_b1
 BCC fpr3               \ high byte of cx - n = -1
.fpr14
 CMP R_CR
 BEQ fpr7
 BCS fpr8
 CMP R_CL
 BCS fpr7
.fpr3
 LDA R_CL
 BRA fpr7
.fpr10                  \ right, A = low byte, C = carry, high byte of cx
 STA fz_t               \ nonzero (X = |d| kept; fz_t is free in the loop)
 LDA f_cxh
 ADC #0                 \ high byte of cx + n
 BMI fpr8               \ minus: empty
 BNE fpr5               \ plus: CR
 LDA fz_t               \ zero
 BRA fpr11
.fpr17
 LDA fz_t               \ (fpr13: high byte zero)
 BRA fpr14
.fpr13                  \ left, A = low byte, C = no borrow, high byte of cx
 STA fz_t               \ nonzero
 LDA f_cxh
 SBC #0                 \ high byte of cx - n
 BEQ fpr17
 BMI fpr3               \ (plus: empty)
.fpr8
 LDA #0                 \ empty row: R = 0, L = 255
 STA R_NDISCR,Y
 DEC A
.fpr7
 STA R_NDISCL,Y
.fpr9
.fpr_id
 INX                    \ patched: DEX while d < 0; when |d| reaches 0
 BNE fpr16              \ step up from then on (fz_u is not kept)
 LDA #&E8
 STA fpr_id
.fpr16
 CPY fz_q               \ (= R_NDB: stored from fz_q at fdx4, unchanged here)
 INY
 BCC fpr2
 RTS

.fds_fast               \ here r <= 127 and |d| <= r, so d fits a signed byte
 LDA f_cx
 STA fsy_cr+1           \ patch cx and 2cx + 1 (mod 256) into both loops
 STA fdf_cr+1
 SEC
 ROL A
 STA fsy_cl+1
 STA fdf_cl+1
 LDA fz_q               \ A = B - T (B = R_NDB = fz_q, T = R_NDT = fz_p)
 SEC
 SBC fz_p               \ (C = 1 after: B >= T)
 LDY fz_t               \ Y = d = T - cy (|d| <= 127, so N = sign of d)
 BPL fdd                \ d >= 0: all rows at or below cy
 CLC
 ADC fz_t               \ A = b = B - cy, C = 1 iff b >= 0
 BCS fdsym              \ b >= 0: cy is in T..B
                        \ b < 0 (C = 0): rows T..B are cy - k for k = -b..a
 EOR #&FF               \ (a = -d), walked up from B
 TAY
 INY                    \ Y = -b
 LDX fz_q               \ X = B
 LDA #2
 SBC fz_t               \ (C = 0) A = a + 1 (C = 0 after)
 STA fdf_cp+1
 LDA #&CA               \ DEX
 BNE fdxs
.fdd                    \ d >= 0 (A = B - T, C = 1, Y = d): rows T..B are cy + k
 ADC fz_t               \ for k = d..b; A = B - T + d + 1 = b + 1 <= 128 (C = 0)
 STA fdf_cp+1
 LDX fz_p               \ X = T
 LDA #&E8               \ INX
.fdxs
 STA fdf_st
.fdf1                   \ X = row, Y = k = |row - cy|, C = 0 here
.fpr_ld
 LDA F_HW,Y             \ patched: half-width table
.fdf_cr
 ADC #0                 \ patched: cx (A = cx + n <= cx + r <= 255, so C = 0)
 STA R_NDISCR,X
 EOR #&FF
.fdf_cl
 ADC #0                 \ patched: 2cx + 1 (A = 2cx + 1 + ~(cx + n) = cx - n)
 STA R_NDISCL,X
.fdf_st
 INX                    \ patched: INX (rows below cy) or DEX (rows above cy)
 INY
.fdf_cp
 CPY #0                 \ patched: last k, plus 1 (C = 0 until then)
 BNE fdf1
 RTS

.fdsym                  \ (A = b, C = 1; a = cy - T = -d > 0)
 TAY                    \ Y = b
 CLC
 ADC fz_t               \ A = b - a, C = 1 iff b >= a
 BEQ fdse
 BCC fdsu
 INY                    \ b > a: rows cy - k and cy + k together for k = 0..a,
 STY fdf_cp+1           \ then rows cy + k for k = a + 1..b
 LDA #&E8               \ INX
 STA fdf_st
 LDA #1
 SBC fz_t               \ (C = 1) A = a + 1 (C = 0 after)
 STA fsy_cp+1
 ADC f_cy               \ A = cy + a + 1 <= B + 1 (C = 0 after)
 STA fsx_x+1
 LDA #&A2               \ LDX #
 BRA fds_c
.fdsu                   \ b < a (C = 0): rows cy - k and cy + k together for
 INY                    \ k = 0..b, then rows cy - k for k = b + 1..a
 STY fsy_cp+1           \ (C = 0 still)
 LDA #2
 SBC fz_t               \ (C = 0) A = a + 1
 STA fdf_cp+1
 LDA #&CA               \ DEX
 STA fdf_st
 LDA #&89               \ BIT # (X is already row cy - b - 1)
 BRA fds_c
.fdse                   \ b = a (C = 1, Y = a): rows cy - k and cy + k for k = 0..a
 INY
 STY fsy_cp+1           \ a + 1
 LDA #&60               \ RTS
.fds_c
 STA fsx_x              \ what follows the symmetric loop
 LDA fpr_ld+2           \ the symmetric loop reads n(k) at table + k (page
 STA fsy_ld+2           \ aligned: no page crossing)
 LDA f_cy               \ X = row cy - k, Y = k, from k = 0; rows cy + k are
 TAX                    \ written at (table + cy) + k
 CLC
 ADC #LO(R_NDISCR)      \ (cy <= R_CB = 191: no carry, see the ASSERT)
 STA fsy_sr+1
 TXA
 ADC #LO(R_NDISCL)
 STA fsy_sl+1
 LDA #HI(R_NDISCL)
 ADC #0                 \ (C = 0 after)
 STA fsy_sl+2
 LDY #0
.fsyl                   \ C = 0 here
.fsy_ld
 LDA F_HW,Y             \ patched: half-width table (high byte)
.fsy_cr
 ADC #0                 \ patched: cx
 STA R_NDISCR,X
.fsy_sr
 STA R_NDISCR,Y         \ patched: R_NDISCR + cy (low byte)
 EOR #&FF
.fsy_cl
 ADC #0                 \ patched: 2cx + 1
 STA R_NDISCL,X
.fsy_sl
 STA R_NDISCL,Y         \ patched: R_NDISCL + cy
 DEX
 INY
.fsy_cp
 CPY #0                 \ patched: last k, plus 1 (C = 0 until then)
 BNE fsyl
.fsx_x
 LDX #0                 \ patched: LDX #first tail row, BIT # (no-op) or RTS
 CLC                    \ (Y = k of the first tail row already)
 JMP fdf1
 ASSERT LO(R_NDISCR) + 191 < 256 AND LO(F_HW) = LO(F_HW2)

f_cx = fpr_cx + 1       \ (the operand of ADC # in the slow disc loop)
.f_cxh EQUB 0           \ high byte of cx
 EQUB 0, 0              \ (spare: keeps the layout after this unchanged)
.f_cy EQUW 0
.f_r  EQUB 0
.f_hwr EQUB 0           \ radius F_HW was built for (0 = none)
.f_hw2r EQUB 0          \ radius F_HW2 was built for

\ f_hwbuild: table[d] = floor(sqrt(r*r - d*d)) for d = 0..r (r = f_r, table
\ patched into fhw_st), by walking x down from r while x*x + d*d > r*r
\ (error e = r*r - d*d - x*x, 16-bit signed)

.f_hwbuild
 LDX f_r                \ x = r
 LDA #0
 STA fz_p               \ e = 0 (d = 0, x = r)
 STA fz_p+1
 LDY #0                 \ d
.fhw1
 TXA
.fhw_st
 STA F_HW,Y             \ patched
 CPY f_r
 BEQ fhw9
 TYA                    \ e -= 2d + 1 ; d++
 ASL A
 STA fz_t
 LDA #0
 ROL A
 STA fz_u
 LDA fz_p
 CLC                    \ (C = 0: SBC takes the + 1 too)
 SBC fz_t
 STA fz_p
 LDA fz_p+1
 SBC fz_u
 STA fz_p+1
 INY
.fhw2
 LDA fz_p+1             \ while e < 0: e += 2x - 1 ; x--
 BPL fhw1
 TXA
 ASL A
 STA fz_t
 LDA #0
 ROL A
 STA fz_u
 LDA fz_t
 SEC
 SBC #1
 STA fz_t
 BCS P%+4
 DEC fz_u
 LDA fz_p
 CLC
 ADC fz_t
 STA fz_p
 LDA fz_p+1
 ADC fz_u
 STA fz_p+1
 DEX
 JMP fhw2
.fhw9
 RTS

\ f_disc2: the secondary disc, drawn in full every frame as spans (rare: both
\ the sun and the planet on screen).

.f_disc2
 LDA f_sec
 BEQ fd29
 CMP #1
 BEQ fd21
 LDA #FC_PLANE          \ (the planet's colour A: the beach ball's sea)
 STA R_COLE
 LDA #FC_PLANO
 STA R_COLO
 JSR f_plrows
 JMP fd22
.fd21
 LDA #FC_SUNE
 STA R_COLE
 LDA #FC_SUNO
 STA R_COLO
 JSR f_sunrows
.fd22
 LDY R_NDT
.fd23
 CPY R_NDB
 BEQ P%+4
 BCS fd29
 LDA R_NDISCL,Y
 CMP R_NDISCR,Y
 BEQ P%+4
 BCS fd28
 STA R_XL
 LDA R_NDISCR,Y
 STA R_XR
 STY fz_i
 JSR T_SPAN
 LDY fz_i
 JSR T_MARKDIRTY
 LDY fz_i
.fd28
 INY
 BNE fd23
.fd29
 RTS

\ ------------------------------------------------------------------------------
\ Lines, ships, dots, lasers, stars
\ ------------------------------------------------------------------------------

.f_setcol               \ A = fixed colour index -> R_COLE/R_COLO
 TAX
 LDA F_CPE,X
 STA R_COLE
 LDA F_CPO,X
 STA R_COLO
 RTS

.f_line8                \ line from (fz_t, fz_u) to (X, Y), 8-bit coordinates
 STX R_X1
 STY R_Y1
 LDA fz_t
 STA R_X0
 LDA fz_u
 STA R_Y0
 LDA #0
 STA R_X0+1
 STA R_Y0+1
 STA R_X1+1
 STA R_Y1+1
 JMP T_LINE

.f_lines
 LDA #0
 STA fz_i
.fln1
 LDX fz_i
 CPX F_NLINE
 BCS fln9
 LDA F_LC,X
 JSR f_setcol
 LDX fz_i
 LDA F_LX0,X
 STA fz_t
 LDA F_LY0,X
 STA fz_u
 LDA F_LY1,X
 TAY
 LDA F_LX1,X
 TAX
 JSR f_line8
 INC fz_i
 BNE fln1
.fln9
 RTS

\ f_ships: insertion-sort the ships far to near, then draw each one (f_ship).

.f_ships
 LDX F_NSHIP
 BNE P%+3
 RTS
 LDX #0                 \ F_ORD = 0, 1, 2, ... sorted by z descending
.fss1
 TXA
 STA F_ORD,X
 INX
 CPX F_NSHIP
 BCC fss1
 LDX #1
.fss2
 CPX F_NSHIP
 BCS fss6
 LDA F_ORD,X            \ insert element X
 STA fz_t
 TXA
 TAY
.fss3
 DEY
 BMI fss5
 LDA F_ORD,Y            \ compare z(fz_t) > z(F_ORD,Y)? then shift
 STA fz_u
 STX fz_n
 LDX fz_t
 LDA F_SZL,X
 STA fz_i
 LDA F_SZH,X
 LDX fz_u
 CMP F_SZH,X
 BCC fss4               \ new is nearer: stop
 BNE fss7               \ new is further: shift
 LDA fz_i
 CMP F_SZL,X
 BCC fss4
 BEQ fss4
.fss7
 LDX fz_n
 LDA fz_u
 STA F_ORD+1,Y
 JMP fss3
.fss4
 LDX fz_n
.fss5
 LDA fz_t
 STA F_ORD+1,Y
 INX
 BNE fss2
.fss6

 LDA #0
 STA fz_i
.fss8
 LDX fz_i
 CPX F_NSHIP
 BCS fss9
 LDA F_ORD,X
 JSR f_ship
 INC fz_i
 BNE fss8
.fss9
 RTS

.f_si   EQUB 0          \ ship index being drawn
.f_nf   EQUB 0
.f_f    EQUB 0          \ face number
.f_x4   EQUB 0
.f_cnt  EQUB 0          \ item counter (details, fins)
.f_k    EQUB 0          \ fin pass: number of its two faces visible

\ f_ship: draw one ship. Every face is flat-shaded (FC_FACETAB: n + 16 * hue
\ ramp, unit normal, n XX3 offsets; the record's XX2 copy holds the face's
\ level, gfx-light.asm, and f_col its ramp entry). Fins standing behind the body are drawn
\ first, then the visible faces, the surface details over them and the other
\ fins (see faces.asm for the order).

.f_ship                 \ A = ship index
 TAX
 STX f_si
 LDY F_STYP,X
 LDA F_SX4,X            \ skip ships whose polygon vertices may be stale
 STA f_x4
 CMP FC_MINVIS,Y
 BEQ P%+5
 BCC P%+3
 RTS
 TYA
 ASL A
 TAY
 LDA FC_FACETAB,Y
 STA fz_ft
 LDA FC_FACETAB+1,Y
 STA fz_ft+1
 LDA FC_DETTAB,Y        \ fins, then details
 STA fz_dt
 LDA FC_DETTAB+1,Y
 STA fz_dt+1
 LDA F_SPL,X            \ XX2 copy, then XX3 copy
 STA fz_dl
 LDA F_SPH,X
 STA fz_dl+1
 LDA F_SNF,X
 STA f_nf
 CLC
 ADC fz_dl
 STA fz_v3
 LDA fz_dl+1
 ADC #0
 STA fz_v3+1
 LDA fz_v3              \ the vertex gather's operands: XX3 copy + 0..3
 STA fsh_x0+1
 LDA fz_v3+1
 STA fsh_x0+2
 FOR k, 1, 3
  CLC
  LDA fz_v3
  ADC #k
  STA fsh_x0+1+6*k
  LDA fz_v3+1
  ADC #0
  STA fsh_x0+2+6*k
 NEXT

 JSR f_behind           \ hidden behind the planet?
 BCC P%+3
 RTS

 LDY #0                 \ fins behind the body (neither of their faces visible)
 LDA (fz_dt),Y
 BEQ fsh_nf0
 TYA
 JSR f_fins
.fsh_nf0

 LDA #0
 STA f_f
 BEQ fsh_face
.fsh_skip               \ hidden face: just step over its entry
 LDY #0
 LDA (fz_ft),Y
 AND #15
 STA fz_n
 JMP fsh_next
.fsh_face
 LDY f_f
 CPY f_nf
 BCC P%+5
 JMP fsh_done
 LDA (fz_dl),Y          \ visibility
 BEQ fsh_skip
 STA fz_t
 LDY #0
 LDA (fz_ft),Y          \ n + 16 * ramp
 AND #15
 STA fz_n
 CMP #3
 BCC fsh_next
 STA R_PN
 LDA fz_t               \ the face's level
 AND #31
 TAX
 LDA (fz_ft),Y          \ its hue ramp
 LSR A
 LSR A
 LSR A
 LSR A
 JSR f_col              \ lit: R_COLE, R_COLO, R_COL2, R_COL3
 CLC                    \ the face's vertex offsets at fz_ft + 4
 LDA fz_ft
 ADC #4
 STA fsh_o+1
 LDA fz_ft+1
 ADC #0
 STA fsh_o+2
 LDX #0                 \ gather the vertices
.fsh_v
.fsh_o
 LDY &FFFF,X            \ XX3 offset (patched)
.fsh_x0
 LDA &FFFF,Y            \ (patched: the XX3 copy + 0..3)
 STA R_PXL,X
.fsh_x1
 LDA &FFFF,Y
 STA R_PXH,X
.fsh_x2
 LDA &FFFF,Y
 STA R_PYL,X
.fsh_x3
 LDA &FFFF,Y
 STA R_PYH,X
 ASSERT fsh_x1 = fsh_x0 + 6 AND fsh_x2 = fsh_x0 + 12 AND fsh_x3 = fsh_x0 + 18
 INX
 CPX fz_n
 BCC fsh_v
 BIT fz_t               \ far ships (XX2 = 255, bit 6 of the copy: Elite skipped
 BVC fsh_draw           \ the normal test) cull back faces by their winding on
                        \ screen, except the station (mirrored until its first TIDY)
 LDX f_si
 LDA F_STYP,X
 CMP #SST
 BEQ fsh_draw
 CMP #DOD               \ (Master port: the Dodo station too)
 BEQ fsh_draw
 JSR f_winding
 BCC fsh_next
.fsh_draw
 JSR T_POLY
.fsh_next
 LDA fz_n               \ next face list entry: n + 4 bytes on
 CLC
 ADC #4
 ADC fz_ft
 STA fz_ft
 BCC P%+4
 INC fz_ft+1
 INC f_f
 JMP fsh_face

.fsh_done               \ details: skip the fins (7 bytes each) to the count
 LDY #0
 LDA (fz_dt),Y
 STA f_cnt
 ASL A
 ASL A
 ASL A
 SEC
 SBC f_cnt              \ 7 * count (C = 1: no borrow)
 SEC
 ADC fz_dt
 STA fz_q
 LDA fz_dt+1
 ADC #0
 STA fz_q+1
 LDA (fz_q),Y
 BEQ fdt8
 STA f_cnt
 INC fz_q
 BNE fdt1
 INC fz_q+1
.fdt1
 JSR f_item
 DEC f_cnt
 BNE fdt1
.fdt8
 LDY #0                 \ the other fins: one face visible, then both (the
 LDA (fz_dt),Y          \ fin nearest the viewer)
 BEQ fdt9
 LDA #1
 JSR f_fins
 LDA #2
 JMP f_fins
.fdt9
 RTS

\ f_item: draw the detail at (fz_q) if it is within its visibility distance
\ and face1 or face2 is visible: n = 2 a line, else a polygon (culled by its
\ winding if XX2 = 255). Then fz_q -> the next item.

.f_item
 LDY #0
 LDA (fz_q),Y           \ visibility distance
 CMP f_x4
 BCC fit8
 INY
 LDA (fz_q),Y           \ face1 + 16 * face2
 AND #15
 TAY
 LDA (fz_dl),Y
 BNE fit1
 LDY #1
 LDA (fz_q),Y
 LSR A
 LSR A
 LSR A
 LSR A
 TAY
 LDA (fz_dl),Y
 BEQ fit8
.fit1
 STA fz_t
 JSR f_itemv            \ colour and vertices
 LDA fz_n
 CMP #3
 BCC fit3
 STA R_PN
 BIT fz_t               \ (XX2 = 255: cull by winding)
 BVC fit2
 JSR f_winding
 BCC fit8
.fit2
 JSR f_poly2            \ (T_POLY, and the docking slot's outline)
 JMP fit8
.fit3
 LDA R_PXL              \ a line
 STA R_X0
 LDA R_PXH
 STA R_X0+1
 LDA R_PYL
 STA R_Y0
 LDA R_PYH
 STA R_Y0+1
 LDA R_PXL+1
 STA R_X1
 LDA R_PXH+1
 STA R_X1+1
 LDA R_PYL+1
 STA R_Y1
 LDA R_PYH+1
 STA R_Y1+1
 JSR T_LINE
.fit8
 LDY #3                 \ next item: 4 + n bytes on
 LDA (fz_q),Y
 CLC
 ADC #4
 ADC fz_q
 STA fz_q
 BCC P%+4
 INC fz_q+1
 RTS

\ f_itemv: the item at (fz_q): its colour (lit at the brighter of its two
\ faces' levels, or unlit), fz_n = n, R_PX/R_PY[0..n-1]

.f_itemv
 LDY #1                 \ face1 + 16 * face2: the brighter level (a hidden
 LDA (fz_q),Y           \ face's is 0)
 AND #15
 TAY
 LDA (fz_dl),Y
 AND #31
 STA fz_u
 LDY #1
 LDA (fz_q),Y
 LSR A
 LSR A
 LSR A
 LSR A
 TAY
 LDA (fz_dl),Y
 AND #31
 CMP fz_u
 BCS P%+4
 LDA fz_u
 TAX
 LDY #2
 LDA (fz_q),Y           \ colour byte: a hue ramp, or &80 + an unlit colour
 JSR f_col              \ R_COLE, R_COLO, R_COL2, R_COL3
 LDY #3
 LDA (fz_q),Y
 STA fz_n
 INY
 LDX #0
.fiv1
 STY fz_u
 LDA (fz_q),Y           \ XX3 offset
 TAY
 LDA (fz_v3),Y
 STA R_PXL,X
 INY
 LDA (fz_v3),Y
 STA R_PXH,X
 INY
 LDA (fz_v3),Y
 STA R_PYL,X
 INY
 LDA (fz_v3),Y
 STA R_PYH,X
 LDY fz_u
 INY
 INX
 CPX fz_n
 BCC fiv1
 RTS

\ f_fins: A = k: draw the fins (two-sided triangles standing on the body edge
\ between face1 and face2) with exactly k of those two faces visible. A fin
\ with neither visible is behind the body, one with one or both in front of
\ it, and only the fin on the corner facing the viewer (both visible) can hide
\ another fin.

.f_fins
 STA f_k
 LDY #0
 LDA (fz_dt),Y
 STA f_cnt
 LDA fz_dt
 CLC
 ADC #1
 STA fz_q
 LDA fz_dt+1
 ADC #0
 STA fz_q+1
.ffi1
 LDY #0
 LDA (fz_q),Y           \ visibility distance
 CMP f_x4
 BCC ffi8
 LDX #0                 \ X = number of the two faces visible
 INY
 LDA (fz_q),Y
 AND #15
 TAY
 LDA (fz_dl),Y
 BEQ P%+3
 INX
 LDY #1
 LDA (fz_q),Y
 LSR A
 LSR A
 LSR A
 LSR A
 TAY
 LDA (fz_dl),Y
 BEQ P%+3
 INX
 CPX f_k
 BNE ffi8
 JSR f_itemv
 LDA #3
 STA R_PN
 JSR T_POLY
.ffi8
 LDA fz_q               \ next fin: 7 bytes on
 CLC
 ADC #7
 STA fz_q
 BCC P%+4
 INC fz_q+1
 DEC f_cnt
 BNE ffi1
 RTS

\ f_col: A = a face's or item's colour byte, X = the level (0..31): the
\ colour R_COLE, R_COLO, R_COL2, R_COL3 (rows y AND 3 = 0..3). A = 0..8: entry
\ X of that hue ramp (gfx-light6.asm), a 4x4 dither packed as w = a + 32 b +
\ 1024 c, whose rows are H[a] EOR H[c] EOR HL[b] (H = HL AND &F0); A = &80 +
\ k: the unlit colour k (black, cyan, magenta, yellow).

.fc_fix
 AND #3
 TAY
 LDA LT_FIX,Y
 STA R_COLE
 STA R_COLO
 STA R_COL2
 STA R_COL3
 RTS
.f_col
 TAY
 BMI fc_fix
 LDA LT_RL,Y
 STA fcl+1
 CLC
 ADC #32
 STA fch+1
 LDA LT_RH,Y
 STA fcl+2
 ADC #0
 STA fch+2
.fch
 LDA &FFFF,X            \ (patched) w's high byte: c = hi >> 2
 STA fc_hi
 LSR A
 LSR A
 TAY
.fcl
 LDA &FFFF,X            \ (patched) w's low byte: a = lo AND 31
 STA fc_lo
 AND #31
 TAX
 FOR r, 0, 3            \ H[a] EOR H[c]
  LDA LT_HL0+17*r,X
  EOR LT_HL0+17*r,Y
  AND #&F0
  STA fc_row+r
 NEXT
 LDA fc_hi              \ b = (hi AND 3) * 8 + lo DIV 32
 AND #3
 ASL fc_lo
 ROL A
 ASL fc_lo
 ROL A
 ASL fc_lo
 ROL A
 TAY
 LDA LT_HL0,Y           \ EOR HL[b]
 EOR fc_row
 STA R_COLE
 LDA LT_HL0+17,Y
 EOR fc_row+1
 STA R_COLO
 LDA LT_HL0+34,Y
 EOR fc_row+2
 STA R_COL2
 LDA LT_HL0+51,Y
 EOR fc_row+3
 STA R_COL3
 RTS
ASSERT LT_HL1 = LT_HL0 + 17 AND LT_HL2 = LT_HL0 + 34 AND LT_HL3 = LT_HL0 + 51

.fc_lo  EQUB 0
.fc_hi  EQUB 0
.fc_row SKIP 4

.f_dots
 LDA #0
 STA fz_i
.fdo2
 LDX fz_i
 CPX F_NDOT
 BCS fdo8
 LDA F_DC,X
 BPL fdo3
 AND #&7F               \ a ship type: its dot colour
 TAY
 LDA FC_DOTE,Y
 STA R_COLE
 LDA FC_DOTO,Y
 STA R_COLO
 JMP fdo4
.fdo3
 JSR f_setcol
.fdo4
 LDX fz_i
 LDA F_DS,X
 PHA
 LDA F_DY,X
 TAY
 LDA F_DX,X
 TAX
 PLA
 JSR T_DOT
 INC fz_i
 BNE fdo2
.fdo8
 RTS

\ f_lasers: our laser beams (LASLI's four lines from LASX,LASY to the bottom
\ of the view) and the sights

.f_lasers
 LDA GLASV
 BEQ fla2
 LDA #FC_LASER
 JSR f_setcol
 LDA LASX
 STA fz_t
 LDA LASY
 STA fz_u
 LDX #32
 LDY #2*Y-1
 JSR f_line8
 LDX #224
 LDY #2*Y-1
 JSR f_line8
 LDX #48
 LDY #2*Y-1
 JSR f_line8
 LDX #208
 LDY #2*Y-1
 JSR f_line8
.fla2
.fla9
 RTS

IF _TPART = 0 OR _TDUMB
.f_stars                \ stars 1..NOSTM (NOSTM is only ever NOST = 18), recorded
 LDA #NOST+1            \ by the hooks straight into R_SX/R_SY/R_SS (R_SS = 0: none)
 STA R_SN               \ (Master port: NOST = 20)
 JMP T_STARPLOT
ENDIF

ENDIF
IF _TPART <> 1 OR _TDUMB  \ (Tube: the host's part; the dumb host's parasite's too)
IF _TDUMB = FALSE OR _TPART = 2   \ (the Tube's dumb host's parasite: in its overlay S)
 INCLUDE "src/gfx-ftext.asm"
ENDIF
ENDIF
IF _TPART <> 2             \ (Tube: the parasite's part; docs/TUBE-MAP.md)
\ ------------------------------------------------------------------------------
\ Planet surface detail, filled: per-row colour boundaries for the disc layer
\ (R_NDN, R_NDX0-3, R_NDP: the disc alternates between colour A and colour B
\ at each boundary): circles on the planet's sphere, the beach ball's, the
\ craters' or the bands' (PF_HOOK, gfx-planet7.asm, makes them in game
\ context; PC_ROWS, gfx-merid.asm's circle engine, the rows), both in the
\ meridian window (bank 7).
\ ------------------------------------------------------------------------------

\ f_nobounds: rows R_NDT..R_NDB have no boundaries (plain disc)

.f_nobounds
 STZ R_NDF
 RTS

\ f_bounds: the planet's detail -> R_NDN/R_NDX0-3/R_NDP for rows R_NDT..R_NDB
\ (which f_plrows has just set), and colour B (f_bcol)

.f_bounds
 JSR f_nobounds
 LDA R_NDT
 CMP R_NDB
 BEQ P%+4
 BCS fnb9
 BIT PF_CLS             \ the detail PF_HOOK made this frame (the beach
 BPL fnb9               \ ball, craters or bands): from the circle engine's
 JSR f_bcol             \ PC_ROWS
 JMP T_CAPS
.fnb9
 RTS

\ The planet's colours, every style's the beach ball's (pairs of bytes, even
\ rows and odd rows): colour A, the disc, its sea (FC_PLANE, FC_PLANO), and
\ colour B, its detail (the beach ball's land, the craters, the belt), green

FC_PLLE = &5F : FC_PLLO = &AF

\ f_bcol: R_NDF on and colour B

.f_bcol
 LDA #1
 STA R_NDF
 LDA #FC_PLLE
 STA R_DBE
 LDA #FC_PLLO
 STA R_DBO
 RTS

IF _PLANET_RINGS
\ ------------------------------------------------------------------------------
\ The ring (gfx-planet7.asm's pf_ring makes its dots in game context: RG_X,
\ RG_Y, RG_F, RG_N of them): each dot drawn in yellow (marked dirty, for the
\ next frame on this buffer to repair), but a dot behind the planet's centre
\ and inside its disc, which the planet hides
\ ------------------------------------------------------------------------------

.f_ring
 LDA RG_N
 BNE frg0
 RTS
.frg0
 LDA #&FF
 STA R_COLE
 STA R_COLO
 LDX #0
.frg1
 STX fm_i
 LDA RG_F,X
 BPL frg3
 LDA F_PLON             \ behind: inside the planet's disc?
 BEQ frg3
 LDA RG_Y,X
 SEC
 SBC F_PLY
 STA fz_t
 LDA #0
 SBC F_PLY+1
 JSR f_abs16
 BCS frg3
 CMP F_PLR
 BEQ frg2
 BCS frg3
.frg2
 TAY
 LDX fm_i
 LDA RG_X,X
 SEC
 SBC F_PLX
 STA fz_t
 LDA #0
 SBC F_PLX+1
 JSR f_abs16
 BCS frg3
 CMP F_HW,Y
 BCC frg4
 BEQ frg4
.frg3
 LDX fm_i
 LDA RG_X,X
 LDY RG_Y,X
 TAX
 LDA #1
 JSR T_DOT
.frg4
 LDX fm_i
 INX
 CPX RG_N
 BCC frg1
 RTS
ENDIF

\ ------------------------------------------------------------------------------
\ The moon (gfx-planet7.asm's pf_moon makes it in game context: MN_ON, MN_X,
\ MN_Y, MN_R, MN_Z, its crater in the caps' slot PCMAX): a third disc, drawn
\ every frame as spans after the sun and the planet (f_discs, f_disc2), light
\ grey with a dark grey crater, its rows hidden where the planet or the sun is
\ in front of it (MN_ON bits 6 and 5: the moon further than they), and each
\ row marked dirty for the next frame on this buffer to repair. Ships further
\ than the moon and inside its disc are hidden (f_behind)
\ ------------------------------------------------------------------------------

IF _TPART = 1 AND _TDUMB
.f_mpre                 \ (Tube: the moon's spans, then p-moon.asm's T_MPRE)
 LDA #1
 STA R_NDT
 STZ R_NDB
 BIT MN_ON
 BPL fmp9
 JSR fm_spans
.fmp9
 JMP T_MPRE
ENDIF

.f_moon
 BIT MN_ON
 BMI fmn0
 RTS
.fmn0
 JSR fm_spans
 LDA R_NDT
 CMP R_NDB
 BEQ fmn2
 BCC fmn2
 RTS

.fm_spans               \ the moon's spans into R_NDISCL/R, R_NDT/R_NDB
 LDA MN_X
 STA f_cx
 LDA MN_X+1
 STA f_cxh
 LDA MN_Y
 STA f_cy
 LDA MN_Y+1
 STA f_cy+1
 LDA MN_R
 STA f_r
 CMP f_hw3r
 BEQ fmn1
 STA f_hw3r
 LDA #LO(F_HW3)
 STA fhw_st+1
 LDA #HI(F_HW3)
 STA fhw_st+2
 JSR f_hwbuild
.fmn1
 LDA #LO(F_HW3)
 STA fpr_ld+1
 STA fpr_ld2+1
 LDA #HI(F_HW3)
 STA fpr_ld+2
 STA fpr_ld2+2
 JMP f_discspans
.fmn2
 JSR T_MCAPS            \ (its crater's boundaries, as the planet's)
 LDY R_NDT
.fmn3
 STY fm_y
 LDA R_NDISCL,Y
 CMP R_NDISCR,Y
 BEQ fmn4
 BCC fmn4
 JMP fmn8
.fmn4
 STA fm_pa              \ one piece, the row's span, less the planet's and
 LDA R_NDISCR,Y         \ the sun's where they are in front
 STA fm_pb
 LDA #1
 STA fm_n
 BIT MN_ON
 BVC fmn5
 LDA F_PLON
 BEQ fmn5
 LDA F_PLX
 STA fm_ox
 LDA F_PLX+1
 STA fm_ox+1
 LDA F_PLY
 STA fm_oy
 LDA F_PLY+1
 STA fm_oy+1
 LDA F_PLR
 STA fm_or
 LDA #HI(F_HW)
 LDX #LO(F_HW)
 JSR fm_occ
.fmn5
 LDA MN_ON
 AND #&20
 BEQ fmn6
 LDA GSUNON
 BEQ fmn6
 LDA F_SUX
 STA fm_ox
 LDA F_SUX+1
 STA fm_ox+1
 LDA F_SUY
 STA fm_oy
 LDA F_SUY+1
 STA fm_oy+1
 LDA GSUNR
 STA fm_or
 LDA #HI(F_HW2)
 LDX #LO(F_HW2)
 JSR fm_occ
.fmn6
IF _TPART = 1 AND _TDUMB
 JSR T_MROW             \ (Tube: a row as this buffer holds it is not drawn,
 BCS fmn8               \ and no row is marked dirty: p-moon.asm)
ENDIF
 LDX #0                 \ paint the pieces
.fmn7
 CPX fm_n
 BCS fmn7a
 STX fm_i
 JSR fm_paint
 LDX fm_i
 INX
 BRA fmn7
.fmn7a
IF _TPART <> 1 OR _TDUMB = FALSE
 LDY fm_y               \ the whole span to be repaired next time
 LDA R_NDISCL,Y
 STA R_XL
 LDA R_NDISCR,Y
 STA R_XR
 JSR T_MARKDIRTY
ENDIF
.fmn8
 LDY fm_y
 CPY R_NDB
 INY
 BCS fmn9
 JMP fmn3
.fmn9
 RTS

\ fm_occ: the pieces less the disc (fm_ox, fm_oy, fm_or) with half-width
\ table (X, A) (low, high), on row fm_y

.fmo0
 RTS
.fm_occ
 STX fmo_ld+1
 STA fmo_ld+2
 LDA fm_y               \ dy = y - oy, |dy| <= r
 SEC
 SBC fm_oy
 STA fz_t
 LDA #0
 SBC fm_oy+1
 JSR f_abs16
 BCS fmo0
 CMP fm_or
 BEQ fmo1
 BCS fmo0
.fmo1
 TAX
.fmo_ld
 LDA F_HW,X             \ (patched: the half-width table)
 STA fz_n
 LDA fm_ox              \ ol = ox - n, or = ox + n (16-bit), to 0..255
 SEC
 SBC fz_n
 STA fm_l
 LDA fm_ox+1
 SBC #0
 BMI fmo2
 BNE fmo0               \ (ol > 255: none)
 BEQ fmo3
.fmo2
 STZ fm_l
.fmo3
 LDA fm_ox
 CLC
 ADC fz_n
 STA fm_r
 LDA fm_ox+1
 ADC #0
 BMI fmo0               \ (or < 0: none)
 BEQ fmo4
 LDA #255
 STA fm_r
.fmo4
 LDX fm_n               \ each piece less [fm_l, fm_r]: from the last
.fmo5
 DEX
 BMI fmo9
 LDA fm_pb,X
 CMP fm_l
 BCC fmo5               \ (b < l: kept)
 LDA fm_pa,X
 CMP fm_r
 BEQ fmo6
 BCS fmo5               \ (a > r: kept)
.fmo6
 LDA fm_pa,X            \ [a, l - 1] in its place if a < l, and [r + 1, b]
 CMP fm_l               \ at the end if r < b
 BCS fmo7
 LDA fm_pb,X
 PHA
 LDA fm_l
 DEC A
 STA fm_pb,X
 PLA
 CMP fm_r
 BEQ fmo5
 BCC fmo5
 LDY fm_n
 STA fm_pb,Y
 LDA fm_r
 INC A
 STA fm_pa,Y
 INC fm_n
 BRA fmo5
.fmo7
 LDA fm_pb,X            \ (a >= l: only [r + 1, b], if any)
 CMP fm_r
 BEQ fmo8
 BCC fmo8
 LDA fm_r
 INC A
 STA fm_pa,X
 BRA fmo5
.fmo8
 LDY fm_n               \ (wholly hidden: the last piece into its place)
 DEY
 STY fm_n
 LDA fm_pa,Y
 STA fm_pa,X
 LDA fm_pb,Y
 STA fm_pb,X
 BRA fmo5
.fmo9
 RTS

\ fm_paint: piece X on row fm_y in the moon's colours: light grey from the
\ row's start colour, flipping to dark grey and back at its boundaries

.fm_paint
 LDA fm_pa,X
 STA fm_a
 LDA fm_pb,X
 STA fm_b
 LDY fm_y
 LDA R_NDP,Y
 AND #1
 STA fm_c
 LDA R_NDN,Y
 STA fm_k
 LDA R_NDX0,Y
 STA fm_x
 LDA R_NDX1,Y
 STA fm_x+1
 LDA R_NDX2,Y
 STA fm_x+2
 LDA R_NDX3,Y
 STA fm_x+3
 LDX #0
.fmp1
 CPX fm_k
 BCS fmp4
 LDA fm_x,X
 CMP fm_a
 BEQ fmp2
 BCS fmp3
.fmp2
 LDA fm_c               \ (at or left of the piece's start: a flip)
 EOR #1
 STA fm_c
 BRA fmp3a
.fmp3
 CMP fm_b               \ inside: paint up to it, then flip
 BEQ fmp3b
 BCS fmp4
.fmp3b
 DEC A
 STA R_XR
 PHX
 JSR fm_span
 PLX
 LDA fm_x,X
 STA fm_a
 LDA fm_c
 EOR #1
 STA fm_c
.fmp3a
 INX
 BRA fmp1
.fmp4
 LDA fm_b
 STA R_XR
.fm_span                \ R_XL = fm_a .. R_XR in colour fm_c, on row fm_y
 LDA fm_a
 STA R_XL
 LDX fm_c
 LDA mn_ce,X
 STA R_COLE
 LDA mn_co,X
 STA R_COLO
 LDY fm_y
 JMP T_SPAN

\ The moon's colours: light grey (C, M, Y and black in equal measure) and
\ dark grey (one of C, M, Y in four pixels): even rows, odd rows (MODE 1
\ bytes: pixel i in bits 7 - i and 3 - i)
.mn_ce EQUB &6A, &28    \ light C M Y K, dark C K M K
.mn_co EQUB &9A, &44    \ light Y K C M, dark K Y K K

.f_hw3r EQUB 0          \ the radius F_HW3 was built for
.fm_y  EQUB 0
.fm_i  EQUB 0
.fm_n  EQUB 0
.fm_pa SKIP 3
.fm_pb SKIP 3
.fm_ox EQUW 0
.fm_oy EQUW 0
.fm_or EQUB 0
.fm_l  EQUB 0
.fm_r  EQUB 0
.fm_a  EQUB 0
.fm_b  EQUB 0
.fm_c  EQUB 0
.fm_k  EQUB 0
.fm_x  SKIP 4

\ ------------------------------------------------------------------------------
\ f_behind: is ship f_si behind the planet or the moon, with the first vertex
\ of its first visible face inside its disc? C set if so (don't draw it)
\ ------------------------------------------------------------------------------

.f_behind
 LDA F_PLON             \ the planet's disc, if any
 BEQ fbh0
 LDX #4
.fbhp
 LDA F_PLX,X            \ (F_PLX, F_PLY, F_PLR)
 STA fb_x,X
 DEX
 BPL fbhp
 LDA F_PLZH
 STA fb_zh
 LDA F_PLZL
 STA fb_zl
 LDA #LO(F_HW)
 LDX #HI(F_HW)
 JSR f_bdisc
 BCC fbh0
 RTS
.fbh0
 BIT MN_ON              \ the moon's, if any
 BMI fbh0a
 CLC
 RTS
.fbh0a
 LDX #3
.fbhm
 LDA MN_X,X             \ (MN_X, MN_Y, MN_R, MN_Z)
 STA fb_x,X
 DEX
 BPL fbhm
 LDA MN_R
 STA fb_r
 LDA MN_Z+1
 STA fb_zh
 LDA MN_Z
 STA fb_zl
 LDA #LO(F_HW3)
 LDX #HI(F_HW3)

\ f_bdisc: is ship f_si behind the disc fb_x, fb_y, fb_r (half-widths at
\ (A, X)), z fb_zh/fb_zl, with the first vertex of its first visible face
\ inside it? C set if so

.f_bdisc
 STA fbh_hw+1
 STX fbh_hw+2
 LDX f_si               \ further away than the disc?
 LDA fb_zl
 CMP F_SZL,X
 LDA fb_zh
 SBC F_SZH,X
 BCS fbh8               \ disc z >= ship z: in front
 LDY #0                 \ first visible face: its first vertex
 STY f_f
 LDA fz_ft
 STA fz_p
 LDA fz_ft+1
 STA fz_p+1
.fbh1
 LDY f_f
 CPY f_nf
 BCS fbh8
 LDA (fz_dl),Y
 BNE fbh2
 LDY #0                 \ skip this face's list entry (n + 16 * its hue ramp,
 LDA (fz_p),Y           \ its normal, n offsets: n + 4 bytes)
 AND #15
 CLC
 ADC #4
 ADC fz_p
 STA fz_p
 BCC P%+4
 INC fz_p+1
 INC f_f
 JMP fbh1
.fbh2
 LDY #4                 \ XX3 offset of the vertex
 LDA (fz_p),Y
 TAY
 LDA (fz_v3),Y          \ dx = x - the disc's x (16-bit)
 SEC
 SBC fb_x
 STA fz_t
 INY
 LDA (fz_v3),Y
 SBC fb_x+1
 JSR f_abs16            \ -> A = |dx| if < 256, else C set
 BCS fbh8
 STA f_bdx
 INY
 LDA (fz_v3),Y          \ dy = y - the disc's y
 SEC
 SBC fb_y
 STA fz_t
 INY
 LDA (fz_v3),Y
 SBC fb_y+1
 JSR f_abs16
 BCS fbh8
 CMP fb_r               \ |dy| <= r and |dx| <= half-width(|dy|)?
 BEQ fbh3
 BCS fbh8
.fbh3
 TAX
.fbh_hw
 LDA F_HW,X             \ (patched: the half-width table)
 CMP f_bdx
 BCC fbh8
 SEC
 RTS
.fbh8
 CLC
 RTS

.fb_x  EQUW 0           \ the disc: centre, radius (as F_PLX, F_PLY, F_PLR)
.fb_y  EQUW 0
.fb_r  EQUB 0
.fb_zh EQUB 0
.fb_zl EQUB 0
.f_bdx EQUB 0

\ f_abs16: (A fz_t) 16-bit signed -> A = |value| and C clear if < 256, else
\ C set

.f_abs16
 BPL fab1
 EOR #&FF
 STA fz_u
 LDA fz_t
 EOR #&FF
 CLC
 ADC #1
 STA fz_t
 LDA fz_u
 ADC #0
.fab1
 BNE fab9
 LDA fz_t
 CLC
 RTS
.fab9
 SEC
 RTS

\ f_winding: the face just gathered into R_PXL/R_PYL (low bytes; a far ship is
\ small, so differences fit in 8 bits): C set if it is clockwise on screen
\ (front-facing), i.e. (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0) > 0

.f_winding
 LDA R_PXL+1
 SEC
 SBC R_PXL
 STA fw_a
 LDA R_PYL+2
 SEC
 SBC R_PYL
 JSR f_smul             \ (x1 - x0) * (y2 - y0)
 STA fw_h
 STX fw_l
 LDA R_PYL+1
 SEC
 SBC R_PYL
 STA fw_a
 LDA R_PXL+2
 SEC
 SBC R_PXL
 JSR f_smul             \ (y1 - y0) * (x2 - x0)
 STA fw_t
 STX fw_t+1
 LDA fw_l               \ first - second, 16-bit signed
 SEC
 SBC fw_t+1
 STA fw_l
 LDA fw_h
 SBC fw_t
 BVC P%+4
 EOR #&80
 BMI fwn9               \ negative: back face
 ORA fw_l
 BEQ fwn9               \ zero: edge-on
 SEC
 RTS
.fwn9
 CLC
 RTS

\ f_smul: A * fw_a, both signed 8-bit -> A (high), X (low), signed 16-bit

.f_smul
 STA fw_b
 STA fw_bo
 LDA #0
 STA fw_t2
 LDX #8
.fsm1                   \ unsigned (fw_a * fw_b), then correct for signs
 LSR fw_b
 BCC fsm2
 CLC
 ADC fw_a
.fsm2
 ROR A
 ROR fw_t2
 DEX
 BNE fsm1
 TAX                    \ A = high byte of the unsigned product
 LDA fw_a               \ if fw_a < 0, high -= original b; if b < 0, high -= a
 BPL fsm3
 TXA
 SEC
 SBC fw_bo
 TAX
.fsm3
 LDA fw_bo
 BPL fsm4
 TXA
 SEC
 SBC fw_a
 TAX
.fsm4
 TXA
 LDX fw_t2
 RTS

.fw_a  EQUB 0
.fw_b  EQUB 0
.fw_bo EQUB 0
.fw_t  EQUW 0
.fw_t2 EQUB 0
.fw_h  EQUB 0
.fw_l  EQUB 0

ENDIF