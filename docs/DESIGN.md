# Filled Elite for the BBC Master — design spec (shared by all workers)

Base: the Elite Demonstration Disc source (ref/elite-demo-source-code-bbc-micro,
cassette Elite + self-playing autopilot), ported to the BBC Master 128 (65C02,
shadow RAM, sideways RAM banks 4-7). The demo's own logic is the stimulus: the
game logic must stay bit-for-bit identical to the original (same RNG calls, same
ship state per main-loop iteration), only rendering changes.

Target: same main-loop iteration rate as the original demo on a Model B
(~15-20 iterations/s in flight; measured with harness/run.mjs).

## Screen

Master-version geometry: custom MODE 1, 256 pixels wide, CRTC R1=64, R2=90,
R6=31, R12/R13=&0800 (screen starts &4000).

* Space view: 192 lines, y = 0..191, at &4000-&6FFF, 4 colours (2 bpp).
  Address of pixel row y, byte column c (c = x DIV 4, 0..63):
      &4000 + (y DIV 8) * &200 + (y MOD 8) + 8 * c
  MODE 1 pixel p (0 = leftmost of the byte, x MOD 4) of logical colour v (0..3):
      bit (7-p) = v bit 1, bit (3-p) = v bit 0
  so a byte of four pixels of colour 1 = &0F, colour 2 = &F0, colour 3 = &FF.
* Dashboard: 56 lines (7 char rows) at &7000-&7DFF in MODE 2 format (as the BBC
  Master Elite version), main RAM only. ULA switched to MODE 2 by the IRQ split.
* Double buffering: buffer A = main RAM &4000-&6FFF, buffer B = shadow RAM
  &4000-&6FFF (same addresses). ACCCON (&FE34) bit 2 (X) selects which one the
  CPU sees at &3000-&7FFF; bit 0 (D) selects which one is displayed. The IRQ
  sets D for the front buffer at vsync and clears D at the dashboard split (the
  dashboard is in main RAM). Code/data touched while X=1 must live outside
  &3000-&7FFF (i.e. below &3000 or in sideways RAM &8000-&BFFF).

## Palette / colours: CMYK

Space view logical colours: 0 = blacK, 1 = Cyan, 2 = Magenta, 3 = Yellow.
Filled colours are 2x2 dithers of those four inks (tools/swatch35.py: 35 cells,
same phase conventions as Lander). A dithered colour is a PAIR of bytes:
(even-row byte, odd-row byte), each byte = 4 pixels, pixel x takes the ink at
(x AND 1, y AND 1) of the cell.

## Memory map (Master)

* &0000-&00E1 Elite zero page (as original). Renderer may use a ZP block that it
  saves/restores itself (see below); &E2-&EF unusable (MOS).
* &0100-&01FF XX3 vertex heap + stack (as original).
* &0300-&037F T% commander; &0400-&07F6 WORDS9; &0900-&0AAF K% ship slots;
  &0D40-&0F38 WP workspace (as original).
* &0F40-&3FFF Elite code (main RAM).
* &4000-&6FFF screen buffer A (main) / buffer B (shadow).
* &7000-&7DFF dashboard (main).
* &8000-&BFFF sideways RAM bank 4, permanently paged in: overflow Elite code,
  ship blueprints, renderer code and tables. (A second bank may be paged in for
  the duration of the render only, via a stub below &3000, if bank 4 overflows.)

## Frame model (space view)

The game loop runs unchanged, but drawing primitives no longer touch the
screen during the loop; they record into a display list:
  * ships: LL9 projects vertices (XX3) and face visibility (XX2) as before; the
    hook records each visible face as a polygon (16-bit screen coords) with a
    colour chosen from the ship's hue ramp by the face's XX2 brightness;
  * sun / planet: per-row half-widths (the sun's LSO heap) or circle (planet
    K3,K4,K) -> the incremental "disc layer";
  * lines (lasers, planet meridians/craters), dots (explosion particles), stars;
  * text: a 32x24 text map (desired characters) rendered as an overlay.
At the end of each main-loop iteration FRAME renders the display list into the
back buffer and requests a flip at the next vsync.

Back-buffer render order (buffer b, two frames old):
 1. wait until the previous flip has happened;
 2. erase this buffer's old stars (they were only plotted on black pixels);
 3. per row: disc-layer diff — using this buffer's old disc span, old dirty
    extent and the new disc span, write disc colour where it is not already
    intact and black where something old is no longer covered;
 4. ships far-to-near (filled convex faces), lines, particles -> extend the new
    dirty extents (per row [min x, max x] in pixels);
 5. stars (only on black pixels; positions remembered per buffer);
 6. text overlay (cells whose content changed or whose pixels were overwritten);
 7. flip request.
Clip window for fills: x 1..254, y 1..191 (the border box at x=0, x=255, y=0 is
never touched).
