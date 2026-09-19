# Apply the measured grab VALUES to RS_VR_Weapons/WMCARD.txt: values and their comments only, no key, part,
# id or load renames, and no reflow (the bake ledger finds parts by name). Each edit must match exactly once.
# Run ONLY after the weapons lane's sound pass is committed.   python apply_grabs.py [--check]
import sys

P = 'E:/DOOMWork/RS_VR_Weapons/WMCARD.txt'
EDITS = [
 # WM_SSG barrels: across and up measured from the forend island.
 ("  # units x 0.459 = 3.2 map units. Across and up: ESTIMATE, for the grab-point page.\n"
  "  grab     = 10.0, 0.0, -0.9\n"
  "  grabsize = 3.2, 1.5, 2.0\n",
  "  # units x 0.459 = 3.2 map units. Across and up measured 09-14: the same island's half-width 2.48 and\n"
  "  # half-height 1.79 units x 0.459.\n"
  "  grab     = 10.0, 0.0, -0.9\n"
  "  grabsize = 3.2, 1.14, 0.82\n"),
 # WM_DoubleBarrel barrels: across and up measured from the hinge block and forend island.
 ("  # Across and up: ESTIMATE, for the grab-point page (1.5 and 2.0 at the old scale, shrunk with the gun).\n"
  "  grab     = 37.6, 0.0, 8.8\n"
  "  grabsize = 1.92, 0.79, 1.05\n",
  "  # Across and up measured 09-14: that island (barrels #1, x 26.80 to 48.41) is 4.23 wide and 3.01 tall\n"
  "  # either side of its middle, x 0.178.\n"
  "  grab     = 37.6, 0.0, 8.8\n"
  "  grabsize = 1.92, 0.75, 0.54\n"),
 # WM_PlasmaRifle support: the rail's bottom, its middle.
 ("# ESTIMATE: under the rail beneath the barrel (underside z -8.09 at x 12-16).\n"
  "part support\n"
  "  role    = support\n"
  "  subject = support\n"
  "  grab       = 14.0, 0.54, -8.1\n",
  "# Measured 09-14: under the rail beneath the barrel. Its bottom (z -8.09) runs x 8.12 to 15.77 and y -1.23\n"
  "# to 2.30; this is its middle.\n"
  "part support\n"
  "  role    = support\n"
  "  subject = support\n"
  "  grab       = 11.95, 0.54, -8.09\n"),
 # WM_PlasmaCarbine support: the heatsink's flat underside, its middle.
 ("# ESTIMATE: under the heatsink (x 41.3..73.5, underside z 8.03).\n"
  "part support\n"
  "  role    = support\n"
  "  subject = support\n"
  "  grab       = 57.0, 0.0, 8.0\n",
  "# Measured 09-14: under the heatsink. Its underside is flat at z 8.03 from x 41.33 to 73.52, on the centre\n"
  "# line; this is its middle.\n"
  "part support\n"
  "  role    = support\n"
  "  subject = support\n"
  "  grab       = 57.42, 0.0, 8.03\n"),
 # WM_RPG support: the tube's measured bottom; x stays the exposed tube's middle.
 ("# ESTIMATE: the mesh has no forward grip. Under the front tube, well ahead of the trigger\n"
  "# guard (which ends at x 29) and short of the muzzle (65.9); the underside is z -6.28 there.\n"
  "part support\n"
  "  role    = support\n"
  "  subject = support\n"
  "  grab       = 47.5, 3.25, -6.28\n",
  "# The mesh has no forward grip, so the hand goes under the front tube, well ahead of the trigger guard (which\n"
  "# ends at x 29) and short of the muzzle (65.9): the middle of that stretch. Measured 09-14: the tube's bottom\n"
  "# is z -6.44 on y 1.67 to 4.83 (the mesh has no vertices between x 36 and 58, only the tube's long faces).\n"
  "part support\n"
  "  role    = support\n"
  "  subject = support\n"
  "  grab       = 47.5, 3.25, -6.44\n"),
 # WM_BFG support: already island 11's centroid, so only the comment changes.
 ("# THE FORWARD GRIP, ESTIMATE: the keel under the barrel housing (body island 11), its middle.\n",
  "# THE FORWARD GRIP: the keel under the barrel housing. Measured 09-14: body island 11 (x 25.78 to 52.08,\n"
  "# y -1.78 to 1.81, z -6.53 to 1.62), its centroid, the hand wrapping the fin.\n"),
 # WM_BFGHeavy cell: the belly island's lowest point, its middle along x.
 ("  grab       = -0.33, 0.08, -12.41    # the belly's lowest point\n",
  "  grab       = -0.29, 0.08, -12.59    # measured 09-14: the belly (body island 2, x -13.89 to 13.31), its lowest point\n"),
 ("  # magcenter ESTIMATE: the belly's centroid.\n",
  "  # magcenter, measured: the belly's centroid (body island 2).\n"),
 # WM_BFGHeavy support: island 13's underside, its middle.
 ("# ESTIMATE: under the lower fore end (island 13's underside).\n"
  "part support\n"
  "  role    = support\n"
  "  subject = support\n"
  "  grab       = 31.39, 0.08, -5.96\n",
  "# Measured 09-14: under the lower fore end. Body island 13 runs x 6.36 to 56.33 with its underside at\n"
  "# z -6.02; this is its middle.\n"
  "part support\n"
  "  role    = support\n"
  "  subject = support\n"
  "  grab       = 31.35, 0.06, -6.02\n"),
 # WM_MachineGun launcher tube: the middle of its full-width underside.
 ("  grab       = 30.0, -0.27, -9.75     # ESTIMATE along x\n",
  "  grab       = 15.96, -0.31, -9.73    # measured 09-14: the tube's full-width underside, x 11.05 to 20.88 (its island x 5.30 to 26.62)\n"),
 # GRAB RADII: 3.0 is the house reach tolerance the grab page tunes, not a size a mesh can give -- the
 # ESTIMATE notes become that, and no radius changes.
 ("  # +y end; this is that hand's centroid with the rack seated (frame 90). Radius ESTIMATE.\n",
  "  # +y end; this is that hand's centroid with the rack seated (frame 90). Radius 3.0: the house reach\n"
  "  # tolerance for the grab page, not a mesh size.\n"),
 ("# (hand2.md3 frame 80, centroid x 28.55); z is the tube's underside (6.75). Radius ESTIMATE.\n",
  "# (hand2.md3 frame 80, centroid x 28.55); z is the tube's underside (6.75). Radius 3.0: the house reach\n"
  "# tolerance for the grab page, not a mesh size.\n"),
 ("  # (0, -0.944, 0.329), at the drum's middle x. Radius ESTIMATE.\n",
  "  # (0, -0.944, 0.329), at the drum's middle x. Radius 3.0: the house reach tolerance for the grab\n"
  "  # page, not a mesh size.\n"),
 ("  grab       = -16.34, 0.02, 31.78    # the rear edge, top centre\n"
  "  grabradius = 3.0                    # ESTIMATE\n",
  "  grab       = -16.34, 0.02, 31.78    # the rear edge, top centre\n"
  "  grabradius = 3.0                    # the house reach tolerance, not a mesh size\n"),
 ("  grab       = 23.58, 0.04, 33.78     # the top face\n"
  "  grabradius = 3.0                    # ESTIMATE\n",
  "  grab       = 23.58, 0.04, 33.78     # the top face\n"
  "  grabradius = 3.0                    # the house reach tolerance, not a mesh size\n"),
 # WM_MachineGun support: under the launcher's frame, its lowest run.
 ("  grab       = 0.0, -0.30, -12.2      # ESTIMATE: under the launcher's frame\n",
  "  grab       = -2.29, -0.37, -12.11   # measured 09-14: under the launcher's frame, its lowest run x -3.23 to -1.34\n"),
]

def main():
    check = '--check' in sys.argv
    s = open(P, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in s else '\n'
    bad = 0
    for old, new in EDITS:
        o, n = old.replace('\n', nl), new.replace('\n', nl)
        c = s.count(o)
        if c != 1:
            bad += 1
            print('NOT ONCE (%d): %s' % (c, old.split('\n')[0][:90]))
            continue
        if not check:
            s = s.replace(o, n)
    if bad:
        print('%d edit(s) do not match exactly once -- nothing written' % bad)
        sys.exit(1)
    if check:
        print('all %d edits match exactly once (check only, nothing written)' % len(EDITS))
        return
    open(P, 'w', encoding='utf-8', newline='').write(s)
    print('applied %d edits' % len(EDITS))

main()
