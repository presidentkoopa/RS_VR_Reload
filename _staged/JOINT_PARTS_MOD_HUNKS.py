# RS_VR_Reload, THE GUN SIDE OF THE BONE DRIVE (Engine docs/MODEL_JOINT_DRIVE_PLAN.md section 4). Written by the reload
# lane, 2026-09-15. STAGED: NOT APPLIED.
#
# APPLY ONLY WITH AN EXE THAT HAS PIECES B AND C (build 9: SetModelJointOffset, the SetModelJointDrive family,
# GetModelJointDrawnValue). Against an older exe those natives are unknown and the whole RS_VR_Reload pk3 fails to
# compile. _staged/ is outside build.ps1's allowlist.
#
# WHAT IT DOES.
#   * A card part may name a JOINT instead of surfaces: `joint = <name>`. A rigged gun (an IQM) keeps its parts on bones --
#     the Breach Glock's slide, frame and magazine are all one mesh -- so the part is moved by its joint: posed each tic
#     with Actor.SetModelJointOffset from the same PartOffset / PartRotation a surface part gets, hidden with MJP_Hide,
#     and driven by the hand with the SetModelJointDrive family on exactly StartDrive's axes, signs and pivots.
#   * Gun-wide hides on the card: `hidesurface = <mesh name>` (a rig's own arms mesh; model index 0) and
#     `hidejoint = <joint name>` (a duplicate magazine the artist parked). Re-asserted every tic in Pose.
#   * The Body IK lane's note, kept: a joint's offset and drive entries are set once and updated after -- a grab re-arms the
#     drive, a release switches it off (ClearModelJointDrive keeps the entry) -- so no grab bumps the pose table's
#     generation. A hide toggles only when a part leaves or returns (a magazine out, in).
#   * Surface-only extras (roundsurface, metersurface, flip) stay surface-only. A joint part's hand seat rides the whole
#     gun, not the part, until piece E (a follower riding a joint).
# Everything else -- verbs, grabs, dof, dof2, index, the drawn value deciding a seat or a rack -- works on a joint part
# unchanged, because it reads WM_Part.value, which the joint drive publishes like a surface drive.
#
# Paths relative to RS_VR_Reload. Every anchor must occur exactly once. `python _staged/JOINT_PARTS_MOD_HUNKS.py` is a
# dry run; add --write to apply.

def T(n, s):
    return '\t' * n + s + '\n'

HUNKS = [
 # ---- card.zs -----------------------------------------------------------------------------------------------------------
 {'name': 'card.zs WM_Part: jointName',
  'file': 'zscript/wm/card.zs',
  'old': T(1, 'WM_Dof  dof;'),
  'new': (T(1, '// A PART THAT IS A JOINT: `joint = <name>`. On a rigged model (an IQM) a gun\'s parts are bones, not separate')
        + T(1, '// surfaces -- a slide, its frame and the magazine may all be one mesh. A part naming a joint is moved by that joint')
        + T(1, '// (Actor.SetModelJointOffset and the SetModelJointDrive family, the engine\'s bone drive) with the same dof, verbs,')
        + T(1, '// grabs and hand drive as any part. Surface-only extras -- roundsurface, metersurface, flip -- need surfaces.')
        + T(1, '// "" (unset): a surface part, as before.')
        + T(1, 'String  jointName;')
        + '\n'
        + T(1, 'WM_Dof  dof;')),
 },
 {'name': 'card.zs WM_Part live state: jointDriven',
  'file': 'zscript/wm/card.zs',
  'old': T(1, 'int     poseSlot;    // its first surface-override slot, for life; -1 if none fit'),
  'new': (T(1, 'int     poseSlot;    // its first surface-override slot, for life; -1 if none fit')
        + T(1, 'bool    jointDriven; // a joint part (jointName) that the hand drive holds right now')),
 },
 {'name': 'card.zs WM_Card: hideSurfaces, hideJoints',
  'file': 'zscript/wm/card.zs',
  'old': T(1, 'String propClass;'),
  'new': (T(1, 'String propClass;')
        + '\n'
        + T(1, '// PARTS OF THE MODEL NEVER DRAWN, gun-wide: `hidesurface = <mesh name>` hides a surface of the model (model index')
        + T(1, '// 0) -- a rig\'s own arms mesh; `hidejoint = <joint name>` collapses a joint and everything under it (Actor.MJP_Hide)')
        + T(1, '// -- a duplicate magazine the artist parked for an animation. Either may repeat. Re-asserted every tic (WM_Rig.Pose).')
        + T(1, 'Array<String> hideSurfaces;')
        + T(1, 'Array<String> hideJoints;')),
 },

 # ---- parser.zs ---------------------------------------------------------------------------------------------------------
 {'name': 'parser.zs NewPart: a surface part by default',
  'file': 'zscript/wm/parser.zs',
  'old': T(2, 'p.poseSlot   = -1;'),
  'new': (T(2, 'p.poseSlot   = -1;')
        + T(2, 'p.jointName  = "";          // a surface part unless the card names a joint')
        + T(2, 'p.jointDriven = false;')),
 },
 {'name': 'parser.zs part key: joint',
  'file': 'zscript/wm/parser.zs',
  'old': T(2, 'else if (key == "surface")    p.surfaceNames.Push(Unquote(val));'),
  'new': (T(2, 'else if (key == "surface")    p.surfaceNames.Push(Unquote(val));')
        + T(2, 'else if (key == "joint")      p.jointName = Unquote(val);   // a rigged part: moved by this joint (card.zs WM_Part.jointName)')),
 },
 {'name': 'parser.zs card keys: hidesurface, hidejoint',
  'file': 'zscript/wm/parser.zs',
  'old': T(2, 'if      (key == "prop")       c.propClass = Unquote(val);'),
  'new': (T(2, 'if      (key == "prop")       c.propClass = Unquote(val);')
        + T(2, 'else if (key == "hidesurface") c.hideSurfaces.Push(Unquote(val));   // card.zs WM_Card.hideSurfaces')
        + T(2, 'else if (key == "hidejoint")   c.hideJoints.Push(Unquote(val));     // card.zs WM_Card.hideJoints')),
 },
 {'name': 'parser.zs verb check: a joint is something on the mesh for a hand to move',
  'file': 'zscript/wm/parser.zs',
  'old': (T(3, 'if (part.surfaceNames.Size() == 0)')
        + T(4, 'return String.Format("part %s names no surface -- there is nothing on the mesh for a hand to move", part.id);')),
  'new': (T(3, 'if (part.surfaceNames.Size() == 0 && part.jointName == "")')
        + T(4, 'return String.Format("part %s names no surface and no joint -- there is nothing on the mesh for a hand to move", part.id);')),
 },
 {'name': 'parser.zs latch check: a joint latch',
  'file': 'zscript/wm/parser.zs',
  'old': T(3, 'if (card.parts[v.latchIndex].surfaceNames.Size() == 0)'),
  'new': T(3, 'if (card.parts[v.latchIndex].surfaceNames.Size() == 0 && card.parts[v.latchIndex].jointName == "")'),
 },

 # ---- rig.zs ------------------------------------------------------------------------------------------------------------
 {'name': 'rig.zs fields: the gun-wide hides',
  'file': 'zscript/wm/rig.zs',
  'old': T(1, 'bool    stowed;      // its hand is busy working the other gun'),
  'new': (T(1, 'bool    stowed;      // its hand is busy working the other gun')
        + T(1, 'Array<int> hideSurfaceIdx;   // card hidesurface, resolved (Resolve); -1 for a name the mesh lacks')
        + T(1, 'int     hideSlotBase;        // the first override slot the gun-wide hidden surfaces use (Bind); -1 if none fit')),
 },
 {'name': 'rig.zs Bind: a joint part starts unheld',
  'file': 'zscript/wm/rig.zs',
  'old': (T(3, 'p.driveSlot = -1;')
        + T(3, 'if (p.role == "hammer")      p.value = p.cockByTrigger ? 0.0 : 1.0;')),
  'new': (T(3, 'p.driveSlot = -1;')
        + T(3, 'p.jointDriven = false;')
        + T(3, 'if (p.role == "hammer")      p.value = p.cockByTrigger ? 0.0 : 1.0;')),
 },
 {'name': 'rig.zs Bind: slots for the gun-wide hidden surfaces, after the parts\'',
  'file': 'zscript/wm/rig.zs',
  'old': (T(3, 'p.poseSlot = slot;')
        + T(3, 'slot += n;')
        + T(2, '}')),
  'new': (T(3, 'p.poseSlot = slot;')
        + T(3, 'slot += n;')
        + T(2, '}')
        + T(2, '// THE GUN-WIDE HIDDEN SURFACES (card hidesurface) take override slots after the parts\'.')
        + T(2, 'hideSlotBase = (slot + c.hideSurfaces.Size() <= SLOTS) ? slot : -1;')
        + T(2, 'if (hideSlotBase < 0 && c.hideSurfaces.Size() > 0)')
        + T(3, 'WM_Log.Err(String.Format("%s: %d hidesurface lines do not fit in the override slots left -- none of them is hidden", c.weaponClass, c.hideSurfaces.Size()));')),
 },
 {'name': 'rig.zs Resolve: joint parts resolve by joint name; the hidden surfaces by name',
  'file': 'zscript/wm/rig.zs',
  'old': (T(4, 'part.surfaceRound.Push(part.RoundBindFor(part.surfaceNames[s]));')
        + T(4, 'found++;')
        + T(3, '}')
        + T(2, '}')
        + T(2, 'if (found == 0) return;')),
  'new': (T(4, 'part.surfaceRound.Push(part.RoundBindFor(part.surfaceNames[s]));')
        + T(4, 'found++;')
        + T(3, '}')
        + T(3, '// A JOINT PART (card `joint`): there when the model has a joint by that name.')
        + T(3, 'if (part.jointName != "" && prop.FindBoneIndex(Name(part.jointName)) >= 0) found++;')
        + T(2, '}')
        + T(2, 'hideSurfaceIdx.Clear();')
        + T(2, 'for (int k = 0; k < card.hideSurfaces.Size(); k++)')
        + T(3, 'hideSurfaceIdx.Push(prop.FindModelSurfaceIndex(0, card.hideSurfaces[k]));')
        + T(2, 'if (found == 0) return;')),
 },
 {'name': 'rig.zs Resolve log: a joint the model lacks is said',
  'file': 'zscript/wm/rig.zs',
  'old': T(3, 'if (part.surfaceNames.Size() > 0 && part.surfaces.Size() < part.surfaceNames.Size())'),
  'new': (T(3, 'if (part.jointName != "" && prop.FindBoneIndex(Name(part.jointName)) < 0)')
        + T(3, '{')
        + T(4, 'WM_Log.Err(String.Format("part \'%s\' names joint \'%s\', which this model does not have -- it will not move", part.id, part.jointName));')
        + T(4, 'continue;')
        + T(3, '}')
        + T(3, 'if (part.surfaceNames.Size() > 0 && part.surfaces.Size() < part.surfaceNames.Size())')),
 },
 {'name': 'rig.zs Reset: a held joint part keeps its value',
  'file': 'zscript/wm/rig.zs',
  'old': T(3, 'if (p.driveSlot < 0) p.value = (p.role == "hammer" && !p.cockByTrigger) ? 1.0 : 0.0;'),
  'new': T(3, 'if (p.driveSlot < 0 && !p.jointDriven) p.value = (p.role == "hammer" && !p.cockByTrigger) ? 1.0 : 0.0;'),
 },
 {'name': 'rig.zs NoteSplitCrossing: a held joint part is in the hand',
  'file': 'zscript/wm/rig.zs',
  'old': T(3, '(part.driveSlot >= 0) ? "in the hand" : "not held"));'),
  'new': T(3, '(part.driveSlot >= 0 || part.jointDriven) ? "in the hand" : "not held"));'),
 },
 {'name': 'rig.zs DrawnValue: a joint drive\'s drawn value',
  'file': 'zscript/wm/rig.zs',
  'old': T(2, 'if (part.driveSlot >= 0 && prop) return prop.GetModelSurfaceDrawnValue(part.driveSlot);'),
  'new': (T(2, 'if (part.jointDriven && prop) return prop.GetModelJointDrawnValue(Name(part.jointName), part.modelIndex);')
        + T(2, 'if (part.driveSlot >= 0 && prop) return prop.GetModelSurfaceDrawnValue(part.driveSlot);')),
 },
 {'name': 'rig.zs Pose: the gun-wide hides, every tic',
  'file': 'zscript/wm/rig.zs',
  'old': (T(1, 'void Pose()')
        + T(1, '{')
        + T(2, 'if (!prop || !resolved) return;')),
  'new': (T(1, 'void Pose()')
        + T(1, '{')
        + T(2, 'if (!prop || !resolved) return;')
        + T(2, '// THE GUN-WIDE HIDES (card hidesurface / hidejoint): not saved by the engine, so re-asserted every tic. A repeat')
        + T(2, '// changes nothing in the engine, so it costs no generation.')
        + T(2, 'for (int k = 0; k < hideSurfaceIdx.Size() && hideSlotBase >= 0; k++)')
        + T(3, 'if (hideSurfaceIdx[k] >= 0) prop.SetModelSurfaceHidden(hideSlotBase + k, 0, hideSurfaceIdx[k], true);')
        + T(2, 'for (int k = 0; k < card.hideJoints.Size(); k++)')
        + T(3, 'prop.SetModelJointDrawPose(Name(card.hideJoints[k]), Quat(0, 0, 0, 1), Actor.MJP_Hide, 0);')),
 },
 {'name': 'rig.zs Pose: a joint part posed by its joint',
  'file': 'zscript/wm/rig.zs',
  'old': (T(3, 'let part = card.parts[i];')
        + T(3, 'int n = part.surfaces.Size();')
        + T(3, 'if (n == 0 || part.poseSlot < 0) continue;')),
  'new': (T(3, 'let part = card.parts[i];')
        + T(3, '// A JOINT PART (card `joint`): its own branch -- PoseJointPart.')
        + T(3, 'if (part.jointName != "")')
        + T(3, '{')
        + T(4, 'PoseJointPart(part);')
        + T(4, 'continue;')
        + T(3, '}')
        + T(3, 'int n = part.surfaces.Size();')
        + T(3, 'if (n == 0 || part.poseSlot < 0) continue;')),
 },
 {'name': 'rig.zs StartDrive: a joint part goes to the bone drive',
  'file': 'zscript/wm/rig.zs',
  'old': (T(2, 'if (!prop || part.poseSlot < 0) return;')
        + T(2, 'int n = part.surfaces.Size();')),
  'new': (T(2, 'if (prop && part.jointName != "")')
        + T(2, '{')
        + T(3, 'StartJointDrive(part, workHand, startValue);')
        + T(3, 'return;')
        + T(2, '}')
        + T(2, 'if (!prop || part.poseSlot < 0) return;')
        + T(2, 'int n = part.surfaces.Size();')),
 },
 {'name': 'rig.zs StopDrive: a joint part\'s drawn value, and its drive switched off (the entry kept)',
  'file': 'zscript/wm/rig.zs',
  'old': T(2, 'if (part.driveSlot < 0 || !prop) return part.value;'),
  'new': (T(2, 'if (part.jointName != "")')
        + T(2, '{')
        + T(3, 'if (!part.jointDriven || !prop) return part.value;')
        + T(3, 'Name jn = Name(part.jointName);')
        + T(3, 'double jv = prop.GetModelJointDrawnValue(jn, part.modelIndex);')
        + T(3, 'prop.ClearModelJointDrive(jn, part.modelIndex);')
        + T(3, 'part.jointDriven = false;')
        + T(3, 'part.value = jv;')
        + T(3, 'return jv;')
        + T(2, '}')
        + T(2, 'if (part.driveSlot < 0 || !prop) return part.value;')),
 },
 {'name': 'rig.zs: PoseJointPart and StartJointDrive, before the hand drive',
  'file': 'zscript/wm/rig.zs',
  'old': T(1, '// HAND THE PART TO THE RENDERER. From here until release it is placed from'),
  'new': (T(1, '// A JOINT PART\'S POSE (card `joint`), every tic: hidden by collapsing its joint (MJP_Hide) while it is `hidden` or out')
        + T(1, '// of the gun, and cleared when it is back; otherwise its drawn value taken from a held drive, and a model-space joint')
        + T(1, '// offset from the very PartOffset / PartRotation a surface part gets -- the engine draws the drive instead while one')
        + T(1, '// holds it. Set once and updated after: no tic adds or removes the joint\'s entries (the Body IK lane\'s note).')
        + T(1, 'private void PoseJointPart(WM_Part part)')
        + T(1, '{')
        + T(2, 'Name jn = Name(part.jointName);')
        + T(2, 'bool hidden = (part.role == "hidden" || !part.present);')
        + T(2, 'prop.SetModelJointDrawPose(jn, Quat(0, 0, 0, 1), hidden ? Actor.MJP_Hide : Actor.MJP_Clear, part.modelIndex);')
        + T(2, 'if (hidden) return;')
        + T(2, 'if (part.jointDriven) part.value = prop.GetModelJointDrawnValue(jn, part.modelIndex);')
        + T(2, 'if (part.dof2) NoteSplitCrossing(part);')
        + T(2, 'prop.SetModelJointOffset(jn, PartOffset(part), PartRotation(part), part.modelIndex);')
        + T(1, '}')
        + '\n'
        + T(1, '// A JOINT PART IN THE HAND (card `joint`): the engine\'s bone drive, on exactly StartDrive\'s axes, signs and pivots')
        + T(1, '// (WM_Space.Eng; a hinge\'s negated degrees; a twist; a dof2 stage), so the posed part and the driven part agree at')
        + T(1, '// every value. The drive\'s entry is made on the first grab and kept; each grab re-arms it, each release switches it')
        + T(1, '// off (StopDrive).')
        + T(1, 'private void StartJointDrive(WM_Part part, int workHand, double startValue)')
        + T(1, '{')
        + T(2, 'Name jn = Name(part.jointName);')
        + T(2, 'let d = part.dof;')
        + T(2, 'if (d.moveKind == WM_Dof.MOVE_HINGE)')
        + T(3, 'prop.SetModelJointDriveHinge(jn, part.modelIndex, workHand, WM_Space.Eng(d.axis), -d.degrees, WM_Space.Eng(d.pivot), startValue);')
        + T(2, 'else')
        + T(2, '{')
        + T(3, 'prop.SetModelJointDrive(jn, part.modelIndex, workHand, WM_Space.Eng(d.axis), d.distance, startValue);')
        + T(3, 'if (d.twist != 0)')
        + T(4, 'prop.SetModelJointDriveRotation(jn, part.modelIndex, WM_Space.Eng(d.twistAxis), -d.twist, WM_Space.Eng(d.pivot));')
        + T(2, '}')
        + T(2, 'let d2 = part.dof2;')
        + T(2, 'if (d2)')
        + T(2, '{')
        + T(3, 'bool isHinge = (d2.moveKind == WM_Dof.MOVE_HINGE);')
        + T(3, 'if (!prop.SetModelJointDriveStage(jn, part.modelIndex, isHinge ? Actor.DRIVESTAGE_Hinge : Actor.DRIVESTAGE_Slide,')
        + T(4, 'WM_Space.Eng(d2.axis), isHinge ? -d2.degrees : d2.distance, WM_Space.Eng(d2.pivot), d2.split))')
        + T(4, 'WM_Log.Err(String.Format("%s gun: the engine refused %s\'s dof2 on joint %s -- in the hand it is a single-stage drive", HandName(), part.id, part.jointName));')
        + T(2, '}')
        + T(2, 'part.jointDriven = true;')
        + T(2, 'part.value = startValue;')
        + T(1, '}')
        + '\n'
        + T(1, '// HAND THE PART TO THE RENDERER. From here until release it is placed from')),
 },
 {'name': 'rig.zs magazine drop: a held joint magazine is let go first',
  'file': 'zscript/wm/rig.zs',
  'old': T(2, 'if (feed && feed.driveSlot >= 0) StopDrive(feed);'),
  'new': T(2, 'if (feed && (feed.driveSlot >= 0 || feed.jointDriven)) StopDrive(feed);'),
 },

 # ---- system.zs ---------------------------------------------------------------------------------------------------------
 {'name': 'system.zs unbind: joint parts come out of the hand too',
  'file': 'zscript/wm/system.zs',
  'old': (T(4, 'for (int i = 0; i < rig.card.parts.Size(); i++)')
        + T(5, 'rig.card.parts[i].driveSlot = -1;')),
  'new': (T(4, 'for (int i = 0; i < rig.card.parts.Size(); i++)')
        + T(4, '{')
        + T(5, 'rig.card.parts[i].driveSlot = -1;')
        + T(5, 'rig.card.parts[i].jointDriven = false;')
        + T(4, '}')),
 },
 {'name': 'system.zs grab candidates: a joint part is on the mesh',
  'file': 'zscript/wm/system.zs',
  'old': T(3, 'if (part.role != "support" && part.surfaces.Size() == 0) continue;'),
  'new': T(3, 'if (part.role != "support" && part.surfaces.Size() == 0 && part.jointName == "") continue;'),
 },
]

NEW_FILES = {}


if __name__ == '__main__':
    import os, sys
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    write = '--write' in sys.argv
    texts, bad = {}, 0
    for h in HUNKS:
        p = os.path.join(root, h['file'])
        if h['file'] not in texts:
            texts[h['file']] = open(p, encoding='utf-8', newline='').read()
        t = texts[h['file']]
        n, done = t.count(h['old']), t.count(h['new'])
        state = 'ok' if n == 1 else ('already in' if done == 1 else 'ANCHOR x%d' % n)
        if n == 1 and done == 1 and h['old'] in h['new']:
            state = 'already in'
        print('%-80s %s' % (h['name'][:80], state))
        if state == 'ok':
            texts[h['file']] = t.replace(h['old'], h['new'], 1)
        elif state != 'already in':
            bad += 1
    print('PROBLEMS: %d' % bad)
    if write and not bad:
        for f, t in texts.items():
            open(os.path.join(root, f), 'w', encoding='utf-8', newline='').write(t)
        print('WRITTEN')
    sys.exit(1 if bad else 0)
