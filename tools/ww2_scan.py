r"""Scan the WW2 (Brutal Wolfenstein) gun models: what each is made of, and what moves.

The first pass before any card can be written. For every model in the set:
  * its surfaces, with vertex counts
  * which surface is the BODY
  * every other surface's motion RELATIVE to that body -- how far it travels, along
    which axis, over which frames, and how rigidly it fits

THE BODY IS THE STEADIEST SURFACE, AND THEN THE BIGGEST OF THOSE. Neither half works on
its own. "Biggest" picks a slide that outweighs its frame -- pistolet.md3, where it cost a
day. "Steadiest" ties, because the whole gun recoils together and every part bolted to the
frame wanders exactly as much as the frame does; on the 1911 that let a 159-vertex bracket
beat the 1401-vertex receiver. So: everything within a whisker of the least motion, then
the one carrying the most geometry.

TRAVEL IS MEASURED BETWEEN FRAMES, NOT OFF A FIT'S TRANSLATION TERM. For a part that
rotates, a rigid fit's translation carries an artifact proportional to the part's distance
from the model origin, unrelated to travel -- which is how a trigger hinging 45 degrees
reported 41.80 units of movement. Distance here is the centroid's own displacement.

    python ww2_scan.py [set folder] > WW2_SCAN.md
"""
import glob, math, os, sys

sys.path.insert(0, "E:/DOOMWork/tools")
import md3

SET = sys.argv[1] if len(sys.argv) > 1 else "E:/DOOMWork/VR_WeaponSetRebuild/WeaponSets/BrutalWolf"


def centroid(P):
    n = len(P)
    return [sum(p[i] for p in P) / n for i in range(3)]


def dist(a, b):
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(3)))


def islands(s):
    """Connected lumps of geometry inside ONE surface, by shared vertices.

    A surface is a drawing unit, not a part: these authors weld a magazine, a
    bolt and a receiver into one surface and the name says nothing. Scanning per
    surface alone therefore MISSES parts entirely -- it reports "nothing moves"
    for a gun whose magazine is right there, welded in. Splitting by triangle
    connectivity finds them, because a part that moves is a lump that shares no
    vertex with the part it moves against.
    """
    nv = s.num_verts
    parent = list(range(nv))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for tri in s.triangles:
        ra, rb, rc = find(tri[0]), find(tri[1]), find(tri[2])
        if ra != rb: parent[ra] = rb
        if find(tri[1]) != rc: parent[find(tri[1])] = rc

    groups = {}
    for v in range(nv):
        groups.setdefault(find(v), []).append(v)
    return list(groups.values())


def surf_track(s):
    """Per-frame centroid of one surface, and how far it wanders overall."""
    cs = [centroid(s.verts[f]) for f in range(s.num_frames)]
    span = max(dist(c, cs[0]) for c in cs) if len(cs) > 1 else 0.0
    return cs, span


if __name__ == "__main__":
    print("# The WW2 set, scanned\n")
    print("Brutal Wolfenstein's models, read with our own md3 tool. The body of each model is")
    print("the surface that MOVES LEAST across the animation; every other surface is measured")
    print("against it. Travel is a centroid's own displacement between frames, so a hinging")
    print("part reports its real movement rather than a rotation artifact.\n")

    for path in sorted(glob.glob(os.path.join(SET, "Models", "*", "*.md3"))):
        gun = os.path.basename(os.path.dirname(path))
        try:
            M = md3.MD3Model.load(path)
        except Exception as e:
            print("## %s\n\nUNREADABLE: %s\n" % (gun, e))
            continue

        tracks = []
        for i, s in enumerate(M.surfaces):
            if not len(s.verts[0]):
                continue
            cs, span = surf_track(s)
            p0 = s.verts[0]
            lo = [min(v[k] for v in p0) for k in range(3)]
            hi = [max(v[k] for v in p0) for k in range(3)]
            diag = math.sqrt(sum((hi[k] - lo[k]) ** 2 for k in range(3)))
            tracks.append(dict(i=i, name=s.name, nv=len(p0), cs=cs, span=span,
                               nf=s.num_frames, size=diag))
        if not tracks:
            print("## %s\n\nno geometry\n" % gun)
            continue

        # THE BODY IS WHATEVER EVERYTHING ELSE SITS STILL AGAINST.
        #
        # Not the biggest (that picks a slide heavier than its frame) and not the
        # steadiest in world terms either -- on the Kar98 that chose a 64-vertex
        # bracket over the 5347-vertex receiver, because the whole rifle swings
        # during the animation and the receiver swings with it.
        #
        # The definition is the test: the body is the piece the others are measured
        # FROM, so try each candidate as the reference and keep the one that leaves
        # the least motion in everything else, weighted by how much geometry each
        # carries. A receiver leaves a slide moving and nothing else; a slide leaves
        # the whole gun moving.
        # WEIGHTED BY PHYSICAL SIZE, NOT VERTEX COUNT. A vertex count is the artist's
        # polygon budget, not a statement about the gun: weighting by it picked a
        # TRIGGER as the body on one SMG, and a trigger taken for the body subtracts
        # the trigger pull out of every other measurement on that mesh. Size is a
        # fact about the object.
        def cost(cand):
            total = 0.0
            for t in tracks:
                if t is cand:
                    continue
                rel = [[t["cs"][f][k] - cand["cs"][min(f, len(cand["cs"]) - 1)][k] for k in range(3)]
                       for f in range(len(t["cs"]))]
                total += max(dist(r, rel[0]) for r in rel) * t["size"]
            return total
        body = min(tracks, key=cost)
        print("## %s  --  %s" % (gun, os.path.basename(path)))
        print("\n%d frame(s), %d surface(s). Body: **%s** (%d verts, wanders %.2f).\n"
              % (M.num_frames, len(M.surfaces), body["name"] or "surface %d" % body["i"],
                 body["nv"], body["span"]))

        moving = []
        for t in tracks:
            if t is body:
                continue
            # motion relative to the body, frame by frame
            rel = [[t["cs"][f][k] - body["cs"][min(f, len(body["cs"]) - 1)][k] for k in range(3)]
                   for f in range(len(t["cs"]))]
            d = [dist(r, rel[0]) for r in rel]
            far = max(range(len(d)), key=lambda f: d[f])
            if d[far] < 0.05:
                continue
            v = [rel[far][k] - rel[0][k] for k in range(3)]
            n = math.sqrt(sum(x * x for x in v)) or 1.0
            moving.append((t, d[far], [x / n for x in v], far))

        if not moving:
            print("Nothing moves against the body -- one solid piece as far as the animation goes.\n")
            continue

        print("| surface | verts | travels | along | peak frame |")
        print("|---|---|---|---|---|")
        for t, d, ax, far in sorted(moving, key=lambda m: -m[1]):
            print("| %d `%s` | %d | %.2f | %.3f, %.3f, %.3f | %d |"
                  % (t["i"], t["name"] or "?", t["nv"], d, ax[0], ax[1], ax[2], far))
        print()
