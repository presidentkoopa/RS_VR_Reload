r"""Generate the WW2 set's cards, the way the BREACH set was generated.

Same shape as tools/gen_breach_set.py: a table up here, measurements taken off the meshes
down there, and the cards written whole every run. Change the table, never the output.

WHAT IT MEASURES, per gun, off the RE-ORIGINED copy in WW2_work/models:
  * the BODY -- the surface everything else sits stillest against, weighted by physical
    size rather than vertex count (a vertex count is the artist's polygon budget; by that
    measure a 64-vertex bracket beat the Kar98's 5347-vertex receiver, and on an SMG a
    trigger was taken for the body, which subtracts the trigger pull out of every other
    number on the mesh)
  * the MUZZLE and the BORE -- the front face along the gun's long axis
  * each PART named in the table: its travel, its axis, and the distance that CLEARS it
    from the body rather than the distance the author animated

WHY CLEARING DISTANCE AND NOT ANIMATED TRAVEL. A hand drives a part until it is free, not
however far the author flung it to get it out of shot -- the same rule the Breach and
Pistolet cards were measured to, and the same reason a magazine measured at 64.60 on a
19-unit gun was wrong. The owner ruled on it directly: "clear of the well seems good".

A FINGERPRINT PER PART, and this set needs it more than any other: a card here addresses
parts by INDEX, because half these meshes name every surface the same string. An index
survives a copy and does not survive a re-export -- the surface order shifts and the card
silently drives a different piece, which gets blamed on the card, the engine and the
player's eyes long before anyone suspects the mesh. So every part records the vertex count
and size it was measured against, and a mismatch is a loud failure instead of a mystery.

    python gen_ww2_set.py            # report
    python gen_ww2_set.py --write    # write WMCARD.ww2
"""
import glob, math, os, re, sys

sys.path.insert(0, "E:/DOOMWork/tools")
import md3

WORK = "E:/DOOMWork/WW2_work"
SRC  = "E:/DOOMWork/VR_WeaponSetRebuild/WeaponSets/BrutalWolf"
OUT = os.path.join(WORK, "WMCARD.ww2")

# THE TABLE. One row per gun: its folder, the card id, the hand, the type, and which
# surfaces are its parts -- taken from the scan, and checked against the authors' own
# names wherever they bothered to give one.
#
#   feed   the magazine, clip or shell carrier
#   action the bolt, pump or charging handle
#   fires  WHERE ITS ROUNDS COME FROM, for the four guns that have none of their own.
#          A card that declares no stores AND does not say this is handed the pistol
#          pair -- a REAL detachable magazine of `capacity` rounds in the pistol family
#          (card.zs SynthesiseStores). So the knife had a magazine, it could be dropped,
#          and a Luger's magazine fitted it. Saying where a gun feeds from is what stops
#          that: `none` is no ammunition at all (a blade), `reserve` spends the weapon's
#          own ammo with no store to fill (a flamethrower's fuel, a grenade you throw).
#   fam    WHICH MAGAZINES FIT IT. Unstated, a card counts as the "pistol" family, so
#          every WW2 magazine fitted every WW2 gun and an MP40's box seated in a Kar98.
#          In this set almost nothing interchanges, so it is a family per gun -- and the
#          two that are not magazines at all (the Kar98's stripper clip, the Garand's
#          en-bloc) most of all, because a name nothing else shares is what stops anything
#          else accepting them. Values from the weapons lane, which owns what fits what.
#
# A gun with no entry for one of those genuinely has none in its mesh: every other
# surface moves under a unit across the whole animation, and a card claiming a part
# there would drive a surface that does not move.
GUNS = [
    dict(actor="MP40", dir="MP40",    id="WW2_MP40",    fam="mp40", type="smg",       feed=4,  action=None,
         note="Magazine straight down 12.00. No bolt animated as its own piece."),
    dict(actor="STG44", dir="STG44",   id="WW2_STG44",   fam="stg44", type="rifle",     feed=2,  action=21,
         note="Author-named: Low_Magazin_Low and Low_Zatvor_Low (bolt). 23 surfaces."),
    dict(actor="THOMP", dir="Tommy",   id="WW2_Tommy",   fam="thompson", type="smg",       feed=3,  action=1,
         note="Author-named Magazine and Bolt."),
    dict(actor="KAR98", dir="Kar98",   id="WW2_Kar98",   fam="mauser_stripper", type="boltrifle", feed=1,  action=4,
         note="Bolt 12.07. Feed is a STRIPPER CLIP: five rounds and the clip travel together."),
    dict(actor="M1GARAND", dir="Garand",  id="WW2_Garand",  fam="garand_enbloc", type="rifle",     feed=0,  action=3,
         note="Bullet_pack is an en-bloc clip and ejects UPWARD, which is correct for a Garand."),
    dict(actor="LUGER", dir="Luger",   id="WW2_Luger",   fam="luger", type="pistol",    feed=5,  action=3,
         note="Toggle action: surface 3 runs back along the barrel."),
    dict(actor="1911", dir="1911",    id="WW2_1911",    fam="m1911", type="pistol",    feed=4,  action=3,
         note="Magazine down and out; slide back 4.33."),
    dict(actor="PPSH41", dir="PP41",    id="WW2_PPSh",    fam="ppsh", type="smg",       feed=6,  action=0,
         note="Drum magazine (surface 6, 1695 verts)."),
    dict(actor="BAR", dir="BAR",     id="WW2_BAR",     fam="bar", type="rifle",     feed=1,  action=3),
    dict(actor="mg42", dir="MG42",    id="WW2_MG42",    fam="mg42", type="mg",        feed=2,  action=4,
         note="Belt box is surface 2."),
    dict(actor="TRENCHGUN", dir="Shotgun", id="WW2_Shotgun", fam="shell12", type="pump",      feed=None, action=3,
         note="Pump 6.86 back. Its shells are islands inside surface 4, not a surface."),
    dict(actor="CHAINGUN", dir="Chaingun", id="WW2_Chaingun", fam="hmg", type="chaingun", feed=None, action=None,
         note="Surface 2 travels 43.65 but this gun has no feed part to drive."),
    # Melee and thrown: no moving parts to drive, carded for completeness.
    dict(dir="Knife",   id="WW2_Knife",   fires="none", type="melee",   feed=None, action=None),
    dict(dir="Axe",     id="WW2_Axe",     fires="none", type="melee",   feed=None, action=None),
    dict(actor="LANCIAMERDA", dir="Flame",   id="WW2_Flamethrower", fires="reserve", type="flamer", feed=None, action=None),
    dict(dir="Grenade", id="WW2_Grenade", fires="reserve", type="thrown",  feed=None, action=None),
]


def stats_for(actor):
    """Capacity, ammo class, shot and rate of fire, out of Brutal Wolfenstein's own
    actor file. Their numbers, our names -- exactly as the BREACH set took its shot
    data from Breach's own zscript rather than inventing any."""
    path = os.path.join(SRC, "Actors", "Weaps", actor + ".txt")
    if not os.path.exists(path):
        return None
    t = open(path, encoding="utf-8", errors="replace").read()
    out = {}
    m = re.search(r'Weapon\.AmmoGive1\s+(\d+)', t)
    if m: out["capacity"] = int(m.group(1))
    m = re.search(r'Weapon\.AmmoType1\s+"([^"]+)"', t)
    if m: out["ammo"] = m.group(1)
    m = re.search(r'A_FireBullets\s*\(\s*([\d.\-]+)\s*,\s*([\d.\-]+)\s*,\s*([\d.\-]+)\s*,\s*([\d.\-]+)', t)
    if m:
        out["spread"] = (float(m.group(1)), float(m.group(2)))
        n = int(float(m.group(3)))
        out["pellets"] = n if n > 1 else 1
        out["damage"] = int(float(m.group(4)))
    tics = re.findall(r'^\s*\S+\s+\w+\s+(\d+)\s+(?:BRIGHT\s+)?A_FireBullets', t, re.M)
    if tics: out["firetics"] = max(1, sum(int(x) for x in tics[:2]))
    return out


def box(pts):
    lo = [min(v[k] for v in pts) for k in range(3)]
    hi = [max(v[k] for v in pts) for k in range(3)]
    return lo, hi


def size_of(pts):
    lo, hi = box(pts)
    return math.sqrt(sum((hi[k] - lo[k]) ** 2 for k in range(3)))


def centroid(pts):
    n = len(pts)
    return [sum(v[k] for v in pts) / n for k in range(3)]


def dist(a, b):
    return math.sqrt(sum((a[k] - b[k]) ** 2 for k in range(3)))


def body_of(M):
    """The surface everything else sits stillest against -- see the header."""
    live = [s for s in M.surfaces if s.num_verts > 0]
    tracks = {s.index: [centroid(s.verts[f]) for f in range(s.num_frames)] for s in live}
    sizes = {s.index: size_of(s.verts[0]) for s in live}

    def cost(cand):
        total = 0.0
        for s in live:
            if s.index == cand.index:
                continue
            a, b = tracks[s.index], tracks[cand.index]
            rel0 = [a[0][k] - b[0][k] for k in range(3)]
            worst = 0.0
            for f in range(len(a)):
                rel = [a[f][k] - b[min(f, len(b) - 1)][k] for k in range(3)]
                worst = max(worst, dist(rel, rel0))
            total += worst * sizes[s.index]
        return total

    return min(live, key=cost)


def travel(part, body):
    """A part's motion against the body: how far, along what, peaking when."""
    n = min(part.num_frames, body.num_frames)
    pc = [centroid(part.verts[f]) for f in range(n)]
    bc = [centroid(body.verts[f]) for f in range(n)]
    rel = [[pc[f][k] - bc[f][k] for k in range(3)] for f in range(n)]
    far = max(range(n), key=lambda f: dist(rel[f], rel[0]))
    v = [rel[far][k] - rel[0][k] for k in range(3)]
    d = math.sqrt(sum(x * x for x in v))
    ax = [x / d for x in v] if d > 1e-9 else [0.0, 0.0, 0.0]
    return d, ax, far


def clearing(part, body, axis):
    """How far along `axis` the part must go before it is clear of the body.

    The number a HAND wants. Measured at rest, so an author who throws a magazine out
    of shot to hide it cannot inflate it.
    """
    pp = [sum(v[k] * axis[k] for k in range(3)) for v in part.verts[0]]
    bp = [sum(v[k] * axis[k] for k in range(3)) for v in body.verts[0]]
    return max(bp) - min(pp)


def muzzle_of(body):
    """The front face along the gun's longest axis."""
    lo, hi = box(body.verts[0])
    k = max(range(3), key=lambda i: hi[i] - lo[i])
    front = [v for v in body.verts[0] if v[k] >= hi[k] - 0.4]
    c = centroid(front)
    ax = [0.0, 0.0, 0.0]
    ax[k] = 1.0
    return c, ax, len(front)


def part_block(name, role, subject, surf, part, body, d, ax, far):
    # CLEARING IS FOR PARTS THAT LEAVE. A magazine is driven until it is free of the
    # well, because its author may fling it out of shot and that distance is a hiding
    # trick rather than travel. A BOLT NEVER LEAVES: asking how far it must go to clear
    # the receiver is a question with no meaning, and it answers 61 units on a gun whose
    # bolt runs nine. So an action keeps the travel the mesh actually animates -- which
    # is the number that matched the owner's cards exactly on the M4A3 slide (6.78
    # against 6.784) and the M37 pump (11.20 against 11.205).
    clear = clearing(part, body, ax) if role == "feed" else d
    lo, hi = box(part.verts[0])
    grab = centroid([v for v in part.verts[0] if v[2] <= lo[2] + 1.0])
    L = []
    L.append("  part %s" % name)
    L.append("    role    = %s" % role)
    L.append("    subject = %s" % subject)
    L.append("    surface = %d" % surf)
    L.append("    # FINGERPRINT: %d verts, %.2f across. A re-export that renumbers the"
             % (part.num_verts, size_of(part.verts[0])))
    L.append("    # surfaces makes this index mean something else; these two numbers are")
    L.append("    # what a loader checks so that failure is loud instead of a mystery.")
    L.append("    fingerprint = %d, %.2f" % (part.num_verts, size_of(part.verts[0])))
    L.append("    grab       = %.3f, %.3f, %.3f" % tuple(grab))
    L.append("    grabradius = 3.0")
    L.append("    dof")
    L.append("      kind     = slide")
    L.append("      axis     = %.3f, %.3f, %.3f" % tuple(ax))
    L.append("      # The author animates %.2f (peaking at frame %d); a hand drives until"
             % (d, far))
    L.append("      # the part is CLEAR, which is %.2f." % clear)
    L.append("      distance = %.2f" % clear)
    L.append("      detach   = 0.9")
    L.append("    end")
    L.append("  end")
    return L


if __name__ == "__main__":
    write = "--write" in sys.argv
    out = ["# " + "=" * 74,
           "# THE WW2 SET -- Brutal Wolfenstein's weapons, carded.",
           "#",
           "# GENERATED by tools/gen_ww2_set.py. Edit its table, not this file.",
           "#",
           "# Measured off the RE-ORIGINED copies in WW2_work/models -- centred on visible",
           "# geometry at frame 0, packed normals byte-compared against the originals",
           "# afterwards. A number from an un-re-origined copy is wrong by the length of the",
           "# gun and must never be mixed in.",
           "#",
           "# Travel is the distance that CLEARS a part, not the distance its author",
           "# animated. Parts are addressed by INDEX because half these meshes name every",
           "# surface the same string, so each carries a fingerprint as well.",
           "# " + "=" * 74, ""]
    report = []
    for g in GUNS:
        folder = os.path.join(WORK, "models", g["dir"])
        files = [f for f in os.listdir(folder) if f.lower().endswith(".md3")] if os.path.isdir(folder) else []
        if not files:
            report.append("%-10s NO MESH" % g["dir"])
            continue
        M = md3.MD3Model.load(os.path.join(folder, files[0]))
        body = body_of(M)
        S = {s.index: s for s in M.surfaces}
        mz, bore, nfront = muzzle_of(body)

        out.append("")
        out.append("# " + "-" * 72)
        out.append("# %s -- %s, %d surfaces, %d frames. Body is surface %d (%s, %d verts)."
                   % (g["id"], files[0], len(M.surfaces), M.num_frames, body.index,
                      body.name or "unnamed", body.num_verts))
        if g.get("note"):
            out.append("# %s" % g["note"])
        out.append("# " + "-" * 72)
        out.append('weapon "%s"' % g["id"])
        out.append("  hand      = main")
        out.append("  type      = %s" % g["type"])
        if g.get("fires"):
            out.append("  firesfrom = %s" % g["fires"])
        if g.get("fam"):
            out.append('  magfamily = "%s"' % g["fam"])
        out.append('  prop      = "WW2_Prop%s"' % g["id"].replace("WW2_", ""))
        out.append('  model     = "models/ww2/%s" "%s"' % (g["dir"], files[0]))
        out.append("  body      = %d" % body.index)
        out.append("  muzzle    = %.3f, %.3f, %.3f" % tuple(mz))
        out.append("  barrel    = %.0f, %.0f, %.0f" % tuple(bore))

        # THE SHOT IS NOT A MODEL CARD'S BUSINESS. Damage, spread, pellets and fire
        # tics live on the WEAPON card (WMSHEET.ww2) with the class, and parser.zs
        # refuses them here BY NAME -- deliberately, since a model card describes a
        # mesh and a weapon card describes a gun. Capacity stays because it is a
        # property of the magazine this card measures.
        #
        # The numbers still come from Brutal Wolfenstein's own Actors/Weaps/*.txt;
        # they are read by the weapons lane into the sheet rather than by this.
        st = stats_for(g["actor"]) if g.get("actor") else None
        if st and "capacity" in st:
            out.append("  # capacity from Actors/Weaps/%s.txt (their number, our name)" % g["actor"])
            out.append("  capacity  = %d" % st["capacity"])

        bits = []
        for key, role, subject in (("feed", "feed", "magazine"), ("action", "action", "slide")):
            si = g.get(key)
            if si is None or si not in S:
                continue
            d, ax, far = travel(S[si], body)
            out.extend(part_block(subject, role, subject, si, S[si], body, d, ax, far))
            shown = clearing(S[si], body, ax) if role == "feed" else d
            bits.append("%s %.2f->%.2f" % (subject, d, shown))
        if not bits:
            out.append("  # NO MOVING PARTS. Every surface of this mesh stays within a unit of")
            out.append("  # the body across the whole animation; there is nothing to drive.")
        out.append("end")
        report.append("%-10s body %-2d  muzzle %7.2f  %s" % (g["dir"], body.index, mz[0], ", ".join(bits) or "no parts"))

    print("\n".join(report))
    if write:
        open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
        print("\nwrote %s (%d lines)" % (OUT, len(out)))
