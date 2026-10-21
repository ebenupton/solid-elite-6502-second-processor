import json,sys,re
D=sys.argv[1]; KMIN=int(sys.argv[2]) if len(sys.argv)>2 else 8; V2='v2' in sys.argv
P=json.load(open(D+'/polys.json'))
keys=sorted(P,key=lambda k:tuple(map(int,k.split('.')))[::-1])
K=[{},{}]   # buffer -> row -> [l,r,v,pending]
st=dict(frames=0,spans=0,fast=0,rec=0,slow=0,settle=0,savedB=0,pendErasedB=0,rowrepK=0,lines=0,polyframes=0)
def trim(l,r,t0,t1):
    a=(l,min(r,t0-1)) if l<t0 else None
    b=(max(l,t1+1),r) if r>t1 else None
    la=a[1]-a[0]+1 if a else 0; lb=b[1]-b[0]+1 if b else 0
    if lb>=la and lb>0: return b
    if la>0: return a
    return None
b=0
for key in keys:
    f=P[key]; sp=f.get('sp',[])
    if not any(not isinstance(s[0],str) for s in sp):  # no polygon frame: skip but alternate buffer
        b^=1; continue
    st['frames']+=1
    k=K[b]
    # pre-erase: K rows become pending
    for y,e in k.items(): e[3]=True; st['rowrepK']+=1
    nd=f.get('nd',[255,0])
    for y in range(nd[0],nd[1]+1):
        e=k.pop(y,None)
        if e and e[3]: st['pendErasedB']+=e[1]-e[0]+1
    for s in sp:
        if isinstance(s[0],str):
            x0,y0,x1,y1=s[1:]
            c0=max(0,min(63,min(x0,x1)>>2)) if max(x0,x1)>=0 else 0; c1=max(0,min(63,max(x0,x1)>>2))
            for y in range(max(0,min(y0,y1)),min(191,max(y0,y1))+1):
                e=k.get(y)
                if not e: continue
                t=trim(e[0],e[1],c0,c1)
                if e[3]:
                    if V2 and t: 
                        st['pendErasedB']+=(e[1]-e[0]+1)-(t[1]-t[0]+1); e[0],e[1]=t
                    else: st['pendErasedB']+=e[1]-e[0]+1; del k[y]
                else:
                    if t and t[1]-t[0]+1>=KMIN: e[0],e[1]=t
                    else: del k[y]
            continue
        y,xl,xr,c=s; st['spans']+=1
        e0,e1=xl>>2,xr>>2; nl,nr=e0+1,e1-1; big=nr-nl+1>=KMIN
        e=k.get(y)
        if not e:
            if not big: st['fast']+=1; continue
            st['rec']+=1; k[y]=[nl,nr,c,False]; continue
        st['slow']+=1
        if e[3]:
            if big:
                st['settle']+=1
                if e[2]==c:
                    ov=max(0,min(e[1],nr)-max(e[0],nl)+1); st['savedB']+=ov
                    st['pendErasedB']+=(e[1]-e[0]+1)-ov
                else: st['pendErasedB']+=e[1]-e[0]+1
                k[y]=[nl,nr,c,False]
            else:
                t=trim(e[0],e[1],e0,e1)
                if V2 and t: st['pendErasedB']+=(e[1]-e[0]+1)-(t[1]-t[0]+1); e[0],e[1]=t
                else: st['pendErasedB']+=e[1]-e[0]+1; del k[y]
        else:
            if big and e[2]==c and e[0]<=nr+1 and nl<=e[1]+1:
                e[0]=min(e[0],nl); e[1]=max(e[1],nr)
            else:
                t=trim(e[0],e[1],e0,e1)
                if big and (not t or nr-nl>t[1]-t[0]): k[y]=[nl,nr,c,False]
                elif t and t[1]-t[0]+1>=KMIN: e[0],e[1]=t
                else: del k[y]
    # fe: flush pending
    for y in [y for y,e in k.items() if e[3]]:
        st['pendErasedB']+=k[y][1]-k[y][0]+1; del k[y]
    # sight trims (front view assumed)
    for y,(c0,c1) in [(96,(27,29)),(96,(34,37))]+[(y,(32,32)) for y in list(range(76,86))+list(range(107,117))]:
        e=k.get(y)
        if e:
            t=trim(e[0],e[1],c0,c1)
            if t and t[1]-t[0]+1>=KMIN: e[0],e[1]=t
            else: del k[y]
    for y in range(nd[0],nd[1]+1): k.pop(y,None)
    b^=1
fr=st['frames']
print({x:round(v/fr,1) for x,v in st.items()})
saved=8*st['savedB']; cost=33*st['fast']+70*st['rec']+120*st['slow']+250*st['settle']+250*st['rowrepK']
print('per frame: saved cycles %.0f, host bookkeeping %.0f, net %.0f'%(saved/fr,cost/fr,(saved-cost)/fr))
