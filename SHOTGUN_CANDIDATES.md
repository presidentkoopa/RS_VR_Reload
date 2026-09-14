# Shotgun candidates for the pump (and break) archetype

Measured 2026-09-12, read-only, from `E:\DOOMWork\RS_ModelSwapper` (owner-approved source,
nothing edited there). Two independent surveys agreed: the ModelSwapper lane's and a
measuring agent using `tools/md3.py` rigid fits with the receiver's own motion divided out.
Assets get COPIED into this package when the pump step starts.

**COPIED IN 2026-09-12 (owner: "grab all 4")** to `models/shotguns/`: `AE_Shotgun/m37a2.md3` +
`m37a2.png`; `Shotgun/shotgun.md3` + `WPN-GUNS-k1.png`; `AssaultShotgun/AssaultShotgun.md3` +
`AssaultShotgun.png`; `SuperShotgun/ssg.md3` (ModelSwapper's re-centred copy of 2026-09-12) +
`WPN-GUNS-k1.png`. Not yet referenced by any MODELDEF or card. The M37A2's `shotgun_shell.png`
does not exist anywhere and was not copied.

**Licence/credit: nothing is recorded in RS_ModelSwapper.** Code comments name the sources:
Aliens Eradication (M37A2), VanAlek (Doom shotgun, super shotgun), Brutal Doom v21 (assault
shotgun). Ask the owner before anything ships.

## Main hand — M37A2 ("Steel Shotgun", MS_AE_Shotgun) — fully usable

- Model `models/hud/AE_Shotgun/m37a2.md3`, skin `m37a2.png`; MODELDEF line 339
  (`Scale -1.1 1.1 1.1` — MIRRORED like the m4a3, `Offset -0.257 -49.130 -5.625`); pickup at 823.
- Surfaces: `m37a2` body (1000 v), `m37a2_pump` forend (381), `m37a2_trigger` (46), `shell` (188).
- Forend: **11.205 along -x**, 0.011° turn, fit 0.015 (frames 8, 26). Rest centroid (19.2, -0.2, 0.17).
- Trigger: hinge **31.11°** about (0, +1, 0), pivot (-17.88, 0, -1.11), fit 0.012.
- Shell: rest centroid (-6.18, -0.22, 3.34); frame 18 is a pure translation of 12.659 along
  (-0.440, 0, -0.898) — comes up into the gun from below (use frame 18 only; 19-23 tilt).
- Muzzle ≈ (38.34, -0.20, 3.52), barrel +x level.
- Ejects and loads through the BOTTOM (Ithaca 37): ejectport ≈ (-6.2, -0.2, -1.8), ejectdir ≈ (0, 0, -1) — estimate.
- Size: 0.374 map units per model unit; gun 26.0 mu long, pump travel 4.19 mu (pistols 8.7 / 10.7).
- Problems: `shell` asks for `shotgun_shell.png`, which does not exist — needs its own skin;
  receiver swings up to 90° in the reload frames (body-relative fits already remove it).

## Off hand — classic Doom shotgun (MS_Shotgun) — usable with gaps

- Model `models/hud/Shotgun/shotgun.md3`, skin `WPN-GUNS-k1.png`; MODELDEF line 75
  (`Scale 1.35`, not mirrored, `Offset 0.042 -41.745 -4.028`); pickup at 550.
- Surfaces: `doomshot` body (494 v), `doomshot.001` forend (69), `shotshl` ejected hull (34).
  Trigger and loading gate are fused into the body.
- Forend: **7.400 along (-1, 0, +0.002)**, 0.003° turn, fit 0.009 (frame 13). Centroid (15.89, -0.03, 0.27).
- Hull: real only on frames 12-21 (collapsed to a point otherwise); appears at (-0.06, 0.33, 1.74),
  leaves along (-0.84, +0.53, +0.10). Take frame 12 if used as the round model; its UVs are on the gun sheet.
- Muzzle ≈ (30.6, 0.0, 2.75), barrel +x level. Ejectport ≈ (0.0, 1.3, 1.7), ejectdir ≈ (-0.84, 0.53, 0.1), right side.
- Size: 0.459 map units per model unit; gun 28.4 mu long, pump travel 3.40 mu.
- Problems: no trigger, gate or tube-cap surface to drive. (ModelSwapper's `RS_ForeignAnim.zs:284-289`
  comment about frames 20-31 showing a shell going in is wrong by measurement — not our file, not touched.)

## Break action — super shotgun (MS_SuperShotgun)

- `models/hud/SuperShotgun/ssg.md3`, skin `WPN-GUNS-k1.png`, `Scale 1.35`. Surfaces `ssgbase`,
  `ssgbarrel`, 2 chambered shells, 2 new shells (two collapsed at rest).
- Barrel hinges **58.55°** (fit 0.012). Good candidate for the break-action card.

## Not usable

- Assault shotgun (`AssaultShotgun.md3`): magazine-fed, no forend; duplicate surface names (not
  addressable by name); frames drift 30-68 units.

## Neither pump has a loading-gate surface

CARDS_ON_PAPER.md's pump card assumed a `pump_gate`. Loading will be proximity + release at a
load point (BUILD.md step 7's "no driven surface first"), which needs no gate surface.
