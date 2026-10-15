\ ******************************************************************************
\
\ ELITE DEMONSTRATION DISC, BBC MASTER PORT: DISC IMAGE SCRIPT
\
\ Builds build/elite-master.ssd from the assembled binaries (run by build.sh
\ with -do build/elite-master.ssd -boot ELITE -opt 3, so !BOOT does *RUN ELITE)
\
\ ******************************************************************************

 PUTFILE "build/ELITE.bin", "ELITE", &FF1100, &FF1100
 PUTFILE "build/WORDS9.bin", "WORDS9", &FF0400, &FF0400
 PUTFILE "build/ELTMAIN.bin", "ELTMAIN", &FF0F40, &FF0F40
 PUTFILE "build/ELTBANK.bin", "ELTBANK", &FF8000, &FF8000
 PUTFILE "build/DIALS1.bin", "DIALS", &FF7000, &FF7000
 PUTFILE "build/BANK5.bin", "BANK5", &FF8000, &FF8000
 PUTFILE "build/BANK6.bin", "BANK6", &FF8000, &FF8000
 PUTFILE "build/BANK7.bin", "BANK7", &FF8000, &FF8000
