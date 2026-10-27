#!/bin/sh
# Build agentd (elite-agent's player as a subprocess) from an elite-agent checkout.
#   ELITE_AGENT=path (default ~/elite-agent): https://github.com/8bitkick/elite-agent
#   OUT=path (default <worktree>/scratch/agentplay/agentd)
# Only elite-agent's cplayer/*.c (the player) is compiled: not its emulator, run_sim or lab.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
WT=$(cd "$HERE/../../.." && pwd)
EA=${ELITE_AGENT:-$HOME/elite-agent}
OUT=${OUT:-$WT/scratch/agentplay/agentd}
[ -f "$EA/cplayer/player.h" ] || { echo "no elite-agent checkout at $EA (set ELITE_AGENT)"; exit 1; }
mkdir -p "$(dirname "$OUT")"
SRC="keyq.c agent.c combat.c docked.c drv.c fair.c flight.c galaxy.c pilot.c ships.c show.c"
for f in cfly.c elite_ver.c; do [ -f "$EA/cplayer/$f" ] && SRC="$SRC $f"; done   # (newer elite-agents)
cd "$EA/cplayer"
# (newer elite-agents put declarations after labels, C23: a gcc that takes them if there is one)
[ -z "${CC:-}" ] && for c in gcc-15 gcc-14 gcc-13; do command -v $c >/dev/null && CC=$c && break; done
MM=; grep -q "g_moon" pilot.c && MM=-DMOONMODE           # (an elite-agent with the moon mode)
grep -q "int machine;" player.h && MM="$MM -DHAVE_MACHINE"  # (one that asks which machine it is on)
${CC:-cc} -O2 -fwrapv -w $MM -o "$OUT" "$HERE/agentd.c" $SRC -I. -lm
echo "agentd: $OUT (elite-agent $(git -C "$EA" rev-parse --short HEAD 2>/dev/null || echo '?'))"
