#!/usr/bin/env python3
import sys, glob
from PIL import Image
d, out = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 4
fs = sorted(glob.glob(d + '/t*.png'))
if len(sys.argv) > 4: fs = fs[int(sys.argv[4]):int(sys.argv[5])]
ims = [Image.open(f).crop((180, 60, 716, 570)) for f in fs]
w, h = ims[0].size
m = Image.new('RGB', (w*cols, h*((len(ims)+cols-1)//cols)))
for i, im in enumerate(ims): m.paste(im, ((i % cols)*w, (i//cols)*h))
m.save(out)
