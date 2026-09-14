# Measure a card's mesh for grab points: every surface's bounds, the islands of chosen surfaces, and the
# whole mesh's underside profile along x. Read-only; uses tools/md3.py and tools/card_skeleton.py.
#   python measure.py MESH [--islands SURF,SURF] [--frame N] [--xbin 2.0] [--min-verts 12]
import sys, os, argparse, collections
sys.path.insert(0, 'E:/DOOMWork/tools')
import md3, card_skeleton as cs

def load(p):
    for name in ('read', 'load', 'from_file', 'parse', 'open'):
        f = getattr(md3.MD3Model, name, None)
        if f:
            try:
                return f(p)
            except TypeError:
                pass
    return md3.MD3Model(p)

def bb(pts):
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return lo, hi

def fmt(v):
    return '(' + ', '.join('%.2f' % c for c in v) + ')'

ap = argparse.ArgumentParser()
ap.add_argument('mesh')
ap.add_argument('--islands', default='')
ap.add_argument('--frame', type=int, default=0)
ap.add_argument('--xbin', type=float, default=2.0)
ap.add_argument('--min-verts', type=int, default=12)
a = ap.parse_args()

m = load(a.mesh)
f = a.frame
print('MESH', a.mesh, 'frames', m.surfaces[0].num_frames if m.surfaces else 0)
allpts = []
for s in m.surfaces:
    pts = s.verts[f]
    allpts += [(p, s.name) for p in pts]
    lo, hi = bb(pts)
    c = cs.centroid(pts)
    print('  SURF %-18s v%5d  min %s max %s  half %s  centroid %s' % (
        s.name, len(pts), fmt(lo), fmt(hi), fmt([(h - l) / 2 for l, h in zip(lo, hi)]), fmt(c)))

want = [w for w in a.islands.split(',') if w]
if a.islands == '*':
    want = [s.name for s in m.surfaces]
for s in m.surfaces:
    if s.name not in want:
        continue
    isl = cs.islands(s, f)
    print('  ISLANDS of %s: %d' % (s.name, len(isl)))
    for k, ids in enumerate(isl):
        if len(ids) < a.min_verts:
            continue
        pts = [s.verts[f][i] for i in ids]
        lo, hi = bb(pts)
        print('    #%-2d v%5d  min %s max %s  half %s  centroid %s' % (
            k, len(ids), fmt(lo), fmt(hi), fmt([(h - l) / 2 for l, h in zip(lo, hi)]), fmt(cs.centroid(pts))))

# THE UNDERSIDE: per x bin, the lowest vertex (and which surface), and how wide the mesh is across there.
bins = collections.defaultdict(list)
for p, name in allpts:
    bins[int((p[0]) // a.xbin)].append((p, name))
print('  UNDERSIDE (x bin %.1f): x_from  low_z  at_y  surface  | top_z  | y_span at the lowest 1.0' % a.xbin)
for b in sorted(bins):
    ps = bins[b]
    low = min(ps, key=lambda q: q[0][2])
    top = max(q[0][2] for q in ps)
    near = [q[0][1] for q in ps if q[0][2] <= low[0][2] + 1.0]
    print('    %7.1f  %7.2f  %6.2f  %-16s | %7.2f | %6.2f..%6.2f' % (
        b * a.xbin, low[0][2], low[0][1], low[1], top, min(near), max(near)))
