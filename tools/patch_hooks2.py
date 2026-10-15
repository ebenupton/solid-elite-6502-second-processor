import sys
p = 'src/elite-source.asm'
s = open(p).read()
def rep(old, new, count=1):
    global s
    n = s.count(old)
    if n != count:
        sys.exit(f'patch anchor found {n} times (want {count}):\n{old}')
    s = s.replace(old, new)
H = ' JSR {}                \\ Frame layer hook (see hooks.asm)'
def line_after(label, text):
    rep(f'\n.{label}\n', f'\n.{label}\n\n{text}\n')

rep("""\n.PX4\n\n RTS                    \\ Return from the subroutine\n""",
    """\n.PX4\n\n RTS                    \\ Return from the subroutine\n\n.px4s\n\n JSR H_STAROFF          \\ Frame layer hook: star Y is off screen\n RTS\n""")
# TT26
rep(""" DEC XC                 \\ We want to delete the character to the left of the
""", """ DEC XC                 \\ We want to delete the character to the left of the
 JSR H_DEL              \\ Frame layer hook (see hooks.asm)
""")
line_after('RR3', H.format('H_CHAR'))
line_after('CLYNS', H.format('H_CLYNS'))
line_after('TTX66', ' JSR G_DIRECT           \\ Frame layer: direct drawing from now on')
line_after('tt66', H.format('H_FORCE1'))
rep(""" JSR BOS2               \\ Call BOS2 below, which will call BOS1 twice, and then
""", """ JSR BOS2               \\ Frame layer: draw the four lines, then GFORCE off
 JSR BOS2
 JMP H_FORCE0
""")
# IRQ
rep(""" STA VIA+&45            \\ (SHEILA &45) to VSCAN (57) to start the T1 counter
""", """ STA VIA+&45            \\ (SHEILA &45) to VSCAN (57) to start the T1 counter
 JSR H_VSYNC            \\ Frame layer: flip buffers, show the front one
""")
rep(""" STA VIA+&20            \\ %00010100, which is the same as switching to mode 2
""", """ STA VIA+&20            \\ %00010100, which is the same as switching to mode 2
 JSR H_SPLIT            \\ Frame layer: the dashboard is in main RAM
""")
# LL9
line_after('EE31', H.format('H_EE31'))
line_after('LL91', H.format('H_ZN'))
rep(""" LDA #8                 \\ Set A = 8 so when we call LL18+2 next, byte #0 of the
""", """ JSR H_SHPPT            \\ Frame layer: record the dot

 LDA #8                 \\ Set A = 8 so when we call LL18+2 next, byte #0 of the
""")
# planet, sun, explosions
line_after('CIRCLE', H.format('H_CIRC'))
line_after('WPLS2', H.format('H_WPLS2'))
rep(""" BCS PLF3-3             \\ If CHKON set the C flag then the new sun's circle does
""", """ BCS PLF3-3             \\ If CHKON set the C flag then the new sun's circle does
 JSR H_SUN              \\ Frame layer: record the sun
""")
rep(""" JSR PTCLS              \\ Call PTCLS to remove the existing cloud by drawing it
""", """ JSR H_PTCLSE           \\ Call PTCLS to remove the existing cloud by drawing it
""")
# lasers, sights, rings
rep("""\n.LASLI2\n""", """\n JSR H_LAS1             \\ Frame layer: show our laser beams\n\n.LASLI2\n\n JSR H_LAS2             \\ Frame layer: remove our laser beams\n""")
line_after('SIGHT', H.format('H_SIGHT'))
rep(""" JSR HFS1               \\ Call HFS1 below and then fall through into the same
""", """ JSR H_HFS              \\ Frame layer: HFS1 twice, drawn directly
""")
# frames
rep("""\n.TT100\n\n JSR M%                 \\ Call M% to iterate through the main flight loop""",
    """\n.TT100\n\n JSR H_MFRAME           \\ Call M% to iterate through the main flight loop""")
rep("""\n.D2\n\n JSR M%                 \\ Call the M% routine to do the main flight loop once,""",
    """\n.D2\n\n JSR H_MFRAME           \\ Call the M% routine to do the main flight loop once,""")
open(p, 'w').write(s)
print('ok')
