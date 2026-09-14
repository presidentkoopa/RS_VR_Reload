# Handoff — Universal Reload lane (`uzdxrema-5f`)

Branch `workingbuild`, engine tree `E:\DOOMWork\UZDXREMA`, package
`E:\DOOMWork\RS_VR_PistolTest\` → `RS_VR_PistolTest.pk3`.

---

## 1. What this is

A **card-driven immersive VR reload**. A weapon opts in by shipping text
(`WMCARD.txt`) naming its moving parts and how each one travels: an axis and a
distance for a slide, an axis, angle and pin for a hinge. There is no per-gun
mechanism code, so gun #3 should cost a text block.

The test build is **two guns, one per hand**: `WM_M4A3` in the main hand and
`WM_Pistolet` in the off hand. They're two different meshes on the same code,
which is the proof that the system is general. Each hand also has a WorldHands
fist. Classic button reload is out of scope, and RS_Reloading is abandoned
(nothing from it survives).

**Acceptance (owner's words, `ACCEPTANCE.md`):**
- Drop the mag: it lands, coloured neutral if empty, otherwise green→red by remaining ammo.
- One in the chamber, and the slide locks back when empty.
- Drop the mag by button, or grab it and pull it out. A removed mag can be dropped or thrown.
- The off hand goes to the pouch for a fresh mag, which can be dropped, put back, seated or thrown.
- Once it's seated, rack the slide closed. 15 per mag.
- **"Working means Working Completely from dropmag to insert and rack." If one is still in the chamber, no rack is needed.**

---

## 2. Engine

### Committed

- `69f8605049` — *Model surfaces you can move, drive from a hand, and find by name.*
  - Per-surface offset and rotation, interpolated to the drawn instant with shortest-arc nlerp.
  - The **draw-rate hand drive** (`SetModelSurfaceDrive` / `ClearModelSurfaceDrive` / `GetModelSurfaceDrawnValue`).
  - Surface lookup by name, frame count, analog trigger and grip.
  - The `ShiftSurfacePositions` tick-order fix.
  - The beams lane's `SetBeamAnchor`.
- `cf743b0b73` (another lane) — adds the `AttackVel` / `OffhandVel` controller velocity that throws use.

### Committed in `c3c9f0d7e3` — `ModelPointToWorld` answers in map order

Built into doomxr.exe 14:30:06. `ModelWorldTransform` returned the renderer's (x, height, y) for pos, fwd and up. It now swaps back to map order, as `AActor::GetBonePosition` does. The input stays in the renderer's model space.

| File | What |
|---|---|
| `src/r_data/models.cpp` | `ModelWorldTransform`: `toMap` on pos, fwd and up |
| `wadsrc/static/zscript/actors/actor.zs` | the native's doc now says what goes in and what comes out |

Every caller in `E:\DOOMWork` was checked, and none compensated for the old order. See §8, item 1, for what starts working.

### Committed in `b73294c211` — optional turn on a driven surface

`SetModelSurfaceDriveRotation(slot, axis, degrees, pivot)`. At drive value v, the part turns `v·degrees` about `axis` through `pivot`, then slides. It's for mags that rock into the well and bolts that lift as they draw.
- **Additive and default-off:** `SetModelSurfaceDrive` and `ClearModelSurfaceDrive` reset the turn to 0.
- **Same space and sense as the static path.** The quaternion is the one `Quat.AxisAngle` would give `SetModelSurfaceOffset`. The renderer takes the pivot term from the same matrix `VSMatrix::multQuaternion` builds, so the pivot stays still whatever the handedness.

| File | What |
|---|---|
| `src/playsim/actor.h` | `SurfOvDriveTurnAxis/TurnDeg/TurnPivot` beside the drive arrays |
| `src/playsim/p_actionfunctions.cpp` | the native; the drive's set and clear reset the turn |
| `src/r_data/models.cpp` | drive branch: `offset += P − R·P`, `rotation = q` |
| `wadsrc/static/zscript/actors/actor.zs` | declaration |

Only a slot that's already driven accepts a turn.

The doomwork lane's `AActor::VisibleCVar` went into the same commit, and RS_VRBody.pk3 needs it.

### Building — not this lane's job

**Since 2026-09-11, only the doomwork-94 lane builds (the engine or any pk3) or commits, in any repo.** That's the owner's rule. This lane edits source, then sends doomwork-94:
1. the files touched;
2. what needs building;
3. a one-line commit description.

Don't run cmake, build.ps1, doomxr (-norun included) or git writes from here.

The steps that lane follows, kept for reference:

Announce to the live lanes first (`ListAgents`, then `SendMessage`): two builds at once truncate `doomxr.exe`.
1. Check that `doomxr.exe` isn't running.
2. Clear the LTCG cache (`build-dxr/src/zdoom.dir/RelWithDebInfo/doomxr.iobj/.ipdb`, `RelWithDebInfo/doomxr.pdb`, `src/RelWithDebInfo/doomxr.lib/.exp`), or the link fails with LNK1103.
3. Run `cmake --build build-dxr --config RelWithDebInfo --target zdoom`. This target also refreshes `doomxr.pk3` with the actor.zs changes.

### Proposed, not built

- **Hand rides the part at draw rate.** Today the WorldHands hand is pinned to a part from script at 35 Hz (`PinHand`: seat sliders plus `FollowHandOfs` travel), while the part itself moves at display rate.
  - The PhysicalHolsters lane built **`FollowActor` / `FollowActorSlot` / `FollowActorOfs`** (a child drawn in a parent's model frame, optionally carried by one surface slot's live motion). It landed in `2f4c603d12` (doomxr.exe 15:02:34), and I reviewed the refactor as behaviour-preserving. It also factored my drive code into the pure helpers `SurfaceHandProjection`, `SurfaceDrivePose` and `SurfaceSetPose`.
  - **The missing piece is the seat.** `FollowActorOfs` is in the follow frame, which leaves out the parent's scale, mirror (M4A3 Scale −0.82) and MODELDEF base orientation, while card grab points are in the gun's model space. The proposed additive flag, **`bool FollowActorOfsInModel`** (default false, so holster seats are untouched), reads `FollowActorOfs` as a parent **model-space** point: in `ModelFollowFrame`, seat = frameBeforeCarry⁻¹ · parentMat · P.
    - The child ends up at M·S_slot·P, so the point stays on the moving part. With slot −1 it's just M·P. The PhysicalHolsters lane checked the algebra and has no objection.
    - Only the **position** comes from model space. The frame's orientation still has no mirror, scale or base rotation, so the wrist sliders turn relative to the gun's placement frame.
    - Files: actor.h, p_mobj.cpp, vmthunks_actors.cpp, actor.zs, models.cpp. It needs the owner's go. The files are free now that FollowActor has landed.
  - **pk3 side:** while a part is held, set on the hand
    - `FollowActor` = the prop;
    - `FollowActorSlot` = `part.poseSlot`;
    - `FollowActorOfs` = `Eng(grabAt)` with the flag on;
    - `FollowHandOfs` = 0.
    
    Clear `FollowActor` on release, because it outranks `FollowHandMode`.
  - **The seat sliders change meaning.** They become relative to the gun rather than the controller, so the owner's tuned values need a re-tune. Ship it behind a menu toggle, and do it after the base loop is confirmed in the headset.

---

## 3. Space — the single most expensive thing to get wrong

- The MD3 loader stores vertices as (x, **z, y**) (`models_md3.cpp:328`). Card numbers are MD3-file space, and every value handed to the engine goes through `WM_Space.Eng(v) = (v.x, v.z, v.y)`.
- That swap is a reflection, so **rotation angles flip sign**: `WM_Space.EngRot(a, deg) = Quat.AxisAngle(Eng(a), −deg)`.
- `multQuaternion` was checked to be the standard right-handed conversion. So `EngRot` agrees exactly with `WM_Space.Rotate` (Rodrigues in MD3 space), which the hinge pivot math uses.
- Grab points come from `ModelPointToWorld(Eng(m))`: the renderer's own matrix, including the follow-hand transform and the live placement cvars, and valid at tic time. Nothing is computed from the controller by hand.
- The follow-hand frame is 0.34 map units per model unit (`wm_world_factor`). Grab radii are map units.
- The drive's `distance` is both how far the part travels and how far the hand travels, so the part is glued 1:1. Seat and rack decisions read the **drawn** value, never script's estimate.

---

## 4. The pk3

`zscript.txt` includes: log, space, card, parser, ammo, loose, fx, weapon, rig, system.

| File | |
|---|---|
| `card.zs` / `parser.zs` | `WM_Dof` (slide or hinge, plus optional twist), `WM_Part`, `WM_Card`; several `weapon` blocks per lump; a bad card refuses only itself |
| `ammo.zs` | `WM_Ammo` — magazine, chamber and action lock kept separate |
| `rig.zs` | `WM_Rig`, one per hand: prop, part posing (hinges about their pin), drive start/stop, shot/cycle/hammer, flash, brass, eject a live round, drop, seat, rack |
| `system.zs` | `WM_System`: hand work (take, hold, release, pull out, carry, throw, pouch, guide, seat), WorldHands grip-arbiter claims, belt pouch, markers, HUD overlay and HUD log, netevents |
| `weapon.zs` | `WM_Gun` (semi-auto, vanilla pistol damage and 19-tic ROF, TNT1 view states), `WM_M4A3`, `WM_Pistolet` (+OFFHANDWEAPON), the `WM_Prop*` world props, and `WM_Player` (both guns, both fists, 200 Clip) |
| `loose.zs` | `WM_LooseMag` (FU-style: bounces up to 3×, lands on its side, coloured by rounds) and `WM_LooseRound` (stays `wm_round_life` tics); **laser-grabbable but not walk-over pickup** for `wm_walk_grace` tics, enforced in `TryPickup` because WorldHands resets `bSPECIAL` |
| `fx.zs` | muzzle flash (sprite, light, volumetric beam), smoke, casings, wire-sphere markers |
| `log.zs` | `WM_Log`, levels 0–4 |

**The cards** (`WMCARD.txt`), with every number measured by rigid fit (`tools/md3.py`):
- **m4a3:** slide 6.784 along −X; magazine 17.0 along (−0.354, 0, −0.935); hammer 62.15° hinge; trigger 11°.
- **pistolet:** slide 3.889; magazine `mag` + `mag.001` driven together, 10.0 along (−0.31, 0, −0.95); trigger 40.8°; baked `casing` hidden.

The dropped mags are extracted meshes: `wm_m4a3_mag.md3` and `wm_pistolet_mag.md3`, made by `tools/md3_write.py extract`. The round is FU's `bullet.md3`.

**Buttons:** `BT_MAINHANDDROPMAG` (1<<20) and `BT_OFFHANDDROPMAG` (1<<28), on press edges.

### WorldHands coexistence (lessons paid for)

- **Grip subjects are published only while actually holding** (guiding, carried, holding, bracing), never on hover. A hover subject stood WorldHands down and killed its catch and pull, even with a gun in hand.
- Fists come from `StartItem`s. During the 35-tic spawn window, guns are put into their card's hand even over a fist; after that they only fill empty hands.
- The pouch is on the **belt** (`wm_belt_*`), out of the chest catch zone.

---

## 5. Menu and sliders

The build won't let a dead slider ship. `tools/menu_lint.py` runs first in `build.ps1` and fails the build on:

| Check | Fails on |
|---|---|
| E1 | a menu cvar that isn't declared |
| E2 | a declared cvar nothing reads |
| E3 | code reading an undeclared cvar |
| E4 | a placement set missing a suffix, or with no sliders |
| E5 | a slider range that excludes its default, or a size slider reaching ≤ 0 |
| E6 | a MODELDEF or WMCARD class no ZScript declares |

E6 exists because `-norun` exits before MODELDEF loads, so the compile check can't see that bug. It stopped startup once.

Cvars whose meaning changed were **renamed**, because a saved ini value outranks a changed default: `wm_well_*`, `wm_belt_*`, `wm_reach_override`.

The menus are `WM_Options` → main gun, off gun, hand seats (the six `wm_main|off_slide|mag|support` sets), mags, pouch, fire, grab (including the wire-sphere size and placement). Everything is live.

---

## 6. Diagnostics — on by default

- **Overlay:** per-hand lines, each part's distance vs its reach, the pouch, and a gun-to-hand sanity line (`>30 TOO FAR`).
- **The same HUD goes into the log** (`build-dxr/RelWithDebInfo/log-debug.txt`, overwritten every launch). It's written as `---- WM HUD  tic N  <reason> ----` blocks on every grip squeeze and release, and every `wm_log_hud_every` (70) tics. Read this file before the owner relaunches.
- **Markers:** blue is a part, green is in reach, gold is the pouch, each with a coloured light. There's also a controller buzz on entering reach.
- **Netevents:** `wm_dump`, `wm_selftest`, `wm_rack_main/off`, `wm_drop_main/off`, `wm_reset`.

---

## 7. Proving a build

- **pk3:** doomwork-94 runs `build.ps1`. It lints, packs, verifies the entries, then runs a doomxr -norun compile check from a scratch folder, never the exe folder, whose `log-debug.txt` is the owner's test log. `-NoCompileCheck` skips that last step. It passes **only** on `script parsing took` with no `pk3:zscript` line. Compile errors never contain the word "error".
- **Launch:** the owner launches from their own launcher file (a .zdl), and doesn't want anyone else launching the game. Loaded mods: Graveyard, Fog, Sweeps, Darkness, Flashlight, Grenade, WeaponSelectionSystem, GESTURES, VRBody, WorldHands, RS_VR_PistolTest. No autoloads, ever.
- **Known zdl problem:** `iwad=doom` with `+map map01` doesn't match. Flagged to the owner, not yet resolved.

---

## 8. State

- **Machine-verified:** lint, pack, compile; mesh measurements; MD3 writer round-trip (error 0.00000).
- **Previous headset report:** couldn't seat a mag or rack the slide, no markers visible, and WorldHands catch and pull were broken. The catch-and-pull part was fixed by removing the hover subjects.

**Fixed 2026-09-11 after a line-by-line audit. These are why seat, rack and markers failed:**

1. **Positions came back in the renderer's order.** `ModelPointToWorld` returns the object-to-world matrix output unswapped: (x, **height**, y). Every grab point, the mag well, every marker, and the drop/brass/flash spawn points sat far off the gun.
   - **Fixed in the engine** (the owner's call: "always proper fix"). `ModelWorldTransform` (models.cpp) now returns map order for pos, fwd and up, the same swap `AActor::GetBonePosition` does. The pk3's temporary swap is gone, and `WM_Rig.World()` uses the answer as is. Built into doomxr.exe 14:30:06.
   - Every other caller had a distance guard that silently threw the swapped answer away, and none compensated. Those paths run for the first time on this exe:
     - RS_WorldHands `rs_grab.zs:248` (palm) and `rs_stabilize.zs:449-452/481`;
     - RS_VRBody `body_rig.zs:1388` (holster drawnAt) and `body_holsters.zs:498` (palm).
   - RS_WorldHands' reach oval, carry point and swap overlap now centre on the real palm rather than the controller. Its grab sliders were tuned against the controller.
2. **A released drive slot pinned its part at rest.** `ClearModelSurfaceDrive` only switches the drive off. The slot still names its surface, and the lowest slot wins, so after the first grab the slide couldn't lock back and the mag couldn't hide.
   - The pose and the drive now share one slot per (part, surface), reserved in `Bind`.
3. **A put-away gun could be braced**, which put the working hand's own gun away too. The gun went invisible, the drive stopped updating, and the slide froze.
   - `NearestPart` now ignores a stowed gun, and a gun the other hand is holding is never stowed.
4. **The support sphere swallowed the mag grab.** The brace was tested first and returned.
   - Now a squeeze takes a part first, and the brace is only a posture for an open hand.
5. **Smaller fixes:**
   - The first idle marker got no skin or light.
   - Pouching at full reserve deleted rounds; the pouch now never destroys rounds.
   - Switching to the fist and back was a free reload. The ammo now lives on `WM_Gun.wmAmmo`, and part state is rebuilt from it.

- **Not yet seen in the headset.** First check in `log-debug.txt`: the HUD line "drawn N from its hand" should read well under 30.
