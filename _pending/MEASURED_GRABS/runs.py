# Precise underside runs and nearby islands for the estimated support grabs. Read-only.
import sys
sys.path.insert(0, 'E:/DOOMWork/tools')
import md3, card_skeleton as cs

M = 'E:/DOOMWork/RS_VR_Weapons/models/'

def load(p):
    for name in ('read', 'load', 'from_file', 'parse', 'open'):
        f = getattr(md3.MD3Model, name, None)
        if f:
            try:
                return f(p)
            except TypeError:
                pass
    return md3.MD3Model(p)

def surf(model, name):
    for s in model.surfaces:
        if s.name == name:
            return s
    return None

def run(label, mesh, surfaces, x_from, x_to, bin_size):
    m = load(M + mesh)
    pts = []
    for s in m.surfaces:
        if not surfaces or s.name in surfaces:
            pts += s.verts[0]
    r = cs.underside_run(pts, x_from, x_to, bin_size)
    if r:
        print('%-34s run x %.2f..%.2f  middle x %.2f  z %.2f  y %.2f' % (label, r[2], r[3], r[0], r[1], r[4]))
    else:
        print('%-34s no run between x %.1f and %.1f' % (label, x_from, x_to))
    return m

def islands_near(label, model, sname, x_from, x_to, z_below, min_verts=20):
    s = surf(model, sname)
    for k, ids in enumerate(cs.islands(s, 0)):
        if len(ids) < min_verts:
            continue
        p = [s.verts[0][i] for i in ids]
        lo = [min(q[j] for q in p) for j in range(3)]
        hi = [max(q[j] for q in p) for j in range(3)]
        if hi[0] < x_from or lo[0] > x_to or lo[2] > z_below:
            continue
        c = cs.centroid(p)
        print('   %s island #%d v%d  x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f  centroid (%.2f, %.2f, %.2f)' % (
            label, k, len(ids), lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], c[0], c[1], c[2]))

run('plasma rifle, rail under the barrel', 'plasma/PlasmaRifle/plasmarifle_wm.md3', ['body'], 6, 18, 1.0)
run('plasma carbine, under the heatsink', 'plasma/PlasmaCarbine/plasmacarbine_wm.md3', ['body'], 38, 76, 2.0)
rpg = run('rpg, under the front tube', 'launchers/RPG/rpg_wm.md3', ['body'], 20, 66, 2.0)
islands_near('rpg', rpg, 'body', 30, 66, 0.0, 40)
bfg = run('bfg, the keel under the housing', 'bfg/BFG/bfg_wm.md3', ['body'], 28, 50, 1.0)
islands_near('bfg', bfg, 'body', 28, 50, 1.0, 40)
mg = run('machine gun, under the launcher', 'chainguns/MachineGun/machinegun_wm.md3', ['launcher'], -6, 4, 1.0)
run('machine gun, the tube underside', 'chainguns/MachineGun/machinegun_wm.md3', ['launchertube'], 4, 40, 1.0)
heavy = run('heavy bfg, the belly', 'bfg/BFGHeavy/bfgheavy_wm.md3', ['body'], -14, 14, 1.0)
run('heavy bfg, the lower fore end', 'bfg/BFGHeavy/bfgheavy_wm.md3', ['body'], 6, 57, 2.0)
