#!/usr/bin/env python3
"""master/tools/discmem/cmp.py A B: compare two master/tools/discmem/bench.sh
outputs (A the reference build, B the candidate): pixels (every frame the
scenes dump, byte for byte; run1's and the gate's frame hashes through
fbcmp.mjs and mfbcmp.mjs --cmp) and cycles (each scene's mean per routine,
run1's windows)."""
import json, os, subprocess, sys, glob, re

A, B = sys.argv[1], sys.argv[2]
R = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
bad = 0


def frames_equal(da, db):
    fa = sorted(glob.glob(os.path.join(da, 'frame-*.bin')))
    same = diff = 0
    first = None
    for f in fa:
        g = os.path.join(db, os.path.basename(f))
        if not os.path.exists(g):
            diff += 1
            continue
        if open(f, 'rb').read() == open(g, 'rb').read():
            same += 1
        else:
            diff += 1
            first = first or os.path.basename(f)
    return same, diff, first


def mean(xs):
    return sum(xs) / len(xs) if xs else 0


if os.path.exists(os.path.join(A, 'run1-fb.json')) and os.path.exists(os.path.join(B, 'run1-fb.json')):
    r = subprocess.run(['node', os.path.join(R, 'master/tools/solidspan/fbcmp.mjs'), os.path.join(A, 'run1-fb.json'),
                        os.path.join(B, 'run1-fb.json')], capture_output=True, text=True)
    print('run1 pixels:', r.stdout.strip())
    bad += r.returncode != 0
    sa = open(os.path.join(A, 'run1-speed.txt')).read()
    sb = open(os.path.join(B, 'run1-speed.txt')).read()
    for la, lb in zip(re.findall(r'iterations (\S+): (\d+) cycles', sa), re.findall(r'iterations (\S+): (\d+) cycles', sb)):
        ca, cb = int(la[1]), int(lb[1])
        print('run1 %-10s %7d -> %7d cycles an iteration (%+d, %+.2f%%)' % (la[0], ca, cb, cb - ca, 100.0 * (cb - ca) / ca))
if os.path.exists(os.path.join(A, 'gate-fb.json')) and os.path.exists(os.path.join(B, 'gate-fb.json')):
    r = subprocess.run(['node', os.path.join(R, 'harness/mfbcmp.mjs'), '--cmp', os.path.join(A, 'gate-fb.json'),
                        os.path.join(B, 'gate-fb.json')], capture_output=True, text=True)
    print('gate pixels:', r.stdout.strip())
    bad += r.returncode != 0
for d in sorted(glob.glob(os.path.join(A, 'pl-*'))) + [os.path.join(A, 'sunnear')]:
    if not os.path.isdir(d):
        continue
    n = os.path.basename(d)
    e = os.path.join(B, n)
    if not os.path.isdir(e):
        continue
    same, diff, first = frames_equal(d, e)
    bad += diff > 0
    ja = json.load(open(os.path.join(d, 'frames.json')))['frames']
    jb = json.load(open(os.path.join(e, 'frames.json')))['frames']
    if n != 'sunnear':              # (mplanet's first frame counts all before it)
        ja, jb = ja[1:], jb[1:]
    if n == 'sunnear':
        keys = ['discs', 'disc2', 'frame']
        get = lambda f, k: f.get(k, 0)
    else:
        keys = [k for k in ['T_DISCROWS', 'T_CAPS', 'f_moon', 'T_MCAPS', 'F_FRAME'] if k in ja[0]['cyc']]
        get = lambda f, k: f['cyc'].get(k, 0)
    parts = []
    for k in keys:
        ma, mb = mean([get(f, k) for f in ja]), mean([get(f, k) for f in jb])
        parts.append('%s %.0f -> %.0f (%+.0f)' % (k, ma, mb, mb - ma))
    print('%-13s pixels %d same, %d differ%s; %s' % (n, same, diff, (' (first ' + first + ')') if first else '', '; '.join(parts)))
print('PIXELS', 'IDENTICAL' if not bad else 'DIFFER')
