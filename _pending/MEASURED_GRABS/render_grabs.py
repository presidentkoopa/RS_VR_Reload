# Comparison renders for the measured grabs: each mesh's vertices seen from the SIDE (x right, z up) and
# from ABOVE (x right, y up), the card's old point as a red ring and the measured point as a green one.
# Read-only; writes PNGs beside this script.
import sys, os
sys.path.insert(0, 'E:/DOOMWork/tools')
import md3
from PIL import Image, ImageDraw

M = 'E:/DOOMWork/RS_VR_Weapons/models/'
OUT = os.path.dirname(os.path.abspath(__file__))

def load(p):
    for name in ('read', 'load', 'from_file', 'parse', 'open'):
        f = getattr(md3.MD3Model, name, None)
        if f:
            try:
                return f(p)
            except TypeError:
                pass
    return md3.MD3Model(p)

# (file stem, mesh, [(label, old xyz, new xyz)])
GUNS = [
 ('ssg', 'shotguns/SuperShotgun/ssg.md3', [('barrels grab (size only)', (10.0, 0.0, -0.9), (10.0, 0.0, -0.9))]),
 ('doublebarrel', 'shotguns/DoubleBarrel/doublebarrel_wm.md3', [('barrels grab (size only)', (37.6, 0.0, 8.8), (37.6, 0.0, 8.8))]),
 ('plasmarifle', 'plasma/PlasmaRifle/plasmarifle_wm.md3', [('support', (14.0, 0.54, -8.1), (11.95, 0.54, -8.09))]),
 ('plasmacarbine', 'plasma/PlasmaCarbine/plasmacarbine_wm.md3', [('support', (57.0, 0.0, 8.0), (57.42, 0.0, 8.03))]),
 ('rpg', 'launchers/RPG/rpg_wm.md3', [('support', (47.5, 3.25, -6.28), (47.5, 3.25, -6.44))]),
 ('bfg', 'bfg/BFG/bfg_wm.md3', [('support (unchanged)', (38.93, 0.01, -2.90), (38.93, 0.01, -2.90))]),
 ('bfgheavy', 'bfg/BFGHeavy/bfgheavy_wm.md3', [('cell', (-0.33, 0.08, -12.41), (-0.29, 0.08, -12.59)),
                                               ('support', (31.39, 0.08, -5.96), (31.35, 0.06, -6.02))]),
 ('machinegun', 'chainguns/MachineGun/machinegun_wm.md3', [('launchertube', (30.0, -0.27, -9.75), (15.96, -0.31, -9.73)),
                                                          ('support', (0.0, -0.30, -12.2), (-2.29, -0.37, -12.11))]),
]

W, H, PAD = 900, 420, 30

def view(draw, pts, marks, ox, oy, w, h, ax, ay, title):
    xs = [p[ax] for p in pts]; ys = [p[ay] for p in pts]
    for _, o, n in marks:
        xs += [o[ax], n[ax]]; ys += [o[ay], n[ay]]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    s = min((w - 2 * PAD) / max(x1 - x0, 1e-6), (h - 2 * PAD) / max(y1 - y0, 1e-6))
    def P(a, b):
        return (ox + PAD + (a - x0) * s, oy + h - PAD - (b - y0) * s)
    for p in pts[::max(1, len(pts) // 12000)]:
        x, y = P(p[ax], p[ay])
        draw.point((x, y), fill=(90, 90, 90))
    for label, o, n in marks:
        for (pt, col, r) in ((o, (220, 40, 40), 7), (n, (30, 170, 60), 5)):
            x, y = P(pt[ax], pt[ay])
            draw.ellipse((x - r, y - r, x + r, y + r), outline=col, width=2)
    draw.text((ox + 6, oy + 4), title, fill=(0, 0, 0))

for stem, mesh, marks in GUNS:
    m = load(M + mesh)
    pts = [p for s in m.surfaces for p in s.verts[0]]
    img = Image.new('RGB', (W * 2, H + 40), (255, 255, 255))
    d = ImageDraw.Draw(img)
    view(d, pts, marks, 0, 0, W, H, 0, 2, 'SIDE  x right, z up')
    view(d, pts, marks, W, 0, W, H, 0, 1, 'TOP  x right, y up')
    legend = '   '.join('%s: red old %s -> green new %s' % (l, o, n) for l, o, n in marks)
    d.text((6, H + 12), stem + '  ' + legend, fill=(0, 0, 0))
    out = os.path.join(OUT, 'grab_' + stem + '.png')
    img.save(out)
    print('wrote', out)
