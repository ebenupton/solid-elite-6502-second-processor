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
fz_nm   = FZ+10         \ normal-length table pointer (2)
fz_i    = FZ+12
fz_n    = FZ+13
fz_t    = FZ+14
fz_u    = FZ+15

\ ------------------------------------------------------------------------------
\ State
\ ------------------------------------------------------------------------------

\ Shared with the IRQ handler and Elite (these live in main RAM, defined by the
\ main source): GMODE (bit 7 set = space mode, double buffered), GFRONT (0/1
\ buffer displayed), GFLIP (non-zero = flip pending to GPEND), GPEND, GACCX
\ (ACCCON X bit value currently wanted by the main code: 0 or 4), GDRAWON
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
.F_SZN      SKIP MAXSH  \ LL9's halved z (for face brightness)
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

.F_STV      SKIP 24     \ star valid flags, by star index (1..NOSTM)
.F_STX      SKIP 24
.F_STY      SKIP 24
.F_STS      SKIP 24

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
.F_CPO
 EQUB &00, &FF, &F0, &0F, &FF, &0F, &FF

\ ------------------------------------------------------------------------------
\ F_INIT: one-off initialisation (called by the loader / startup)
\ ------------------------------------------------------------------------------

.F_INIT
 JSR T_INIT
 LDA #0
 STA F_NSHIP
 STA F_NLINE
 STA F_NDOT
 STA F_PLON
 LDX #23
.fin1
 STA F_STV,X
 DEX
 BPL fin1
 JSR f_tmclear
 RTS

\ ------------------------------------------------------------------------------
\ Text map: 24 rows x 32 columns of desired characters (F_TM), and what each
\ buffer actually shows (F_SH0, F_SH1). F_TMR/F_SHR0/F_SHR1 count the non-zero
\ cells in each row so empty rows cost nothing.
\ ------------------------------------------------------------------------------

.f_tmclear              \ clear the text map and both shown maps
 LDA #0
 TAX
.ftc1
 STA F_TM,X
 STA F_TM+256,X
 STA F_TM+512,X
 STA F_SH0,X
 STA F_SH0+256,X
 STA F_SH0+512,X
 STA F_SH1,X
 STA F_SH1+256,X
 STA F_SH1+512,X
 INX
 BNE ftc1
 LDX #23
.ftc2
 STA F_TMR,X
 STA F_SHR0,X
 STA F_SHR1,X
 DEX
 BPL ftc2
 RTS

\ f_cell: X = column, Y = row -> f_ptr = row*32 + column (offset into a map)
\ Returns the offset in f_off (2 bytes) and also patches the three map
\ accessors f_tmld/f_tmst.

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
 LDA f_off+1
 ADC #HI(F_TM)
 STA f_tmld+2
 STA f_tmst+2
 RTS

.f_off  EQUW 0
.f_row  EQUB 0

\ F_CHAR: A = character, (XC-1, YC) = cell. EOR semantics like the original:
\ printing the same character again removes it.

.F_CHAR
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
 LDA #0
 JSR f_tmstore
 LDX f_row
 DEC F_TMR,X
.fch8
 LDY f_ysav
 RTS
.fch9
 PLA
 LDY f_ysav
 RTS

.f_tmstore
.f_tmst
 STA F_TM               \ patched
 RTS

.f_tmget
.f_tmld
 LDX F_TM               \ patched; sets Z on the content
 RTS

.f_ysav EQUB 0
.f_tmp  EQUB 0

\ F_DELCHAR: clear the text map cell at X = column, Y = row

.F_DELCHAR
 STY f_ysav
 CPY #24
 BCS fdc9
 CPX #32
 BCS fdc9
 STY f_row
 JSR f_cell
 JSR f_tmget
 BEQ fdc9
 LDA #0
 JSR f_tmstore
 LDX f_row
 DEC F_TMR,X
.fdc9
 LDY f_ysav
 RTS

\ F_CLRTEXT: clear text map rows X to Y inclusive

.F_CLRTEXT
 STY f_ysav
 STY f_tmp
.fct1
 STX f_row
 LDY f_row
 LDX #0
 JSR f_cell             \ f_tmst -> start of row
 LDA f_tmst+1
 STA fct3+1
 LDA f_tmst+2
 STA fct3+2
 LDA #0
 LDY #31
.fct3
 STA F_TM,Y             \ patched
 DEY
 BPL fct3
 LDX f_row
 STA F_TMR,X
 INX
 CPX #24
 BCS fct9
 CPX f_tmp
 BCC fct1
 BEQ fct1
.fct9
 LDY f_ysav
 RTS

\ ------------------------------------------------------------------------------
\ F_DIRECT: the screen is about to be cleared and drawn directly (TT66):
\ cancel double buffering, show and access main RAM.
\ ------------------------------------------------------------------------------

.F_DIRECT
 SEI
 LDA #0
 STA GMODE
 STA GFLIP
 STA GFRONT
 STA GACCX
 STA GSIGHT
 STA GLASV
 LDA #ACCY
 STA &FE34              \ ACCCON: HAZEL in, X = 0, D = 0
 CLI
 STY f_ysav
 JSR f_tmclear
 LDY f_ysav
 RTS

\ ------------------------------------------------------------------------------
\ Recorders (called during the main loop; must only touch Elite variables they
\ are documented to read, and preserve Y)
\ ------------------------------------------------------------------------------

\ F_SHIP: record the ship being drawn by LL9. Inputs: TYPE, GNF (faces),
\ GNV (vertices), XX2 (face visibility), XX3 (projected vertices), INWK+6/7 (z).

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
 LDA TYPE
 STA F_STYP,X
 LDA GNF
 STA F_SNF,X
 LDA GZN
 STA F_SZN,X
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
.fsh3
 TYA                    \ advance the destination past the XX2 copy
 CLC
 ADC fsh2+1
 STA fsh5+1
 LDA fsh2+2
 ADC #0
 STA fsh5+2
 LDY #0
 LDX f_nv4
 BEQ fsh6
.fsh4
 LDA XX3,Y
.fsh5
 STA &FFFF,Y            \ patched
 INY
 DEX
 BNE fsh4
.fsh6
 TYA
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
 LDX #1
 LDA ZZ
 CMP #144
 BCS fdo1
 INX
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

\ F_STAR: star Y. C clear = off screen (invalid); C set = at X = x, A = y,
\ size from ZZ.

.F_STAR
 BCS fst1
 LDA #0
 STA F_STV,Y
 RTS
.fst1
 STA F_STY,Y
 TXA
 STA F_STX,Y
 LDX #1
 LDA ZZ
 CMP #144
 BCS fst2
 INX
 CMP #80
 BCS fst2
 INX
.fst2
 TXA
 STA F_STS,Y
 LDA #&FF
 STA F_STV,Y
 RTS

\ F_PLANET: record the planet: centre (K3, K4) 16-bit, radius K, TYPE

.F_PLANET
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
 LDA #&FF
 STA F_PLON
 RTS

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
 LDX TYPE
 LDA FC_HUE,X
 ORA #&80               \ bit 7: hue (bits 0-6), drawn at its brightest level
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
 JMP f_reset            \ not a space view: just forget what was recorded

.ff1
 BIT GMODE
 BMI ff2
 JSR f_enter            \ first space-mode frame since the screen was cleared

.ff2
 LDA GFLIP              \ wait for the previous flip, so the back buffer is
 BNE ff2                \ no longer on screen

 LDX #&21               \ save the zero page the rasteriser uses (&06-&27)
.ff3
 LDA &06,X
 STA f_zsave,X
 DEX
 BPL ff3
 LDX #15                \ and the frame layer's (&D2-&E1)
.ff3a
 LDA FZ,X
 STA f_zsave+&22,X
 DEX
 BPL ff3a
 JSR f_bufpatch

 LDA F_BACK             \ let the CPU see the back buffer at &4000-&6FFF
 ASL A
 ASL A
 STA GACCX
 SEI
 ORA GFRONT
 ORA #ACCY
 STA &FE34
 CLI

 LDA F_BACK
 JSR T_SETBUF

 JSR f_text1            \ text cells to be erased: background them (old dirty)
 JSR T_STARERASE        \ undo last time's stars in this buffer
 JSR f_discs            \ the disc layer (sun or planet), incremental
 JSR f_disc2            \ the other disc, if both are on screen (full spans)
 JSR f_lines            \ planet meridians, craters, enemy lasers
 JSR f_ships            \ filled ships, far to near
 JSR f_dots             \ particles, distant ships
 JSR f_lasers           \ our laser beams and the sights
 JSR f_stars            \ stardust, on black only
 JSR f_text2            \ text on top

 LDX #&21               \ restore the zero page
.ff4
 LDA f_zsave,X
 STA &06,X
 DEX
 BPL ff4
 LDX #15
.ff4a
 LDA f_zsave+&22,X
 STA FZ,X
 DEX
 BPL ff4a

 SEI                    \ CPU back to main RAM, and flip at the next vsync
 LDA #0
 STA GACCX
 LDA GFRONT
 ORA #ACCY
 STA &FE34
 LDA F_BACK
 STA GPEND
 EOR #1
 STA F_BACK
 LDA #&FF
 STA GFLIP
 CLI

.f_reset
 LDA #0                 \ empty the per-frame lists
 STA F_NSHIP
 STA F_NLINE
 STA F_NDOT
 STA F_PLON
 STA GSUNON
 LDA #LO(F_DL)
 STA F_DLP
 LDA #HI(F_DL)
 STA F_DLP+1
 LDY f_ysav
 RTS

.f_zsave SKIP &22+16

\ f_enter: switch from direct drawing to double buffering. Main RAM (buffer
\ 0) has just been cleared by TT66 and holds the border; shadow RAM (buffer 1)
\ still holds the last frame of the previous space-mode session, which its
\ rasteriser state, disc colour and shown-text map still describe exactly
\ (direct mode only ever writes main RAM), so it is left alone and repaired
\ incrementally by its next frame. Only the border is copied across.

.f_enter
 LDA #HI(&4000)         \ copy byte columns 0 and 63 of every line, and the
 STA fen1+2             \ whole of line 0, from main RAM to shadow RAM
 STA fen2+2
 LDA #HI(&41F8)
 STA fen5+2
 STA fen6+2
.fen0
 LDX #7
.fen1
 LDA &4000,X            \ column 0, lines 0-7 of this character row
 STA f_page,X
.fen5
 LDA &41F8,X        \ column 63
 STA f_page+8,X
 DEX
 BPL fen1
 LDA #ACCY+4
 STA &FE34              \ X = 1: shadow RAM
 LDX #7
.fen3
 LDA f_page,X
.fen2
 STA &4000,X
 LDA f_page+8,X
.fen6
 STA &41F8,X
 DEX
 BPL fen3
 LDA #ACCY
 STA &FE34
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
 LDX #0                 \ line 0: bytes 0, 8, 16, ... (every 8th byte of
.fen7                   \ pages &40 and &41)
 LDA &4000,X
 STA f_page,X
 LDA &4100,X
 STA f_page+256,X       \ (f_page is 512 bytes)
 TXA
 CLC
 ADC #8
 TAX
 BNE fen7
 LDA #ACCY+4
 STA &FE34
.fen8
 LDA f_page,X
 STA &4000,X
 LDA f_page+256,X
 STA &4100,X
 TXA
 CLC
 ADC #8
 TAX
 BNE fen8
 LDA #ACCY
 STA &FE34

 LDA #0                 \ buffer 0's state: empty (TT66 blacked it)
 JSR T_SETBUF
 JSR T_RESETBUF
 LDA #&FF
 STA F_DCOL
 LDA #0
 TAX
.fen4
 STA F_SH0,X
 STA F_SH0+256,X
 STA F_SH0+512,X
 INX
 BNE fen4
 LDX #23
.fen9
 STA F_SHR0,X
 DEX
 BPL fen9
 LDA #1
 STA F_BACK
 LDA #0
 STA GFRONT
 STA GFLIP
 LDA #&80
 STA GMODE
 RTS

.f_page SKIP 512

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

.f_bufpatch
 FPATCH fdc_dl1, R_DIRTYL0, R_DIRTYL1
 FPATCH fdc_dl2, R_DIRTYL0, R_DIRTYL1
 FPATCH fdc_dr1, R_DIRTYR0, R_DIRTYR1
 FPATCH fdc_dr2, R_DIRTYR0, R_DIRTYR1
 FPATCH fdc_ol, R_DISCL0, R_DISCL1
 FPATCH fdc_or, R_DISCR0, R_DISCR1
 FPATCH ft_sr1, F_SHR0, F_SHR1
 FPATCH ft_sr2, F_SHR0, F_SHR1
 FPATCH ft_sr3, F_SHR0, F_SHR1
 FPATCH ft_wd1, R_DIRTYL0, R_DIRTYL1
 FPATCH ft_wd2, R_DIRTYR0, R_DIRTYR1
 RTS

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
 JSR f_discdirty
.fds5
 LDA f_lay
 BEQ fds9
 CMP #1
 BEQ fds6
 LDA #FC_PLANE
 STA R_DCE
 LDA #FC_PLANO
 STA R_DCO
 JSR f_plrows           \ planet spans into R_NDISCL/R, R_NDT/R_NDB
 JMP T_DISCROWS
.fds6
 LDA #FC_SUNE
 STA R_DCE
 LDA #FC_SUNO
 STA R_DCO
 JSR f_sunrows
 JMP T_DISCROWS
.fds9
 LDA #1                 \ no disc
 STA R_NDT
 LDA #0
 STA R_NDB
 JMP T_DISCROWS

.f_lay EQUB 0           \ disc layer: 0 none, 1 sun, 2 planet
.f_sec EQUB 0           \ secondary disc

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

\ f_clamp: (fz_p) = 16-bit left edge, (fz_q) = 16-bit right edge -> R_XL, R_XR
\ clamped to the clip window; C set if the span is empty.

.f_clamp
 LDA fz_q+1
 BMI fcl9               \ right < 0
 BNE fcl1
 LDA fz_q
 CMP R_CL
 BCC fcl9               \ right < CL
 CMP R_CR
 BCC fcl2
.fcl1
 LDA R_CR
.fcl2
 STA R_XR
 LDA fz_p+1
 BMI fcl3               \ left < 0
 BNE fcl9               \ left > 255
 LDA fz_p
 CMP R_CR
 BEQ fcl4
 BCS fcl9               \ left > CR
 CMP R_CL
 BCS fcl4
.fcl3
 LDA R_CL
.fcl4
 STA R_XL
 CLC
 RTS
.fcl9
 SEC
 RTS

\ f_sunrows: the sun's spans from Elite's own sun line heap: row y has
\ half-width LSO[y] about SUNX (16-bit) when non-zero.

.f_sunrows
 LDA #255
 STA R_NDT
 LDA #0
 STA R_NDB
 LDY R_CT
.fsr1
 LDA LSO,Y
 BEQ fsr8
 STA fz_t
 LDA SUNX
 SEC
 SBC fz_t
 STA fz_p
 LDA SUNX+1
 SBC #0
 STA fz_p+1
 LDA SUNX
 CLC
 ADC fz_t
 STA fz_q
 LDA SUNX+1
 ADC #0
 STA fz_q+1
 JSR f_clamp
 BCS fsr8
 LDA R_XL
 STA R_NDISCL,Y
 LDA R_XR
 STA R_NDISCR,Y
 CPY R_NDT
 BCS P%+5
 STY R_NDT
 STY R_NDB
 BNE fsr9
.fsr8
 LDA #255
 STA R_NDISCL,Y
 LDA #0
 STA R_NDISCR,Y
.fsr9
 INY
 CPY R_CB
 BCC fsr1
 BEQ fsr1
 RTS

\ f_plrows: the planet's spans, from the half-width table F_HW (rebuilt when
\ the radius changes): row y is in the disc when |y - cy| <= r.

.f_plrows
 LDA F_PLR
 CMP f_hwr
 BEQ fpr1
 STA f_hwr
 JSR f_hwbuild
.fpr1
 LDA #255
 STA R_NDT
 LDA #0
 STA R_NDB
 LDY R_CT
.fpr2
 TYA                    \ d = y - cy (16-bit)
 SEC
 SBC F_PLY
 STA fz_t
 LDA #0
 SBC F_PLY+1
 BPL fpr3
 EOR #&FF               \ |d|
 STA fz_u
 LDA fz_t
 EOR #&FF
 CLC
 ADC #1
 STA fz_t
 LDA fz_u
 ADC #0
.fpr3
 BNE fpr8               \ |d| > 255
 LDA fz_t
 CMP F_PLR
 BEQ fpr4
 BCS fpr8
.fpr4
 TAX
 LDA F_HW,X
 STA fz_t
 LDA F_PLX
 SEC
 SBC fz_t
 STA fz_p
 LDA F_PLX+1
 SBC #0
 STA fz_p+1
 LDA F_PLX
 CLC
 ADC fz_t
 STA fz_q
 LDA F_PLX+1
 ADC #0
 STA fz_q+1
 JSR f_clamp
 BCS fpr8
 LDA R_XL
 STA R_NDISCL,Y
 LDA R_XR
 STA R_NDISCR,Y
 CPY R_NDT
 BCS P%+5
 STY R_NDT
 STY R_NDB
 BNE fpr9
.fpr8
 LDA #255
 STA R_NDISCL,Y
 LDA #0
 STA R_NDISCR,Y
.fpr9
 INY
 CPY R_CB
 BCC fpr2
 BEQ fpr2
 RTS

.f_hwr EQUB 0           \ radius F_HW was built for (0 = none)

\ f_hwbuild: F_HW[d] = floor(sqrt(r*r - d*d)) for d = 0..r, r = f_hwr, by
\ walking x down from r while x*x + d*d > r*r (error kept as e = r*r - d*d -
\ x*x, 16-bit signed).

.f_hwbuild
 LDX f_hwr              \ x = r
 LDA #0
 STA fz_p               \ e = 0 (d = 0, x = r)
 STA fz_p+1
 LDY #0                 \ d
.fhw1
 TXA
 STA F_HW,Y
 CPY f_hwr
 BEQ fhw9
 TYA                    \ e -= 2d + 1 ; d++
 ASL A
 STA fz_t
 LDA #0
 ROL A
 STA fz_u
 LDA fz_p
 SEC
 SBC fz_t
 STA fz_p
 LDA fz_p+1
 SBC fz_u
 STA fz_p+1
 LDA fz_p
 SEC
 SBC #1
 STA fz_p
 BCS P%+4
 DEC fz_p+1
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
 LDA #FC_PLANE
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

\ f_ships: insertion-sort the ships far to near, then fill each one's visible
\ faces and draw its detail lines.

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
.f_hue  EQUB 0
.f_d    EQUB 0          \ brightness offset D for this ship
.f_nf   EQUB 0
.f_f    EQUB 0          \ face number
.f_x4   EQUB 0

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
 LDA FC_HUE,Y
 STA f_hue
 TYA
 ASL A
 TAY
 LDA FC_FACETAB,Y
 STA fz_ft
 LDA FC_FACETAB+1,Y
 STA fz_ft+1
 LDA FC_NRMTAB,Y
 STA fz_nm
 LDA FC_NRMTAB+1,Y
 STA fz_nm+1
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
 LDY F_SZN,X            \ D = min(255, 256 - FC_LOG[zn])
 LDA FC_LOG,Y
 EOR #&FF
 CLC
 ADC #1                 \ 256 - L (L = 0 gives 0 = 256 -> saturate below)
 BNE P%+4
 LDA #255
 STA f_d

 LDA #0
 STA f_f
.fsh_face
 LDA f_f
 CMP f_nf
 BCC P%+5
 JMP f_detail
 LDY #0
 LDA (fz_ft),Y          \ n
 STA fz_n
 TAY                    \ Y = f
 LDY f_f
 LDA (fz_dl),Y          \ visibility
 BEQ fsh_next
 CMP #255
 BNE fsh_lvl
 LDA #FC_FARLVL
 BNE fsh_col
.fsh_lvl
 TAX                    \ idx = FC_LOG[v] + C_f + D, saturating
 LDA FC_LOG,X
 CLC
 ADC (fz_nm),Y
 BCS fsh_sat
 ADC f_d
 BCC P%+4
.fsh_sat
 LDA #255
 TAX
 LDA FC_LEVEL,X
.fsh_col
 STA fz_t               \ colour = ramp[hue*8 + level]
 LDA f_hue
 ASL A
 ASL A
 ASL A
 ORA fz_t
 TAX
 LDA FC_RAMPE,X
 STA R_COLE
 LDA FC_RAMPO,X
 STA R_COLO
 LDA fz_n
 CMP #3
 BCC fsh_next
 STA R_PN
 LDX #0                 \ gather the vertices
 LDY #1
.fsh_v
 STY fz_u
 LDA (fz_ft),Y          \ XX3 offset
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
 BCC fsh_v
 JSR T_POLY
.fsh_next
 LDA fz_n               \ next face list entry
 SEC
 ADC fz_ft
 STA fz_ft
 BCC P%+4
 INC fz_ft+1
 INC f_f
 JMP fsh_face

.f_detail               \ detail lines: count, then (vis, f1+16*f2, a, b)
 LDX f_si
 LDY F_STYP,X
 TYA
 ASL A
 TAY
 LDA FC_DETTAB,Y
 STA fz_ft
 LDA FC_DETTAB+1,Y
 STA fz_ft+1
 LDY #0
 LDA (fz_ft),Y
 BNE P%+5
 JMP fdt9             \ (fz_n) count
 STA fz_n
 LDX f_hue
 LDA FC_DETC,X
 STA R_COLE
 STA R_COLO
 LDY #1
.fdt1
 LDA (fz_ft),Y          \ visibility distance
 CMP f_x4
 BCC fdt8
 INY
 LDA (fz_ft),Y
 PHA
 AND #15
 STY fz_u
 TAY
 LDA (fz_dl),Y
 BNE fdt2
 PLA
 LSR A
 LSR A
 LSR A
 LSR A
 TAY
 LDA (fz_dl),Y
 BEQ fdt7
 PHA
.fdt2
 PLA
 LDY fz_u
 INY
 LDA (fz_ft),Y          \ vertex a
 STY fz_u
 TAY
 LDA (fz_v3),Y
 STA R_X0
 INY
 LDA (fz_v3),Y
 STA R_X0+1
 INY
 LDA (fz_v3),Y
 STA R_Y0
 INY
 LDA (fz_v3),Y
 STA R_Y0+1
 LDY fz_u
 INY
 LDA (fz_ft),Y          \ vertex b
 STY fz_u
 TAY
 LDA (fz_v3),Y
 STA R_X1
 INY
 LDA (fz_v3),Y
 STA R_X1+1
 INY
 LDA (fz_v3),Y
 STA R_Y1
 INY
 LDA (fz_v3),Y
 STA R_Y1+1
 LDA fz_ft              \ R_LINE clobbers &10-&27 only; keep our pointers
 PHA
 LDA fz_ft+1
 PHA
 JSR T_LINE
 PLA
 STA fz_ft+1
 PLA
 STA fz_ft
 LDY fz_u
 INY
 JMP fdt6
.fdt7
 LDY fz_u
 INY
 INY
 INY
 JMP fdt6
.fdt8
 INY
 INY
 INY
 INY
.fdt6
 DEC fz_n
 BEQ fdt9
 JMP fdt1
.fdt9
 RTS

.f_dots
 LDA #0
 STA fz_i
.fdo2
 LDX fz_i
 CPX F_NDOT
 BCS fdo8
 LDA F_DC,X
 BPL fdo3
 AND #&7F               \ a hue: its brightest level
 ASL A
 ASL A
 ASL A
 ORA #7
 TAY
 LDA FC_RAMPE,Y
 STA R_COLE
 LDA FC_RAMPO,Y
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
 LDA GSIGHT
 BEQ fla9
 LDA #FC_SIGHT
 JSR f_setcol
 LDA #X-20
 STA fz_t
 LDA #Y
 STA fz_u
 LDX #X-11
 LDY #Y
 JSR f_line8
 LDA #X+11
 STA fz_t
 LDX #X+20
 LDY #Y
 JSR f_line8
 LDA #X
 STA fz_t
 LDA #Y-20
 STA fz_u
 LDX #X
 LDY #Y-11
 JSR f_line8
 LDA #Y+11
 STA fz_u
 LDX #X
 LDY #Y+20
 JSR f_line8
.fla9
 RTS

.f_stars                \ gather the valid stars into R_SX/R_SY/R_SS
 LDX #0
 LDY #1
.fst5
 LDA F_STV,Y
 BEQ fst6
 LDA F_STX,Y
 STA R_SX,X
 LDA F_STY,Y
 STA R_SY,X
 LDA F_STS,Y
 STA R_SS,X
 INX
.fst6
 INY
 CPY #24
 BCC fst5
 STX R_SN
 JMP T_STARPLOT

\ ------------------------------------------------------------------------------
\ Text overlay
\ ------------------------------------------------------------------------------

F_TCOL = &FF            \ text ink: yellow (logical colour 3)

\ f_rowptr: X = text row -> fz_p = F_TM + 32*row, fz_q = shown map + 32*row

.f_rowptr
 TXA
 LSR A
 LSR A
 LSR A
 STA fz_p+1
 TXA
 ASL A
 ASL A
 ASL A
 ASL A
 ASL A
 STA fz_p
 STA fz_q
 LDA fz_p+1
 STA fz_q+1
 LDA fz_p
 CLC
 ADC #LO(F_TM)
 STA fz_p
 LDA fz_p+1
 ADC #HI(F_TM)
 STA fz_p+1
 LDA F_BACK
 BNE frp1
 LDA fz_q
 CLC
 ADC #LO(F_SH0)
 STA fz_q
 LDA fz_q+1
 ADC #HI(F_SH0)
 STA fz_q+1
 RTS
.frp1
 LDA fz_q
 CLC
 ADC #LO(F_SH1)
 STA fz_q
 LDA fz_q+1
 ADC #HI(F_SH1)
 STA fz_q+1
 RTS

\ f_text1: cells shown in this buffer that must change: give them back their
\ background by marking them dirty before R_DISCROWS repaints

.f_text1
 LDX #0
.ft11
 STX fz_i
.ft_sr1
 LDA F_SHR0,X           \ patched
 BEQ ft18
 JSR f_rowptr
 LDY #31
.ft12
 LDA (fz_q),Y
 BEQ ft17
 CMP (fz_p),Y
 BEQ ft17
 LDA #0                 \ this cell goes: forget it, mark it dirty
 STA (fz_q),Y
 LDX fz_i
.ft_sr2
 DEC F_SHR0,X           \ patched
 STY fz_u
 TYA
 ASL A
 ASL A
 ASL A
 STA R_XL
 ORA #7
 STA R_XR
 JSR f_clipx
 BCC ft16
 LDA fz_i               \ lines 8r..8r+7 within the clip window
 ASL A
 ASL A
 ASL A
 STA fz_t
 CLC
 ADC #8
 STA fz_n
.ft13
 LDY fz_t
 CPY R_CT
 BCC ft14
 CPY R_CB
 BEQ P%+4
 BCS ft16
 LDA R_XL
 PHA
 LDA R_XR
 PHA
 JSR T_MARKDIRTY
 PLA
 STA R_XR
 PLA
 STA R_XL
.ft14
 INC fz_t
 LDA fz_t
 CMP fz_n
 BCC ft13
.ft16
 LDY fz_u
.ft17
 DEY
 BPL ft12
.ft18
 LDX fz_i
 INX
 CPX #24
 BCC ft11
 RTS

.f_clipx                \ clamp R_XL..R_XR to the clip window; C set if empty
 LDA R_XL
 CMP R_CL
 BCS P%+6
 LDA R_CL
 STA R_XL
 LDA R_XR
 CMP R_CR
 BCC P%+6
 LDA R_CR
 STA R_XR
 LDA R_XR
 CMP R_XL
 RTS                    \ C clear if XR < XL... invert below

\ f_text2: draw the text map's cells that this buffer doesn't show yet, or
\ whose pixels something overwrote this frame

.f_text2
 LDX #0
.ft21
 STX fz_i
 LDA F_TMR,X
 BNE P%+5
 JMP ft29
 JSR f_rowptr
 LDA #255               \ W = union of R_WL/R_WR and DIRTY over the 8 lines
 STA f_wl
 LDA #0
 STA f_wr
 LDA fz_i
 ASL A
 ASL A
 ASL A
 TAY
 CLC
 ADC #8
 STA fz_n
.ft22
 LDA R_WR,Y
 BEQ ft23
 CMP f_wr
 BCC P%+5
 STA f_wr
 LDA R_WL,Y
 CMP f_wl
 BCS ft23
 STA f_wl
.ft23
.ft_wd2
 LDA R_DIRTYR0,Y        \ patched
 BEQ ft24
 CMP f_wr
 BCC P%+5
 STA f_wr
.ft_wd1
 LDA R_DIRTYL0,Y        \ patched
 CMP f_wl
 BCS ft24
 STA f_wl
.ft24
 INY
 CPY fz_n
 BCC ft22
 LDA f_wl               \ as cell columns: wl DIV 8 .. wr DIV 8
 LSR A
 LSR A
 LSR A
 STA f_wl
 LDA f_wr
 BEQ ft25
 LSR A
 LSR A
 LSR A
 STA f_wr
 JMP ft26
.ft25
 LDA #255               \ nothing written in this row
 STA f_wl
 LDA #0
 STA f_wr
.ft26
 LDY #31
.ft27
 LDA (fz_p),Y
 BEQ ft28
 CMP (fz_q),Y
 BNE ft2d               \ not shown yet
 CPY f_wl
 BCC ft28
 CPY f_wr
 BEQ ft2d
 BCS ft28
.ft2d
 LDA (fz_q),Y
 BNE ft2e
 LDX fz_i
.ft_sr3
 INC F_SHR0,X           \ patched
.ft2e
 LDA (fz_p),Y
 STA (fz_q),Y
 STY fz_u
 JSR f_glyph
 LDY fz_u
.ft28
 DEY
 BPL ft27
 LDX fz_i
.ft29
 INX
 CPX #24
 BCS P%+5
 JMP ft21
 RTS

.f_wl EQUB 0
.f_wr EQUB 0

\ f_glyph: draw character A at column Y, text row fz_i, ink F_TCOL, only on
\ the glyph's pixels and only inside the clip window

.f_glyph
 SEC
 SBC #32
 STA fz_nm               \ glyph address = F_FONT + 8 * (char - 32)
 LDA #0
 ASL fz_nm
 ROL A
 ASL fz_nm
 ROL A
 ASL fz_nm
 ROL A
 STA fz_nm+1
 LDA fz_nm
 CLC
 ADC #LO(F_FONT)
 STA fgl1+1
 LDA fz_nm+1
 ADC #HI(F_FONT)
 STA fgl1+2
 TYA                    \ screen: &4000 + row*&200 + 16*col
 ASL A
 ASL A
 ASL A
 ASL A
 STA fz_nm               \ low byte (16*col, may carry)
 LDA #0
 ROL A
 STA fz_nm+1
 LDA fz_i
 ASL A
 ADC #&40
 ADC fz_nm+1
 STA fz_nm+1
 LDA #&FF               \ masks for the border columns
 STA f_lmk
 STA f_rmk
 CPY #0
 BNE P%+7
 LDA #&77               \ pixel 0 of column 0 is the border
 STA f_lmk
 CPY #31
 BNE P%+7
 LDA #&EE               \ pixel 255 is the border
 STA f_rmk
 LDA fz_i               \ first line y = 8*row
 ASL A
 ASL A
 ASL A
 STA f_gy
 LDX #0
.fgl0
 LDA f_gy               \ inside the clip window vertically?
 CMP R_CT
 BCC fgl3
 CMP R_CB
 BEQ P%+4
 BCS fgl3
.fgl1
 LDA F_FONT,X           \ patched
 BEQ fgl3
 PHA
 LSR A
 LSR A
 LSR A
 LSR A
 TAY
 LDA f_nib,Y
 AND f_lmk
 STA fz_v3               \ mask (fz_v3 is free here)
 TXA
 TAY
 LDA fz_v3
 EOR #&FF
 AND (fz_nm),Y
 STA fz_v3+1
 LDA #F_TCOL
 AND fz_v3
 ORA fz_v3+1
 STA (fz_nm),Y
 PLA
 AND #15
 TAY
 LDA f_nib,Y
 AND f_rmk
 STA fz_v3
 TXA
 CLC
 ADC #8
 TAY
 LDA fz_v3
 EOR #&FF
 AND (fz_nm),Y
 STA fz_v3+1
 LDA #F_TCOL
 AND fz_v3
 ORA fz_v3+1
 STA (fz_nm),Y
.fgl3
 INC f_gy
 INX
 CPX #8
 BCC fgl0
 RTS

.f_gy EQUB 0
.f_lmk EQUB 0
.f_rmk EQUB 0

.f_nib                  \ 4 font bits (bit 3 = leftmost) -> MODE 1 pixel mask
FOR n, 0, 15
 EQUB n * &11
NEXT

.F_FONT
 INCBIN "src/font.bin"

