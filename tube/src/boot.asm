\ ******************************************************************************
\
\ boot.asm - the disc's first program (tube/src/disc.asm: !BOOT
\ runs ELITE): which host is this? OSBYTE 0 gives the MOS's version, 3 or more
\ on a BBC Master (MOS 3.20 and 3.50; 4 the Master ET, 5 the Compact), less on
\ a BBC Micro (1 the Model B's MOS 1.20, 2 the B+'s). It runs the host's own
\ loader: ELITEM (tube/src/loader.asm, the Master host) or ELITEB
\ (tube/src/loader-b.asm, the Model B host with 64K of sideways RAM), each of
\ which checks for the 6502 Second Processor and the sideways RAM it needs,
\ and stops with a message if either is missing. NMOS code, at &0900 (the
\ cassette and RS423 buffers): below both loaders (&2700, &1900) and the
\ pages they load files through.
\
\ ******************************************************************************

 CPU 0
OSBYTE = &FFF4
OSCLI = &FFF7

 ORG &0900
.ENTRY
 LDA #0                 \ X = the MOS's version (OSBYTE 0 with X non-zero)
 LDX #1
 JSR OSBYTE
 CPX #3
 LDX #LO(RUNM)          \ (X, Y and the carry are kept by the loads)
 LDY #HI(RUNM)
 BCS P%+6
 LDX #LO(RUNB)
 LDY #HI(RUNB)
 JMP OSCLI              \ *RUN the loader, which never returns

.RUNM EQUS "RUN ELITEM" : EQUB 13
.RUNB EQUS "RUN ELITEB" : EQUB 13
.BEND
 PRINT "Common disc's boot: &0900-&", ~BEND-1
 SAVE "build/BOOT.bin", &0900, BEND, ENTRY
