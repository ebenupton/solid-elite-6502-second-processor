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
cd "$EA/cplayer"
cc -O2 -fwrapv -w -o "$OUT" "$HERE/agentd.c" $SRC -I. -lm
echo "agentd: $OUT (elite-agent $(git -C "$EA" rev-parse --short HEAD 2>/dev/null || echo '?'))"
