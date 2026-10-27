\ ******************************************************************************
\
\ disc.asm - the Tube version's disc (tube/build.sh): SHIFT+BREAK runs the
\ host's loader (ELITE), which loads the host's images and the parasite's
\ code and starts both
\
\ ******************************************************************************

 PUTFILE "build/M128Elt.bin", "ELITE", &FF0E00, &FF0E55
 PUTFILE "build/BDATA.unprot.bin", "BDATA", &000000, &000000
 PUTFILE "build/HRASTA.bin", "HRASTA", &000000, &000000
 PUTFILE "build/HBANK5.bin", "HBANK5", &000000, &000000
 PUTFILE "build/HBANK6.bin", "HBANK6", &000000, &000000
 PUTFILE "build/HSTZ.bin", "HSTZ", &000000, &000000
 PUTFILE "build/HSTM2.bin", "HSTM2", &000000, &000000
 PUTFILE "build/HSTM1.bin", "HSTM1", &000000, &000000
 PUTFILE "build/HSTB7.bin", "HSTB7", &000000, &000000
 PUTFILE "build/HMAIN.bin", "HMAIN", &FF1EDC, &FF1EDC
 PUTFILE "build/PCODE.bin", "PCODE", &001400, &001400
