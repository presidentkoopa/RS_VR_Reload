"""Does a gun's SUPPORT point sit on a part, or in open space? (reload lane, for the body/hands lane, 2026-09-18)

THE QUESTION, from the body lane: a contact point is a PLACE and the subject is what the hand DOES there -- on a
shotgun you brace where you rack. If a card's support point lands on or near a part that already exists, then a support
point is a one-word reference (`support = mag | forend | grip`) plus a nudge, and 200 weapons are tractable. If support
points mostly land in open space, that claim is wrong and the owner's tuning sphere carries the load.

This measures it and reports whatever it finds. Nothing is snapped or tuned to make the answer tidier: where a support
point is far from every part, the table says FAR and names the nearest anyway.

UNITS: a card's points are in the model's own space; its grab RADII are map units. A gun's MODELDEF Scale converts one
to the other, so every distance is given in map units (the yardstick a hand actually reaches with, radius 3.0 typical)
with the model-space number beside it.

NOTE ON TRUST: a support point is a HAND OPINION, not a fact about the mesh -- nobody has confirmed one in a headset,
and they were fitted to the RS hand at its size. Read the PART IDENTITY here, not the offset.

    python support_points.py            # -> SUPPORT_POINTS.md beside this script
"""
import glob, os, re
import numpy as np

CARDS = sorted(glob.glob("E:/DOOMWork/RS_VR_Weapons/WMCARD.*") + glob.glob("E:/DOOMWork/RS_Modern/WMCARD.*"))
MODELDEFS = ["E:/DOOMWork/RS_VR_Weapons/MODELDEF.txt", "E:/DOOMWork/RS_Modern/MODELDEF.txt"]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "SUPPORT_POINTS.md")
NEAR = 3.0        # a typical grabradius, in map units: "the same place" if a hand reaching one would touch the other


def num3(v):
    n = re.findall(r'-?\d+\.?\d*', v)
    return [float(x) for x in n[:3]] if len(n) >= 3 else None


def read_cards():
    guns = []
    for path in CARDS:
        gun = part = None
        stack = []
        for raw in open(path, encoding="utf-8", errors="replace"):
            s = raw.split("#")[0].strip()
            if not s:
                continue
            m = re.match(r'^weapon\s+"([^"]+)"', s)
            if m:
                gun = dict(cls=m.group(1), file=os.path.basename(path), parts=[], prop=None)
                guns.append(gun)
                stack = ["weapon"]
                part = None
                continue
            if gun is None:
                continue
            m = re.match(r'^part\s+([a-z_0-9]+)\s*$', s)
            if m:
                part = dict(id=m.group(1), role=None, subject=None, grab=None, at=None, pivot=None)
                gun["parts"].append(part)
                stack.append("part")
                continue
            if re.match(r'^(dof|cycle|load|store|mechanism|feed|link|spin|flip)\b', s) and "=" not in s:
                stack.append("block")
                continue
            if s == "end":
                if stack:
                    closed = stack.pop()
                    if closed == "part":
                        part = None
                continue
            m = re.match(r'^([a-z_]+)\s*=\s*(.+?)$', s)
            if not m:
                continue
            k, v = m.group(1), m.group(2).strip()
            if k == "prop":
                gun["prop"] = v.strip('"')
            elif part is not None:
                if k in ("grab", "at", "pivot"):
                    p = num3(v)
                    if p:
                        part[k] = p
                elif k in ("role", "subject"):
                    part[k] = v.strip('"')
    return guns


def read_scales():
    sc, cls = {}, None
    for path in MODELDEFS:
        if not os.path.exists(path):
            continue
        for raw in open(path, encoding="utf-8", errors="replace"):
            s = raw.split("//")[0].strip()
            m = re.match(r'^Model\s+(\S+)', s)
            if m and not m.group(1).isdigit():
                cls = m.group(1)
            m = re.match(r'^Scale\s+(-?\d+\.?\d*)', s)
            if m and cls:
                sc[cls] = abs(float(m.group(1)))   # a mirrored gun's scale is negative; a distance is not
    return sc


def place(p):
    """Where a part is, for this comparison: its grab if it has one, else its pivot or its `at`."""
    for k in ("grab", "at", "pivot"):
        if p[k]:
            return np.array(p[k], float), k
    return None, None


if __name__ == "__main__":
    guns, scales = read_cards(), read_scales()
    rows, far, no_support = [], 0, []
    for g in guns:
        sup = next((p for p in g["parts"] if p["id"] == "support" or p["subject"] == "support"), None)
        others = [p for p in g["parts"] if p is not sup]
        if not sup or sup["grab"] is None:
            no_support.append(g["cls"])
            continue
        s = np.array(sup["grab"], float)
        scale = scales.get(g["prop"] or "", None)
        best = []
        for p in others:
            q, src = place(p)
            if q is None:
                continue
            d = float(np.linalg.norm(s - q))
            best.append((d, p["id"], p["subject"] or p["role"] or "-", src))
        best.sort()
        if not best:
            rows.append((g["cls"], "-", "-", None, None, scale, "ONLY PART"))
            continue
        d, pid, subj, src = best[0]
        dmap = d * scale if scale else None
        verdict = "?" if dmap is None else ("SAME PLACE" if dmap <= NEAR else ("NEAR" if dmap <= 2 * NEAR else "FAR"))
        if verdict == "FAR":
            far += 1
        rows.append((g["cls"], pid, subj, d, dmap, scale, verdict))

    rows.sort(key=lambda r: (r[4] is None, r[4] if r[4] is not None else 0))
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("# Where a gun's SUPPORT point actually sits (reload lane, 2026-09-18)\n\n"
                 "For every card with a support point: the distance to the NEAREST other part, and which part it was. "
                 "Nothing is snapped -- a support point far from everything is reported as FAR.\n\n"
                 "Distances are MAP units (a gun's MODELDEF Scale applied to its model-space points), because a grab "
                 "radius is map units and 3.0 is typical. **SAME PLACE** = within one grab radius, so a hand reaching "
                 "one would touch the other. **NEAR** = within two. **FAR** = further.\n\n"
                 "A support point is a HAND OPINION, unconfirmed in a headset and fitted to the RS hand's size. "
                 "The trustworthy column here is the part identity, not the number.\n\n"
                 "| Gun | Nearest part | Its subject | Map units | Model units | Scale | |\n"
                 "|---|---|---|---|---|---|---|\n")
        for cls, pid, subj, d, dmap, scale, verdict in rows:
            fh.write("| %s | %s | %s | %s | %s | %s | %s |\n"
                     % (cls, pid, subj,
                        "%.2f" % dmap if dmap is not None else "?",
                        "%.2f" % d if d is not None else "-",
                        "%.3f" % scale if scale else "?", verdict))
        tot = len(rows)
        same = sum(1 for r in rows if r[6] == "SAME PLACE")
        near = sum(1 for r in rows if r[6] == "NEAR")
        fh.write("\n## What it says\n\n"
                 "- %d cards carry a support point; %d carry none.\n"
                 "- **%d of %d land on an existing part** (within one grab radius), %d within two, %d further off.\n"
                 % (tot, len(no_support), same, tot, near, far))
    print("wrote %s -- %d gun(s) with a support point, %d without" % (OUT, len(rows), len(no_support)))
    for cls, pid, subj, d, dmap, scale, verdict in rows:
        print("  %-26s %-16s %-12s %s" % (cls, pid, subj, ("%.2f map" % dmap) if dmap else "?"), verdict)
