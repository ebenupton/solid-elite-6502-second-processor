\ ******************************************************************************
\
\ ACORNSOFT ELITE DEMONSTRATION DISC DISC IMAGE SCRIPT
\
\ The Acornsoft Elite Demonstration Disc was written by Ian Bell and David
\ Braben and is copyright Acornsoft 1984
\
\ The code in this file is identical to the source discs released on Ian Bell's
\ personal website at http://www.elitehomepage.org/ (it's just been reformatted
\ to be more readable)
\
\ The commentary is copyright Mark Moxon, and any misunderstandings or mistakes
\ in the documentation are entirely my fault
\
\ The terminology and notations used in this commentary are explained at
\ https://elite.bbcelite.com/terminology
\
\ The deep dive articles referred to in this commentary can be found at
\ https://elite.bbcelite.com/deep_dives
\
\ ------------------------------------------------------------------------------
\
\ This source file produces an SSD disc image for the BBC Micro Elite
\ demonstration disc.
\
\ ------------------------------------------------------------------------------
\
\ This source file produces one of the following SSD disc images, depending on
\ which release is being built:
\
\   * elite-demonstration-disc.ssd
\
\ This can be loaded into an emulator or a real BBC Micro.
\
\ ******************************************************************************

 INCLUDE "1-source-files/main-sources/elite-build-options.asm"

 _SOURCE_DISC           = (_VARIANT = 1)
 _TEXT_SOURCES          = (_VARIANT = 2)
 _STH_CASSETTE          = (_VARIANT = 3)

 PUTFILE "1-source-files/boot-files/$.!BOOT.bin", "!BOOT", &FFFFFF, &FFFFFF
 PUTFILE "3-assembled-output/ELITE.bin", "ELTDemo", &FF1100, &FF2000
 PUTFILE "3-assembled-output/ELTcode.bin", "ELTCode", &FF1128, &FF1128
 PUTFILE "3-assembled-output/README.txt", "README", &FFFFFF, &FFFFFF
