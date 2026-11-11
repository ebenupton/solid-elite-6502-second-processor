\ ******************************************************************************
\
\ disc.asm - the Tube version's disc (tube/build.sh): one disc for a BBC
\ Master host and a BBC Micro Model B host with 64K of sideways RAM, each
\ with a 6502 Second Processor. SHIFT+BREAK: !BOOT runs ELITE
\ (tube/src/boot.asm), which runs the host's loader, ELITEM or ELITEB. The
\ parasite's code (PCODE) and the dashboard's image (BDATA) are the same
\ files for both hosts; the Master host's images are packed
\ (tube/tools/zpack.py).
\
\ The files in the order the loaders read them, so that each host's reads
\ run on through the disc with one seek forward: the Master's loader reads
\ its images, BDATA, then (over the Model B's images) PCODE and HMAIN; the
\ Model B's reads BDATA (past the Master's images), its images, then PCODE.
\
\ ******************************************************************************

 PUTFILE "build/BOOT.bin", "ELITE", &FF0900, &FF0900
 PUTFILE "build/M128Elt.bin", "ELITEM", &FF0E00, &FF0E55
 PUTFILE "build/LOADB.bin", "ELITEB", &FF1900, &FF1900 + (ENTRY_B - &1900)
\ the Master host's images (tube/src/loader.asm's FTAB)
 PUTFILE "build/HRASTA.pk", "HRASTA", &000000, &000000
 PUTFILE "build/HBANK5.pk", "HBANK5", &000000, &000000
 PUTFILE "build/HBANK6.pk", "HBANK6", &000000, &000000
 PUTFILE "build/HSTB7.pk", "HSTB7", &000000, &000000
 PUTFILE "build/HSTB4.pk", "HSTB4", &000000, &000000
 PUTFILE "build/HSTZ.pk", "HSTZ", &000000, &000000
 PUTFILE "build/HSTM2.pk", "HSTM2", &000000, &000000
 PUTFILE "build/HSTM1.pk", "HSTM1", &000000, &000000
\ both hosts' dashboard
 PUTFILE "build/BDATA.unprot.bin", "BDATA", &000000, &000000
\ the Model B host's images (tube/src/loader-b.asm's FTAB)
 PUTFILE "build/HBD.bin", "HBD", &000000, &000000
 PUTFILE "build/HBP.bin", "HBP", &000000, &000000
 PUTFILE "build/HBF.bin", "HBF", &000000, &000000
 PUTFILE "build/HBS.bin", "HBS", &000000, &000000
 PUTFILE "build/HBE.bin", "HBE", &000000, &000000
\ both hosts' parasite code, then the Master host's main RAM code
 PUTFILE "build/PCODE.bin", "PCODE", &001400, &001400
 PUTFILE "build/HMAIN.bin", "HMAIN", &FF0000 + HMAINAT, &FF0000 + HMAINAT
