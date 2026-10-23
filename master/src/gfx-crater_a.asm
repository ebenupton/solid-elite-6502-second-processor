\ gfx-crater_a.asm - the crater curves' recorded points (F_PCURVE, F_PPOINT)
\ (included by gfx-frame.asm; on the Tube parasite, see the IFs there)

MAXCV = 3               \ curves per frame
MAXPT = 40              \ points per frame: PLS22's step STP is at least 2
                        \ (CIRCLE's PL89), so a crater's full ellipse has at
                        \ most 33 points and the meridian and equator's half
                        \ ellipses 17 each; a point past the end is dropped

                        \ F_NCV (curves recorded this frame) and F_NPT
                        \ (points recorded this frame) live in F_PPOINT's
                        \ LDA #/LDY # operands
.F_CVS SKIP MAXCV       \ first point of each curve
.F_CVE SKIP MAXCV       \ one past its last point
.F_CVT SKIP MAXCV       \ TGT: 31 (half ellipse) or 64 (full)
.F_PXL SKIP MAXPT
.F_PXH SKIP MAXPT
.F_PYL SKIP MAXPT
.F_PYH SKIP MAXPT

IF _TPART = 1            \ (Tube: F_NCV and F_NPT are bytes, as F_PPOINT is in
.F_NCV EQUB 0           \ overlay S's crater tail, which f_reset must not write)
.F_NPT EQUB 0
ENDIF

