\ ******************************************************************************
\
\ disc.asm - the Tube version's disc (tube/build.sh): one disc for a BBC
\ Master host and a BBC Micro Model B host with 64K of sideways RAM, each
\ with a 6502 Second Processor. SHIFT+BREAK: !BOOT runs ELITE
\ (tube/src/boot.asm), which runs the host's loader, ELITEM or ELITEB. The
\ parasite's code (PCODE) and the dashboard's image (BDATA) are the same
\ files for both hosts. The Master host's files are plain images: overlay
\ D's and S's stored images (HOVD, HOVS), the host's code in bank 7 (HCODE),
\ and HMAIN: CHPR's font, then the kernel.
\
\ The files in the order the loaders read them, so that each host's reads
\ run on through the disc with one seek forward: the Master's loader reads
\ HOVD, HCODE, HOVS, BDATA, then (past the Model B's images) HMAIN and
\ PCODE; the Model B's reads BDATA (past the Master's files), its images,
\ then PCODE.
\
\ ******************************************************************************

 PUTFILE "build/BOOT.bin", "ELITE", &FF0900, &FF0900
 PUTFILE "build/M128Elt.bin", "ELITEM", &FF0000 + LOAD_M, &FF0000 + ENTRY_M
 PUTFILE "build/LOADB.bin", "ELITEB", &FF1900, &FF1900 + (ENTRY_B - &1900)
\ the Master host's files (tube/src/loader.asm: LDD, then FTAB)
 PUTFILE "build/HOVD.bin", "HOVD", &000000, &000000
 PUTFILE "build/HCODE.bin", "HCODE", &FF0000 + B7AT, &FF0000 + B7AT
 PUTFILE "build/HOVSK.bin", "HOVS", &000000, &000000
\ both hosts' dashboard
 PUTFILE "build/BDATA.unprot.bin", "BDATA", &000000, &000000
\ the Model B host's images (tube/src/loader-b.asm's FTAB)
 PUTFILE "build/HBD.bin", "HBD", &000000, &000000
 PUTFILE "build/HBP.bin", "HBP", &000000, &000000
 PUTFILE "build/HBF.bin", "HBF", &000000, &000000
 PUTFILE "build/HBS.bin", "HBS", &000000, &000000
 PUTFILE "build/HBE.bin", "HBE", &000000, &000000
\ the Master host's main RAM, then both hosts' parasite code
 PUTFILE "build/HMAIN.bin", "HMAIN", &FF0000 + HFONTST, &FF0000 + HMAINAT
 PUTFILE "build/PCODE.bin", "PCODE", &001400, &001400
