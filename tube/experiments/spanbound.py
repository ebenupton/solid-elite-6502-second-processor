import sys,re,glob,json
exec(open('tube/experiments/spanpix.py').read().split('prev=None')[0])
D=sys.argv[1]
P=json.load(open(D+'/polys.json'))
def pc(key):
    c=[0]*192
    for ys,yl,_ in P[key]['p']:
        for y in range(ys,min(yl,191)+1): c[y]+=1
    return c
def largest(r):
    r=bytearray(r); r[0]&=0x33; r[63]&=0xCC
    best=(0,0,0,None); i=0
    while i<64:
        v=r[i]
        if v==0: i+=1; continue
        j=i
        while j+1<64 and r[j+1]==v: j+=1
        if j-i+1>best[0]: best=(j-i+1,i,j,v)
        i=j+1
    return best
TH=[1,2,3,4,6,8,12,16,24,32]
prevB=None; lastpc={}
S={t:[0,0,0] for t in TH}; frames=0; ssrows=0; ssbytes=0; polyrows=0
for f in files:
    it,n=re.findall(r'it-(\d+)-(\d+)',f)[0]; key=f'{it}.{n}'
    d=open(f,'rb').read(); B=[d[:0x3000],d[0x3000:]]
    if prevB is not None and key in P:
        ch=[B[i]!=prevB[i] for i in (0,1)]
        if ch[0]!=ch[1]:
            k=0 if ch[0] else 1; c=pc(key); frames+=1
            if k in lastpc:
                oc=lastpc[k]; o=rows(prevB[k]); nn=rows(B[k])
                for y in range(1,191):
                    if not(c[y] and oc[y]): continue
                    polyrows+=1
                    L,ol,orr,v=largest(o[y])
                    if not L: continue
                    # saved bytes: in [ol,orr], new==v (contiguous pieces all count)
                    sv=sum(1 for x in range(ol,orr+1) if nn[y][x]==v)
                    for t in TH:
                        if L>=t: S[t][0]+=1; S[t][1]+=sv
            lastpc[k]=c
    prevB=B
print('frames',frames,'poly rows in both per frame %.1f'%(polyrows/frames))
for t in TH: print('threshold %2d bytes: rows remembered %.1f/frame, bytes kept %.0f/frame -> ~%.0f cycles saved (8/byte) minus bookkeeping'%(t,S[t][0]/frames,S[t][1]/frames,8*S[t][1]/frames))
