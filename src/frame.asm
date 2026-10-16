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
.F_CPO
 EQUB &00, &FF, &F0, &0F, &FF, &0F, &FF

\ ------------------------------------------------------------------------------
\ F_INIT: one-off initialisation (called by the loader / startup)
\ ------------------------------------------------------------------------------

.F_INIT
 LDX #&21               \ R_INIT uses &06-&27: keep Elite's values
.fin0
 LDA &06,X
 STA f_zsave,X
 DEX
 BPL fin0
 JSR T_INIT
 LDX #&21
.fin4
 LDA f_zsave,X
 STA &06,X
 DEX
 BPL fin4
 LDA #ACCY+4            \ clear shadow RAM's screen (buffer 1)
 STA &FE34
 LDA #&40
 STA fin3+2
 LDA #0
 TAX
.fin3
 STA &4000,X
 INX
 BNE fin3
 INC fin3+2
 LDY fin3+2
 CPY #&70
 BNE fin3
 LDA #ACCY
 STA &FE34
 LDA #0
 STA F_NSHIP
 STA F_NLINE
 STA F_NDOT
 STA F_PLON
 LDX #23
.fin1
 STA R_SS,X
 DEX
 BPL fin1
 JSR f_tmclear
 RTS

\ ------------------------------------------------------------------------------
\ Text map: 24 rows x 32 columns of desired characters (F_TM), and what each
\ buffer actually shows (F_SH0, F_SH1). F_TMR/F_SHR0/F_SHR1 count the non-zero
\ cells in each row so empty rows cost nothing.
\ ------------------------------------------------------------------------------

.f_tmclear              \ clear the text map and buffer 0's shown map (buffer
 LDA #0                 \ 1 keeps its own: it still holds that picture)
 TAX
.ftc1
 STA F_TM,X
 STA F_TM+256,X
 STA F_TM+512,X
 STA F_SH0,X
 STA F_SH0+256,X
 STA F_SH0+512,X
 INX
 BNE ftc1
 LDX #23
.ftc2
 STA F_TMR,X
 STA F_SHR0,X
 DEX
 BPL ftc2
 JMP f_tchall

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
.F_TCH  SKIP 24         \ per text row: bit b set = buffer b's shown row may
                        \ differ from the text map (f_text1/f_text2 scan it whole)
.f_tbit EQUB 0          \ this frame's buffer bit (1 or 2)

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
 LDX f_row
 LDA #3
 STA F_TCH,X
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
 LDA #0
 JSR f_tmstore
 LDX f_row
 DEC F_TMR,X
 LDA #3
 STA F_TCH,X
.fdc9
 LDY f_ysav
 RTS

\ f_clrtext0 (F_CLRTEXT, frame_cold.asm): clear text map rows X to Y inclusive

.f_clrtext0
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
 LDA #3
 STA F_TCH,X
 LDA #0
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
\ f_direct0 (F_DIRECT, frame_cold.asm): the screen is about to be cleared and
\ drawn directly (TT66): cancel double buffering, show and access main RAM.
\ ------------------------------------------------------------------------------

.f_direct0
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
 LDX #23                \ the stars will be re-recorded too
.fdi1
 STA R_SS,X
 DEX
 BPL fdi1
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
 STA PM_R
 LDA TYPE
 STA F_PLT
 LDA INWK+7
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
 JMP f_reset            \ not a space view: just forget what was recorded

.ff1

 \ save the zero page the rasteriser uses (&06-&27) and the frame layer's
 \ (&D2-&E1), unrolled
 FOR z, &06, &27
  LDA z
  STA f_zsave + z - &06
 NEXT
 FOR z, 0, 15
  LDA FZ + z
  STA f_zsave + &22 + z
 NEXT

 BIT GMODE
 BMI ff5
 JSR f_enter2           \ first space-mode frame since the screen was cleared
                        \ (f_enter, with frame_cold.asm's direct-mode fix-ups)

.ff5                    \ (what touches no screen memory goes before the wait)
 JSR f_bufpatch
 LDA #2                 \ the clip window inside the border (the zero page
 STA R_CL               \ copy is Elite's between frames)
 LDA #253
 STA R_CR
 LDA #1
 STA R_CT
 LDA #191
 STA R_CB
 LDA F_BACK
 JSR T_SETBUF
 JSR f_text1            \ text cells to be erased: background them (old dirty)
 JSR f_sight1           \ and the sights, if they have gone

.ff2
 LDA GFLIP              \ wait for the previous flip, so the back buffer is
 BNE ff2                \ no longer on screen

 LDA F_BACK             \ let the CPU see the back buffer at &4000-&6FFF
 ASL A
 ASL A
 STA GACCX
 SEI
 ORA GFRONT
 ORA #ACCY
 STA &FE34
 CLI

 JSR T_STARERASE        \ undo last time's stars in this buffer
 JSR f_discs            \ the disc layer (sun or planet), incremental
 JSR f_disc2            \ the other disc, if both are on screen (full spans)
 JSR f_lines            \ planet meridians, craters, enemy lasers
 JSR f_ships            \ filled ships, far to near
 JSR f_dots             \ particles, distant ships
 JSR f_lasers           \ our laser beams and the sights
 JSR f_text2            \ text on top
 JSR f_sight2           \ and the sights
 JSR f_stars            \ stardust, on black only (last: erasing it next
                        \ time restores black, so it needs no WL/WR)

 FOR z, &06, &27         \ restore the zero page
  LDA f_zsave + z - &06
  STA z
 NEXT
 FOR z, 0, 15
  LDA f_zsave + &22 + z
  STA FZ + z
 NEXT

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
 STA PM_OK
 STA F_NSHIP
 STA F_NLINE
 STA F_NDOT
 STA F_PLON
 STA GSUNON
 STA F_NCV
 STA F_NPT
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
 STA F_SGS
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
 JSR f_tchall
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

.f_bufpatch             \ (each array's two copies differ only in the high byte)
 LDX F_BACK
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
 RTS
.fbp_dl EQUB HI(R_DIRTYL0), HI(R_DIRTYL1)
.fbp_dr EQUB HI(R_DIRTYR0), HI(R_DIRTYR1)
.fbp_ol EQUB HI(R_DISCL0), HI(R_DISCL1)
.fbp_or EQUB HI(R_DISCR0), HI(R_DISCR1)
.fbp_sr EQUB HI(F_SHR0), HI(F_SHR1)
.fbp_srl EQUB LO(F_SHR0), LO(F_SHR1)
ASSERT LO(R_DIRTYL0) = LO(R_DIRTYL1) AND LO(R_DIRTYR0) = LO(R_DIRTYR1)
ASSERT LO(R_DISCL0) = LO(R_DISCL1) AND LO(R_DISCR0) = LO(R_DISCR1)

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

\ f_sunrows / f_plrows: a disc's spans into R_NDISCL/R and R_NDT/R_NDB, from
\ its centre (16-bit screen coordinates) and radius (8-bit), using a cached
\ half-width table per disc (rebuilt only when the radius changes)

.f_sunrows
 LDA F_SUX
 STA f_cx
 LDA F_SUX+1
 STA f_cx+1
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
 STA f_cx+1
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
 LDA #0
 STA R_NDB
 RTS

.f_discspans            \ rows of the disc (f_cx, f_cy, f_r) within the window
 LDA #255               \ (rows outside R_NDT..R_NDB are not looked at)
 STA R_NDT
 LDA #0
 STA R_NDB
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
 LDA f_cx+1             \ fast path if the whole disc is inside the window
 BNE fds_slow           \ horizontally: cx - r >= CL and cx + r <= CR
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
 CMP R_CR
 BEQ fds_fast
 BCS fds_slow
.fds_fast               \ here r <= 127 and |d| <= r, so d fits a signed byte
 LDA f_cx
 STA fdf_cr+1           \ patch cx and 2cx + 1 (mod 256) into the loop
 SEC
 ROL A
 STA fdf_cl+1
 LDY R_NDT
 LDX fz_t               \ X = |d|, stepped by INX (d >= 0) or DEX (d < 0)
 LDA #&E8               \ INX
 BIT fz_u
 BPL fdf0
 TXA
 EOR #&FF
 TAX
 INX
 LDA #&CA               \ DEX
.fdf0
 STA fdf_st
 CLC
.fdf1                   \ C = 0 here
.fpr_ld
 LDA F_HW,X             \ patched: half-width n
.fdf_cr
 ADC #0                 \ patched: cx (A = cx + n <= cx + r <= 255, so C = 0)
 STA R_NDISCR,Y
 EOR #&FF
.fdf_cl
 ADC #0                 \ patched: 2cx + 1 (A = 2cx + 1 + ~(cx + n) = cx - n)
 STA R_NDISCL,Y
 CPY R_NDB
 INY
 BCS fdf9
.fdf_st
 INX                    \ patched: INX or DEX
 BNE fdf1
 LDA #&E8               \ d has reached 0: count |d| up from here
 STA fdf_st
 BNE fdf1               \ always (A = &E8)
.fdf9
 RTS

.fds_slow
 LDY R_NDT
.fpr2
 LDX fz_t               \ |d|
 LDA fz_u
 BPL fpr4
 TXA
 EOR #&FF
 TAX
 INX
.fpr4
.fpr_ld2
 LDA F_HW,X             \ patched: half-width
 STA fz_n
 LDA fz_t
 PHA
 LDA fz_u
 PHA
 LDA f_cx
 SEC
 SBC fz_n
 STA fz_p
 LDA f_cx+1
 SBC #0
 STA fz_p+1
 LDA f_cx
 CLC
 ADC fz_n
 STA fz_q
 LDA f_cx+1
 ADC #0
 STA fz_q+1
 JSR f_clamp
 BCS fpr8
 LDA R_XL
 STA R_NDISCL,Y
 LDA R_XR
 STA R_NDISCR,Y
 JMP fpr9
.fpr8
 LDA #255
 STA R_NDISCL,Y
 LDA #0
 STA R_NDISCR,Y
.fpr9
 PLA
 STA fz_u
 PLA
 STA fz_t
 INC fz_t
 BNE P%+4
 INC fz_u
 CPY R_NDB
 INY
 BCC fpr2
 RTS

.f_cx EQUW 0
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

\ f_ship: draw one ship. Every face has a fixed colour (FC_FACETAB: n, even
\ colour, odd colour, n XX3 offsets). Fins standing behind the body are drawn
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
 STA fz_n
 JMP fsh_next
.fsh_face
 LDY f_f
 CPY f_nf
 BCS fsh_done
 LDA (fz_dl),Y          \ visibility
 BEQ fsh_skip
 STA fz_t
 LDY #0
 LDA (fz_ft),Y          \ n
 STA fz_n
 CMP #3
 BCC fsh_next
 STA R_PN
 INY
 LDA (fz_ft),Y          \ the face's colour
 STA R_COLE
 INY
 LDA (fz_ft),Y
 STA R_COLO
 CLC                    \ the face's vertex offsets at fz_ft + 3
 LDA fz_ft
 ADC #3
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
 LDA fz_t               \ far ships (XX2 = 255: Elite skipped the normal test)
 CMP #255               \ cull back faces by their winding on screen, except
 BNE fsh_draw           \ the station (mirrored until its first TIDY)
 LDX f_si
 LDA F_STYP,X
 CMP #SST
 BEQ fsh_draw
 JSR f_winding
 BCC fsh_next
.fsh_draw
 JSR T_POLY
.fsh_next
 LDA fz_n               \ next face list entry: n + 3 bytes on
 CLC
 ADC #3
 ADC fz_ft
 STA fz_ft
 BCC P%+4
 INC fz_ft+1
 INC f_f
 JMP fsh_face

.fsh_done               \ details: skip the fins (8 bytes each) to the count
 LDY #0
 LDA (fz_dt),Y
 STA f_cnt
 ASL A
 ASL A
 ASL A
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
 LDA fz_t
 CMP #255
 BNE fit2
 JSR f_winding
 BCC fit8
.fit2
 JSR T_POLY
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
 LDY #4                 \ next item: 5 + n bytes on
 LDA (fz_q),Y
 CLC
 ADC #5
 ADC fz_q
 STA fz_q
 BCC P%+4
 INC fz_q+1
 RTS

\ f_itemv: the item at (fz_q): R_COLE/R_COLO, fz_n = n, R_PX/R_PY[0..n-1]

.f_itemv
 LDY #2
 LDA (fz_q),Y
 STA R_COLE
 INY
 LDA (fz_q),Y
 STA R_COLO
 INY
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
 LDA fz_q               \ next fin: 8 bytes on
 CLC
 ADC #8
 STA fz_q
 BCC P%+4
 INC fz_q+1
 DEC f_cnt
 BNE ffi1
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

.f_stars                \ stars 1..NOSTM (NOSTM is only ever NOST = 18), recorded
 LDA #19                \ by the hooks straight into R_SX/R_SY/R_SS (R_SS = 0: none)
 STA R_SN
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
 LDA fz_p               \ F_SH1 = F_TM + 1536 (gfx-build.asm), and LO(F_TM)+32*row never carries
 STA fz_q
 LDA fz_p+1
 ADC #HI(F_SH1-F_TM)    \ C=0 here (from the ADC #HI(F_TM) above)
 STA fz_q+1
 RTS

\ f_text1: cells shown in this buffer that must change: give them back their
\ background by marking them dirty before R_DISCROWS repaints

.f_text1
 LDA F_BACK             \ this buffer's bit in F_TCH
 INC A
 STA f_tbit
 LDX #23                \ rows 23..0 (each row is independent)
.ft11
.ft_sr1
 LDA F_SHR0,X           \ patched
 BEQ ft18x              \ X = row still
 LDA F_TCH,X            \ shown row = text map row: nothing to remove
 AND f_tbit
 BEQ ft18x
 STX fz_i
 JSR f_rowptr
 LDY #31
.ft12
 LDA (fz_q),Y
 BEQ ft17a
 CMP (fz_p),Y
 BNE ft15
.ft17a
 DEY
 BPL ft12
 BMI ft18
.ft15
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
 LDY fz_t
.ft13                   \ Y = row (T_MARKDIRTY preserves Y, R_XL, R_XR)
 CPY R_CT
 BCC ft14
 CPY R_CB
 BEQ P%+4
 BCS ft16
 JSR T_MARKDIRTY
.ft14
 INY
 CPY fz_n
 BCC ft13
.ft16
 LDY fz_u
.ft17
 DEY
 BPL ft12
.ft18
 LDX fz_i
.ft18x
 DEX
 BPL ft11
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
 LDA F_TMR,X            \ skip empty rows in a tight loop
 BNE ft2r
.ft29
 INX
 CPX #24
 BCC ft21
 RTS
.ft2r
 STX fz_i
 JSR f_rowptr
 LDA #255               \ W = union of R_WL/R_WR and DIRTY over the 8 lines
 STA f_wl
 LDA #0
 STA f_wr
 TXA                    \ X = fz_i (f_rowptr preserves X)
 ASL A
 ASL A
 ASL A
 TAY
 ADC #8                 \ C = 0: row <= 23, so 8*row < 256
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
 LDX fz_i               \ row unchanged for this buffer: only the cells
 LDA F_TCH,X            \ written over (columns f_wl..f_wr)
 AND f_tbit
 BNE ft2f
 LDY f_wr
 CPY f_wl
 BCC ft2x
 LDA f_wl
 STA ft_end
 BRA ft27
.ft2x
 JMP ft29
.ft2f
 EOR F_TCH,X            \ whole row (then it is unchanged)
 STA F_TCH,X
 STZ ft_end
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
 CPY ft_end
 BEQ ft2e9
 DEY
 JMP ft27
.ft2e9
 LDX fz_i
 JMP ft29

.f_wl EQUB 0
.f_wr EQUB 0
.ft_end EQUB 0

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
 LDA #&33               \ pixels 0-1 of column 0 are the border
 STA f_lmk
 CPY #31
 BNE P%+7
 LDA #&CC               \ pixels 254-255 are the border
 STA f_rmk
 ASSERT F_TCOL = &FF    \ ink is all-ones: (m AND ink) OR (NOT m AND s) = m OR s
 LDA fz_nm              \ fz_v3 = fz_nm + 8, the right byte of the cell
 ORA #8                 \ (fz_nm = 16*col: low nibble 0, so no carry; fz_v3 is free here)
 STA fz_v3
 LDA fz_nm+1
 STA fz_v3+1
 LDA fz_i               \ first line y = 8*row
 ASL A
 ASL A
 ASL A
 STA f_gy
 LDY #0
.fgl0
 LDA f_gy               \ inside the clip window vertically?
 CMP R_CT
 BCC fgl3
 CMP R_CB
 BEQ P%+4
 BCS fgl3
.fgl1
 LDA F_FONT,Y           \ patched
 BEQ fgl3
 PHA
 LSR A
 LSR A
 LSR A
 LSR A
 TAX
 LDA f_nib,X
 AND f_lmk
 ORA (fz_nm),Y
 STA (fz_nm),Y
 PLA
 AND #15
 TAX
 LDA f_nib,X
 AND f_rmk
 ORA (fz_v3),Y
 STA (fz_v3),Y
.fgl3
 INC f_gy
 INY
 CPY #8
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


\ ------------------------------------------------------------------------------
\ Laser sights: four short arms about (128, 96), drawn after everything else
\ and only redrawn when something was written over them (like the text)
\ ------------------------------------------------------------------------------

SGX = 128
SGY = 96
SGIN = 11               \ arms run from SGIN to SGOUT pixels from the centre
SGOUT = 20

.F_SGS EQUB 0, 0        \ per buffer: the sights are drawn in it

\ f_sight1: sights shown in this buffer but no longer wanted: mark them dirty

.f_sight1
 LDX F_BACK
 LDA F_SGS,X
 BEQ fsg9
 LDA GSIGHT
 BNE fsg9
 LDA #0
 STA F_SGS,X
 LDA #SGX-SGOUT
 STA R_XL
 LDA #SGX+SGOUT
 STA R_XR
 LDY #SGY
 JSR T_MARKDIRTY
 LDA #SGX
 STA R_XL
 STA R_XR
 LDY #SGY-SGOUT
.fsg1
 STY fz_i
 JSR T_MARKDIRTY
 LDY fz_i
 INY
 CPY #SGY+SGOUT+1
 BCC fsg1
.fsg9
 RTS

\ f_wcov: does anything written this frame in row Y cover x = A .. X?
\ (R_WL/R_WR, or this buffer's new dirty extent). C set if so. Keeps Y.

.f_wcov
 STA fz_t
 STX fz_u
 LDA R_WR,Y             \ written: WL..WR (WR = 0: none)
 BEQ fwc2
 CMP fz_t
 BCC fwc2
 LDA fz_u
 CMP R_WL,Y
 BCS fwc9
.fwc2
.fsw_d2
 LDA R_DIRTYR0,Y        \ patched
 BEQ fwc8
 CMP fz_t
 BCC fwc8
 LDA fz_u
.fsw_d1
 CMP R_DIRTYL0,Y        \ patched
 BCS fwc9
.fwc8
 CLC
.fwc9
 RTS

.f_sight2
 LDA GSIGHT
 BEQ fsg9
 LDX F_BACK
 LDA F_SGS,X
 BEQ fsg3               \ not drawn yet
 LDY #SGY               \ overwritten anywhere?
 LDA #SGX-SGOUT
 LDX #SGX+SGOUT
 JSR f_wcov
 BCS fsg3
 LDA fsw_d2+2           \ this buffer's R_DIRTYR (f_bufpatch), high byte
 STA fsg_or+2           \ (the low bytes are equal)
 ASSERT LO(R_DIRTYR0) = LO(R_DIRTYR1)
 LDY #SGY-SGOUT         \ f_wcov with A = X = SGX: WR, DIRTYR >= SGX (= &80,
.fsg2                   \ so <> 0) <=> bit 7 set; usually neither is
 LDA R_WR,Y
.fsg_or
 ORA R_DIRTYR0,Y        \ patched (high byte, above)
 BMI fsgs
.fsg8
 INY
 CPY #SGY+SGOUT+1
 BCC fsg2
 RTS
.fsgs
 LDA #SGX
 STA fz_t
 STA fz_u
 LDX R_WR,Y
 BPL fsg7
 CMP R_WL,Y
 BCS fsg3
.fsg7
 JSR fwc2               \ this buffer's dirty extent (uses fz_t = fz_u = SGX)
 BCS fsg3
 BRA fsg8
.fsg3
 LDX F_BACK
 LDA #&FF
 STA F_SGS,X
 LDA F_CPE+FC_SIGHT     \ horizontal arms (row SGY is even)
 STA R_COLE
 STA R_COLO
 LDA #SGX-SGOUT
 STA R_XL
 LDA #SGX-SGIN
 STA R_XR
 LDY #SGY
 JSR T_SPAN
 LDA #SGX+SGIN
 STA R_XL
 LDA #SGX+SGOUT
 STA R_XR
 LDY #SGY
 JSR T_SPAN
 LDA F_CPE+FC_SIGHT     \ vertical arms: pixel 0 of byte column 32
 AND #&88               \ (loop-invariant colour bits)
 STA fz_t
 ASSERT SGY-SGOUT = 76 AND SGY-SGIN = 85   \ byte = &4000 + (y DIV 8)*&200 + &100 + (y MOD 8)
 ASSERT SGY+SGIN = 107 AND SGY+SGOUT = 116
 LDY #3                 \ rows 76..79: &5304..&5307
.fsg4
 LDA &5304,Y
 AND #&77
 ORA fz_t
 STA &5304,Y
 DEY
 BPL fsg4
 LDY #5                 \ rows 80..85: &5500..&5505
.fsg5
 LDA &5500,Y
 AND #&77
 ORA fz_t
 STA &5500,Y
 DEY
 BPL fsg5
 LDY #4                 \ rows 107..111: &5B03..&5B07, rows 112..116: &5D00..&5D04
.fsg6
 LDA &5B03,Y
 AND #&77
 ORA fz_t
 STA &5B03,Y
 LDA &5D00,Y
 AND #&77
 ORA fz_t
 STA &5D00,Y
 DEY
 BPL fsg6
 SEC                    \ C = 1 on exit, as before
 RTS

\ ------------------------------------------------------------------------------
\ Planet surface detail, filled: Elite's PLS22 computes each ellipse (half
\ ellipses for the equator and meridian, a full one for a crater) as points
\ passed to BLINE; we record them (F_PCURVE, F_PPOINT) and turn the curves
\ into per-row colour boundaries for the disc layer: the disc alternates
\ between colour A and colour B at each boundary, so the meridian and equator
\ give a two-colour "beach ball" and a crater a filled ellipse.
\ ------------------------------------------------------------------------------

MAXCV = 3               \ curves per frame
MAXPT = 140             \ points per frame

.F_NCV EQUB 0           \ curves recorded this frame
.F_NPT EQUB 0           \ points recorded this frame
.F_CVS SKIP MAXCV       \ first point of each curve
.F_CVE SKIP MAXCV       \ one past its last point
.F_CVT SKIP MAXCV       \ TGT: 31 (half ellipse) or 64 (full)
.F_PXL SKIP MAXPT
.F_PXH SKIP MAXPT
.F_PYL SKIP MAXPT
.F_PYH SKIP MAXPT

.F_PCURVE
 STX f_xs
 STY f_ys
 LDX F_NCV
 CPX #MAXCV
 BCS fpc9
 LDA F_NPT
 STA F_CVS,X
 STA F_CVE,X
 LDA TGT
 STA F_CVT,X
 INC F_NCV
.fpc9
 LDX f_xs
 LDY f_ys
 RTS

.F_PPOINT
 STX f_xs
 STY f_ys
 LDX F_NCV
 BEQ fpc9
 LDY F_NPT
 CPY #MAXPT
 BCS fpc9
 LDA K6
 STA F_PXL,Y
 LDA K6+1
 STA F_PXH,Y
 LDA K6+2
 STA F_PYL,Y
 LDA K6+3
 STA F_PYH,Y
 INY
 STY F_NPT
 TYA
 STA F_CVE-1,X
 JMP fpc9

.f_xs EQUB 0
.f_ys EQUB 0

\ f_nobounds: rows R_NDT..R_NDB have no boundaries (plain disc)

.f_nobounds
 LDA #0
 STA R_NDF
 RTS

.f_zerobounds           \ rows R_NDT..R_NDB: no boundaries yet
 LDY R_NDT
 CPY R_NDB
 BEQ P%+4
 BCS fnb9
 LDA #0
.fnb1
 STA R_NDN,Y
 STA R_NDP,Y
 CPY R_NDB
 INY
 BCC fnb1
.fnb9
 RTS

\ f_bounds: the planet's curves -> R_NDN/R_NDX0-3/R_NDP for rows
\ R_NDT..R_NDB (which f_plrows has just set), and colour B

.f_bounds
 JSR f_nobounds
 LDA R_NDT
 CMP R_NDB
 BEQ P%+4
 BCS fnb9
 LDA F_NCV
 BEQ fnb9
 LDA #1
 STA R_NDF
 LDA F_PLT              \ colour B: green land on a meridian planet, a dark
 CMP #128               \ crater otherwise
 BNE fbd1
 LDA #&5F
 STA R_DBE
 LDA #&AF
 STA R_DBO
 JMP f_merid            \ the meridians: from the true geometry
.fbd1
 JSR f_zerobounds
 LDA #&50
 STA R_DBE
 LDA #&A0
 STA R_DBO
.fbd2
 LDA #0
 STA f_ci
.fbd3                   \ for each curve
 LDX f_ci
 CPX F_NCV
 BCC P%+5
 JMP f_parity
 LDA F_CVE,X            \ its segments: points F_CVS .. F_CVE-1
 STA fbd_e+1
 LDA F_CVS,X
 TAX
.fbd5
 INX                    \ segment X-1 -> X
.fbd_e
 CPX #0                 \ patched: F_CVE of this curve
 BCS fbd6
 LDA F_PXL-1,X          \ segment start = point X-1
 STA sg_ax
 LDA F_PXH-1,X
 STA sg_ax+1
 LDA F_PYL-1,X
 STA sg_ay
 LDA F_PYH-1,X
 STA sg_ay+1
 LDA F_PXL,X            \ segment end = point X
 STA sg_bx
 LDA F_PXH,X
 STA sg_bx+1
 LDA F_PYL,X
 STA sg_by
 LDA F_PYH,X
 STA sg_by+1
 PHX
 JSR f_seg16
 PLX
 BRA fbd5
.fbd6
                        \ (a crater's full ellipse is closed; the meridians'
                        \ half ellipses go to f_merid instead)
.fbd7
 INC f_ci
 JMP fbd3

.f_ci EQUB 0

 SKIP 18                \ (unused: keeps the rest of bank 6 where it was)

\ f_seg16: boundary crossings of the segment (sg_ax, sg_ay) - (sg_bx, sg_by)
\ (16-bit) for rows y with min(y) <= y < max(y) within R_NDT..R_NDB. A crossing
\ left of the row's disc span flips the row's starting colour (R_NDP), one
\ right of it is ignored, one inside is added to the row's boundaries. Long
\ segments (|dx| or |dy| > 255) are halved, recursively.

.f_seg16
 LDA sg_bx              \ |dx| > 255 or |dy| > 255?
 SEC
 SBC sg_ax
 LDA sg_bx+1
 SBC sg_ax+1
 BEQ fs16a
 CMP #&FF
 BNE fs16s
 LDA sg_bx
 CMP sg_ax
 BEQ fs16s              \ dx = -256
.fs16a
 LDA sg_by
 SEC
 SBC sg_ay
 LDA sg_by+1
 SBC sg_ay+1
 BEQ fs16b
 CMP #&FF
 BNE fs16s
 LDA sg_by
 CMP sg_ay
 BEQ fs16s
.fs16b
 JMP f_segment
.fs16s                  \ split at the midpoint: push the second half
 LDA sg_bx+1
 PHA
 LDA sg_bx
 PHA
 LDA sg_by+1
 PHA
 LDA sg_by
 PHA
 LDA sg_ax              \ mid = (a + b) / 2 (arithmetic: the true sign of the
 CLC                    \ 17-bit sum is N EOR V)
 ADC sg_bx
 STA fz_t
 LDA sg_ax+1
 ADC sg_bx+1
 STA fz_u
 BVC P%+4
 EOR #&80
 ASL A
 ROR fz_u
 ROR fz_t
 LDA fz_u
 STA sg_bx+1
 LDA fz_t
 STA sg_bx
 LDA sg_ay
 CLC
 ADC sg_by
 STA fz_t
 LDA sg_ay+1
 ADC sg_by+1
 STA fz_u
 BVC P%+4
 EOR #&80
 ASL A
 ROR fz_u
 ROR fz_t
 LDA fz_u
 STA sg_by+1
 LDA fz_t
 STA sg_by
 JSR f_seg16            \ first half: a -> mid
 LDA sg_bx              \ second half: mid -> b
 STA sg_ax
 LDA sg_bx+1
 STA sg_ax+1
 LDA sg_by
 STA sg_ay
 LDA sg_by+1
 STA sg_ay+1
 PLA
 STA sg_by
 PLA
 STA sg_by+1
 PLA
 STA sg_bx
 PLA
 STA sg_bx+1
 JMP f_seg16

\ f_segment: as f_seg16 for |dx|, |dy| <= 255

.f_segment
 LDA sg_ay              \ order the end points by y: (sg_x, sg_y) is the top
 CMP sg_by
 LDA sg_ay+1
 SBC sg_by+1
 BVC P%+4
 EOR #&80
 BMI fsg_ok             \ a above b
 LDA sg_ay              \ equal rows: nothing
 CMP sg_by
 BNE fsg_sw
 LDA sg_ay+1
 CMP sg_by+1
 BNE fsg_sw
 RTS
.fsg_sw
 LDX #3                 \ swap a and b
.fsg_w
 LDA sg_ax,X
 LDY sg_bx,X
 STA sg_bx,X
 TYA
 STA sg_ax,X
 DEX
 BPL fsg_w
.fsg_ok
 LDA sg_ax              \ start at a; dy = by - ay, dx = bx - ax
 STA sg_x
 LDA sg_ax+1
 STA sg_x+1
 LDA sg_ay
 STA sg_y
 LDA sg_ay+1
 STA sg_y+1
 LDA sg_by
 STA sg_y1
 SEC
 SBC sg_ay
 STA sg_dy
 LDA sg_by+1
 STA sg_y1+1
 LDA sg_bx
 SEC
 SBC sg_ax
 STA sg_dx
 LDA sg_bx+1
 SBC sg_ax+1
 STA sg_sx              \ sign of dx (bit 7)
 BPL fsg_p
 LDA sg_dx              \ |dx|
 EOR #&FF
 CLC
 ADC #1
 STA sg_dx
.fsg_p
 LDA sg_y+1             \ the segment must reach rows NDT..NDB:
 BMI fsg_a              \ y1 > NDT and y0 <= NDB
 BNE fsg_x
 LDA R_NDB
 CMP sg_y
 BCC fsg_x              \ NDB < y0: misses
.fsg_a
 LDA sg_y1+1
 BMI fsg_x
 BNE fsg_b
 LDA R_NDT
 CMP sg_y1
 BCC fsg_b              \ y1 > NDT: reaches the span
.fsg_x
 RTS
.fsg_b
 LDA sg_dx              \ q = |dx| DIV dy, r = |dx| MOD dy
 LDX #0
.fsg_d
 CMP sg_dy
 BCC fsg_e
 SBC sg_dy
 INX
 BNE fsg_d
.fsg_e
 STA sg_r
 STX sg_q
 STZ sg_err
.fsg_row                \ row sg_y: record the crossing if it's in range
 LDY sg_y               \ Y = sg_y (low byte) for the whole loop: sg_y itself
.fsg_ry                 \ is not updated after this (only read before here)
 LDA sg_y+1
 BMI fsg_n              \ above the screen
 BNE fsg_x              \ below it
 CPY R_NDT
 BCC fsg_n
 CPY R_NDB
 BEQ P%+4
 BCS fsg_x
 LDA sg_x+1             \ left of the span? (x <= NDISCL, x 16-bit)
 BMI fsg_l
 BNE fsg_n              \ x > 255: right of it
 LDA R_NDISCL,Y
 CMP sg_x
 BCS fsg_l
 LDA R_NDISCR,Y
 CMP sg_x
 BCC fsg_n              \ right of the span
 LDA sg_x
 LDX R_NDN,Y            \ inside: append (up to four)
 BNE fsg_k1
 STA R_NDX0,Y           \ n = 0
 LDA #1
 STA R_NDN,Y
 BRA fsg_n
.fsg_k1
 CPX #2
 BCS fsg_k2
 STA R_NDX1,Y           \ n = 1
 LDA #2
 STA R_NDN,Y
 BRA fsg_n
.fsg_k2
 BNE fsg_k3
 STA R_NDX2,Y           \ n = 2
 LDA #3
 STA R_NDN,Y
 BRA fsg_n
.fsg_k3
 CPX #4
 BCS fsg_n              \ n >= 4: full
 STA R_NDX3,Y           \ n = 3
 LDA #4
 STA R_NDN,Y
 BRA fsg_n
.fsg_l
 LDA R_NDP,Y            \ left of the span: flip the starting colour
 EOR #1
 STA R_NDP,Y
.fsg_n
 INY                    \ next row: y++, x += sx * (q + carry of the error)
 BNE P%+5
 INC sg_y+1
 CPY sg_y1              \ done at y1
 BNE fsg_m
 RTS
.fsg_m
 LDA sg_err
 CLC
 ADC sg_r
 STA sg_err
 LDX sg_q
 BCS fsg_m1             \ (err + r can exceed 255 only if dy > 128)
 CMP sg_dy
 BCC fsg_m2
.fsg_m1
 SBC sg_dy
 STA sg_err
 INX
.fsg_m2
 BIT sg_sx              \ N = sign of dx
 BMI fsg_m3
 TXA
 CLC
 ADC sg_x
 STA sg_x
 BCC P%+5
 INC sg_x+1
 JMP fsg_ry
.fsg_m3
 TXA                    \ x - step = x + ~step + 1 (same A, C, V as SBC)
 EOR #&FF
 SEC
 ADC sg_x
 STA sg_x
 BCS P%+5
 DEC sg_x+1
 JMP fsg_ry

.sg_ax  EQUW 0          \ segment end points: ax, ay, bx, by would be
.sg_ay  EQUW 0          \ contiguous with this order for the swap: ax, ay
.sg_bx  EQUW 0
.sg_by  EQUW 0
.fsg_tab
 EQUW R_NDX0, R_NDX1, R_NDX2, R_NDX3
.fsg_t  EQUB 0
.sg_x   EQUW 0
.sg_y   EQUW 0
.sg_y1  EQUW 0
.sg_dx  EQUB 0
.sg_dy  EQUB 0
.sg_sx  EQUB 0
.sg_q   EQUB 0
.sg_r   EQUB 0
.sg_err EQUB 0

\ f_parity: per row, sort the boundaries and set the colour at the left end

.f_parity
 LDY R_NDT
.fpa1
 LDA R_NDN,Y            \ sort up to four (insertion sort by hand)
 CMP #2
 BCC fpa5
 LDA R_NDX0,Y
 CMP R_NDX1,Y
 BCC fpa2
 LDX R_NDX1,Y
 STA R_NDX1,Y
 TXA
 STA R_NDX0,Y
.fpa2
 LDA R_NDN,Y
 CMP #3
 BCC fpa5
 LDA R_NDX1,Y           \ insert X2
 CMP R_NDX2,Y
 BCC fpa3
 LDX R_NDX2,Y
 STA R_NDX2,Y
 TXA
 STA R_NDX1,Y
 LDA R_NDX0,Y
 CMP R_NDX1,Y
 BCC fpa3
 LDX R_NDX1,Y
 STA R_NDX1,Y
 TXA
 STA R_NDX0,Y
.fpa3
 LDA R_NDN,Y
 CMP #4
 BCC fpa5
 LDA R_NDX2,Y           \ insert X3
 CMP R_NDX3,Y
 BCC fpa5
 LDX R_NDX3,Y
 STA R_NDX3,Y
 TXA
 STA R_NDX2,Y
 LDA R_NDX1,Y
 CMP R_NDX2,Y
 BCC fpa5
 LDX R_NDX2,Y
 STA R_NDX2,Y
 TXA
 STA R_NDX1,Y
 LDA R_NDX0,Y
 CMP R_NDX1,Y
 BCC fpa5
 LDX R_NDX1,Y
 STA R_NDX1,Y
 TXA
 STA R_NDX0,Y
.fpa5
.fpa8
 CPY R_NDB
 INY
 BCC P%+3
 RTS
 JMP fpa1

\ ------------------------------------------------------------------------------
\ f_merid: the meridian planet's colour boundaries from the true geometry.
\ Elite draws the visible halves of two great circles, in the planes normal to
\ sidev and roofv; here each is projected exactly instead of via Elite's
\ polylines. For a great circle with normal m (Elite axes, y up, negated if
\ need be so that mz >= 0) and row Ys = y - cy (down), the projected ellipse
\ crosses the row at x = cx + a Ys -/+ sqrt(D), D = K0 - K2 Ys^2, with
\ a = -mx my' / rho2, K0 = r^2 mz^2 / rho2, K2 = mz^2 |m|^2 / rho2^2,
\ my' = -my, rho2 = mx^2 + mz^2. The X- crossing is on the visible hemisphere
\ iff the side function f = m.p is <= 0 at the row's left limb point, X+ iff
\ it is at the right one; along the limb f changes sign only at the circle's
\ nodes (rows cy -/+ w, w = r mx / sqrt(mx^2 + my^2)), so both tests are row
\ comparisons, and the row starts (left limb) on the f > 0 side iff X- is not
\ valid. Colour B where the surface point is on the same side of both planes
\ (as the polyline construction had it). Boundary pixel = ceil(x), with
\ sqrt(D) rounded to the nearest integer.
\ Per circle: constants (planet4.asm PM_HOOK, run from the H_PCURVE hook: a
\ few 16-bit multiplies and divides, once per frame), then rows in pairs
\ cy + k, cy - k from the centre out, with D(k), s(k) = round(sqrt(D(k))) and
\ cx + a k stepped incrementally (planet4.asm PM_MERID, in bank 4 for room:
\ reached through G_MERID).
\ tools/planet_analytic.py (analytic_rows_fixed) models this code exactly.
\ ------------------------------------------------------------------------------

.f_merid
 BIT PM_OK              \ the constants (at PLS22 time)
 BMI fmw0
 JMP f_nobounds
.fmw0
 LDX #3                 \ the centre for bank 4
.fmw1
 LDA F_PLX,X
 STA PM_CX,X
 DEX
 BPL fmw1
 JMP G_MERID

\ ------------------------------------------------------------------------------
\ f_behind: is ship f_si behind the planet, with the first vertex of its first
\ visible face inside the planet's disc? C set if so (don't draw it)
\ ------------------------------------------------------------------------------

.f_behind
 LDA F_PLON
 CMP #1                 \ C clear (not behind) if there is no planet
 BCS P%+3
 RTS
 LDX f_si               \ further away than the planet?
 LDA F_PLZL
 CMP F_SZL,X
 LDA F_PLZH
 SBC F_SZH,X
 BCS fbh8               \ planet z >= ship z: in front
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
 LDY #0                 \ skip this face's list entry (n, 2 colour bytes,
 LDA (fz_p),Y           \ n offsets)
 CLC
 ADC #3
 ADC fz_p
 STA fz_p
 BCC P%+4
 INC fz_p+1
 INC f_f
 JMP fbh1
.fbh2
 LDY #3                 \ XX3 offset of the vertex
 LDA (fz_p),Y
 TAY
 LDA (fz_v3),Y          \ dx = x - planet x (16-bit)
 SEC
 SBC F_PLX
 STA fz_t
 INY
 LDA (fz_v3),Y
 SBC F_PLX+1
 JSR f_abs16            \ -> A = |dx| if < 256, else C set
 BCS fbh8
 STA f_bdx
 INY
 LDA (fz_v3),Y          \ dy = y - planet y
 SEC
 SBC F_PLY
 STA fz_t
 INY
 LDA (fz_v3),Y
 SBC F_PLY+1
 JSR f_abs16
 BCS fbh8
 CMP F_PLR              \ |dy| <= r and |dx| <= half-width(|dy|)?
 BEQ fbh3
 BCS fbh8
.fbh3
 TAX
 LDA F_HW,X
 CMP f_bdx
 BCC fbh8
 SEC
 RTS
.fbh8
 CLC
 RTS

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
