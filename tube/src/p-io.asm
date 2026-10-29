\ ******************************************************************************
\
\ p-io.asm - the parasite's side of the Tube protocol (tube/src/cmds.asm,
\ docs/TUBE-MAP.md): sending commands, the requests, and the frame layer's
\ trampolines into the rasteriser, which here send the rasteriser's inputs to
\ the host instead (each T_xxx keeps A, X and Y: the rasteriser's callers rely
\ on no register it returns, and on Y, R_XL and R_XR after T_MARKDIRTY)
\
\ ******************************************************************************

R_COLE  = &06           \ (gfx-raster.asm's zero page: the rasteriser's inputs,
R_COLO  = &07           \ which the frame layer sets)
R_XL    = &08
R_XR    = &09
R_CL    = &0A
R_CR    = &0B
R_CT    = &0C
R_CB    = &0D
R_DCE   = &0E
R_DCO   = &0F

fl_dx = &10             \ (gfx-flare.asm's zero page: the flare's inputs, which
fl_dy = &11             \ the frame layer's f_flt sets, before gfx-flare.asm)
fl_t  = &0E



\ ptx: send A to the host through register 1, waiting for room. Keeps A, X
\ and Y (and C)

.ptx
 BIT PR1S               \ (a JMP rq_ptx in ring mode: ppring)
 BVC penq
 STA PR1D
 RTS

\ ******************************************************************************
\
\ The ring: the frame's commands buffered on the parasite (docs/TUBE-MAP.md)
\
\ A send that finds register 1 full puts its byte into the ring instead of
\ waiting, and so does every send after it (ring mode) until the ring is empty
\ again: ppring makes ptx's and the send sites' BIT PR1S a JMP to their ring
\ stubs (rq_*), which store the byte at the write pointer. The ring drains
\ into register 1 in the parasite's IRQ (pirq): the host rings its doorbell
\ (any byte through register 1, host to parasite: the Tube's I flag) whenever
\ it finds register 1 empty, and the IRQ sends up to PBN bytes from the ring
\ without checking for room. So the game goes on with its next iteration
\ while the host draws this one's commands, and the stream's order is
\ unchanged. Interrupts are on only in ring mode; the IRQ that empties the
\ ring leaves ring mode and returns with them off, unless it came in on a
\ stub, which is about to store a byte. pflush empties the ring by polling,
\ before the commands that wait for an answer behind the stream (the
\ overlays, the disc commands); p_buf waits for the ring to empty before a
\ frame's C_BUF, so the parasite is never more than a frame ahead.
\
\ Each ring page is written and read downwards, from 255 to 1 (0 is never
\ used): a write pointer with a low byte of 0 is a stub between its DEC and
\ rpg, and means the next page's 255
\
\ ******************************************************************************

RING    = &F400         \ the ring's pages (above both overlays and the boot's
                        \ staging: p-layout.asm asserts it): 4, giving overlay S
                        \ the room for the discs (7 were 0.8% faster in flight
                        \ on the Master host, 11 about 2% faster than 4, 3 were
                        \ 3-6% slower in the beach-ball windows; one stalls)
RINGEND = &F800
rq      = &FA           \ the write pointer (zero page the game leaves free)
rpz     = &FE           \ the IRQ's read pointer (0, the reader's page)
PR1N    = 24            \ register 1's FIFO, parasite to host
PBN     = PR1N - 1      \ bytes sent a doorbell (one spare: a byte ppump sends
                        \ may race a doorbell)

\ penq: a send site found register 1 full (direct mode): A to the host if it
\ has room now, else into the ring, in ring mode. Keeps A, X, Y and C; N, V
\ and Z are not kept, as ptx's BIT

.penq
 SEI
 BIT PR1S
 BVS pq_dir
 PHA
 LDA PR1D               \ (a doorbell from before register 1 filled: stale)
 LDA #&80
 STA rmode
 PHP                    \ (C kept: ppring's CMP)
 JSR ppring
 PLP
 PLA
 STA (rq)
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 RTS
.pq_dir
 STA PR1D               \ (room: straight to the host, interrupts still off)
 RTS

\ The ring stubs: ptx's and each send site's, back to the instruction after
\ the site's STA or STX PR1D. The IRQ never leaves ring mode while the
\ interrupted code is in here (RQ_START to RQ_END)

.RQ_START
.rq_ptx
 STA (rq)
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 RTS
.rq_psb_s0
 STA (rq)
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 JMP psb_s0 + 8
.rq_psb_s1
 STA (rq)
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 JMP psb_s1 + 8
.rq_psb_s2
 STA (rq)
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 JMP psb_s2 + 8
.rq_psb_s3
 STA (rq)
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 JMP psb_s3 + 8
.rq_psb_s4
 STA (rq)
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 JMP psb_s4 + 8
.rq_pem_s0
 PHA
 TXA
 STA (rq)
 PLA
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 JMP pem_s0 + 8
.rq_pem_s1
 STA (rq)
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 JMP pem_s1 + 8
.rq_pem_s2
 PHA
 TXA
 STA (rq)
 PLA
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 JMP pem_s2 + 8
.rq_pem_s3
 STA (rq)
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 JMP pem_s3 + 8
.rq_pem_s4
 STA (rq)
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 JMP pem_s4 + 8
.rq_pem_s5
 STA (rq)
 DEC rq
 BNE P%+5
 JSR rpg
 CLI
 JMP pem_s5 + 8
.RQ_END

\ rpg: a stub's write pointer has left its page: the next page's 255; then
\ wait (the IRQ sending from the ring) while the reader is in that page a lap
\ behind, or in the page after it. Keeps A, X and Y; interrupts off

.rpg
 PHP                    \ (C kept: ptx's callers rely on it)
 SEI
 PHA
 PHY
 LDA #255
 STA rq
 LDA rq+1
 INC A
 CMP #HI(RINGEND)
 BNE rpg1
 LDA #HI(RING)
.rpg1
 STA rq+1
.rpg2
 LDA rph
 SEC
 SBC rq+1
 BEQ rpg4               \ (the same page: wait unless empty)
 CMP #1
 BEQ rpg5
 CMP #LO(1 - (RINGEND - RING) DIV 256)
 BNE rpg6
.rpg5
 JSR pwait
 BRA rpg2
.rpg4
 LDA rpl
 CMP #255
 BNE rpg5
.rpg6
 PLY
 PLA
 PLP
 RTS

\ pwait: with interrupts off, let the doorbell's IRQ in; if a doorbell waits
\ but no IRQ came, the Tube's I flag is off (the MOS's), so send a byte by
\ polling. Clobbers A and Y

.pwait
 CLI
 NOP
 SEI
 BIT PR1S
 BPL pwt9
 JSR ppump
.pwt9
 RTS

\ ppump: with interrupts off, one byte from the ring into register 1 if it
\ has room and the ring has one. Clobbers A and Y; keeps X

.ppump
 BIT PR1S
 BVC ppu9
 JSR pempty
 BEQ ppu9
 LDA rph
 STA ppu1+2
 LDY rpl
.ppu1
 LDA RING,Y             \ (patched: the reader's page)
 STA PR1D
 DEY
 STY rpl
 BNE ppu9
 LDA #255
 STA rpl
 LDA rph
 INC A
 CMP #HI(RINGEND)
 BNE ppu2
 LDA #HI(RING)
.ppu2
 STA rph
.ppu9
 RTS

\ pempty: Z set if the ring is empty (interrupts off: no stub is between its
\ DEC and rpg). Clobbers A

.pempty
 LDA rph
 CMP rq+1
 BNE pem9
 LDA rpl
 CMP rq
.pem9
 RTS

\ pflush: empty the ring into register 1 by polling, then leave ring mode,
\ interrupts off (keeps A, X and Y)

.pflush
 BIT rmode
 BPL pfl9
 PHP                    \ (C kept)
 PHA
 PHY
 SEI
.pfl1
 JSR pempty
 BEQ pfl3
 JSR ppump
 BRA pfl1
.pfl3
 LDA PR1D               \ (a doorbell: stale from now on)
 STZ rmode
 JSR ppdir
 PLY
 PLA
 PLP
 SEI
.pfl9
 RTS

\ pfwait: p_buf's wait (the IRQ sending) until the ring has no byte from
\ before the C_BUF two frames back (fmark2; fmark is the last one's: the
\ write pointer then), so that at most two frames wait in the ring; then this
\ C_BUF's place is the mark. Keeps A, X and Y

.pfwait
 PHP                    \ (C kept)
 PHA
 PHX
 PHY
.pfw1
 SEI
 BIT rmode              \ (the ring empty: nothing from before)
 BPL pfw8
 CLI                    \ (the IRQ sends meanwhile: a reader's place read as it
 LDA rq+1               \ moves only makes this wait a little shorter or longer)
 LDX rq                 \ the writer, the mark and the reader as distances back
 JSR pidx               \ from the writer (bytes, the ring's order)
 STA pfwh
 STX pfwl
 LDA fmark2+1
 LDX fmark2
 JSR pdist
 STA pfmh
 STX pfml
 LDA rph
 LDX rpl
 JSR pdist
 CMP pfmh               \ the reader nearer the writer than the mark: past it
 BCC pfw7
 BNE pfw2
 CPX pfml
 BCC pfw7
.pfw2
 BIT PR1S               \ a doorbell waits, but no IRQ came: the Tube's I flag
 BPL pfw1               \ is off (the MOS's), so send a byte by polling
 SEI
 JSR ppump
 BRA pfw1
.pfw7
 SEI
.pfw8
 LDA fmark
 STA fmark2
 LDA fmark+1
 STA fmark2+1
 LDA rq                 \ the mark: this C_BUF's place
 STA fmark
 LDA rq+1
 STA fmark+1
 PLY
 PLX
 PLA
 PLP
 SEI                    \ (interrupts on in ring mode only)
 BIT rmode
 BPL pfw9
 CLI
.pfw9
 RTS

\ pidx: A = a page, X = a low byte: A X = the place's index in the ring's
\ order (255 bytes a page, each read downwards). pdist: the distance back
\ from the writer's index (pfwh pfwl) to that place, modulo the ring's size

RINGN = (RINGEND - RING) DIV 256 * 255

.pidx
 SEC
 SBC #HI(RING)
 STA pxk
 TXA
 EOR #&FF
 SEC
 SBC pxk
 TAX
 LDA pxk
 SBC #0
 RTS
.pdist
 JSR pidx
 STA pxk
 STX pxl
 LDA pfwl
 SEC
 SBC pxl
 TAX
 LDA pfwh
 SBC pxk
 BCS pds9
 STA pxk
 TXA
 CLC
 ADC #LO(RINGN)
 TAX
 LDA pxk
 ADC #HI(RINGN)
.pds9
 RTS
.pfwh  EQUB 0
.pfwl  EQUB 0
.pfmh  EQUB 0
.pfml  EQUB 0
.pxk   EQUB 0
.pxl   EQUB 0
.fmark EQUB 255, HI(RING)
.fmark2 EQUB 255, HI(RING)

\ ppring, ppdir: ptx's and the send sites' first instruction to a JMP to
\ their ring stubs, or back to BIT PR1S; overlay S's sites only while S is
\ in. Keep X and Y
.ppring
 LDA #&4C
 STA ptx
 LDA #LO(rq_ptx)
 STA ptx+1
 LDA #HI(rq_ptx)
 STA ptx+2
 LDA ovl_cur
 CMP #OVL_S
 BEQ P%+3
 RTS
 LDA #&4C
 STA psb_s0
 STA psb_s1
 STA psb_s2
 STA psb_s3
 STA psb_s4
 STA pem_s0
 STA pem_s1
 STA pem_s2
 STA pem_s3
 STA pem_s4
 STA pem_s5
 LDA #LO(rq_psb_s0)
 STA psb_s0+1
 LDA #HI(rq_psb_s0)
 STA psb_s0+2
 LDA #LO(rq_psb_s1)
 STA psb_s1+1
 LDA #HI(rq_psb_s1)
 STA psb_s1+2
 LDA #LO(rq_psb_s2)
 STA psb_s2+1
 LDA #HI(rq_psb_s2)
 STA psb_s2+2
 LDA #LO(rq_psb_s3)
 STA psb_s3+1
 LDA #HI(rq_psb_s3)
 STA psb_s3+2
 LDA #LO(rq_psb_s4)
 STA psb_s4+1
 LDA #HI(rq_psb_s4)
 STA psb_s4+2
 LDA #LO(rq_pem_s0)
 STA pem_s0+1
 LDA #HI(rq_pem_s0)
 STA pem_s0+2
 LDA #LO(rq_pem_s1)
 STA pem_s1+1
 LDA #HI(rq_pem_s1)
 STA pem_s1+2
 LDA #LO(rq_pem_s2)
 STA pem_s2+1
 LDA #HI(rq_pem_s2)
 STA pem_s2+2
 LDA #LO(rq_pem_s3)
 STA pem_s3+1
 LDA #HI(rq_pem_s3)
 STA pem_s3+2
 LDA #LO(rq_pem_s4)
 STA pem_s4+1
 LDA #HI(rq_pem_s4)
 STA pem_s4+2
 LDA #LO(rq_pem_s5)
 STA pem_s5+1
 LDA #HI(rq_pem_s5)
 STA pem_s5+2
.ppr9
 RTS

.ppdir
 LDA #&2C
 STA ptx
 LDA #LO(PR1S)
 STA ptx+1
 LDA #HI(PR1S)
 STA ptx+2
 LDA ovl_cur
 CMP #OVL_S
 BEQ P%+3
 RTS
 LDA #&2C
 STA psb_s0
 STA psb_s1
 STA psb_s2
 STA psb_s3
 STA psb_s4
 STA pem_s0
 STA pem_s1
 STA pem_s2
 STA pem_s3
 STA pem_s4
 STA pem_s5
 LDA #LO(PR1S)
 STA psb_s0+1
 STA psb_s1+1
 STA psb_s2+1
 STA psb_s3+1
 STA psb_s4+1
 STA pem_s0+1
 STA pem_s1+1
 STA pem_s2+1
 STA pem_s3+1
 STA pem_s4+1
 STA pem_s5+1
 LDA #HI(PR1S)
 STA psb_s0+2
 STA psb_s1+2
 STA psb_s2+2
 STA psb_s3+2
 STA psb_s4+2
 STA pem_s0+2
 STA pem_s1+2
 STA pem_s2+2
 STA pem_s3+2
 STA pem_s4+2
 STA pem_s5+2
.ppd9
 RTS

\ pirq: the parasite's IRQ (BRK: p_crash). The host's doorbell: up to PBN
\ bytes from the ring into register 1, which the doorbell says is empty, in
\ segments (to the writer, or to the end of the reader's page); the doorbell
\ is taken last, so that the host cannot ring again before these bytes reach
\ it. The ring empty: ring mode left, the interrupted code given interrupts
\ off (but for a stub's, which is about to store a byte)

.pirq
 STA pia
 PLA
 PHA
 AND #&10
 BEQ pirq1
 LDA pia                \ (a BRK: a crash)
 JMP p_crash
.pirq1
 STX pix
 STY piy
 BIT rmode
 BMI P%+5
 JMP pir8
 BIT PR1S               \ (no doorbell: register 4's data, should the J flag be
 BMI P%+5               \ on; register 1 full: a stale doorbell)
 JMP pir8b
 BVS P%+5
 JMP pir7
 LDA #PBN
 STA pirm
 STZ rpz
.pir0                   \ a segment: the writer's place (a low byte of 0: the
 LDX rq+1               \ next page's 255)
 LDA rq
 BNE pir1
 INX
 CPX #HI(RINGEND)
 BNE P%+4
 LDX #HI(RING)
 LDA #255
.pir1
 CPX rph
 BNE pir2               \ (the reader a page or more behind: to its page's end)
 STA pirt               \ the same page: rpl - the writer's
 LDA rpl
 SEC
 SBC pirt
 BEQ pir6               \ (empty)
 BRA pir3
.pir2
 LDA rpl
.pir3
 CMP pirm               \ n = the smaller of that and the room left
 BCC P%+5
 LDA pirm
 STA pirt
 LDA pirm
 SEC
 SBC pirt
 STA pirm
 LDA rph
 STA rpz+1
 LDY rpl
 LDA pirt               \ into the unrolled sends, n from their end
 ASL A
 ADC pirt
 ASL A
 EOR #&FF
 SEC
 ADC #LO(pbl_end)
 STA pir4+1
.pir4
 JMP pbl_end            \ (patched: the low byte)
.pirab
 STY rpl
 TYA
 BNE pir5
 LDA #255               \ the page's end: the next page
 STA rpl
 LDA rph
 INC A
 CMP #HI(RINGEND)
 BNE P%+4
 LDA #HI(RING)
 STA rph
.pir5
 LDA pirm
 BNE pir0
.pir7                   \ the doorbell, and return
 LDA PR1D
.pir7b
 LDY piy
 LDX pix
 LDA pia
 RTI
.pir6                   \ the ring empty: direct mode, interrupts off on return,
 TSX                    \ unless a stub was interrupted
 LDA &0103,X
 CMP #HI(RQ_START)
 BCC pir6a
 BNE pir6b
 LDA &0102,X
 CMP #LO(RQ_START)
 BCC pir6a
.pir6b
 LDA &0103,X
 CMP #HI(RQ_END)
 BCC pir7
 BNE pir6a
 LDA &0102,X
 CMP #LO(RQ_END)
 BCC pir7
.pir6a
 STZ rmode
 JSR ppdir
.pir8
 TSX
 LDA &0101,X
 ORA #4
 STA &0101,X
 BRA pir7
.pir8b                  \ (interrupts off on return, ring mode kept: the stubs'
 TSX                    \ CLI turns them on again)
 LDA &0101,X
 ORA #4
 STA &0101,X
 BRA pir7b

.rmode EQUB 0           \ bit 7: ring mode
.rpl   EQUB 255         \ the read pointer
.rph   EQUB HI(RING)
.pirm  EQUB 0
.pirt  EQUB 0
.pia   EQUB 0
.pix   EQUB 0
.piy   EQUB 0
IF HI(P%) <> HI(P% + PBN * 6)
 SKIP &100 - LO(P%)     \ (the unrolled sends in one page: pirq patches a low byte)
ENDIF
.pbl                    \ (pirq's unrolled sends: entered n from the end)
FOR i, 1, PBN
 LDA (rpz),Y
 STA PR1D
 DEY
NEXT
.pbl_end
 JMP pirab
 ASSERT HI(pbl) = HI(pbl_end)

\ preq: send A to the host through register 2, waiting for room: the
\ requests (keys, a key test, the vsync, port B, the star records), which the
\ host answers between commands, ahead of those queued in register 1. Keeps
\ A, X and Y (and C)

.preq
 BIT PR2S
 BVC preq
 STA PR2D
 RTS

\ preq4: A to the host through register 4: the fast I/O requests (C_KEYS,
\ C_DKS and its key, C_IRB), which the host's IRQ answers at once, wherever
\ it is (h4irq, h-main.asm; Model B: hb-res3.asm's irqm), rather than at the
\ command loop's next boundary (tube/proto/PROTO-REPORT.md, branch tubeproto)

.preq4
 BIT PR4S
 BVC preq4
 STA PR4D
 RTS

\ prx: A = the next byte from the host (register 4), waiting for it. Keeps X
\ and Y (and C). (prx4: the game's code calls it so: its own prx is TT151's)

.prx4
.prx
 BIT PR4S
 BPL prx
 LDA PR4D
 RTS

\ ptxv: send the X bytes from (pov),Y... (Y = 0 up): used by the commands that
\ carry a block

MACRO PSEND
 BIT PR1S
 BVC P%-3
 STA PR1D
ENDMACRO

\ p_sync: the end of a main-loop iteration's frame (hframe): a marker for the
\ harness, which hashes the host's screen when the host takes it

.p_sync
 PHA
 LDA #C_SYNC
 JSR ptx
 PLA
 RTS

\ p_buf: the frame's buffer, A (C_BUF): the host waits for the last flip, then
\ draws into it. p_flip: show it at the next vsync (C_FLIP)

.p_buf
 JSR pfwait             \ (the frames before the last two out of the ring)
 PHA
 LDA #C_BUF
 JSR ptx
 PLA
 JMP ptx

.p_flip
 LDA #C_FLIP
 JMP ptx

\ The trampolines into the rasteriser (gfx-tramp.asm in the Master port)

.T_POLY                 \ R_POLY: phase A here (p-polya.asm), the rows to the host
 PHA
 PHX
 PHY
 JSR R_POLY
 PLY
 PLX
 PLA
 RTS

\ The rasteriser's entry points are p-rast.asm's (T_SETBUF ... in the overlay
\ S, which F_FRAME and F_INIT load)


.T_GAME                 \ game code from the frame (gfx-frame.asm's f_proj, the
 STA tgm+1              \ clouds' PTCLS in f_dots): A, X its address, with P
 STX tgm+2              \ kept round it (GPCT) and H_EE31 returning at once
 LDA P                  \ (GPRJ), as the Master port's T_GAME (no banks, no
 STA GPCT               \ ACCCON here)
 DEC GPRJ
.tgm
 JSR &FFFF              \ (patched)
 INC GPRJ
 LDA GPCT
 STA P
 RTS

.T_CAPS                 \ the planet's surface detail's rows (gfx-merid.asm's
 JMP PC_ROWS            \ circle engine, in overlay S)


.T_FLARE                \ the lens flare (gfx-flare.asm), X, Y: this buffer's
 JSR R_FLARE            \ dirty extents' pages; C set: the sun was in sight,
 BCC tfl9               \ and rows Y .. X written (none if Y > X)
 STX tfl_x
 BIT KMODE              \ K mode: the flare's rows are not kept (p-kept.asm)
 BPL tfl1
 PHY
 JSR k_clear
 PLY
.tfl1
 CPY tfl_x              \ the rows written, if any, into the repair's row
 BEQ P%+4               \ range (R_FLARE set R_XL, R_XR)
 BCS tfl9
 JSR R_MARKDIRTY
 LDY tfl_x
 JMP R_MARKDIRTY
.tfl9
 RTS
.tfl_x EQUB 0

\ p_hloin: HLOIN3 (Master's drawing, the host's: C_HLOIN): a line from (X1, Y1)
\ to (X2, Y1) in COL, leaving YSAV, X1, X2 and X as Master's does; keeps Y

.p_hloin
 STY YSAV
 LDX X1
 CPX X2
 BEQ phl9
 BCC phl1
 LDA X2                 \ (X1 on the left)
 STA X1
 STX X2
 TAX
.phl1
 LDA #C_HLOIN
 JSR ptx
 TXA
 JSR ptx
 LDA X2
 JSR ptx
 DEC X2                 \ (as Master's: no pixel at the end)
 LDA Y1
 JSR ptx
 LDA COL
 JSR ptx
 LDA X2
 AND #3
 TAX
.phl9
 RTS

\ p_pixel: PIXEL's drawing (the host's: C_PIXEL): a point at (X, A) sized by
\ ZZ, in COL, leaving T1 and X (x AND 3) as Master's does; keeps Y

.p_pixel
 STY T1
 PHA
 LDA #C_PIXEL
 JSR ptx
 TXA
 JSR ptx
 PLA
 JSR ptx
 LDA ZZ
 JSR ptx
 LDA COL
 JSR ptx
 TXA
 AND #3
 TAX
 RTS

.p_cls                  \ TTX66's screen clear (the direct-mode buffer)
 PHP
 LDA #C_CLS
 JSR ptx
 PLP
 RTS

.p_boxc                 \ BOX's two corners, in COL (A = COL)
 PHP
 PHA
 LDA #C_BOXC
 JSR ptx
 PLA
 JSR ptx
 PLP
 RTS

.p_clyns                \ CLYNS's screen clear (keeps A and the flags)
 PHP
 PHA
 LDA #C_CLYNS
 JSR ptx
 PLA
 PLP
 RTS

\ ******************************************************************************
\
\ The host's hardware: requests and their answers
\
\ ******************************************************************************

\ p_wscan: WSCAN: wait for the host's vertical sync; leaves DL = 72 and A =
\ 72, as WSCAN's loop leaves them (the IRQ's LINSCN sets DL to VSCAN+1)

.p_wscan
 LDA #C_WSCAN           \ (register 4: the host's IRQ marks it pending, its next
 JSR preq4              \ vsync interrupt answers it)
 JSR prx
 LDA #72
 STA DL
 RTS

\ p_noise: NOISE: send sound Y (and DNOIZ) to the host, which makes it with its
\ own sound buffers and IRQ, then free every channel here, so that NOISE goes
\ on as the harness makes the original (docs/TUBE-MAP.md): keeps X and Y

.p_noise                \ (register 4: made at once by the host's IRQ, never
 LDA #C_NOISE           \ behind the drawing)
 JSR preq4
 TYA
 JSR preq4
 LDA DNOIZ
 JSR preq4
 STZ SOPR
 STZ SOPR+1
 STZ SOPR+2
 RTS

.p_soflush
 LDA #C_SOFLUSH
 JMP preq4

\ p_det1: DET1: 6845 R6 = X; returns as DET1 (A = 6)

.p_det1
 LDA #C_DET1
 JSR ptx
 TXA
 JSR ptx
 LDA #6
 RTS

\ p_irb: A = the host's System VIA port B (the joystick's fire button)

.p_irb
 LDA #C_IRB
 JSR preq4
 JMP prx

\ p_dks: DKS5: X = key A, with bit 7 set if the host has it held. Keeps Y and C

.p_dks                  \ (A is kept: the harness reads the key there)
 PHA
 LDA #C_DKS
 JSR preq4
 PLA
 JSR preq4
 PHA
 JSR prx
 TAX
 PLA
 RTS

\ p_fillkl: FILLKL after ZEKTRAN (X = 0): the host sends the keys held, in
\ increasing internal number from 16 up, then 0; each updates the key logger
\ through IKNS as Rd2 does, and KL holds the last. Returns as FILLKL: A = KY6
\ (after Rd7's TRB), X = KL with N and Z from it, C set if no key was held,
\ D clear

.p_fillkl
 LDA #C_KEYS
 JSR preq4
 LDA #1
 STA pfkn
.pfk1
 JSR prx
 BEQ pfk9
 STZ pfkn
 STA KL
.pfk2
 CMP IKNS,X
 BCC pfk1
 BEQ pfk3
 INX
 BNE pfk2
.pfk3
 DEC KY17,X
 INX
 BNE pfk1
.pfk9
 CLD
 LDA pfkn
 LSR A
 LDA KY6
 TRB KY19
 LDX KL
 RTS
.pfkn EQUB 0

\       Area: ovl D

\ p_oscli: DOSCLI (the disc commands, Y X = the command, CR-ended): C_DISC,
\ the host's MOS runs it as the host's own I/O (h_disc, h-cold.asm): the
\ printing's context (QQ11 OR GFORCE, GMODE, CHPR's zero page, W, CATF), the
\ mode (1 SAVE, 2 LOAD, else 0) with, for those, commbuf's 256 bytes (the
\ host saves from and loads into its buffer at &3F00, which savosc and lodosc
\ name), then the command. The host answers through register 4: 0, or &FF
\ and the error's number, message and 0 (then NEWBRK prints it, as after the
\ MOS's BRK); then the printing's context back, and for a load commbuf. As
\ DOSCLI: GSTASH is set (the Master port's next space-mode frame clears
\ buffer 0, which the host's disc command may use)

PCTX = &0A              \ CHPR's zero page: SC, SCH, P(4), XC, COL, YC, QQ17, K3, K3+1
PCTXN = 12
\ (the error block: R_NDX3, free outside space mode)
pov = &FC                \ (the command's pointer: zero page the game leaves free;
                        \ &FD is NEWBRK's too, set after the last use of pov)

.p_oscli
 JSR pflush             \ (the ring sent first: the answer comes after it)
 STX pov
 STY pov+1
 LDA #&80
 STA GSTASH
 LDA #C_DISC
 JSR ptx
 LDA QQ11
 ORA GFORCE
 JSR ptx
 LDA GMODE
 JSR ptx
 LDX #0
.pos1
 LDA PCTX,X
 JSR ptx
 INX
 CPX #PCTXN
 BNE pos1
 LDA W
 JSR ptx
 LDA CATF
 JSR ptx
 LDY #0                 \ the mode: SAVE 1, LOAD 2, else 0
 LDA (pov),Y
 LDX #1
 CMP #'S'
 BEQ pos2
 INX
 CMP #'L'
 BEQ pos2
 LDX #0
.pos2
 STX pdm
 TXA
 JSR ptx
 LDA pdm
 BEQ pos4
 LDY #0                 \ commbuf
.pos3
 LDA commbuf,Y
 JSR ptx
 INY
 BNE pos3
.pos4
 LDY #0                 \ the command, to its CR
.pos5
 LDA (pov),Y
 JSR ptx
 INY
 CMP #13
 BNE pos5
 JSR prx                \ 0, or &FF: an error
 STA pdst
 BEQ pos7
 LDY #0                 \ the error's number, message and 0, into R_NDX3
.pos6
 JSR prx
 STA R_NDX3,Y
 INY
 CMP #0
 BNE pos6
 CPY #1                 \ (the number byte itself may be 0)
 BEQ pos6
.pos7
 LDX #0                 \ the printing's context back
.pos8
 JSR prx
 STA PCTX,X
 INX
 CPX #PCTXN
 BNE pos8
 JSR prx
 STA W
 JSR prx
 STA CATF
 LDA pdm                \ a load: commbuf back (as the host's buffer is, also
 CMP #2                 \ after an error)
 BNE pos10
 LDY #0
.pos9
 JSR prx
 STA commbuf,Y
 INY
 BNE pos9
.pos10
 LDA pdst
 BNE pos11
 RTS
.pos11
 LDA #LO(R_NDX3)         \ the error: as the MOS's BRK leaves it, (&FD) at the
 STA &FD                \ number, the message after it
 LDA #HI(R_NDX3)
 STA &FE
 JMP NEWBRK

\       Area: frame

\ p_dosnmi: NEWBRK's DOSNMI: nothing to do (the host is back in its command
\ loop already). Keeps A and the flags

.p_dosnmi
 RTS

.pdm  EQUB 0
.pdst EQUB 0

.T1SYNC                 \ (BEGIN's: the host's, at its start)
 RTS

.TTX66M                 \ (CHPR's call of TTX66: no banks here)
 JMP TTX66



\ p_start: the parasite's entry (the loader starts it through the client
\ OS's Tube code, its only use): the boot (p_boot, in the staging area above
\ overlay D, p-layout.asm) takes the parasite's memory over, then wakes the
\ host's command loop with &FE (the host's WRCHV, as the MOS's Tube code
\ passes the byte to OSWRCH), then the renderer's initialisation (G_INIT,
\ as the Master port's loader calls it) and the game (S%)

.p_start
 SEI
 CLD
 LDX #&FF
 TXS
 JSR p_boot
 LDA #255               \ (the ring's write pointer: rpl, rph's start)
 STA rq
 LDA #HI(RING)
 STA rq+1
 LDA #&FE
 JSR ptx
 JSR G_INIT
 JMP S%
