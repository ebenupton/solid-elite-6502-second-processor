#!/bin/sh
# Build the BBC Master port of the Elite Demonstration Disc:
#   build/elite-master.ssd (boots with SHIFT+BREAK on a BBC Master)
set -e
cd "$(dirname "$0")"
BEEBASM=${BEEBASM:-./tools/beebasm}
mkdir -p build
python3 tools/dashboard.py build
$BEEBASM -i src/elite-source.asm -v > build/compile.txt
$BEEBASM -i src/elite-source.asm -d > build/symbols.txt 2>/dev/null
TRTBL=$(python3 -c "import re;print(re.search(r\"'TRTBL':(\\d+)\", open('build/symbols.txt').read()).group(1))")
GINIT=$(python3 -c "import re;print(re.search(r\"'G_INIT':(\\d+)\", open('build/symbols.txt').read()).group(1))")
DASHDUAL=$(sed -n 's/^ DASHDUAL = \([01]\).*/\1/p' src/elite-source.asm)
HZLEN=$(python3 -c "import re;t=open('build/symbols.txt').read();g=lambda n:int(re.search(r\"'\"+n+r\"':(\\d+)\",t).group(1));print(g('HZ_CODE_END')-g('HZ_START'))")
$BEEBASM -i src/elite-loader.asm -D TRTBL=$TRTBL -D GINIT=$GINIT -D HZLEN=$HZLEN -D DASHDUAL=$DASHDUAL -v > build/compile-loader.txt
rm -f build/elite-master.ssd
$BEEBASM -i src/elite-disc.asm -do build/elite-master.ssd -boot ELITE -opt 3 -title "ELITE DEMO"
grep -E "^(Main code|Bank 4|Port workspace|HAZEL|Bank 5|Bank 6)" build/compile.txt
