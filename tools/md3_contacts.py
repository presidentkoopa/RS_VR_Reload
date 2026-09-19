"""Where a vanilla gun's contact points land on its mesh -- the md3 half of the hand-posing survey (2026-09-18).

The IQM pass (RS_Modern/tools/breach_bindpoints.py) did the ten Breach guns and turned up brace points floating 4-6
units off the gun. This does the same for the md3 guns, which is where the owner's actual symptom lives (a pump
shotgun's off hand facing the chest, pistol slides wrong).

md3 IS SIMPLER THAN IQM: no skeleton and no skinning palette. A frame's vertices ARE the model space the card's points
were measured in, so nothing has to be carried anywhere -- what is measured here is exactly what the card names. Parts
are named SURFACES rather than joints, so a part's grab can be checked against its OWN surface, which the IQM pass
could not do.

FOR EVERY CONTACT POINT: the surface it belongs to, the nearest point on the mesh, how far off it sits, the outward
normal there, and -- when the mesh wraps the point so no single surface faces it -- no normal at all rather than an
artefact, plus the walls found by firing rays out from it perpendicular to the bore.

    python md3_contacts.py [--types shotgun,pistol] [--all]
"""
import argparse, glob, json, math, os, re, struct
import numpy as np

CARDS = sorted(glob.glob("E:/DOOMWork/RS_VR_Weapons/WMCARD.*"))
MODELDEF = "E:/DOOMWork/RS_VR_Weapons/MODELDEF.txt"
ROOTS = ["E:/DOOMWork/RS_VR_Weapons/", "E:/DOOMWork/RS_Main/"]
HERE = os.path.dirname(os.path.abspath(__file__))
COHERE = 0.35      # under this, the mesh wraps the point and a normal there would be an artefact (the IQM pass's rule)


# ---- cards and MODELDEF ------------------------------------------------------------------------------------------
def num3(v):
    n = re.findall(r'-?\d+\.?\d*', v)
    return [float(x) for x in n[:3]] if len(n) >= 3 else None


def read_cards():
    guns, gun, part, stack = [], None, None, []
    for path in CARDS:
        for raw in open(path, encoding="utf-8", errors="replace"):
            s = raw.split("#")[0].strip()
            if not s:
                continue
            m = re.match(r'^weapon\s+"([^"]+)"', s)
            if m:
                gun = dict(cls=m.group(1), file=os.path.basename(path), parts=[], prop=None, type=None,
                           muzzle=None, barrel=None, model=None)
                guns.append(gun)
                stack, part = ["weapon"], None
                continue
            if gun is None:
                continue
            m = re.match(r'^part\s+([a-z_0-9]+)\s*$', s)
            if m:
                part = dict(id=m.group(1), subject=None, role=None, grab=None, handseat=None, surface=[])
                gun["parts"].append(part)
                stack.append("part")
                continue
            if re.match(r'^(dof|cycle|load|store|mechanism|feed|link|spin|flip)\b', s) and "=" not in s:
                stack.append("block")
                continue
            if s == "end":
                if stack and stack.pop() == "part":
                    part = None
                continue
            m = re.match(r'^([a-z_]+)\s*=\s*(.+?)$', s)
            if not m:
                continue
            k, v = m.group(1), m.group(2).strip()
            if part is not None:
                if k in ("grab", "handseat"):
                    p = num3(v)
                    if p:
                        part[k] = p
                elif k == "surface":
                    part["surface"].append(v.strip('"'))   # a part may name several (mag + mag.001, a spare's twin)
                elif k in ("subject", "role"):
                    part[k] = v.strip('"')
            elif k == "prop":
                gun["prop"] = v.strip('"')
            elif k == "type":
                gun["type"] = v.strip('"')
            elif k == "model":
                q = re.findall(r'"([^"]+)"', v)
                if len(q) >= 2:
                    gun["model"] = (q[0], q[1])
            elif k in ("muzzle", "barrel"):
                gun[k] = num3(v)
    return guns


def read_modeldef():
    out, cls = {}, None
    for raw in open(MODELDEF, encoding="utf-8", errors="replace"):
        s = raw.split("//")[0].strip()
        m = re.match(r'^Model\s+(\S+)', s)
        if m and not m.group(1).isdigit():
            cls = m.group(1)
            out.setdefault(cls, dict(frame=0, scale=1.0))
        if not cls:
            continue
        m = re.match(r'^Scale\s+(-?\d+\.?\d*)', s)
        if m:
            out[cls]["scale"] = abs(float(m.group(1)))
        m = re.match(r'^FrameIndex\s+\S+\s+\S+\s+0\s+(\d+)', s)
        if m:
            out[cls]["frame"] = int(m.group(1))
    return out


# ---- md3 ---------------------------------------------------------------------------------------------------------
def read_md3(path, frame=0):
    d = open(path, "rb").read()
    ident, version = struct.unpack_from("<4si", d, 0)
    if ident != b"IDP3":
        raise ValueError("%s is not md3 (%r)" % (path, ident))
    num_frames, num_tags, num_surfaces, num_skins = struct.unpack_from("<4i", d, 76)
    ofs_frames, ofs_tags, ofs_surfaces, ofs_end = struct.unpack_from("<4i", d, 92)
    frame = min(frame, num_frames - 1)
    surfaces, o = [], ofs_surfaces
    for _ in range(num_surfaces):
        sid, name = struct.unpack_from("<4s64s", d, o)
        s_frames, s_shaders, s_verts, s_tris = struct.unpack_from("<4i", d, o + 72)
        s_ofs_tris, s_ofs_shaders, s_ofs_st, s_ofs_xyz, s_ofs_end = struct.unpack_from("<5i", d, o + 88)
        nm = name.split(b"\0")[0].decode("latin-1")
        tris = np.array(struct.unpack_from("<%di" % (s_tris * 3), d, o + s_ofs_tris)).reshape(-1, 3)
        f = min(frame, s_frames - 1)
        raw = np.array(struct.unpack_from("<%dh" % (s_verts * 4), d, o + s_ofs_xyz + f * s_verts * 8)).reshape(-1, 4)
        verts = raw[:, :3].astype(float) / 64.0
        surfaces.append(dict(name=nm, verts=verts, tris=tris))
        o += s_ofs_end
    return surfaces


def faces(surfaces, only=None):
    """Every triangle of the model (or of one named surface) as (a, b, c) corner arrays."""
    A, B, C, who = [], [], [], []
    for s in surfaces:
        if only is not None and s["name"].lower() != only.lower():
            continue
        v, t = s["verts"], s["tris"]
        if not len(t):
            continue
        A.append(v[t[:, 0]]); B.append(v[t[:, 1]]); C.append(v[t[:, 2]])
        who += [s["name"]] * len(t)
    if not A:
        return None
    return np.concatenate(A), np.concatenate(B), np.concatenate(C), who


def closest_on_faces(F, p):
    """Nearest point on the mesh to p, by projecting onto each triangle's plane and clamping to its corners."""
    a, b, c, who = F
    p = np.array(p, float)
    # sample the three corners and the centroid: enough for a distance-off-surface number on game meshes
    cand = np.stack([a, b, c, (a + b + c) / 3.0], axis=1)                   # (n, 4, 3)
    d = np.linalg.norm(cand - p[None, None, :], axis=2)
    i = int(np.argmin(d.min(axis=1)))
    j = int(np.argmin(d[i]))
    return cand[i, j], float(d[i, j]), who[i], i


def normal_at(F, p, k=24):
    a, b, c, who = F
    n = np.cross(b - a, c - a)
    area = np.linalg.norm(n, axis=1)
    ok = area > 1e-9
    n, area, cen = n[ok] / area[ok, None], area[ok], ((a + b + c) / 3.0)[ok]
    if not len(n):
        return None
    d = np.linalg.norm(cen - np.array(p, float)[None, :], axis=1)
    near = np.argsort(d)[:k]
    w = area[near] / (d[near] + 1e-6)
    v = (n[near] * w[:, None]).sum(axis=0)
    mag = float(np.linalg.norm(v))
    coh = mag / float(w.sum()) if w.sum() else 0.0
    if mag < 1e-9 or coh < COHERE:
        return dict(normal=None, coherence=round(coh, 3), enclosed=True,
                    note="the mesh wraps this point: no single surface faces it, so a normal would be an artefact")
    v /= mag
    hull = np.concatenate([a, b, c]).mean(axis=0)
    if np.dot(v, np.array(p, float) - hull) < 0:
        v = -v
    return dict(normal=[round(float(x), 3) for x in v], coherence=round(coh, 3), enclosed=False)


def outward(F, p, bore, n=32):
    """Walls found by firing rays out from p, perpendicular to the bore -- a measured outside surface, not a guess."""
    a, b, c, who = F
    p, bv = np.array(p, float), np.array(bore, float)
    bv /= (np.linalg.norm(bv) or 1.0)
    u = np.cross(bv, [0.0, 0.0, 1.0])
    if np.linalg.norm(u) < 1e-6:
        u = np.cross(bv, [0.0, 1.0, 0.0])
    u /= np.linalg.norm(u)
    v2 = np.cross(bv, u)
    e1, e2 = b - a, c - a
    hits = []
    for i in range(n):
        ang = 2.0 * math.pi * i / n
        dirv = math.cos(ang) * u + math.sin(ang) * v2
        h = np.cross(dirv, e2)
        det = np.einsum("ij,ij->i", e1, h)
        ok = np.abs(det) > 1e-9
        inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
        s = p[None, :] - a
        uu = inv * np.einsum("ij,ij->i", s, h)
        q = np.cross(s, e1)
        vv = inv * (q @ dirv)
        t = inv * np.einsum("ij,ij->i", e2, q)
        good = ok & (uu >= 0) & (uu <= 1) & (vv >= 0) & (uu + vv <= 1) & (t > 1e-4)
        if not good.any():
            continue
        j = int(np.argmin(np.where(good, t, np.inf)))
        nrm = np.cross(e1[j], e2[j])
        nrm /= (np.linalg.norm(nrm) or 1.0)
        if np.dot(nrm, dirv) > 0:
            nrm = -nrm
        hits.append(dict(deg=round(math.degrees(ang), 1), dist=round(float(t[j]), 3), surface=who[j],
                         at=[round(float(x), 3) for x in p + t[j] * dirv],
                         normal=[round(float(x), 3) for x in nrm]))
    return hits


def find_model(d, f):
    for r in ROOTS:
        p = os.path.join(r, d, f)
        if os.path.exists(p):
            return p
    return None


# ---- run ---------------------------------------------------------------------------------------------------------
if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--types", default="shotgun,pistol")
    ap.add_argument("--all", action="store_true")
    a = ap.parse_args()
    want = [t.strip() for t in a.types.split(",") if t.strip()]
    md, out_rows, skipped = read_modeldef(), [], []

    for g in read_cards():
        if not a.all and (g["type"] or "") not in want:
            continue
        if not g["model"]:
            skipped.append((g["cls"], "no model on the card"))
            continue
        path = find_model(*g["model"])
        if not path or not path.lower().endswith(".md3"):
            skipped.append((g["cls"], "not an md3 (%s)" % (g["model"][1])))
            continue
        info = md.get(g["prop"] or "", dict(frame=0, scale=1.0))
        try:
            surfaces = read_md3(path, info["frame"])
        except Exception as e:
            skipped.append((g["cls"], str(e)))
            continue
        F = faces(surfaces)
        if F is None:
            skipped.append((g["cls"], "no triangles"))
            continue
        bore = g["barrel"] or [1.0, 0.0, 0.0]
        for p in g["parts"]:
            for field in ("grab", "handseat"):
                if not p[field]:
                    continue
                pt = p[field]
                at, dist, surf, _ = closest_on_faces(F, pt)
                # A part's own surface: the NEAREST of the ones it names. A magazine that names mag and mag.001 has a
                # twin parked elsewhere for the reload, and measuring against that twin would invent a problem.
                own, own_name = None, None
                for nm in p["surface"]:
                    FS = faces(surfaces, nm)
                    if FS is None:
                        continue
                    _, dd, _, _ = closest_on_faces(FS, pt)
                    if own is None or dd < own:
                        own, own_name = round(dd, 3), nm
                nn = normal_at(F, pt)
                wall = None
                # Rays for a brace, and for ANY point the mesh wraps -- a pump's forend is a tube a hand closes round,
                # so its grab sits inside it and the wall is the only real surface to turn a hand against.
                if p["id"] == "support" or p["subject"] == "support" or (nn or {}).get("enclosed"):
                    hits = outward(F, pt, bore)
                    if hits:
                        wall = min(hits, key=lambda h: h["dist"])
                out_rows.append(dict(gun=g["cls"], type=g["type"], part=p["id"], field=field, point=pt,
                                     scale=info["scale"], surface_named=own_name, landed_on=surf,
                                     off_surface=round(dist, 3), off_own_surface=own,
                                     off_map=round(dist * info["scale"], 2),
                                     normal=(nn or {}).get("normal"), coherence=(nn or {}).get("coherence"),
                                     enclosed=(nn or {}).get("enclosed"), nearest_wall=wall))
        print("%-22s %-9s frame %-3d %d point(s)" % (g["cls"], g["type"], info["frame"],
                                                     sum(1 for r in out_rows if r["gun"] == g["cls"])))

    json.dump(out_rows, open(os.path.join(HERE, "MD3_CONTACTS.json"), "w"), indent=1)
    with open(os.path.join(HERE, "MD3_CONTACTS.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("# Where the md3 guns' contact points land (reload lane, 2026-09-18)\n\n"
                 "The md3 half of the hand-posing survey, same treatment as the Breach IQM pass. md3 has no skeleton, "
                 "so a frame's vertices ARE the space the card's points were measured in -- nothing is carried "
                 "anywhere, and a part's grab can be checked against its OWN named surface.\n\n"
                 "`off surface` is the distance to the nearest point on the whole mesh, `off its own` to the surface "
                 "the part names. `off (map)` applies the gun's MODELDEF Scale, so it is comparable to a grab radius "
                 "of 3.0. A blank normal with `enclosed` means the mesh wraps that point and no single surface faces "
                 "it -- for those, the wall found by firing rays out from the point is the real surface.\n\n"
                 "These points are HAND OPINIONS: never confirmed in a headset, fitted to the RS hand's size. "
                 "The mesh columns are facts; the points themselves are what is in question.\n\n"
                 "| Gun | Type | Part | Field | Landed on | off surface | off its own | off (map) | Normal | |\n"
                 "|---|---|---|---|---|---|---|---|---|---|\n")
        for r in sorted(out_rows, key=lambda r: -r["off_map"]):
            flag = "ENCLOSED" if r["enclosed"] else ("FAR" if r["off_map"] > 3.0 else "")
            if r["nearest_wall"]:
                flag = (flag + " wall %.2f" % r["nearest_wall"]["dist"]).strip()
            fh.write("| %s | %s | %s | %s | %s | %.3f | %s | %.2f | %s | %s |\n"
                     % (r["gun"], r["type"] or "-", r["part"], r["field"], r["landed_on"], r["off_surface"],
                        ("%.3f" % r["off_own_surface"]) if r["off_own_surface"] is not None else "-",
                        r["off_map"], ", ".join("%.3f" % x for x in r["normal"]) if r["normal"] else "-", flag))
        if skipped:
            fh.write("\n## Not read\n\n")
            for cls, why in skipped:
                fh.write("- %s: %s\n" % (cls, why))
    print("wrote MD3_CONTACTS.md (%d point(s), %d gun(s) skipped)" % (len(out_rows), len(skipped)))
