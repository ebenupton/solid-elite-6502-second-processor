import sys,os,re,glob
D=sys.argv[1]
files=sorted(glob.glob(D+'/it-*.raw'),key=lambda f:tuple(map(int,re.findall(r'it-(\d+)-(\d+)',f)[0][::-1])))
def rows(buf):
    out=[]
    for y in range(192):
        cr,l=divmod(y,8)
        out.append(bytes(buf[cr*512+c*8+l] for c in range(64)))
    return out
def classify(r):
    r=bytearray(r); r[0]&=0x33; r[63]&=0xCC
    nz=[i for i,b in enumerate(r) if b]
    if not nz: return 'E'
    b0,b1=nz[0],nz[-1]
    if b1-b0+1!=len(nz): return None
    inner=set(r[b0+1:b1])
    if len(inner)>1: return None
    v=inner.pop() if inner else None
    return (b0,b1,v)
def classify_old(r):
    px=[]
    for b in r:
        for i in range(4):
            px.append(((b>>(7-i))&1)<<1|((b>>(3-i))&1))
    nz=[i for i,p in enumerate(px) if p]
    if not nz: return 'E'
    x0,x1=nz[0],nz[-1]
    if x1-x0+1!=len(nz): return None
    b0,b1=x0//4,x1//4
    inner=set(r[b0+1:b1])
    if len(inner)>1: return None
    v=inner.pop() if inner else None
    return (b0,b1,v)
prev=None; tot=dict(frames=0,rows=0,ss_both=0,same=0,ident=0,cur=0,fix=0,ss_new=0,nonempty=0)
hist=[]
for f in files:
    d=open(f,'rb').read(); B=[d[:0x3000],d[0x3000:]]
    if prev is not None:
        ch=[B[i]!=prev[i] for i in (0,1)]
        if ch[0]!=ch[1]:
            k=0 if ch[0] else 1
            o=rows(prev[k]); n=rows(B[k]); tot['frames']+=1
            for y in range(1,191):
                a=classify(o[y]); b=classify(n[y])
                if b!='E' or a!='E': tot['nonempty']+=1
                if b not in ('E',None): tot['ss_new']+=1
                if a in ('E',None) or b in ('E',None): continue
                tot['ss_both']+=1
                ob=set(range(a[0],a[1]+1)); nb=set(range(b[0],b[1]+1))
                cur=len(ob)+len(nb)
                if a[2]==b[2]:
                    tot['same']+=1
                    if a==b and o[y]==n[y]: tot['ident']+=1
                    fix=len(ob^nb)+ (2 if True else 0)
                    # edge bytes: only rewrite edges that changed
                    fix=len(ob^nb)+(o[y][b[0]]!=n[y][b[0]])+(o[y][b[1]]!=n[y][b[1]])
                else:
                    fix=len(nb)+len(ob-nb)
                tot['cur']+=cur; tot['fix']+=fix
    prev=B
print(tot)
fr=tot['frames']; print('per frame: ss_both %.1f rows, same colour %.1f, identical %.1f; stores cur %.0f fix %.0f saved %.0f'%(tot['ss_both']/fr,tot['same']/fr,tot['ident']/fr,tot['cur']/fr,tot['fix']/fr,(tot['cur']-tot['fix'])/fr))
