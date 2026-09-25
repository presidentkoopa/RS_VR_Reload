# Hand units: one unit everywhere

**The problem.** A model riding a controller is drawn in a frame that is in metres, times 0.01 (`models.cpp`, `followHandUnitScale`). One model unit there is `vr_vunits_per_meter × 0.01` map units: 0.34 at the default 34, a centimetre. Everything else in the world (plain actors, the body frame) is one unit = one map unit. So a mesh is 2.94× bigger or smaller depending on which path draws it, and every number tuned on one path is wrong on the other. The code already carries the scars: grab ovals at `Scale 100`, flight copies of guns at `× 0.34`, `wm_world_factor 0.34`, the holsters' "as held" `vu × 0.01`, the Praetor hands at a third of their size.

**The fix.** Hand-held models become map units, like everything else, and every number that was in hand units is converted once, exactly, so nothing moves on the day.

| File | What it is |
| --- | --- |
| `engine_hand_units.patch` | Adds `vr_hand_units` (0 legacy, 1 map units) to `src/r_data/models.cpp`. Only the follow-hand branch reads it; the HUD psprite path is untouched |
| `hand_units.py` | Finds every hand-frame number and multiplies it by L = `vr_vunits_per_meter × 0.01`: MODELDEF Scale / Offset / ZOffset / PivotOffset on hand blocks, their placement-offset defaults in CVARINFO, MENUDEF slider ranges, and your saved ini values. Sets `wm_world_factor` to 1 and `vr_hand_units=1` |
| `zscript_hand_units.patch` | The two ZScript lines the script cannot make (holster "as held", recoil slide). Both read `vr_hand_units`, so they are right before and after |

## Order

1. Apply `zscript_hand_units.patch` and `engine_hand_units.patch`; build the engine. With `vr_hand_units 0` (the default) nothing changes yet.
2. Close the game. Run `python hand_units.py inventory --root E:/DOOMWork --ini "C:/Users/Command/Documents/My Games/DoomXR/doomxr.ini"` and read it.
3. `python hand_units.py plan ... > plan.diff` and read the diff.
4. `python hand_units.py apply ...` (writes `.handunits.bak` beside every file, refuses to run twice).
5. Rebuild every changed package's pk3 (`build.ps1` in each).
6. Launch. Everything should look exactly as before. Anything that is now 2.94× too big or too small is a hand-frame number the script didn't know about: add its class to `CHILD_CLASSES` or its prefix to `EXTRA_PREFIXES`, `revert`, and run again.
7. `python hand_units.py revert ...` undoes steps 4 at any time.

## From then on

- A model file is authored in map units whichever path draws it. A gun's hand Scale is its world Scale.
- `vr_vunits_per_meter` no longer resizes what your hands hold relative to the world.
- The Praetor hands then need `Scale -1 1 1` (plus the rotation), not `-2.941 2.941 2.941`.
