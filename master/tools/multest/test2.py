# Random and edge-case check (300000 cases each) that the quarter-square MULT3
# and MLTU2 (body2.asm, as in elite-source.asm) leave exactly what the original
# shift-and-add ones (old2.asm) leave: A, X, Y, C, P(2 1 0), Q, T, T1, R and
# K(3 2 1 0). Needs py65 and tab.bin from new.asm (see test.py); run from this
# directory: beebasm -i old2.asm; beebasm -i new2.asm -d > new2.sym;
#   python3 test2.py MULT3 300000; python3 test2.py MLTU2 300000; ... MLTU2-2
import sys, random, re
from py65.devices.mpu65c02 import MPU
old=open('old2.bin','rb').read(); new=open('new2.bin','rb').read(); tab=open('tab.bin','rb').read()
P,Q,T,T1,R,K=0x70,0x72,0x73,0x74,0x75,0x76
syms=dict((k,int(v)) for k,v in re.findall(r"'(\w+)':(\d+)",open('new2.sym').read()))
def mk(code):
    m=MPU(); m.memory[0x2000:0x2000+len(code)]=list(code); m.memory[0x7600:0x7600+len(tab)]=list(tab); return m
mo=mk(old); mn=mk(new)
def run(m, pc, a, x, y, c, mem):
    for k,v in mem.items(): m.memory[k]=v
    m.a=a; m.x=x; m.y=y; m.sp=0xff; m.p=(m.p&~1)|c
    m.memory[0x1ff0:0x1ff4]=[0x20, pc&255, pc>>8, 0xdb]; m.pc=0x1ff0; n=0
    while m.pc!=0x1ff3:
        m.step(); n+=1
        if n>2000: raise Exception('runaway')
def st(m): return (m.a,m.x,m.y,m.p&1)+tuple(m.memory[a] for a in (P,P+1,P+2,Q,T,T1,R,K,K+1,K+2,K+3))
which=sys.argv[1]; N=int(sys.argv[2])
eo={'MULT3':0x200A,'MLTU2':0x2102,'MLTU2-2':0x2100}[which]
en={'MULT3':syms['MULT3'],'MLTU2':syms['MLTU2'],'MLTU2-2':syms['MLTU2']-2}[which]
random.seed(7); bad=0; nz=0
edge=[0,1,2,0x7f,0x80,0x81,0xfe,0xff]
for i in range(N):
    r=lambda: random.choice(edge) if random.random()<0.3 else random.randint(0,255)
    a,x,y,c=r(),r(),r(),random.randint(0,1)
    mem={P:r(),P+1:r(),P+2:r(),Q:r(),T:r(),T1:r(),R:r(),K:r(),K+1:r(),K+2:r(),K+3:r()}
    run(mo,eo,a,x,y,c,mem); so=st(mo); fo=(mo.p>>7&1,mo.p>>1&1)
    run(mn,en,a,x,y,c,mem); sn=st(mn); fn=(mn.p>>7&1,mn.p>>1&1)
    if so!=sn:
        bad+=1
        if bad<6: print('DIFF',a,x,y,c,mem,'\n old',so,'\n new',sn)
    if fo!=fn: nz+=1
print(which,N,'mismatches',bad,'NZ',nz)
