\ ******************************************************************************
\
\ disc.asm - the Tube version's disc (tube/build.sh): one disc for a BBC
\ Master host and a BBC Micro Model B host with 64K of sideways RAM, each
\ with a 6502 Second Processor. SHIFT+BREAK: !BOOT runs ELITE
\ (tube/src/boot.asm), which runs the host's loader, ELITEM or ELITEB. The
\ parasite's code (PCODE), the dashboard's image (BDATA) and overlay D's and
\ S's stored images (HOVD, HOVS) are the same files for both hosts. The
\ Master host's own are its code in bank 7 (HCODE) and HMAIN (CHPR's font,
\ then the kernel); the Model B host's its span kernel (HBK), its code bank's
\ image (HBC) and its persistent block (HBE). All are plain images.
\
\ The files in the order the loaders read them, so that each host's reads
\ run on through the disc, skipping only forward: the Master's loader reads
\ HOVD, HCODE, HOVS, BDATA, then (past the Model B's files) HMAIN and PCODE;
\ the Model B's reads HOVD, HOVS, BDATA, its own files, then PCODE.
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
\ the Model B host's own files (tube/src/loader-b.asm's FTAB): bank 4's span
\ kernel, bank 7's image, the persistent block at &7E00
 PUTFILE "build/HBK.bin", "HBK", &000000, &000000
 PUTFILE "build/HBC.bin", "HBC", &000000, &000000
 PUTFILE "build/HBE.bin", "HBE", &000000, &000000
\ the Master host's main RAM, then both hosts' parasite code
 PUTFILE "build/HMAIN.bin", "HMAIN", &FF0000 + HFONTST, &FF0000 + HMAINAT
 PUTFILE "build/PCODE.bin", "PCODE", &001400, &001400
