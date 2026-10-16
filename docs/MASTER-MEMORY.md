# Spare memory on the BBC Master 128 (MOS 3.20, DFS 2.24) for full Master Elite

Experiments ran in jsbeeb headless (MachineSession, model "Master" = MOS 3.20 with the
1770 DFS 2.24 in bank 9), with a blank formatted SSD in drive 0. Tracing hooked
every CPU read and write and mapped it to jsbeeb's physical RAM array (main
0000-7FFF, ANDY 8000-8FFF, HAZEL 9000-AFFF = &C000-&DFFF, LYNNE/shadow
B000-FFFF = &3000-&7FFF). That records which code (MOS, ROM bank or RAM) touched
which byte, and whether the first access was a read (state kept from earlier) or
a write. Code addresses below are from the MOS 3.20 image (jsbeeb
`public/roms/master/mos3.20` and its `mos.txt` disassembly; bank 9 = DFS 2.24
with SRAM 1.04, bank F = TERMINAL plus the MOS extension code).

Test driver: a small 6502 program at &2000 (OSCLI `CAT`, `SAVE JAMESON 3000 +100 0 0`,
`LOAD JAMESON 4100`, `DELETE`, `DIR`, `DISC`, OSFILE save and load, a batch of
OSBYTEs (&00, &04, &0F, &15, &79, &80, &81, &83, &84, &A1, &B4, &C8, &DA), OSWORD 1/7/8,
an IRQ-only busy loop with keys pressed, and a private WRCHV that writes output to a
RAM buffer as Elite's CHPR does. Verdicts check the disc image itself (catalogue
and file contents, through jsbeeb's `toSsdOrDsd`), not only the screen output.

Short answer:

| Region | Usable by the port? | Bytes |
|---|---|---|
| ANDY &8000-&8FFF | Yes, all of it, if the MOS VDU is never used (Elite's own WRCHV) and soft keys are not expanded (Master Elite sets *FX 225,128). Disc I/O through OSCLI/OSFILE never touches it. | 4096 |
| HAZEL &C000-&DFFF | Yes, all of it during flight. For disc I/O, keep 66 bytes (stash them or never write them), poke 6 bytes to &FF before each call, and rebuild what DFS/MOS overwrite (mainly &C000-&C2FF). | 8192, of which 66 need care |
| Shadow &3000-&3FFF | Yes (ACCCON X=1). Master Elite already uses shadow &3090-&30FF for its zero-page save. | 4096 (3984 if the zp buffer stays) |
| Shadow &7E00-&7FFF | Yes, if not displayed. | 512 |
| Main &0B00-&0CFF | Yes. Nothing in MOS 3.20 or DFS uses it (the B's soft keys and font moved to ANDY). | 512 |
| Main &0900-&0AFF | Yes, if RS423, cassette and speech are not used. | 512 |
| Main &0840-&08FF | Yes, if MOS SOUND, ENVELOPE and printer are not used. | 192 |
| Main &0800-&083F, &03E0-&03FF | Only while the MOS IRQ code never runs. Master Elite's IRQ1V handler never passes interrupts on. | 64 + 32 |
| Main &0D00-&0DFF | **No, never** (see "Page &0D is off limits" below): the 1770 DFS NMI routine, extended vectors, ROM workspace table | 0 |
| Main &0300-&03DF | Only if the MOS VDU and the cassette/ROM filing systems are never used again. | 224 |

---

## 1. ANDY (&8000-&8FFF, ROMSEL bit 7)

### What MOS 3.20 keeps there

| Range | Contents | Written | Read |
|---|---|---|---|
| &8000-&8021 | Soft-key pointer table (17 start-offset bytes, then 17 more; initialised at MOS &F124-&F131) | `*KEY` (bank F &95xx), hard reset | `*KEY`, `*SHOW`, soft-key expansion when the input buffer is read (MOS &EB45-&EB59) |
| &8022-&83FF | Soft-key text | `*KEY` | expansion, `*SHOW` |
| &8400-&87FF | Graphics extension workspace: the flood-fill queue (4 bytes per entry spread over 4 pages, MOS &DC2C-&DC43) and some PLOT temporaries (&873C, &8744) | flood fill (PLOT &80-&87) | same |
| &8800-&882F | ECF patterns and current colour patterns | every MODE change (MOS &CF80/&CF83), GCOL (&C5A4/&C5B5) | PLOT, line drawing (&DA82) |
| &8830-&884F | VDU graphics temporaries (MOS &D2D5-&D6xx) | PLOT, DRAW, circles and so on | same |
| &8850-&88FF | Not referenced by the MOS | - | - |
| &8900-&8FFF | The full "exploded" font, characters &20-&FF, 8 bytes each (`A` at &8A08 = 3C 66 66 7E 66 66 66 00) | hard reset (copy from ROM), VDU 23,n, OSBYTE 20 (resets &20-&7F, measured 768 bytes), OSBYTE 25,0 (resets all 1792) | every character the MOS prints in a graphics mode (MOS &CE5A/&CE68), OSWORD 10. Not read in MODE 7. |

Sideways RAM/ROM metadata is **not** in ANDY. The ROM type table is at &02A1-&02B0
and the private-workspace table at &0DF0-&0DFF (main RAM). The SRAM utilities' state
(`*SRDATA`/`*SRROM`) is in DFS's private HAZEL page (&DAEE-&DAFD), with the transfer
buffer and code at &DB00-&DBFF. `*INSERT`/`*UNPLUG` state is in CMOS.

### Traces (accesses to ANDY per operation)

* `*CAT`, `SAVE`, `LOAD`, `DELETE`, `DIR`, `DRIVE`, `DISC`, OSFILE save/load, all the
  OSBYTEs above, OSWORD 1/7/8, `*ROMS`, `*SRWRITE`, `*SRREAD`, `*SRLOAD`, `*SRDATA`,
  `*INFO`, `*EX`, `*ACCESS`, `*STATUS`, `*TIME`, `*FX`, and 1.3 s of IRQs with keys
  pressed: **no ANDY accesses at all** (apart from font reads when the MOS echoed
  characters in MODE 1).
* `MODE n`: writes &8800-&882F. PRINT in MODE 1: reads the font. `VDU 23,65,...`:
  writes &8A08-&8A0F. Flood fill (`PLOT 133`): reads and writes &8400-&87FF.
  `*KEY 1 HELLO`: reads &8001-&8021 and writes &8022-&8026.

### Reverse tests (corrupting ANDY)

* All 4K filled with garbage, then SAVE, LOAD, CAT, OSFILE save and load, DELETE,
  OSBYTEs, OSWORDs and an IRQ loop with the private WRCHV: every operation worked,
  the disc image was correct, and **0 of the 4096 bytes changed**.
* With the MOS VDU in use: MODE 1 text prints as garbage (screenshot). Soft BREAK does
  **not** repair the font, soft keys or ECF patterns. CTRL-BREAK, or BREAK after
  `*FX 200,2`, restores all of them (1792/1792 font bytes; soft-key table reset).
  `*FX 25,0` restores the whole font. `*FX 20` restores only &20-&7F.
* Paging: with &F4 = &86 and &FE30 = &86 (ANDY over bank 6), ANDY stayed paged in
  across OSCLI SAVE, OSFILE load, OSBYTE &81 and 1.3 s of IRQs. The MOS restores
  ROMSEL from &F4 with bit 7 intact. Always write bit 7 to both &F4 and &FE30.
  If &F4 lacks bit 7, the first paged-ROM call silently unpages ANDY.

### Which ranges are safe

* (a) The program never calls OSWRCH through the MOS VDU: all of &8000-&8FFF.
  Exceptions: don't call OSWORD 9/10/13, OSBYTE 20/25, `*KEY` or `*SHOW`, and don't let
  the MOS expand soft keys. Master Elite's loader already sets `*FX 225,128`, so
  function keys give plain codes, and the game never reads the input buffer through
  the MOS.
* (b) It also does disc I/O through OSFILE/OSCLI (and the sound/clock OSWORDs) with its
  own WRCHV: still all of &8000-&8FFF (measured: 0 bytes changed, all I/O correct).
* Caveats: ANDY hides the first 4K of whichever sideways bank is paged, so code in
  bank N at &8000-&8FFF can't run or be read while ANDY is in.
  Master Elite sets `*FX 200,1`, so a BREAK during the game is a soft BREAK, and the MOS
  would afterwards print with a garbage font and soft-key table. If the port uses ANDY,
  set `*FX 200,3` (memory cleared on BREAK, which rebuilds ANDY), or run OSBYTE 25,0
  and reset the soft keys on exit.

## 2. HAZEL (&C000-&DFFF) and DFS

### Layout found after boot and DFS use

| Range | Owner | Contents and behaviour |
|---|---|---|
| &C000-&C1FF | DFS static | Catalogue cache (sectors 0 and 1 of the current drive) |
| &C200-&C27F | DFS static | Transient: filename/pathname buffers (&C200-&C23F, &C260-&C27B) |
| &C280-&C2BF | DFS static | Drive state: &C282 = drive whose catalogue is cached, &C287 = "restore drive" flags, &C288/&C289 and &C28B-&C28E = track-position cache, &C290-&C29E = transfer parameters |
| &C2C0-&C2FF | DFS static, **persistent** | Current drive, directory and library (&C2C9-&C2CC), drive density/step settings (&C2DC-&C2DF), NMI claim count (&C2D3), Tube flag (&C2D6), options |
| &C300-&C3BF | DFS static | Open-file channel table (copied to the private page on FS switch) |
| &C3C0-&D8FF | DFS static | Not touched by any test (no files open via OSFIND) |
| &D900-&D9FF | ADFS private page (&0DFD = &D9) | ADFS's saved state |
| &DA00-&DAFF | DFS private page (&0DF9 = &DA) | Copy of &C2C0-&C2ED and &C300-&C3BF saved on FS switch (DFS &8917-&893E); SRAM utility state &DAEE-&DAFD |
| &DB00-&DBFF | DFS/SRAM | `*SRLOAD` sector buffer and a small paging stub at &DB00 |
| &DC00-&DCFF | MOS | OSCLI copies the command line here (MOS &E80D) |
| &DD00-&DEFF | ? | No code references; untouched by every test |
| &DF00-&DF05 | MOS | Current and temporary FS numbers and so on; written during *commands |
| &DF06-&DF47 | MOS | Filing-system name table (CFS, TAPE, ROM, ADFS, DISK, DISC), used for `-FS-` prefixes and `*SRLOAD` |
| &DFC2-&DFDE | MOS (bank F) | &DFC6 = flag shifted on every FSC (MOS &FB6D); **&DFDA/&DFDB = the real FSCV of the current FS** (MOS &EE4C-&EE55 saves FSCV here and points &21E at &FB69, which does `JMP (&DFDA)`); &DFD4-&DFDD read by `*SHOW` |

Bytes DFS/MOS write during ordinary disc I/O (SAVE, LOAD, CAT, DELETE, DIR,
DRIVE, OSFILE): &C000-&C1FF, &C200-&C27B, &C282-&C29E, &C2C0-&C2DC, &DC00 to the end of
the command line, &DF00-&DF05 and &DFC6. `*DISC` or an FS select also writes
&C2C0-&C3BF, &DA00-&DAED, &DF03 and &DFDA/B. `*SRLOAD` also writes &C320-&C33F and
&DB00-&DBFF.

The MOS never touches HAZEL during flight: in the IRQ-only loop with keys
pressed there were no HAZEL (or ANDY, or shadow) accesses.

### Which bytes must persist between calls (clobber experiments)

After a realistic warm-up (OSFILE save, OSCLI save, CAT), ranges were filled with
random bytes, &00 or &FF. Then SAVE (new contents), LOAD and CAT ran, and the
disc image was checked:

| Clobbered | Result |
|---|---|
| all &C000-&DFFF | fails ("Channel" error, nothing saved) |
| &DF00-&DFFF | fails: **&DFDA-&DFDB** (FSCV copy) is the essential pair; &DF00-&DF47, &DFC6 alone are harmless for these operations |
| &C2C0-&C2FF (random/&FF) | **hangs** in SAVE. Bisected (4-byte steps): &C2C8-&C2CB (dir/drive/lib) and &C2DC-&C2DF (drive settings) break it; the rest stored settings not exercised here |
| &C280-&C29F = &00 | "Disc fault 18 at :0 02/00" (bad track cache); random or &FF is harmless |
| &C000-&C1FF, &C200-&C27F, &C300-&D8FF, &D900-&DEFF (any fill) | harmless |
| everything except &C2C0-&C2FF and &DFDA/B, plus &C282, &C287, &C28B-&C28E set to &FF | **works with random, &00, &01, &80 and &FF fills** |

**Catalogue-cache hazard (important).** DFS 2.24 skips re-reading the catalogue if
the 1770 motor is still on (`BIT &FE28`, bit 7) and &C282 equals the drive (DFS
&93B1-&93BF). The motor stays on for about 2 s after the last command. Test
`race3`: LOAD, then zero &C000-&C1FF, then SAVE immediately. DFS wrote a
catalogue built from the zeroed cache: **file TEST was lost and the disc title erased**.
OSFILE save in the same situation gave "Disc full". Setting &C282 = &FF after
clobbering (`race5`) made DFS re-read the catalogue, and the disc stayed intact. So
if anything has written &C000-&C2BF since the last disc call, invalidate the cache
before the next call.

### Reinitialising instead (rejected)

* `*DISC` (OSCLI) or OSBYTE &8F with X=&12, Y=4 (select DFS) after randomising
  everything but &DFDA/B: **hangs**. DFS first handles "FS change" by saving the
  current (garbage) static workspace &C2C0-&C2ED and &C300-&C3BF into its private page
  &DA00, then restores it from there (DFS &9BC2-&9BE6).
  It only works when the clobbered area happens to be zero (the restore is skipped and
  defaults are used), and then it loses the user's *DIR and *DRIVE settings.
* Any FS call needs the MOS's FSCV copy at &DFDA/B anyway, and that lives in HAZEL.
  So reinitialising saves nothing over (a) and is less robust.

### Recommended strategy: save/restore 66 bytes and invalidate 6

1. After the loader's last disc access, and before the port first overwrites HAZEL,
   stash &C2C0-&C2FF (64 bytes) and &DFDA-&DFDB (2 bytes) in main RAM or SWRAM.
   Alternatively, lay out HAZEL so those 66 bytes are never written and skip the stash.
2. Around every docked disc call (OSCLI SAVE/LOAD/CAT/DELETE/DIR, OSFILE):
   * restore the 66 bytes;
   * write &FF to &C282, &C287, &C28B, &C28C, &C28D, &C28E. This forces a catalogue
     re-read and a head restore. It is required whenever &C000-&C2BF may have changed
     since the last call, and is safe always;
   * make the call;
   * re-stash the 66 bytes (`DIR`/`DRIVE` change them);
   * rebuild the port's HAZEL contents that the call overwrote: &C000-&C2FF, &DC00 up to
     the command's CR, &DF00-&DF05 and &DFC6. Putting only launch-reset flight state in
     &C000-&C2FF, and nothing in &DC00-&DCFF, avoids rebuilding at all; otherwise
     re-copy from the bank 6 image.
   * The glue routine, the command strings and OSFILE blocks, and the BRKV path for disc
     errors (Master Elite's error handler) must live outside those ranges, preferably in
     main RAM. The error path must also re-stash and rebuild.
3. Verified end to end. Ten back-to-back OSCLI calls ran with all 8K of HAZEL
   overwritten between every call (random junk, or all zeros), with the drive motor
   still running and ACCCON Y=1 (as in Master Elite): SAVE, LOAD, DIR E, SAVE, LOAD,
   CAT, DELETE, SAVE, `SAVE :0.C.JAMESON ...`, `LOAD :0.C.JAMESON`, `CAT 0`, DIR $, CAT.
   All files and contents on the disc were correct, and the loads were correct. The same
   run without the six &FF pokes and with zero fill failed with "Disc fault 18".

Cost: about 50 bytes of code plus a 66-byte stash. No DFS reinitialisation is needed.

```
stash:   LDX #63 : .s1 LDA &C2C0,X : STA STASH,X : DEX : BPL s1
         LDA &DFDA : STA STASH+64 : LDA &DFDB : STA STASH+65 : RTS
unstash: LDX #63 : .u1 LDA STASH,X : STA &C2C0,X : DEX : BPL u1
         LDA STASH+64 : STA &DFDA : LDA STASH+65 : STA &DFDB
         LDA #&FF : STA &C282 : STA &C287
         STA &C28B : STA &C28C : STA &C28D : STA &C28E : RTS
\ (both with ACCCON Y=1, i.e. HAZEL paged in)
```

## 3. Other spare RAM

### Shadow RAM (LYNNE)

* No MOS or DFS access to shadow &3000-&7FFF in any non-VDU test. The MOS writes it
  only when its VDU drives a shadow mode: MODE 135 touched &7C00-&7FFF, and character
  echo in that mode wrote &7C01 onwards.
* &3000-&3FFF (4096 bytes) and &7E00-&7FFF (512 bytes, if not displayed): free, read
  and written with ACCCON X=1 (bit 2). While X=1, all of main &3000-&7FFF is hidden.
  With HAZEL paged (Y=1), the "VDU code" shadow access (E bit) is disabled, so X=1 is
  the only route.
* Master Elite itself uses shadow &3090-&30FF (getzp/setzp zero-page save around disc
  access), so leave &3000-&30FF alone or move that buffer.
* Bonus: `LOAD TEST 3800` with ACCCON X=1 put the data **into shadow** &3800 (DFS's NMI
  code at &0D00 stores through the normal &3000-&7FFF mapping). A docked-only overlay
  can therefore be loaded straight into shadow RAM.

### Main RAM below &0E00

MOS buffer addresses were found by inserting a byte with OSBYTE &8A into each buffer:
keyboard &03E0-&03FF, RS423 input &0A00-&0AFF, RS423 output &0900-&09BF, speech
&09C0-&09FF, printer &0880-&08BF, sound channels &0840-&087F (as on the Model B).
Envelopes are at &08C0 (OSWORD 8). The MOS's 100 Hz IRQ code reads &0804-&0807 and
&0838 and writes &083B.

| Range | Use | Spare? |
|---|---|---|
| &0300-&037F | VDU variables | Only if the MOS VDU is never used again; OSBYTE &83/&84 read &034x |
| &0380-&03DF | CFS/ROM FS workspace (bank F CFS code) | Yes, if no `*TAPE`/`*ROM` |
| &03E0-&03FF | Keyboard buffer | Only if the MOS IRQ keyboard code never runs |
| &0400-&07FF | Language workspace | Already used by Master Elite (K%, line heap) |
| &0800-&083F | Sound workspace, touched by MOS IRQ | Only if the MOS IRQ never runs. Master Elite's IRQ1V ends in RTI and never chains, so it doesn't |
| &0840-&08FF | Sound buffers, printer buffer, envelopes | Yes, if MOS SOUND, ENVELOPE and printer are unused (192 bytes) |
| &0900-&0AFF | RS423, cassette and speech buffers | Yes, if those are unused (512 bytes) |
| &0B00-&0CFF | Unused on the Master | **Yes** (512 bytes). No MOS 3.20 or DFS references; unchanged by all tests |
| &0D00-&0D93 | DFS NMI routine, copied fresh (DFS &8FF9-&9002) at the start of every disc operation | **No** (see below) |
| &0D94-&0D9E | Unused by MOS 3.20 and DFS 2.24 in jsbeeb | **No** (see below) |
| &0D9F-&0DEF | Extended vectors; DFS's 7 FS vectors at &0DBA-&0DCE | No |
| &0DF0-&0DFF | ROM private-workspace table (&0DF9 = &DA for DFS, &0DFD = &D9 for ADFS); DFS reads it on every operation | No |
| &0E00-&12FF | Master Elite WP workspace and commander buffer (&0E7E) | Already used |

### Page &0D is off limits

Never write main RAM &0D00-&0DFF while the game is loaded, at any time. The
fill test below passed in jsbeeb, but a real Master is different: the Lander
port hung on a real Master 128 booting from a Gotek because it built tables
in page &0D (/Users/ebenupton/elite/elite-master-memo.md). &0D00 holds the
1770 DFS's NMI routine, and NMIs cannot be masked (a Gotek or a late INTRQ
can deliver one at any time); &0D9F-&0DEF are the extended vectors, which
ROMs on a real machine hook (OSBYTE through BYTEV, for example), so any OS
call can jump into page &0D; &0DF0-&0DFF is the ROM workspace table. A clean
emulated Master has none of those hooks, so the emulator does not show the
failure. The port assembles nothing there (asserted in the build), and the
harness checks that only DFS writes the page once the game has started.

Fill test (jsbeeb; superseded for page &0D by the rule above): &0300-&03DF, &0840-&08FF, &0900-&0CFF, &0D00-&0D93 and &0D94-&0D9E were
filled with a pattern. SAVE, LOAD, CAT, the OSBYTE batch and an IRQ loop with keys all
worked. Only &0D00-&0D5D changed (DFS's NMI code).

### ROM private pages in HAZEL (test report F2, assessed)

The MOS hands each sideways ROM that asks for one a private workspace page
in HAZEL, listed at &0DF0+bank. On the emulated Master 128 (MOS 3.20, the
standard ROM set) the table holds DFS (bank 9) = &DA and ADFS (bank 13) =
&D9, before and after the game loads; no other ROM has a page.

Both pages lie in the renderer's lasting HAZEL data: &D900-&DAFF is buffer
1's boundary arrays R_BDX11 to R_BDX31. These only matter for rows with
boundaries in the buffer's last frame, and they are dropped whenever the
space view is re-entered after a screen change (f_enter forgets buffer 1's
state, and r_dbm clears a buffer's counts when its last frame had none),
so DFS or ADFS writing its own page during a docked disc command is
harmless; the save, load, delete and catalogue tests pass.

The failing case is a third-party ROM that hooks BYTEV (or WORDV) on a
service call and writes its private page on every call. Its page is given
out below the standard ones, i.e. somewhere in &C7-&D8, or it may be &DB
(DASHV, the dashboard's scalars) and up. The loader already resets the
non-filing-system vectors (3a4686e), so a ROM hooked at boot is unhooked;
the risk is a ROM that hooks again during the game's own disc commands.

Cheap mitigations considered:

* Reset the vectors again in DOSCLI after OSCLI: no help, the damage is
  done during the command.
* Stash and restore, around OSCLI, each page listed in &0DF0-&0DFF that
  lies in the lasting data (except &D9 and &DA, which are harmless and are
  the ROMs' own): about 80 bytes of code in the cold area and 256 bytes a
  page of buffer in main RAM (the hi region has 1K free, enough for four
  pages). It covers disc commands only; the game makes no OSBYTE or OSWORD
  calls in flight, but the docked screens make some (e.g. *FX through
  OSBYTE), which it would not cover.
* Rebuild the renderer's lasting data after each disc command: the
  per-buffer state is rebuilt anyway on re-entering flight; DASHV and the
  text map would need a full re-initialisation.
* Move the lasting data out of &C7-&DE: a re-layout of HAZEL, ruled out.

Outcome: no ROM in the standard Master set is affected, and the stash is the
cheap mitigation if a real ROM is found that does this; it is not
implemented.

## Caveats

* The results are from jsbeeb's emulation of the Master, the 1770 and the drive motor.
  The DFS code paths quoted (cache test at &93B1, workspace save at &8917, init at
  &9BA5) come from the ROM image, not from the emulator. That makes the HAZEL findings
  independent of emulation detail, except for the motor-on timing.
* `*SRLOAD`, OSFIND/OSBGET (open files) and switching to ADFS were not tested with
  clobbered HAZEL. Master Elite uses none of them. Open files would need
  &C300-&C3BF plus buffers preserved.
* Scratch scripts (temporary): `/private/tmp/claude-501/-Users-ebenupton-elite/3a974b60-8dff-45fb-9391-f790b22cb93d/scratchpad/mm/`
  contains `ops.asm` (test program), `lib.mjs`/`drv.mjs`/`hz.mjs` (tracer and disc
  checker), and t2 (per-op traces), t6 (HAZEL clobber matrix), t7 (catalogue race),
  t8-t10 (ANDY), t15 (low memory), t16 (full protocol), t17-t19 (ANDY paging) and
  t20 (load into shadow).
