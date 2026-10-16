# Exhaustive check that the quarter-square MULTS, MU11 and MULT1 (body.asm, as
# in elite-source.asm) leave exactly what the original shift-and-add ones
# (old.asm) leave: A, X, Y, P, P+1, T, T1 and C, for every pair of 8-bit
# arguments (with random C, Y and other bytes). N and Z are counted apart (MU11
# differs there; no caller reads them). Needs py65; run from this directory:
#   ../../../tools/beebasm -i old.asm; ../../../tools/beebasm -i new.asm
#   python3 test.py MULTS; python3 test.py MU11; python3 test.py MULT1
import sys, random
from py65.devices.mpu65c02 import MPU
old=open('old.bin','rb').read(); new=open('new.bin','rb').read(); tab=open('tab.bin','rb').read()
P,Q,T,T1=0x70,0x72,0x73,0x74
def mk(code, tabs):
    m=MPU(); m.memory[0x2000:0x2000+len(code)]=list(code)
    if tabs: m.memory[0x7600:0x7600+len(tab)]=list(tab)
    m.memory[0x1ff0]=0x20; m.memory[0x1ff1]=0; m.memory[0x1ff2]=0  # JSR placeholder
    return m
mo=mk(old,False); mn=mk(new,True)
import re
def addr(asm, lab):
    pass
ent={'MULTS':(0x2000,None),'MU11':(0x2100,None),'MULT1':(0x2200,None)}
# new entry addresses from beebasm symbol dump
import subprocess
out=subprocess.run(['../../../tools/beebasm','-i','new.asm','-d'],capture_output=True,text=True).stdout
syms=dict((k,int(v)) for k,v in re.findall(r"'(\w+)':(\d+)",out))
newent={'MULTS':syms['MULTS'],'MU11':syms['MU11'],'MULT1':syms['MULT1']}
def run(m, pc, a, x, y, c, mem, maxsteps=500):
    for k,v in mem.items(): m.memory[k]=v
    m.a=a; m.x=x; m.y=y; m.sp=0xff
    m.p = (m.p & ~1) | c
    m.memory[0x1ff0:0x1ff3]=[0x20, pc&255, pc>>8]
    m.memory[0x1ff3]=0xdb  # STP
    m.pc=0x1ff0
    n=0
    while m.pc!=0x1ff3:
        m.step(); n+=1
        if n>maxsteps: raise Exception('runaway')
    return n
def state(m):
    return (m.a, m.x, m.y, m.memory[P], m.memory[P+1], m.memory[T], m.memory[T1], m.p&1)
def flags(m): return (m.p>>7&1, m.p>>1&1)
which=sys.argv[1]
random.seed(1)
bad=0; nzbad=0; cyc_o=cyc_n=0
for i in range(256):
    for j in range(256):
        c=random.randint(0,1); y=random.randint(0,255); x0=random.randint(0,255); junk=[random.randint(0,255) for _ in range(5)]
        if which=='MULTS': a,x,mem=i,x0,{P:j,P+1:junk[0],Q:junk[1],T:junk[2],T1:junk[3]}
        if which=='MU11': a,x,mem=junk[4],i,{P:j,P+1:junk[0],Q:junk[1],T:junk[2],T1:junk[3]}
        if which=='MULT1': a,x,mem=i,x0,{P:junk[4],P+1:junk[0],Q:j,T:junk[2],T1:junk[3]}
        run(mo, ent[which][0], a,x,y,c,mem); so=state(mo); fo=flags(mo)
        run(mn, newent[which], a,x,y,c,mem); sn=state(mn); fn=flags(mn)
        if so!=sn:
            bad+=1
            if bad<10: print('DIFF',which,i,j,c,'old',so,'new',sn)
        if fo!=fn: nzbad+=1
print(which,'state mismatches',bad,'NZ mismatches',nzbad)
