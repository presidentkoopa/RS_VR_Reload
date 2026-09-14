# Publish checklist: a public RS_VR_Reload repo

Prepared 2026-09-13 by the reload lane (uzdxrema-11), at the build lane's request (doomwork-d3). **It decides
nothing.** It lists what a public repo would need, with evidence, and the questions only the owner can answer.
Nothing here has been deleted, licensed or published.

**2026-09-14, the owner:** "publish rs reload and rs vr weapons". `README.md` and `.gitignore` are written. There is no LICENSE, following the other public RS_ repos. The build lane does the split and push.

**Order, as first planned:** the repos come after the owner's calibration bake (hand seats, held-ammo sets, feel thresholds and
grab ovals baked in as defaults with `E:/DOOMWork/tools/bake_defaults.py`).

---

## 1. Questions for the owner

1. **The engine.** RS_VR_Reload runs only on UZDXREMA (section 4). The owner's own notes say UZDXREMA is private and
   never distributed. **Precedent (the build lane):** the other 15 public RS_ mods also run only on UZDXREMA. What
   does the README tell people to run it on?
2. **The licence** for the code, and whether the assets need a different one (section 6).
3. **Which docs ship** (section 5). Several are internal working notes that name lanes and sessions.
4. **The build tools.** Vendor `menu_lint.py` and `compile_check.ps1` into the repo, or ship without the build
   script (section 3)?
5. **Asset permission for public release.** RS_Main's asset folders and the ART SOURCE collection are cleared for the
   owner's use. Does that clearance cover a public repo (section 6)?

---

## 2. Missing files

| File | State | Note |
|---|---|---|
| `README.md` | missing | what it is, the load order, the required engine, the menus, the card grammar pointer |
| `LICENSE` | missing | the owner's choice (question 2) |
| `CREDITS.txt` | missing | asset sources (section 6); RS_VR_SoundSelection already ships one as a model |
| `.gitignore` | missing | untracked in the folder today: `doomxr-log.txt`, `log-debug.txt` (engine logs), and `run.ps1` writes `wm_last.log` and `logs/`. `RS_VR_Reload.pk3` is untracked, as it should stay. |

---

## 3. Hard-coded paths and outside tools

| Where | What it names |
|---|---|
| `build.ps1` | `E:\DOOMWork\tools\menu_lint.py`, `E:\DOOMWork\tools\compile_check.ps1`, `E:\DOOMWork\RS_Ballistics\RS_Ballistics.pk3` |
| `run.ps1` | `E:\DOOMWork\UZDXREMA\build-dxr\RelWithDebInfo` (the engine and `doom2.wad`), the `-Full` mod list under `E:\DOOMWork`, `E:\DOOMWork\RS_Ballistics\RS_Ballistics.pk3` |
| `zscript/wm/menu.zs` (WM_BakeLedger comment), `CVARINFO.txt` (the ledger comment) | `E:/DOOMWork/tools/bake_defaults.py` |
| `RS_VR_Weapons/_pending/card_lint.py` (another package) | reads `E:/DOOMWork/RS_VR_Reload/` by absolute path |

The tools live in `E:\DOOMWork\tools` today and serve several packages.

---

## 4. What it depends on

**Required, loaded before it:** **RS_Ballistics** (since 2026-09-13, row 16). Its guns fire `RSB_Bullet`, and
their flashes and casings are `RSB_Flash` / `RSB_Ejecta`. It's a required load order, never an autoload.

**The guns:** RS_VR_Reload ships the system and four archetypes (`WMCARD.txt`: pump, breaktop_revolver,
swingout_revolver, breakaction), not guns. The guns are **RS_VR_Weapons**, loaded after it.

**Reached softly, works without them:**
- RS_WorldHands' grip arbiter, `ServiceIterator.Find("RS_GripArbiterService")` (system.zs).
- RS_VRBody's placement keys (`rs_body_*` netevents).

**UZDXREMA-only engine features** it calls (counted 2026-09-13; none exist in upstream GZDoom):

| Feature | Uses | | Feature | Uses |
|---|---|---|---|---|
| `VRHaptic` | 34 | | `ScaleCVar` | 5 |
| `FollowHandMode` | 13 | | `FollowActorOfsCVar` | 4 |
| `ModelPointToWorld` | 9 | | `AttackVel` / `OffhandVel` | 4 / 4 |
| `BT_OFFHANDATTACK` / `BT_OFFHANDALTATTACK` | 7 / 3 | | `HasModelFrame` / `HasVoxelFrame` | 3 / 3 |
| `PlacementPrefix` | 7 | | `TintColor` | 3 |
| `PlaceInFrame` | 6 | | `SetModelSurfaceOffset`, `ModelFollowFrameToWorld`, `VoxelOverride`, `AlphaCVar`, `VisibleCVar` | 2 each |

---

## 5. Docs in the folder (listed, NOT pruned)

| File | Lines | Last commit | What it is now |
|---|---|---|---|
| `ACCEPTANCE.md` | 40 | 09-12 | the owner's finish line for the pistol loop |
| `BUILD-1-3.md` | 7 | 09-12 | **says "Superseded"** by BUILD.md |
| `BUILD.md` | 1431 | 09-13 | the build spec; its title still says RS_VR_PistolTest (the old name) |
| `CARDS_ON_PAPER.md` | 224 | 09-12 | the paper design for the pump and break action, since built |
| `FEEL_PLAN.md` | 863 | 09-13 | the live STATUS record; names lanes and sessions |
| `GESTURES-INTEGRATION.md` | 208 | 09-12 | RS_GESTURES notes written against RS_VR_PistolTest |
| `HANDOFF.md` | 210 | 09-12 | **a lane handoff** (uzdxrema-5f) with RS_VR_PistolTest paths |
| `MECHANISMS.md` | 350 | 09-12 | a code review of RS_VR_PistolTest |
| `NETPLAY_SPEC.md` | 372 | 09-13 | the live netplay spec; its section 10 decisions are open |
| `PASSING.md` | 151 | 09-12 | weapon passing moved to GESTURES.pk3, designed against an unseen interface |
| `PUBLISH_CHECKLIST.md` | — | new | this file |
| `SHOTGUN_CANDIDATES.md` | 61 | 09-12 | a RS_ModelSwapper survey for the pump |
| `UNIVERSAL.md` | 562 | 09-12 | the "making it universal" proposal, since built |

---

## 6. Asset provenance

Traced by filename to the owner-cleared pools (RS_Main's asset folders, the ART SOURCE collection), 2026-09-13.

**Sounds, all traced:**

| In the pk3 | Source |
|---|---|
| `sounds/wm/AKEMPT` | `ART SOURCE/SOUNDS/AKEMPT.wav` |
| `sounds/wm/DSCASIN1`-`3` | `ART SOURCE/SOUNDS/CASING/DSCASIN1`-`3.ogg` |
| `sounds/wm/DSBOUNC1`-`3.ogg` | `RS_Main/sounds/combatfx/magdrops/` |

**Sprites and the marker model:**

| In the pk3 | Source recorded |
|---|---|
| `sprites/WMCSA0` | RS_Main's licensed pool, `sprites/combatfx` (`fx.zs` header: "Every sprite here is from RS_Main's licensed pool") |
| `sprites/WMMGA0`, `WMMKA0`, `WMPRA0`, `WMRDA0` | **none recorded** (708a16e) |
| `models/rs_wiresphere.obj`, `rs_wire_hot.png`, `rs_wire_idle.png`, `rs_wire_pouch.png` | **none recorded** (708a16e). `tools/solid_png.py` writes flat swatches, but whether these came from it isn't recorded. |

**Removed in RSB_CALL_SITES_HANDOFF.md section 8 (2026-09-14):** `sprites/WMBT*`, `WMFL*`, `WMSK*`, `WMCSB0`-`E0`
and `sounds/wm/impact0`-`2.wav`, with the WM_ effect classes. `WMCSA0` stays as `WM_BeltLink`'s frame name, and
`DSCASIN1`-`3` stay as `wm/casing` (loose rounds landing, belt links bouncing).

---

## 7. Checked and clean

- **Personal paths or names:** none in tracked files. `git grep` for user-profile paths, account names and email
  found nothing.
- **The pk3 is a build output:** untracked; `build.ps1` makes it.
- **Internal names that do appear in docs:** lane and session names (`uzdxrema-11`, `doomwork-d3`, ...) in
  FEEL_PLAN, NETPLAY_SPEC and HANDOFF. They're harmless, but noise to a public reader (question 3).
