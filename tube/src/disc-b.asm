\ disc-b.asm - the Tube version's disc for a Model B host with 64K of sideways
\ RAM (tube/src/loader-b.asm; SHIFT+BREAK)
 PUTFILE "build/LOADB.bin", "ELITE", &FF1900, &FF1900 + (ENTRY_B - &1900)
 PUTFILE "build/BDATA.unprot.bin", "BDATA", &000000, &000000
 PUTFILE "build/HBD.bin", "HBD", &000000, &000000
 PUTFILE "build/HBP.bin", "HBP", &000000, &000000
 PUTFILE "build/HBF.bin", "HBF", &000000, &000000
 PUTFILE "build/HBS.bin", "HBS", &000000, &000000
 PUTFILE "build/HBE.bin", "HBE", &000000, &000000
 PUTFILE "build/PCODE.bin", "PCODE", &001500, &001500
