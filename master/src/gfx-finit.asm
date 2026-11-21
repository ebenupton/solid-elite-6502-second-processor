\ ******************************************************************************
\
\ gfx-finit.asm - the frame layer's one-off initialisation, F_INIT
\
\ Master port: INCLUDEd by elite-gfx.asm in bank 6's F_SR (the ship records),
\ after the 34 bytes where F_INIT keeps Elite's &06-&27 while the rasteriser's
\ R_INIT uses them: the loader calls it once (G_INIT) before the first frame,
\ and from the first frame on F_SR holds the ship records. (The Tube's
\ parasite: resident, after the frame layer's code, with F_SR in the Tube's
\ workspace, tube/src/p-ws.asm.)
\
\ ******************************************************************************

IF _TPART = 1 AND _TDUMB = FALSE

.F_INIT                 \ (Tube: the rasteriser's state, buffer 0's picture and
 LDA #C_INIT            \ the text map are the host's: tube/src/h-frame.asm)
 JSR ptx
 LDA #0
 STA F_NSHIP
 STA F_NLINE
 STA F_NDOT
 STA F_PLON
 LDX #23+NDSTAR         \ (the parasite's copy of the stars' sizes: R_SS)
.fin1
 STA R_SS,X
 DEX
 BPL fin1
 RTS

ELIF _TPART <> 1

.F_INIT
 LDX #&21               \ R_INIT uses &06-&27: keep Elite's values (in F_SR,
.fin0                   \ before this code)
 LDA &06,X
 STA F_SR,X
 DEX
 BPL fin0
 JSR T_INIT
 LDX #&21
.fin4
 LDA F_SR,X
 STA &06,X
 DEX
 BPL fin4
 LDA #4                 \ Master port: clear main RAM's screen (buffer 0);
 TRB &FE34              \ shadow RAM's (buffer 1, Master's direct-mode screen,
 LDA #&40               \ on show) is cleared by TTX66
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
 LDA #&80               \ no docking slot (F_SLV: f_poly2, f_slot)
 STA F_SLV+16
 LDA #0
 STA F_NSHIP
 STA F_NLINE
 STA F_NDOT
 STA F_PLON
 STA F_DROK              \ (no disc rows kept: f_discspans)
 LDX #NDSTAR-1          \ no stars recorded, no direct-mode stars noted
.fin1
 STA R_SS,X
 STA F_DSS,X
 DEX
 BPL fin1
 RTS                    \ (the text map, F_TCH and f_dlog are all zero, as
                        \ loaded: no text, none shown, none noted)

ENDIF

\ The Tube's parasite (the dumb host): F_INIT is run once, by p_start, from
\ the boot's staging, which loading overlay S overwrites. So its first part,
\ which needs nothing of S, is the boot's ("Area: boot", tube/src/p-layout.asm
\ puts it in the staging): the frame layer's state as the Master port's
\ F_INIT leaves it (no docking slot, no records, no disc rows kept, no
\ stars recorded or noted), which neither loading S nor T_INIT reads; then
\ the resident part, f_init1: overlay S in (the rasteriser is S's), T_INIT
\ with Elite's &06-&27 kept around it, and the host's part (C_INIT: buffer
\ 0 cleared), in the Master port's order

\       Area: boot

IF _TPART = 1 AND _TDUMB

.F_INIT
 LDA #&80               \ no docking slot (F_SLV: f_poly2, f_slot)
 STA F_SLV+16
 LDA #0
 STA F_NSHIP
 STA F_NLINE
 STA F_NDOT
 STA F_PLON
 STA F_DROK              \ (no disc rows kept: f_discspans)
 LDX #NDSTAR-1          \ no stars recorded, no direct-mode stars noted
.fin1
 STA R_SS,X
 STA F_DSS,X
 DEX
 BPL fin1
 JMP f_init1            \ (the text map, F_TCH and f_dlog are all zero, as
                        \ loaded and as p_boot zeroes the workspace: no text,
                        \ none shown, none noted)

ENDIF

\       Area: cache

IF _TPART = 1 AND _TDUMB

.f_init1
 LDA #OVL_S             \ (the rasteriser is in overlay S)
 JSR ovl_need
 LDX #&21               \ R_INIT uses &06-&27: keep Elite's values (in F_SR)
.fin0
 LDA &06,X
 STA F_SR,X
 DEX
 BPL fin0
 JSR T_INIT
 LDX #&21
.fin4
 LDA F_SR,X
 STA &06,X
 DEX
 BPL fin4
 LDA #C_INIT            \ (the host clears buffer 0)
 JMP ptx

ENDIF
