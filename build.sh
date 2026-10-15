#!/bin/sh
# Build the BBC Master port of the Elite Demonstration Disc:
#   build/elite-master.ssd (boots with SHIFT+BREAK on a BBC Master)
set -e
cd "$(dirname "$0")"
BEEBASM=${BEEBASM:-./tools/beebasm}
mkdir -p build
$BEEBASM -i src/elite-source.asm -v > build/compile.txt
$BEEBASM -i src/elite-source.asm -d > build/symbols.txt 2>/dev/null
TRTBL=$(python3 -c "import re;print(re.search(r\"'TRTBL':(\\d+)\", open('build/symbols.txt').read()).group(1))")
$BEEBASM -i src/elite-loader.asm -D TRTBL=$TRTBL -v > build/compile-loader.txt
rm -f build/elite-master.ssd
$BEEBASM -i src/elite-disc.asm -do build/elite-master.ssd -boot ELITE -opt 3 -title "ELITE DEMO"
grep -E "^(Main code|Bank 4|Port workspace)" build/compile.txt
