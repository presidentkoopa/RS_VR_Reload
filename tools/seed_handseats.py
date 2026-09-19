r"""Declare a hand-seat set for a weapon type that has none, seeded from its nearest kin.

    python seed_handseats.py            # report
    python seed_handseats.py --write    # append the blocks to CVARINFO.txt

WHY. A card's seats are read as wm_hs_<profile>_<main|off>_<seat>, where profile is the
card's `handprofile` if it states one, then its `type`, then `default` (handprofile.zs).
A type nobody has declared falls all the way to default -- so a bolt rifle is held with a
pistol's hand positions, silently, and looks like the rig is broken rather than like a
cvar set is missing.

The WW2 set was the first to use `boltrifle`, `mg`, `pump`, `flamer`, `melee` and
`thrown`, and none of the six existed.

SEEDED, NEVER TUNED. Every number here is copied from the nearest declared type. Where a
hand actually sits on a Kar98 to work its bolt is a headset question and the owner is the
only one who can answer it -- he drags them into place once and they are baked. Copying a
rifle's numbers gets him a starting pose on the right kind of gun instead of a pistol's;
inventing numbers would get him a wrong answer that looks considered.

MELEE AND THROWN GET NOTHING, deliberately. They have no parts carded -- nothing to seat
a hand on -- so a set for them would be five groups of dead cvars.
"""
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CVARINFO = os.path.join(os.path.dirname(HERE), "CVARINFO.txt")
PROFILE = os.path.join(os.path.dirname(HERE), "zscript", "wm", "handprofile.zs")

# new profile -> the declared type it is seeded from, and why that one
SEED = [
    ("boltrifle", "rifle",        "a bolt rifle is a rifle whose action a hand turns and pulls"),
    ("mg",        "rifle",        "a belt-fed gun is held like a rifle; its feed is a box, not a magazine"),
    ("pump",      "shotgun",      "the same gun with its forend named -- shotgun's seats already suit it"),
    ("flamer",    "flamethrower", "the same weapon under the card's shorter word"),
]


def main(write):
    text = io.open(CVARINFO, encoding="utf-8").read()
    have = set(re.findall(r"wm_hs_([a-z0-9]+)_(?:main|off)_", text))
    out = []
    for new, src, why in SEED:
        if new in have:
            print("%-10s already declared -- left alone" % new)
            continue
        lines = [ln for ln in text.split("\n") if re.search(r"\bwm_hs_%s_(main|off)_" % src, ln)]
        if not lines:
            print("%-10s SEED MISSING: no wm_hs_%s_* to copy" % (new, src))
            continue
        block = ["", "// ---- %s -- seeded from %s: %s" % (new.upper(), src.upper(), why),
                 "// NOT TUNED. Where a hand sits on one of these is the owner's headset pass."]
        for ln in lines:
            # Keep the column alignment the file is written in: the name grows or
            # shrinks, so the padding before '=' is rebuilt rather than copied.
            m = re.match(r"(\s*nosave\s+float\s+)(\S+)(\s*)=(\s*)(.+)$", ln)
            if not m:
                continue
            name = m.group(2).replace("wm_hs_%s_" % src, "wm_hs_%s_" % new, 1)
            block.append("%s%-41s = %s" % (m.group(1), name, m.group(5).strip()))
        print("%-10s <- %-13s %d cvar(s)" % (new, src, len(block) - 3))
        out.extend(block)

    if not out:
        print("\nnothing to add")
        return
    print("\n%d line(s) to append to %s" % (len(out), CVARINFO))
    if not write:
        print("(dry run -- pass --write)")
        return
    io.open(CVARINFO, "a", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")

    # menu_lint reads the LINT-PREFIXES lines to know a cvar set is real.
    pf = io.open(PROFILE, encoding="utf-8").read()
    seats = ("slide", "mag", "support", "forend", "foregrip")
    add = []
    for new, _src, _why in SEED:
        if ("wm_hs_%s_main_slide" % new) in pf:
            continue
        names = " ".join("wm_hs_%s_%s_%s" % (new, hand, s) for hand in ("main", "off") for s in seats)
        add.append("// LINT-PREFIXES: %s" % names)
    if add:
        anchor = "// LINT-PREFIXES: wm_hs_pistol_main_slide"
        pf = pf.replace(anchor, "\n".join(add) + "\n" + anchor, 1)
        io.open(PROFILE, "w", encoding="utf-8", newline="\n").write(pf)
        print("added %d LINT-PREFIXES line(s) to handprofile.zs" % len(add))
    print("written")


if __name__ == "__main__":
    main("--write" in sys.argv)
