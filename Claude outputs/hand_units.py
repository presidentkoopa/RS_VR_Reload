#!/usr/bin/env python3
"""hand_units.py -- move every hand-held model from centimetres to map units.

WHY. The engine draws a model that rides a controller (MODELDEF FollowMainHand /
FollowOffHand, or an actor with FollowHandMode) in a frame that is in METRES,
times 0.01. One model unit there is vr_vunits_per_meter * 0.01 map units: 0.34
at the default 34. Every other world path (plain actors, the body frame) draws
one model unit as one map unit. So the same mesh is 2.94x bigger or smaller
depending on which path draws it, and every number tuned on one path is wrong
on the other. That is the "everything is massive or tiny" problem.

THE FIX has two halves that must land together:
  1. engine_hand_units.patch: cvar vr_hand_units. 0 = legacy (0.01), 1 = map
     units (1 / vr_vunits_per_meter, the body path's own inverse).
  2. This script: multiplies every number that is expressed in hand-frame units
     by L = vr_vunits_per_meter * 0.01, so that with vr_hand_units 1 every model
     draws exactly where and how big it drew before. Nothing moves on the day.

WHAT IT CHANGES (only with `apply`; `plan` shows the diff and writes nothing):
  * MODELDEF blocks that follow a hand, plus the classes in CHILD_CLASSES (they
    ride a hand model's frame): Scale, Offset, ZOffset, PivotOffset times L.
  * CVARINFO defaults of their placement offsets (<prefix>_ofs_x/_y/_z), and
    of the extra hand-frame prefixes in EXTRA_PREFIXES, times L.
  * MENUDEF slider ranges and steps for those cvars, times L.
  * wm_world_factor (VR_Reload's fallback for the hand ratio) -> 1.0.
  * The player's ini: the same cvars' saved values times L, the offsets packed
    in rs_stab_table times L, and vr_hand_units=1. Game must be closed.
Every file it writes gets a .handunits.bak copy first; `revert` puts them back.

WHAT IT DOES NOT CHANGE (listed by `inventory` as manual edits): ZScript that
states hand-frame numbers in code. See MANUAL_EDITS below.

USAGE
  python hand_units.py inventory  --root E:/DOOMWork --ini "C:/Users/Command/Documents/My Games/DoomXR/doomxr.ini"
  python hand_units.py plan       --root ... --ini ...   > plan.diff
  python hand_units.py apply      --root ... --ini ...
  python hand_units.py revert     --root ... --ini ...
"""
import argparse, difflib, fnmatch, os, re, shutil, sys

PACKAGES = [
    "RS_WorldHands", "RS_VRBody", "RS_VR_Weapons", "RS_VR_Weapons/wardusted", "RS_VR_Weapons/xim",
    "RS_VR_Reload", "RS_Modern", "RS_Lightsaber", "RS_ShieldSaw", "RS_VRPanels", "RS_Lance",
    "RS_Ballistics", "RS_ModelSwapper", "RS_WW2", "RS_Main", "RS_Gestures", "RS_WeaponSelectionSystem",
]
SKIP_DIRS = {".git", "_old", "_backups", "_snapshots", "_parked", "_removed", "_staged", "_drafts",
             "__pycache__", ".gen", "renders", "models", "sounds", "sprites", "textures", "graphics"}

# Drawn in a hand model's frame without carrying FollowMainHand/OffHand themselves
# (RS_VRPanels mounts the watch parts with FollowActor on the hand).
CHILD_CLASSES = ["RS_Watch*"]

# Placement prefixes set from ZScript on actors that are drawn in a hand frame, so
# no MODELDEF block names them. Glob patterns.
EXTRA_PREFIXES = [
    "rs_pwrist_*",          # VRPanels wrist spots (wrist.zs SpotPrefix / HandSpotPrefix)
    "wm_ha_*",              # VR_Reload held-magazine sets (loose.zs HeldPrefix)
    "wm_grab_all",          # VR_Reload whole-gun grab nudge (rig.zs TuneWorld -> FrameToWorld)
    "wm_tune",              # VR_Reload per-part grab nudge (rig.zs NudgeWorld -> FrameToWorld)
]
# ...but never these: world-space sets that happen to match a pattern above.
EXTRA_EXCLUDE = ["*floor*", "*drop*"]

MANUAL_EDITS = [
    ("RS_VRBody/zscript/body_holsters.zs", "SolveScale(): asHeld = vr_vunits_per_meter * 0.01",
     "set asHeld = 1.0 when vr_hand_units is 1 (a held gun and a holstered gun are then the same scale)"),
    ("RS_VR_Reload/zscript/wm/rig.zs", "recoil slide: prop.FollowHandOfs = (0, slide, 0)",
     "FollowHandOfs is in hand-frame units: multiply slide by L, or migrate the recoil profiles' 'back' values in RSBDEFS by L"),
    ("RS_VR_Reload/zscript/wm/loose.zs", "worldScale / wm_world_factor",
     "no code change: wm_world_factor becomes 1.0 (CVARINFO and ini), done by apply"),
    ("RS_VR_Reload/zscript/wm/rig.zs", "FrameUnits() fallback wm_world_factor",
     "no code change: FrameUnits() measures the real frame, so it reads 1.0 by itself"),
    ("RS_VRPanels/zscript/watch.zs", "Mount(): FollowActorOfs when not in-model",
     "check the fallback seat (no hand model): it is in hand-frame units; multiply by L if it is ever non-zero"),
]

OFS_SUFFIXES = ("_ofs_x", "_ofs_y", "_ofs_z")


def walk_files(root, pred):
    for pkg in PACKAGES:
        base = os.path.join(root, pkg)
        if not os.path.isdir(base):
            continue
        for dp, dns, fns in os.walk(base):
            dns[:] = [d for d in dns if d not in SKIP_DIRS and not (pkg != "RS_VR_Weapons" and d in ("wardusted", "xim") and False)]
            # sub-packages are walked on their own
            if pkg == "RS_VR_Weapons":
                dns[:] = [d for d in dns if d not in ("wardusted", "xim")]
            for fn in fns:
                if fn.endswith(".handunits.bak") and pred is not None and pred.__name__ != "<lambda>":
                    continue
                if pred(fn):
                    yield os.path.join(dp, fn)


def is_modeldef(fn):
    return re.match(r"(?i)^modeldef(\..*)?$", fn) is not None or fn.lower() == "modeldef.txt"


def is_cvarinfo(fn):
    return re.match(r"(?i)^cvarinfo(\..*)?$", fn) is not None


def is_menudef(fn):
    return re.match(r"(?i)^menudef(\..*)?$", fn) is not None


def fmt(v):
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    if s in ("-0", ""):
        s = "0"
    if "." not in s:
        s += ".0"
    return s


def scale_numbers(text, L):
    # "Scale -1.0 1.0 1.0" -> each number times L, trailing comment kept
    m = re.match(r"^(\s*\w+\s+)([-+0-9.eE\s]+?)(\s*(//.*)?)$", text)
    if not m:
        return text
    nums = m.group(2).split()
    try:
        vals = [float(x) for x in nums]
    except ValueError:
        return text
    return m.group(1) + " ".join(fmt(v * L) for v in vals) + m.group(3)


BLOCK_RE = re.compile(r"(?ims)^([ \t]*Model[ \t]+(\S+)[ \t]*(?://[^\n]*)?\n?[ \t]*\{)(.*?)(\n[ \t]*\})")


def hand_block(name, body):
    code = re.sub(r"//[^\n]*", "", body)
    if re.search(r"(?i)\bFollow(Main|Off)Hand\b", code):
        return True
    return any(fnmatch.fnmatch(name, pat) for pat in CHILD_CLASSES)


REVIEW_NAMES = ["*Prop*", "*Held*", "*Hand*"]


def review_blocks(text, path, out):
    for m in BLOCK_RE.finditer(text):
        name, body = m.group(2), m.group(3)
        if not hand_block(name, body) and any(fnmatch.fnmatch(name, pat) for pat in REVIEW_NAMES):
            out.append((path, name))


def migrate_modeldef(text, L, prefixes, report, path):
    out, pos = [], 0
    for m in BLOCK_RE.finditer(text):
        head, name, body, tail = m.group(1), m.group(2), m.group(3), m.group(4)
        out.append(text[pos:m.start()])
        if hand_block(name, body):
            lines = body.split("\n")
            for i, ln in enumerate(lines):
                code = ln.split("//")[0]
                if re.match(r"(?i)^\s*(Scale|Offset|ZOffset|PivotOffset)\s", code):
                    lines[i] = scale_numbers(ln, L)
                pm = re.match(r"(?i)^\s*PlacementCVars\s+(\S+)", code)
                if pm:
                    prefixes.add(pm.group(1).lower())
            body = "\n".join(lines)
            report.append((path, name))
        out.append(head + body + tail)
        pos = m.end()
    out.append(text[pos:])
    return "".join(out)


def prefix_match(cvar, prefixes):
    c = cvar.lower()
    for suf in OFS_SUFFIXES:
        if c.endswith(suf):
            p = c[: -len(suf)]
            if p in prefixes:
                return True
            if any(fnmatch.fnmatch(p, pat) for pat in EXTRA_PREFIXES) and not any(fnmatch.fnmatch(p, x) for x in EXTRA_EXCLUDE):
                return True
    return False


def migrate_cvarinfo(text, L, prefixes, hits):
    def rep(m):
        name, val = m.group(2), m.group(3)
        if name.lower() == "wm_world_factor":
            hits.append(name)
            return m.group(1) + "1.0" + m.group(4)
        if prefix_match(name, prefixes):
            try:
                v = float(val)
            except ValueError:
                return m.group(0)
            if v == 0.0:
                return m.group(0)
            hits.append(name)
            return m.group(1) + fmt(v * L) + m.group(4)
        return m.group(0)
    return re.sub(r"(?im)^(\s*(?:user|server|nosave|noarchive|cheat|latch|\s)*\s*float\s+([A-Za-z0-9_]+)\s*=\s*)([-+0-9.eE]+)(\s*;)", rep, text)


def migrate_menudef(text, L, prefixes, hits):
    # Slider "Label", "cvar", min, max, step[, decimals]
    def rep(m):
        cvar = m.group(2)
        if not prefix_match(cvar, prefixes):
            return m.group(0)
        try:
            lo, hi, st = float(m.group(3)), float(m.group(4)), float(m.group(5))
        except ValueError:
            return m.group(0)
        hits.append(cvar)
        st2 = max(round(st * L, 3), 0.001)
        return m.group(1) + fmt(lo * L) + ", " + fmt(hi * L) + ", " + fmt(st2) + m.group(6)
    return re.sub(r'(?i)(Slider\s+"[^"]*"\s*,\s*"([A-Za-z0-9_]+)"\s*,\s*)([-+0-9.eE]+)\s*,\s*([-+0-9.eE]+)\s*,\s*([-+0-9.eE]+)(.*)', rep, text)


def migrate_ini(text, L, prefixes, hits):
    lines = text.split("\n")
    seen_units = False
    for i, ln in enumerate(lines):
        m = re.match(r"^([A-Za-z0-9_]+)=(.*)$", ln.rstrip("\r"))
        if not m:
            continue
        name, val = m.group(1), m.group(2)
        cr = "\r" if ln.endswith("\r") else ""
        if name.lower() == "vr_hand_units":
            lines[i] = name + "=1" + cr; seen_units = True; hits.append(name); continue
        if name.lower() == "wm_world_factor":
            lines[i] = name + "=1" + cr; hits.append(name); continue
        if name.lower() == "rs_stab_table" and val:
            # key:subject:ox:oy:oz:s:sx:sy:sz;  -> offsets times L
            recs = []
            for rec in val.split(";"):
                f = rec.split(":")
                if len(f) == 9:
                    try:
                        for k in (2, 3, 4):
                            f[k] = "%.3f" % (float(f[k]) * L)
                    except ValueError:
                        pass
                recs.append(":".join(f))
            lines[i] = name + "=" + ";".join(recs) + cr; hits.append(name); continue
        if prefix_match(name, prefixes):
            try:
                v = float(val)
            except ValueError:
                continue
            if v == 0.0:
                continue
            lines[i] = name + "=" + fmt(v * L) + cr
            hits.append(name)
    out = "\n".join(lines)
    if not seen_units:
        # vr_hand_units is CVAR_GLOBALCONFIG: it belongs in [GlobalSettings]
        out = re.sub(r"(?m)^\[GlobalSettings\]\r?$", lambda mm: mm.group(0) + "\nvr_hand_units=1", out, count=1)
        hits.append("vr_hand_units (added)")
    return out


def read_vu(ini):
    try:
        t = open(ini, encoding="latin-1").read()
        m = re.search(r"(?m)^vr_vunits_per_meter=([-0-9.]+)", t)
        if m:
            return float(m.group(1))
    except OSError:
        pass
    return 34.0


def run(args):
    vu = read_vu(args.ini) if args.ini else 34.0
    L = vu * 0.01
    prefixes, blocks, changes = set(), [], []  # changes: (path, old, new)
    run.review = []

    for p in sorted(walk_files(args.root, is_modeldef)):
        t = open(p, encoding="latin-1").read()
        review_blocks(t, p, run.review)
        n = migrate_modeldef(t, L, prefixes, blocks, p)
        if n != t:
            changes.append((p, t, n))
    cv_hits, mn_hits = [], []
    for p in sorted(walk_files(args.root, is_cvarinfo)):
        t = open(p, encoding="latin-1").read()
        n = migrate_cvarinfo(t, L, prefixes, cv_hits)
        if n != t:
            changes.append((p, t, n))
    for p in sorted(walk_files(args.root, is_menudef)):
        t = open(p, encoding="latin-1").read()
        n = migrate_menudef(t, L, prefixes, mn_hits)
        if n != t:
            changes.append((p, t, n))
    ini_hits = []
    if args.ini and os.path.isfile(args.ini):
        t = open(args.ini, encoding="latin-1").read()
        if re.search(r"(?m)^vr_hand_units=1\r?$", t):
            t = None  # this ini was already migrated
    if args.ini and os.path.isfile(args.ini) and t is not None:
        n = migrate_ini(t, L, prefixes, ini_hits)
        if n != t:
            changes.append((args.ini, t, n))
    return L, vu, prefixes, blocks, changes, cv_hits, mn_hits, ini_hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["inventory", "plan", "apply", "revert"])
    ap.add_argument("--root", required=True)
    ap.add_argument("--ini")
    args = ap.parse_args()

    if args.cmd == "revert":
        n = 0
        targets = list(walk_files(args.root, lambda fn: fn.endswith(".handunits.bak")))
        if args.ini:
            targets.append(args.ini + ".handunits.bak")
        for bak in targets:
            if os.path.isfile(bak):
                shutil.copy2(bak, bak[: -len(".handunits.bak")]); os.remove(bak); n += 1
        marker = os.path.join(args.root, ".hand_units_applied")
        if os.path.exists(marker):
            os.remove(marker)
        print("restored %d file(s) from .handunits.bak" % n)
        return

    L, vu, prefixes, blocks, changes, cv_hits, mn_hits, ini_hits = run(args)

    if args.cmd == "inventory":
        print("# Hand units inventory\n")
        print("vr_vunits_per_meter = %g, so L = %g (one legacy hand unit in map units)\n" % (vu, L))
        print("## Hand-path MODELDEF blocks: %d\n" % len(blocks))
        byfile = {}
        for p, name in blocks:
            byfile.setdefault(os.path.relpath(p, args.root), []).append(name)
        for f, names in byfile.items():
            print("- %s: %d (%s)" % (f, len(names), ", ".join(names[:6]) + (" ..." if len(names) > 6 else "")))
        print("\n## Placement prefixes found: %d\n" % len(prefixes))
        print(", ".join(sorted(prefixes)))
        print("\nPlus patterns: " + ", ".join(EXTRA_PREFIXES))
        print("\n## CVARINFO defaults to change: %d" % len(cv_hits))
        print("## MENUDEF sliders to rescale: %d" % len(mn_hits))
        print("## ini values to change: %d" % len(ini_hits))
        print("\n## REVIEW: prop/hand-named blocks with no FollowMainHand/OffHand (hand-drawn if script sets FollowHandMode on them; add to CHILD_CLASSES if so): %d\n" % len(run.review))
        for p, name in run.review:
            print("- %s: %s" % (os.path.relpath(p, args.root), name))
        print("\n## Manual ZScript edits\n")
        for f, where, what in MANUAL_EDITS:
            print("- %s -- %s: %s" % (f, where, what))
        return

    if args.cmd == "plan":
        if os.path.exists(os.path.join(args.root, ".hand_units_applied")):
            print("# NOTE: already applied here; this diff is what a SECOND apply would do (apply refuses it).", file=sys.stderr)
        for p, old, new in changes:
            rel = os.path.relpath(p, args.root) if p.startswith(args.root) else p
            sys.stdout.writelines(difflib.unified_diff(old.splitlines(True), new.splitlines(True), "a/" + rel, "b/" + rel, n=1))
        print("\n# %d file(s) would change. L = %g." % (len(changes), L), file=sys.stderr)
        return

    if args.cmd == "apply":
        marker = os.path.join(args.root, ".hand_units_applied")
        if os.path.exists(marker):
            sys.exit("already applied (%s exists): run `revert` first, or delete the marker if you know better" % marker)
        for p, old, new in changes:
            bak = p + ".handunits.bak"
            if not os.path.exists(bak):
                shutil.copy2(p, bak)
            with open(p, "w", encoding="latin-1", newline="") as fh:
                fh.write(new)
        with open(marker, "w") as fh:
            fh.write("L=%g\n" % L)
        print("wrote %d file(s), backups beside each as .handunits.bak. L = %g." % (len(changes), L))
        print("Now: apply the manual ZScript edits, rebuild each package's pk3, run the engine with the patch.")


if __name__ == "__main__":
    main()
