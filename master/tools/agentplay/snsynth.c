// snsynth: the BBC Master's sound (the SN76489) from a film's record of the writes to it
// (film.mjs's sound.bin: f64 emulated cycle, u8 value), rendered for the stretches of the
// emulated timeline a cut of the film keeps (edit.mjs), as 44.1 kHz signed 16-bit mono on stdout.
// The chip is modelled as jsbeeb models it (src/soundchip.js): a 500 kHz sample clock, tone
// counters toggling every period, the 15-bit noise register, 2 dB volume steps; each output
// sample is the mean of the 500 kHz samples it spans, then a DC blocker (the chip's outputs
// are unipolar).
//
// cc -O2 -o snsynth snsynth.c -lm
// snsynth sound.bin < segments > audio.s16
//   segments, a line each: "a T0 T1 N" N samples spanning emulated cycles T0 to T1 (a stretch
//   played at its own speed), or "s N" N samples of silence (a stretch fast-forwarded).
//   T0 must not go back. Writes before T0 are applied without sound being made.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

static float voltab[16];
static int reg[4], latched;
static float vol[4], counter[4];
static int outbit[4];
static int lfsr = 1 << 14, white;
static double now;                  // emulated cycles: the chip's sound made up to here

static void noise_poked(void) { white = (reg[3] & 4) != 0; lfsr = 1 << 14; }
static void poke(int v) {
    int cmd;
    if (v & 0x80) { latched = v & 0x70; cmd = v & 0xf0; } else cmd = latched;
    int ch = (cmd >> 5) & 3;
    if (cmd & 0x10) vol[ch] = voltab[v & 15];
    else if (ch == 3) { reg[3] = v & 15; noise_poked(); }
    else if (cmd & 0x80) reg[ch] = (reg[ch] & ~15) | (v & 15);
    else reg[ch] = (reg[ch] & 15) | ((v & 0x3f) << 4);
}
static int step(int ch, int add) {
    float n = counter[ch] - 0.5f;
    if (n < 0) { counter[ch] = fmaxf(0, n + add); outbit[ch] = !outbit[ch]; return outbit[ch]; }
    counter[ch] = n; return 0;
}
// one 500 kHz sample
static float sample(void) {
    float out = 0;
    for (int c = 0; c < 3; c++) { int r = reg[c] ? reg[c] : 1024; step(c, r); out += outbit[c] * vol[c]; }
    int add = (reg[3] & 3) == 0 ? 0x10 : (reg[3] & 3) == 1 ? 0x20 : (reg[3] & 3) == 2 ? 0x40 : (reg[2] ? reg[2] : 1024);
    if (step(3, add)) {
        if (white) { int bit = (lfsr & 1) ^ ((lfsr >> 1) & 1); lfsr = (lfsr >> 1) | (bit << 14); }
        else { lfsr >>= 1; if (!lfsr) lfsr = 1 << 14; }
    }
    out += (lfsr & 1) * vol[3];
    return out;
}

static uint8_t *W; static size_t nw, wi;
static double wt(size_t i) { double t; memcpy(&t, W + 9 * i, 8); return t; }
static void apply_to(double t) { while (wi < nw && wt(wi) <= t) poke(W[9 * wi++ + 8]); }

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "snsynth sound.bin < segments > out.s16\n"); return 2; }
    { float f = 1; for (int i = 0; i < 15; i++) { voltab[i] = f / 4; f *= powf(10, -0.1f); } voltab[15] = 0; }
    for (int i = 0; i < 4; i++) vol[i] = 0;     // (the MOS silences the chip at boot, before the film begins)
    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror(argv[1]); return 1; }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    W = malloc(n + 1); if (fread(W, 1, n, f) != (size_t) n) return 1; fclose(f);
    nw = n / 9;
    char line[256];
    static int16_t buf[1 << 16];
    double hp_x = 0, hp_y = 0;          // the DC blocker
    float fade_len = 220;               // 5 ms fades at each stretch's ends
    while (fgets(line, sizeof line, stdin)) {
        double t0, t1; long ns;
        if (line[0] == 's' && sscanf(line + 1, "%ld", &ns) == 1) {
            memset(buf, 0, sizeof buf);
            while (ns > 0) { long k = ns < (1 << 16) ? ns : (1 << 16); fwrite(buf, 2, k, stdout); ns -= k; }
            hp_x = hp_y = 0;
            continue;
        }
        if (line[0] != 'a' || sscanf(line + 1, "%lf %lf %ld", &t0, &t1, &ns) != 3) { fprintf(stderr, "bad segment: %s", line); return 2; }
        apply_to(t0);
        now = t0;
        double per = (t1 - t0) / ns;    // cycles an output sample
        double acc = 0;                 // 500 kHz samples owed (fractional): 4 cycles each
        int bi = 0;
        for (long k = 0; k < ns; k++) {
            double tend = t0 + (k + 1) * per;
            acc += (tend - now) / 4.0;
            int m = (int) acc; acc -= m;
            float sum = 0; int cnt = 0;
            // the writes inside this output sample land at their own 500 kHz sample
            for (int j = 0; j < m; j++) {
                double ts = now + 4.0 * (j + 1);
                apply_to(ts);
                sum += sample(); cnt++;
            }
            now = tend;
            apply_to(now);
            double x = cnt ? sum / cnt : 0;
            hp_y = x - hp_x + 0.9995 * hp_y; hp_x = x;
            double g = 1;
            if (k < fade_len) g = k / fade_len;
            if (ns - 1 - k < fade_len) g = fmin(g, (ns - 1 - k) / fade_len);
            double v = hp_y * g * 0.9 * 32767;
            if (v > 32767) v = 32767; if (v < -32768) v = -32768;
            buf[bi++] = (int16_t) lrint(v);
            if (bi == (1 << 16)) { fwrite(buf, 2, bi, stdout); bi = 0; }
        }
        if (bi) fwrite(buf, 2, bi, stdout);
    }
    return 0;
}
