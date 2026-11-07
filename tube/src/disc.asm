\ ******************************************************************************
\
\ disc.asm - the Tube version's disc (tube/build.sh): SHIFT+BREAK runs the
\ host's loader (ELITE), which loads the host's images and the parasite's
\ code and starts both
\
\ ******************************************************************************

 PUTFILE "build/M128Elt.bin", "ELITE", &FF0E00, &FF0E55
 PUTFILE "build/HRASTA.pk", "HRASTA", &000000, &000000
 PUTFILE "build/HBANK5.pk", "HBANK5", &000000, &000000
 PUTFILE "build/HBANK6.pk", "HBANK6", &000000, &000000
 PUTFILE "build/HSTB7.pk", "HSTB7", &000000, &000000
 PUTFILE "build/HSTB4.pk", "HSTB4", &000000, &000000
 PUTFILE "build/HSTZ.pk", "HSTZ", &000000, &000000
 PUTFILE "build/HSTM2.pk", "HSTM2", &000000, &000000
 PUTFILE "build/HSTM1.pk", "HSTM1", &000000, &000000
 PUTFILE "build/BDATA.unprot.bin", "BDATA", &000000, &000000
 PUTFILE "build/PCODE.bin", "PCODE", &001400, &001400
 PUTFILE "build/HMAIN.bin", "HMAIN", &FF1EDC, &FF1EDC
