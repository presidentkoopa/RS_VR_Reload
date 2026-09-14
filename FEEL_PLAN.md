# FEEL_PLAN.md -- reload feel, drop-mag everywhere, and the Doom roster's gaps

Written 2026-09-13, phase 1 (read-only). Nothing in the code has changed. Every anchor below is
a function name plus the line it was at when read; lines will have moved by phase 2, so find the
function, re-read the file, then edit by exact string. Another agent was editing system.zs, rig.zs,
parser.zs, card.zs, CVARINFO.txt and MENUDEF.txt (hand seats per weapon type) while this was
written. **Every one of those files is touched here too.**

## STATUS (update after each phase-2 step, so a usage limit loses nothing)

| # | Step (phase 2 order) | State |
|---|---|---|
| 1 | G1 magazine-only guns (`firesfrom = magazine`) | BUILT in source, 2026-09-13. Card key `firesfrom = chamber \| magazine`; `WM_Store.SynthPlaceholderChamber`; `WM_Ammo.MagazineHolds` / `SpendFromMagazine`; `WM_System.CanFire` / `OnShot` / `OnDry` and `WM_Rig.OnShot` / `OnDry` take `rounds` (default 1); FinishCard refuses a cycle, no counted store, or a verb naming the chamber. Both lints pass. RS_VR_Reload packed. **COMPILED 2026-09-13 14:17 (uzdxrema-11)** against exe 09-13 08:31, after fixing two `Class<Ammo>` declarations in rig.zs. Inside WM_Rig the field `ammo` hides the type name, so they're now `let`. |
| 2 | G3 shot class and rail, G2 rounds per shot, G4 `casing = none`, G5 `firesfrom = reserve / none` | **COMPILED 2026-09-13 14:17**, in the same build as step 1. `WM_Gun.RoundsPerShot`, `ShotClass`, `ShotRail`, `RailColors`; card `casing = yes \| none`; reserve pays by `DepleteAmmo` in the weapon action. The weapons lane took the plasma family live on it. |
| 3 | Shared-set fixes (coordinator, 2026-09-13): held-ammo and floor placement sets, and grab ovals `wm_gp_*`, per weapon TYPE on handprofile.zs's pattern, with the card's `handprofile` reused for per-gun ovals | **HELD AND FLOOR SETS COMPILED 2026-09-13 15:39 (uzdxrema-11)**:<br>• `wm_ha_<profile>_<slot>`: 14 profiles × 6 slots × 7 = 588 nosave cvars.<br>• `WM_HandProfile.AmmoPrefix` (handprofile, then type, then default), `WM_LooseMag.SetAmmoPrefixes`.<br>• Pages `WM_HA_<Profile>` (LINT-LIVE, `WMAmmoProfile` rows); WM_MagMenu is the hub. The old shared sets are deprecated.<br>**GRAB OVALS: HELD for the owner's call.** Per-type sets keyed by part slot (~3000 cvars, still drifting with part order), or BUILD.md step 5's scratch set baked into the card (per gun by construction). |
| 4 | Flick to close, orientation-gated dump, drop-mag on revolvers | **COMPILED 2026-09-13 (uzdxrema-11)**. Sections 2-3 at 15:26:12, section 1 at 15:27:45. Not yet played; the archetype blocks are not parsed by a -norun check.<br>• §2: eject `by = tilt` + `tiltaxis` (`by = muzzleup` is a tilt along the bore); `WM_Rig.EjectByTilt`. The breaktop archetype's extractor is a tilt of its down axis past 0.10, and its open no longer ejects.<br>• §3: `button = yes` on open and eject. `WM_System.ButtonWorksVerbs` runs before the magazine path in `ButtonDrop`. Both revolver archetypes set it.<br>• §1: open `close = flick` + `flickaxis` / `flickscale`. `WM_Rig.FlickByVerbs` / `FlickShut` / `FlickAxisModel`, and `WM_Verb.FlickSideSign`. Cvars `wm_flick_close` and `wm_flick_speed` are on WM_FireMenu. All three archetypes flick. `SetOpen` gains `how`. |
| 5 | G7 charge, G8 fire hold/release hooks, G6 chainsaw | **COMPILED 2026-09-13 (uzdxrema-11).**<br>• `WM_Gun.ChargeTics` / `ChargeSound`: a Fire `WM_Charge` 0-tic state plus `Charge: WM_ChargeWait; Goto Fire+1`, and `WM_System.OnCharge` → `WM_Rig.OnCharge`<br>• `virtual void FireHeld(int)` / `FireReleased(int)`, run by `DoEffect` off the usercmd (`TriggerIsDown`, `fireStarted`, `fireHeldTics`); a dry pull or a switch releases<br>• `WM_Gun.ShotSaw` / `SawSounds`: A_Saw once a pull with SF_NOUSEAMMO\|NOTURN\|NOPULLIN, ShotDamage on `random[WMSaw]` + SF_NORANDOM; no flash or sparks and a lighter buzz in `WM_Rig.OnShot` |
| 6 | G10 `hands = 2` | **COMPILED 2026-09-13 (uzdxrema-11), done ahead of steps 3-5** at the weapons lane's request, because it unblocks most of the roster.<br>• card `hands = 1 \| 2`, and FinishCard 3d refuses 2 with no support part<br>• `WM_System.SupportHeld`; CanFire refuses, and `WM_Rig.OnDry(rounds, needsGrip)` says why<br>• NearestPart always offers a two-hander's support; TakeAllowed's palm gate skips support<br>• DrawMarkers draws the support oval, and the HUD and bind log say so<br>• the grab page lists it as role `grip` |
| 7 | A voxel clip becomes a magazine | **COMPILED 2026-09-13 15:41 (uzdxrema-11).**<br>• become.zs keeps only a model clip (`HasModelFrame() && !HasVoxelFrame()`). The new magazine gets `VoxelOverride = false`.<br>• The header and the log line updated. |
| 7b | G-UBL: a second barrel on one card (`barrel <id>` block, card.zs `WM_Barrel`) -- the machine gun's underbarrel launcher | **COMPILED, installed 2026-09-13 15:02:30 (uzdxrema-11).** Not yet played; the machine gun card is RS_VR_Weapons'.<br>• Keys: input = altfire, trigger, from, shotclass, ammo, muzzle, barrel, firesound, needs = shut:<open id>, firetics, casing.<br>• WM_Gun `AltFire` (WM_TryAltFire / WM_AltFireWait). WM_Ready blocks the second button unless the card has a barrel. WM_HoldFire reads it between full-auto shots.<br>• `WM_System.CanAltFire / OnAltShot / OnAltDry`, and `WM_Rig.OnBarrelShot / OnBarrelDry / BarrelOutOfBattery`. An open verb named by `needs = shut:` stops only its barrel.<br>• `WM_Ammo.BarrelLoaded / DischargeBarrel`: slotted slots are left SPENT. The facade (`FindOwn`, `FacadeStoreId`) never takes a barrel's store.<br>• firesfrom = reserve / none / magazine exempts a barrel's store and the verbs that work only it.<br>• The pouch hands the barrel's named ammo while its gated load waits (`BarrelAwaitingRound`). A loose round remembers it (`WM_LooseMag.reserveName` / `ReserveClass`).<br>• The trigger part follows the button. The bind log has a line per barrel. |
| 7a | F2 (dof2 feed parts) + swap `needs` (queue item 6, BFG) | **COMPILED 2026-09-13 14:38 (uzdxrema-11).**<br>• `WM_Rig.WellPointRaw` uses `TwoStagePoint(..., 1.0)` for a dof2 feed part.<br>• `DropMagazine` spawns a dof2 magazine fully out, thrown along its last stage's axis.<br>• Swap `needs = open:<id>` (VerbTakesKey) gates the drop-mag button, seating (`CanSeat` / `SeatRefusal` through `SwapGateOpen`) and the hand pull-out.<br>• A feed part with no surface seats as soon as its magazine reaches the well: there is no drive. |
| 7b | Flamethrower effect helpers on WM_Gun (queue item 7) | **COMPILED 2026-09-13 14:34 (uzdxrema-11).**<br>• `CardPointToWorld`, `CardDirToWorld`, `MuzzleToWorld`, `BarrelToWorld`, `AcrossToWorld` (each `Vector3, bool`)<br>• `CarrierVelocity`, `FeedRounds`, `FeedShare`, `DrawnRig`; `WM_System.RigForGun`; `WM_Rig.AcrossWorld`<br>• Presentation only: drawn from the local controller.<br>• Also: `build.ps1` now stages and installs only on a pass, and `tools/compile_check.ps1` kills on a `pk3:zscript` line. |
| 8 | loose.zs: bare `frandom` becomes a WM_Jitter hash; every loose-object spawn site listed in section 10 as the netplay gap | **COMPILED 2026-09-13 15:20 (uzdxrema-11).**<br>• `WM_LooseMag.PostBeginPlay`, its bounce, and its lie-down angle hash off the tic, the bounce count and the position, over the same ranges.<br>• A grep of RS_VR_Reload finds no bare playsim RNG left. The named RNGs (WMBullet, WMRail, WMSaw, WMSpread) are all in the fire path, which runs on every machine.<br>• Spawn sites are listed in section 10. |
| 9 | G11 spinning parts, G12 round surfaces on a counted store, G13 a magazine that indexes on the shot, G14 a dropped magazine keeps its twist, G15 `WM_Gun.ReleaseTics`, G16 belt links | **G12 COMPILED 2026-09-13 15:05 (uzdxrema-11):**<br>• `roundsurface` on a counted store, drawn while it holds more than n (`WM_Ammo.RoundShows`).<br>• FinishCard 3b refuses n >= capacity, and a placeholder.<br>**G11 COMPILED 15:09 (uzdxrema-11):**<br>• Part keys `spin = trigger | fire`, `spinrate`, `spinup`, `spindown` on a one-period hinge.<br>• Card sounds spinupsound / spinsound / spindownsound.<br>• `WM_Rig.Spin`, and `WM_Parser.SpinProblem`.<br>**G16 COMPILED 15:15:**<br>• Card linkmodel / linkskin / linkscale.<br>• fx.zs `WM_BeltLink`, thrown from `WM_Rig.Brass`. The weapon package declares its MODELDEF block.<br>**G13 COMPILED 15:17:**<br>• An `index` block inside the feed part: steps = clamp(from - rounds, 0, steps).<br>• Composed under the dof in `WM_Rig.PartOffset`, `PartRotation` and `CarriedBy`.<br>**G15 COMPILED 15:18:**<br>• `WM_Gun.ReleaseTics`, via a Fire `WM_ReleaseWait` state after WM_HoldFire. No tics when unset.<br>**G14 COMPILED 15:33:**<br>• `WM_Rig.DropMagazine` turns the loose magazine to the drawn one: GunWorld·M·Twist·Rᵀ·M (`StandInverse`, `DrawnFeedTurn`, `DrawnMagBasis`).<br>• Solved against the loose actor's own ModelPointToWorld at zero angles as Rz·Ry·Rx (`TurnLikeDrawn`, `LooseBasis`), then verified. A miss over 0.05 falls level with a WARN.<br>**G11-G16 all COMPILED; none played yet.** |
| 10 | Chainsaw asks (RS_VR_Weapons CHAINSAW_CARDS.md CS-G1..G4) | **CS-G1 ripcord COMPILED 2026-09-13 15:45 (uzdxrema-11):**<br>• Verb `start` (part, outat 0.85), springs home.<br>• Card pullsound / startsound / idlesound / stopsound.<br>• `WM_Ammo.engineRunning`: `WM_System.CanFire` gates on it, `WM_Rig.StartEngine` / `EngineIdle` / Unbind stop it, and `OnDry` says to pull.<br>**CS-G3 cord:** needs the engine (a per-vertex drive), so it goes on the owner's queue; `cord` stays hidden.<br>**CS-G2 reach:** dropped. The cut stays A_Saw's, in the playsim; the drawn bar is local.<br>**CS-G4 chain flip COMPILED 15:46:**<br>• Part keys `flip = trigger | fire`, `fliptics` (unset 2), `flipphase = 0 | 1`.<br>• `WM_Rig.FlipShown` hides the part off its beat in Pose; `WM_Parser.FlipProblem`. |
| 11 | BFG meter (BFG_CARDS.md gaps 5-6) | **Point 5 ANSWERED from engine code:** a pose override slot has no skin field, so a moving `meter` keeps its MODELDEF SurfaceSkin.<br>**The fill gauge and spent-cell skin are BLOCKED ON ART:** only `bfg_meter1.png` exists. The mechanism is A_ChangeModel with CMDL_USESURFACESKIN. **The art arrived and the meter COMPILED 2026-09-13 16:16 (uzdxrema-11):**<br>• Part `metersurface` / `meterskins` (one %d) / `metersteps`: `WM_Rig.Meter` sets skin ceil(fill × N) through A_ChangeModel CMDL_USESURFACESKIN, only when the step changes; `WM_Parser.MeterProblem`.<br>• Card `magskinempty`, worn by a loose magazine with 0 rounds (`WM_LooseMag.Setup`). |
| 12 | F3: a latch on a swap (FLAMER_CARDS.md), and the OPEN latch BUILD.md step 8 designed | **COMPILED 2026-09-13 16:18 (uzdxrema-11).**<br>• `latch` / `latchat` (default 0.8) on open and swap. `WM_Card.PartIsWorkable` takes latch parts.<br>• `WM_Rig.LatchThrown` / `LatchLocks`: NearestPart skips a latched part at home.<br>• A swap's button drop, seating (`SwapGateOpen` / `SeatRefusal`) and pull-out wait on the latch. |
| 13 | Grab ovals per gun: BUILD.md step 5, a scratch set baked into the card (the owner's choice, 2026-09-13) | **COMPILED 2026-09-13 16:30 (uzdxrema-11).** Not yet used in the headset.<br>• Scratch set `wm_tune_ofs_*` / `wm_tune_sh_*` / `wm_tune_r` / `wm_tune_for`, read only by the picked slot. `WM_Rig.IsTuned` / `TuneF` / `OwnSeatCVar` / `OwnShapePrefix` give it renderer channels on its marker.<br>• WM_GrabMenu rows: bake part / gun / OLD tuning, and clear (`WM_BakeRow`, event-carried values).<br>• `WM_System.BakePrint` → `WM_Rig.BakeSlot` / `ModelDelta` / `OldSlotTuning`. Picking another slot auto-bakes the old one.<br>• The old per-slot `wm_gp_*` sets stay declared until baked. |
| 14 | The owner's first calibration notes (2026-09-13): the SSG dumps like the revolvers; a pump a hair back won't fire | **COMPILED (uzdxrema-11).**<br>• 16:47: the `breakaction` archetype's `open break` loses ejectall and gains button; a new `eject extractor` (tilt down 0.10, button).<br>• 16:49: per-type `wm_feel_<type>_home` / `_shut` (the shotgun's home 0.25), through `WM_Rig.HomeAt` / `CloseAt` in OutOfBattery, flick, holds, releases and HUD text. A release inside home snaps the part fully home. Page `WM_FeelMenu`, off WM_FireMenu. |
| 15 | Netplay safety spec (the owner, 2026-09-13) | **WRITTEN: `NETPLAY_SPEC.md`.** Spec only, no code.<br>• Finding: every carded shot desyncs in a netgame today.<br>• Recommended: the owner's machine decides and sends network commands; every machine applies them to the weapon's state.<br>• Rollout P0-P5. The decisions in §10 are the owner's. |
| 16 | Wire RS_Ballistics into the reload system (`Engine docs/RSB_CALL_SITES_HANDOFF.md`, re-based 2026-09-13 23:00 by the ballistics lane uzdxrema-c5; the build lane doomwork-d3 approved it NOT waiting on NETPLAY_SPEC §10, as a like-for-like swap on the same fire path) | **COMPILED and installed 2026-09-13 23:06:03 (uzdxrema-11)**, against RS_Ballistics c4a467d (23:04:18) and engine 6997b2c308. Not yet fired in the headset.<br>• **RS_VR_Reload REQUIRES RS_Ballistics** (the owner's choice, 2026-09-12). The load order is RS_Ballistics → RS_VR_Reload → RS_VR_Weapons, a required order, never an autoload. build.ps1 compile-checks with RS_Ballistics.pk3 first, and run.ps1 loads it first.<br>• WM_Gun `RoundProfile` / `FlashProfile` / `AltFlashProfile` / `EjectaProfile` and their `...OrDefault()` getters. ShotClass and a barrel's shotclass default to `RSB_Bullet`.<br>• **`WM_Gun.LaunchRound(shot, shooter, h, withDamage)`** is the ONE launch path: the pellet loop passes true, WM_TryAltFire false (a barrel's round keeps its own damage). ApplyShotDamage sets RSB_Bullet's damageMin/Max.<br>• rig `Flash` / `FlashAt(..., profile)` → `RSB_Flash.Fire`, with OnBarrelShot on AltFlashProfile. Sparks / SparksAt and the WM_Smoke spawn are gone (the profile's bursts and smoke).<br>• `Brass` and ThrowOutAll's spent branch → `RSB_Ejecta.Throw(..., shared: false, SlotSound("casing", card.casingSound))`. WM_BeltLink stays, gated on `RSB_Settings.Casings()`.<br>• The card's default `casingsound` is now "", so a casing sounds as its profile. Loose rounds still land on wm/casing.<br>• Removed now, because only the rig read them and menu_lint would flag them dead: `wm_smoke`, `wm_smoke_size`, `wm_muzzle_sparks`, `wm_casings`. WM_FireMenu's other flash / impact / casing rows are replaced by a Submenu to `RSB_Options`, keeping Beam slot, Ejection speed and Belt links lie. Their cvars and the WM_ classes stay until handoff section 8, after one shipped build.<br>• The weapons lane's per-class profile lines (`merge_ballistics.py`) apply after this installs. |
| 17 | Baking the owner's calibration as the defaults (the owner, 2026-09-13: calibrate "weapons and hands", then "bake those as the defaults") | **COMPILED and installed 2026-09-13 18:02:48 (uzdxrema-11).** Not yet used in the headset.<br>• `E:/DOOMWork/tools/bake_defaults.py PACKAGE --include wm_hs_,wm_ha_,wm_feel_` reads the ini (read-only; `nosave` cvars are saved there, under `[Doom.ConfigOnlyVariables.Mod]`) and rewrites only the changed CVARINFO defaults with `--write`, all or nothing. It refuses a value outside its slider.<br>• The bake ledger: every grab-oval bake is also kept in `wm_bake_ledger_00..63`, with the ini saved at once, because the engine's log starts fresh each launch. `--ledger --cards` prints the card blocks and what each card already has.<br>• As of the ini's 17:20 save, no per-type hand, held-ammo or feel value differs from its default. The 36 changed values are in retired sets; the old per-hand seats are already the revolver's defaults. |
| 18 | Sound picks: the hook for VR Weapon Sound Selection (the weapons lane's companion pk3, the owner's order 2026-09-13) | **COMPILED and installed 2026-09-13 18:47:47 (uzdxrema-11).** Not yet heard in the headset.<br>• `WM_SoundPick` (soundpick.zs; its lookup is `Pick`, since `For` is ZScript's `for` keyword) reads `wm_snd_<gun>_<slot>` through the gun owner's player at every play. Empty or undeclared means the card's sound.<br>• Every card sound site goes through `WM_Rig.SlotSound`: fire, altfire, dry, magout, magin, rackapex / rackreset (the magazine fallback only with no pick and no card sound), cycleout, cyclehome, load, open, close, spinup / spin / spindown, pull / start / idle / stop, charge. Also `WM_Gun.SawFullSound` / `SawHitSound`.<br>• Fixed on the way: loose magazines, loaders, rounds and casings landed on a fixed `wm/magdrop` / `wm/casing`, ignoring the card's `magdropsound` / `casingsound` (no card sets another yet). They now carry the card's sound and owner: `Setup` / `SetupRound` / `SetupLoader` take `from`, and casings set `BounceSound`.<br>• `slidebacksound` / `slidefwdsound` are parsed and never played; six cards set them. Left unchanged and reported to the weapons lane. |
| 19 | `ejectsound` / slot `eject` (the owner, via the weapons lane, 2026-09-13: "yes to eject") | **COMPILED and installed 2026-09-13 18:58:56 (uzdxrema-11).** Not yet heard in the headset.<br>• Card key `ejectsound` (WM_Card.ejectSound, silent unless stated). Played at the top of `WM_Rig.ThrowOutAll` when the verb is an EJECT, through `SlotSound("eject", ...)`.<br>• Once a stroke. A rod worked by hand sounds even on an empty cylinder; a tilt dump or the drop-mag button throws, and so sounds, only with rounds held. An open verb's `ejectall` keeps its open sound.<br>• Named in the bind log's sounds line. |
| 20 | NETPLAY_SPEC section 8, P0 fix 1: network events act for the player who sent them (approved by the build lane doomwork-d3 as a correctness bug, not a section 10 design choice) | **COMPILED and installed 2026-09-13 23:59:40 (uzdxrema-11)**, against RS_Ballistics c4a467d and engine 6997b2c308. `WM_System.NetworkProcess`, split:<br>• **This machine's UI** (`rs_body_edit` / `rs_body_grab_*`, `wm_bake_ofs` / `_shape` / `_go`, `wm_dump`, `wm_selftest`) runs only when `e.Player == consoleplayer`, through `LocalUiEvent`. These write this machine's cvars and print to its console.<br>• **The drop-mag buttons** act on `HandsIfAny(e.Player)`: another player's drop can no longer drop this player's magazine. A machine without that player's hands does nothing.<br>• **The test controls** (`wm_rack_*`, `wm_reset`) are refused when `multiplayer` and not `sv_cheats` (`CheatsOn`), with a line to the sender.<br>• Single-player is unchanged. |
| 21 | RSB_CALL_SITES_HANDOFF.md section 8: the WM_ effect copies removed, after row 16 shipped and the owner tested it (the build lane doomwork-d3, 2026-09-14) | **COMPILED and installed 2026-09-14 00:04:35 (uzdxrema-11)**, against RS_Ballistics c4a467d and engine 6997b2c308. The pk3 went from 64 entries to 41.<br>• Gone: `WM_Bullet` (bullet.zs and its include), `WM_MuzzleFlash`, `WM_Smoke`, and LaunchRound's / ApplyShotDamage's WM_Bullet branches.<br>• **`WM_Casing` folded into `WM_BeltLink`**, its only user: the bounce, tumble and `wm_casing_life` fade kept. The casing size slider and the hot-brass glow are gone; the glow lit a link for its first tics after Wear put it out.<br>• Cvars gone: every `wm_flash_*` but `wm_flash_slot`, `wm_impact_sparks` / `_glow` / `_sound`, `wm_bullet_speed`, `wm_casing_scale`, `wm_casing_hot_tics`.<br>• SNDINFO `wm/impact` gone. Assets gone: sprites WMBT*, WMFL*, WMSK*, WMCSB0-E0; sounds impact0-2.wav. build.ps1's verify list follows.<br>• `wm/casing` and DSCASIN1-3 stay (loose rounds, belt links), as does WMCSA0 (the link's frame name). |
| 22 | Rail and saw puffs from RS_Ballistics (the ballistics lane uzdxrema-c5, approved by doomwork-d3, 2026-09-14) | **COMPILED and installed 2026-09-14 00:08:53 (uzdxrema-11)**, against RS_Ballistics 4cdcf79. weapon.zs WM_TryFire: `A_RailAttack`'s puff `"BulletPuff"` becomes `"RSB_RailPuff"`, and `A_Saw`'s becomes `"RSB_SawPuff"`.<br>• Both are BulletPuff subclasses, so ordinary playsim actors on every machine: the vanilla sprite hidden, an RS_Ballistics `rail` / `saw` impact played on spawn, +PUFFGETSOWNER. No RNG, no consoleplayer, nothing read back.<br>• Needs RS_Ballistics 4cdcf79 or later.<br>• The rail stays A_RailAttack hitscan; the saw keeps its own hit sound. |
| 23 | NETPLAY_SPEC section 8, P0 fix 3: UI-only cvars stop churning userinfo (the reload lane's next unblocked item, approved by doomwork-d3, 2026-09-14) | **COMPILED and installed 2026-09-14 00:12:03 (uzdxrema-11).** `tools/bake_defaults.py` now reads a cvar by name from every mod section in the engine's load order, the last one winning, so the owner's values are found under either scope. CVARINFO scope only; single-player unchanged. 43 cvars go `user` → `nosave` (the noarchive ones stay noarchive):<br>• `wm_belt_fwd` / `_side` / `_up` / `_radius`, `wm_hip_pouches` / `_side` / `_up` / `_fwd`. Placement mode wrote these every tic a pouch was dragged, and each write went to every peer.<br>• `wm_gp_name_m0..o7`, written as parts bind; `wm_gp_sel_m0..o7` and `wm_gp_sel_color`, the grab page's; `wm_tune_gun`, `wm_tune_part`.<br>• Every reader is the console player's or the renderer's by name, and no other package names them. Saved values in `[Doom.Player.Mod]` load by name on the first run (`FGameConfigFile::ReadCVars` sets a found cvar whatever its flags), then save under ConfigOnlyVariables.Mod. |
| 25 | The throwable archetype: RS_Grenade's grenade and RS_ShieldSaw's shield saw as cards (the build lane doomwork-5e, 2026-09-14; the owner: both throw by the hand's real velocity, and the shield saw keeps its throw, route lock and return, caught by the hand) | **DESIGN NOTE WRITTEN: `THROWABLE_PLAN.md` (revised 2026-09-14). STEP 1, THE PARSER, BUILT AND COMPILED (2026-09-14):** `throw`, `route`, `fuse` and `mount <id>` blocks (`zscript/wm/throw.zs`), `pouch = whole`, the `pulloff` and `release` verbs, and the fit checks (`WM_Parser.ThrowableProblem`), printed in the bind log. Nothing acts on them yet (steps 3-5). Not load-tested: no card uses them.<br>• `throw`: both weapons leave at the release velocity from RS_WorldHands' thrower. No button throw.<br>• The shield saw flies home to the hand. A grip closing within `catchat` catches it; a miss stows on the mount; a grip press outside that radius recalls it.<br>• `route` locks, and the verbs `pulloff` (pin) and `release` (lever).<br>• `fuse`, `mount`, `pouch = whole`.<br>• Two general flight actors, modelled on the mods' own.<br>• The thrower's machine measures once and sends commands: `wm_throw` (position, velocity, spin, route); `wm_hand` every 4 tics while it returns; `wm_catch`; `wm_recall`.<br>• Waits on the owner: slot 9 replace or wrap; what a grenade throw leaves in the hand; whether a missed catch stows or drops. |
| 26 | The card pipeline's measuring stage: `tools/card_skeleton.py` (the owner, 2026-09-14: cards for all ~100 weapon models, with "a pipeline for rapid oval / hand placement" perfected first; approved by the build lane doomwork-5e) | **BUILT 2026-09-14 (uzdxrema-11).** It writes a DRAFT card from a mesh, for review; it never edits a WMCARD, renames no id and writes no mesh.<br>**What it does:**<br>• Finds each donor vertex in the one-frame _wm by exact position, which recovers the shift and handles merged and split surfaces.<br>• Fits each part's motion against the body over the donor's frames: slide axis and travel, or hinge axis, degrees and pivot, with the sign checked both ways.<br>• Proposes the muzzle, grab points, hand seat, support hold, eject port and load gate from the shapes.<br>• Reads roles off surface names (REVIEW), marks every guess ESTIMATE, and splits islands before calling a magazine missing.<br>• `--render` draws `md3_render.py`'s check image, `--lint` runs card_lint `--file`, and `--compare` diffs the draft against a written card.<br>**Proof, WM_AssaultShotgun re-derived:** shift recovered exactly (100% of vertices), 41 keys the same, 4 different (the eject port, an ESTIMATE both sides, and three grabs within 0.11), card_lint 0 issues.<br>**Also run** on the bullpup pump, Bolter (split magazine), rotary gun (spin) and longbar chainsaw (flip chain): all lint clean.<br>**THE FLOW:**<br>1. Mesh prep (the weapons lane).<br>2. `card_skeleton.py`.<br>3. Review the draft.<br>4. The card into the package's WMCARD.<br>5. **The owner's headset pass on the grab-point page** (wm_tune sliders; placements kept in the bake ledger).<br>6. `bake_defaults.py`, dry run first, on the build lane's go. |
| 27 | Vanilla parity: the chaingun's first shot of a burst dead on, and pistols refiring while held with spread after the first shot (the build lane doomwork-5e, from the weapons lane's Vanilla-set gaps, 2026-09-14) | **COMPILED 2026-09-14 (uzdxrema-11)** on exe 09-14 07:09; the count form installed 07:19:06 (script parsing took 717.16 ms). Not yet played. Committed as RS_VR_Reload 3e8a4f0.<br>• **`WM_Gun.FirstShotsAccurate N`:** the first N shots of a held run fly dead on, and every later shot scatters within ShotSpread. That is vanilla A_FireBullets' test (one bullet and `!refire`), so one pellet a pull only. N is the shots before vanilla's first A_ReFire: the pistol 1, and the chaingun 2, because both A_FireCGun frames of its first cycle are accurate. The first compile had a bool, and the chaingun's second accurate shot made it a count.<br>• **`refireCount`:** vanilla's player.refire, kept per gun so each hand's run is its own. It counts up in WM_HoldFire when a run goes round to Fire again and resets in WM_Ready. It is read off the owner's usercmd in the weapon's own states, so every machine counts alike; the spread stays on the named RNG WMSpread.<br>• **Refire while held** is the existing `WM_Gun.FullAuto`, which is vanilla's A_ReFire at the same cadence. Now documented as such.<br>• **Default off:** every class fires as before. The weapons lane sets FullAuto on both, with FirstShotsAccurate 1 on the Vanilla pistol and 2 on the chaingun. |
| 28 | Rail trail call site: a railgun's trail drawn by RS_Ballistics from the muzzle to where the rail really hit (the build lane doomwork-5e, item 2, 2026-09-14) | **COMPILED 2026-09-14 (uzdxrema-11)** on exe 09-14 07:09, installed 07:19:06 (script parsing took 717.16 ms). Not yet played. Committed as RS_VR_Reload 3e8a4f0.<br>• **`WM_Gun.TrailProfile "name"`:** an RSBDEFS `trail` ("rail" is the Quake 2 one). When unset, the engine draws its own rail in RailColors, as before.<br>• **The engine's trail is switched off** while a profile is set. Both colours are -1 (`WM_Gun.RailPartOff`), which P_DrawRailTrail reads as "draw none of this part". The class switches it, never a local setting.<br>• **The real end point:** `WM_System.WorldRailgunFired` records the start and end of the engine's own rail trace while A_RailAttack is still running, and the gun reads them straight after the call. That means no second trace and no rebuilt aim, the scatter is included, and it is the same on every machine. A rail a handler cancels lays no trail.<br>• **`WM_Gun.LayRailTrail`:** RSB_Trail.Lay from the drawn muzzle (presentation only), or from the rail's own start when no gun is drawn.<br>• **The weapons lane sets `WM_Gun.TrailProfile "rail"` on WM_Railgun.** |
| 29 | Catch-to-equip support: a gun put straight into a hand is bound on the spot and never fires on the old gun's rig. Profile fallbacks become RS_Ballistics' plain `default` (the build lane doomwork-5e's go; the ballistics lane uzdxrema-45's defaults; 2026-09-14) | **COMPILED 2026-09-14 (uzdxrema-11)** on exe 09-14 07:09, installed 07:44:27 (script parsing took 705.71 ms). Not yet played. Committed as RS_VR_Reload 36794c6.<br>• **`WM_System.PutGunInHand(pmo, weapon, hand)`:** the public entry for a package that hands a gun straight to a hand, such as a caught pickup or a console give. It swaps as EquipInstantly does, then binds both hands' rigs and makes their props at once. It binds on the spot because P_PlayerThink fires before WorldTick binds, so a bind left to the next tick came one tic late.<br>• **`CanFire` / `CanAltFire` gain `Weapon asking = null`:** a rig still bound to another gun refuses. WM_TryFire, WM_Charge and WM_TryAltFire pass the invoker. On that refusal (`RigBoundElsewhere`) they go back to Ready with the trigger free: no click, and nothing told to the old gun that it ran dry. null keeps the old behaviour.<br>• **EquipInstantly clears PendingWeapon only for that hand's switch** (or for the gun being put in). A switch pending for the other hand goes on.<br>• **Profile fallbacks:** round, flash and ejecta fall back to RS_Ballistics' `default` profiles, in weapon.zs's OrDefault helpers and rig.zs's four no-gun fallbacks. No live gun uses a fallback. A bullet gun that names no RoundProfile logs once.<br>• **Specs:** NETPLAY_SPEC §5 notes PutGunInHand as P1, and §10 is written as decided. |
| 30 | The smoking barrel: RS_Ballistics' RSB_Barrel call sites, so a pistol smokes after a quick string of shots (the ballistics lane uzdxrema-45's handoff, owner-approved: the pistols are the showpiece; the build lane doomwork-5e's go; 2026-09-14) | **COMPILED 2026-09-14 (uzdxrema-11)** on exe 09-14 07:09, installed 07:46:39 (script parsing took 712.04 ms). Not yet played. Committed as RS_VR_Reload 3bc4d81.<br>• **Heat:** `RSB_Barrel.Shot(gunItem, profile)` in WM_Rig.FlashAt, right after RSB_Flash.Fire, from the same flash profile. A profile with no `barrelheat` adds none, so a second barrel's flash never heats the main one.<br>• **Smoke:** `WM_Rig.BarrelSmoke()` runs every tic from WM_System's tick, right after Pose. It calls `RSB_Barrel.Muzzle(gunItem, MuzzleWorld(), BarrelWorld())` (the trimmed muzzle and bore) while the gun is drawn, resolved and not stowed. A put-away gun stops smoking and keeps cooling by the map clock.<br>• **Placement:** in the rig, not WM_Gun.DoEffect. The rig knows `stowed` (a hidden gun doesn't smoke) and is the flash's own local path. DoEffect runs for every carried gun on every machine, and would have to ask the rig anyway.<br>• **Cost and netplay:** presentation only, like the flash, with no playsim RNG and nothing read back. A gun with no heat costs one lookup in RSB_Barrel's table of at most 16. Carriers today are the `pistol_9mm` and `pistol_45` flashes. |
| 31 | One squeeze, one owner: a hand another mod holds full (a caught gun, a world object) starts no pouch draw or part grab and catches no falling magazine (catch-to-equip Part B, found by the weapons lane's question; the build lane doomwork-5e's go; 2026-09-14) | **COMPILED 2026-09-14 (uzdxrema-11)** on exe 09-14 07:09, installed 07:56:10 (script parsing took 782.62 ms). Not yet played. Committed as RS_VR_Reload 9849d5f.<br>• **`WM_System.HandHeldByOther(pmo, h)`:** the arbiter says the hand is held (`grip.held`), not by us (`grip.mine` as RS_WeaponMech), for a subject that fills it (`FillsHand`: Round, Shell, Inserting, Magazine, Grip, Slide). Never None, the brace subjects (Forend, Foregrip, Support), Holster or Pouch. With no arbiter it reads the engine GripClaim as CatchFalling does (not ours), where only Grip counts.<br>• **Gated:** WorkHand's fresh press (DrawFromPouch and Take) and CatchFalling. CatchFalling also keeps its old engine-field test. Holds already under way are not asked.<br>• **Who can hold a lease** (grep of the owner's six mods plus RS_Grenade, RS_ShieldSaw and the glow mods):<br>&nbsp;&nbsp;– RS_WorldHands' RS_Held (a world object: Weapon is Grip; Ammo, Health, Armor, Inventory and barrels are Magazine; Key is Round);<br>&nbsp;&nbsp;– RS_WorldHands' RS_Stabilize (off-hand brace: Forend, Foregrip or Support; exempt);<br>&nbsp;&nbsp;– RS_VR_Weapons' WM_CatchToEquip (Grip, while the catching squeeze stays closed);<br>&nbsp;&nbsp;– RS_ShieldSaw (off hand, Grip, renewed only while the shield is drawn into that hand and released when it's stowed; folded into RS_VR_Weapons 2026-09-14, so it is in the owner's load order now, and blocking a draw with the shield in that hand is right).<br>RS_Grenade, the glow mods, RS_VRBody and RS_WeaponSelectionSystem claim nothing.<br>• **`Claim` taking a denied hand is unchanged,** now commented as deliberate. |
| 32 | A saw with no ripcord idles while drawn (VANILLA_PARITY F4, route B: the Heavy and Longbar chainsaws' Weapon.ReadySound restarted every tic; the build lane doomwork-5e's go; 2026-09-14) | **COMPILED 2026-09-14 (uzdxrema-11)** on exe 09-14 07:09, installed 08:11:53 (script parsing took 709.89 ms). Not yet played. Committed as RS_VR_Reload 4aa2fb1.<br>• **`WM_Rig.EngineIdle`:** a card with an `idlesound` and no START verb (`card.HasVerbKind`, so an archetype's verbs count) counts as running whenever drawn. A card with a START verb still idles only once StartEngine has caught, as before.<br>• **The loop still stops** while the trigger is down, on stow, on a hand change and on unbind (WM_Rig.Unbind). New: it also stops for a dead player, which neither path did before.<br>• **Cards with an idlesound today** (grep of both WMCARD files): only WM_Chainsaw, which has its ripcord START verb. No card starts humming from this change; the weapons lane adds `idlesound` to WM_ChainsawHeavy and WM_LongbarChainsaw and drops their ReadySound next.<br>• **Netplay:** sound only, local, no RNG. |
| 33 | Belt links join the one casing cap: a long chaingun burst no longer piles links past rsb_casing_max (the ballistics lane uzdxrema-45's hook, RS_Ballistics d2dab36; the build lane doomwork-5e's go; 2026-09-14) | **COMPILED 2026-09-14 (uzdxrema-11)** on exe 09-14 08:30, installed 08:34:48 (script parsing took 703.51 ms). Not yet played.<br>• **`WM_Rig.Brass`:** each thrown WM_BeltLink calls `casing.keep` on RS_Ballistics' `RSB_Service`, found by name once (`CasingCap`, which answers `casing.hello`). With no such service, a link fades only by wm_casing_life, as before.<br>• **`WM_BeltLink.Deactivate`:** over the cap, RS_Ballistics calls it on the oldest foreign casing, and the link fades from then on, flying or lying. Its own lie-still fade (wm_casing_life) is unchanged.<br>• **One cap:** spent brass and hulls were already in it (RSB_Ejecta.Throw). WM_LooseMag (magazines and live rounds) is gameplay and stays out.<br>• **Netplay:** links are local presentation; the fade draws no RNG and nothing reads it. Noted in NETPLAY_SPEC §5.<br>• **First check FAILED:** the field `casingCap` and the method `CasingCap()` were one name (ZScript is case-insensitive). The field is now `casingCapService`. |
| -- | G17 check: a feed part with two surfaces | ANSWERED: both hide on detach and return on seat (Pose hides every surface of a non-present part). No fix. |

---

## 0. What exists, as read

- **The owner's hand velocity is real and exported.** actor.zs:576-595 declares `AttackVel`,
  `AttackAngularVel`, `OffhandVel` and `OffhandAngularVel` as native readonly vector3. All four
  have `DEFINE_FIELD` lines in vmthunks_actors.cpp:2245-2248.
  - **Linear** is map units per second.
  - **Angular** is radians per second about the MAP axes.
  - Both are zero on a frame the runtime reports nothing.
  - They are written only under `!multiplayer` (vk_openxrdevice.cpp ~4739, ~4781).
  - **The angular sign is safe.** I checked the mapping in `updateHandPose`
    (vk_openxrdevice.cpp ~3680): XR goes to map as (x', y, z') -> (-z', -x', y) after the yaw
    turn, which has determinant +1, a proper rotation. So the angular vector is a right-handed
    pseudo-vector in map space, and `ω × r` gives a real tangential velocity. No consumer has
    used angular yet (RS_WorldHands' spin is still differenced), so the flick log prints the
    wrist term separately (see 1d).
- **`close = flick | hand | none` is already parsed** (parser.zs VerbKey `close`, ~1186) into
  `WM_Verb.closeBy`. Nothing acts on it: verb.zs Describe says "step 11: parsed, not yet acted on".
- **Open and shut have one path**, `WM_Rig.SetOpen` (rig.zs ~1540): sound, log, and
  `onopen = ejectall`. Every shut goes through it: the hand back to closeat in
  `WM_System.HoldByVerbs` (~1026), and a let-go at closeat in `ReleaseByVerbs` (~1127).
- **The muzzle-up dump exists** and is what the owner means by "tilt back":
  - `eject rod` in `archetype swingout_revolver` (by = muzzleup, at 0.70, needs open:crane).
  - It is run by `WM_Rig.EjectByMuzzle` (~1658): `BarrelWorld().Z >= at` while the crane is
    open, once per tilt, re-armed below at - 0.15.
  - It works whether or not a hand still holds the crane.
  - **Verdict: it already does what the owner describes.** It is only renamed and generalised below.
- **Break-tops eject on opening today:** `open break` in `archetype breaktop_revolver` has
  `onopen = ejectall` (throws past openat 0.85).
- **The drop-mag button** goes `WM_System.Buttons` (~553) -> `ButtonDrop` (~564) -> `WM_Rig.DropMagazine`
  (rig.zs ~1273). ButtonDrop returns early when `!ammo.magIn` or `!ammo.MagDetaches()`. Revolvers
  and the SSG get `WM_Store.SynthPlaceholder` as their facade magazine (ammo.zs Build ~556):
  attached, non-detaching. So the button logs "does nothing -- its feed store does not detach"
  once, and stops.
- **Drop-mag on every magazine gun today**, read card by card in RS_VR_Weapons/WMCARD.txt:
  - M4A3 (~115), Pistolet (~221), Rifle (~930), M16 (~1161) and Tec9 (~1280): each has a
    `role = feed` part and a synthesised swap with `button = yes`.
  - SMG (~1395): a `role = feed` part and a declared `swap magwell` with `button = yes`.
  - **All six drop their magazine. No change is needed for them.**
- **G1 is real, confirmed from source.** A card with a swap and no cycle behaves like this on
  the verbs path (wm_verbs on, the default):
  - `ShotByVerbs` (rig.zs ~1355) `Discharge`s the chamber. The loop only feeds for a CYCLE with
    `autoOnShot`, and there is none. `Seat` (rig.zs ~1308) -> `SeatMagazine` never feeds.
  - A cycle needs a part (parser.zs VerbProblem ~560). `RackByEvent` (~1515) only logs "no
    cycle verb to rack".
  - **Result: the first pull fires the round the gun was built with, and every pull after
    clicks.**
  - On the old path (wm_verbs off), `FireBody` feeds from the magazine until empty and then
    locks. `SeatMagazine` does not release the lock, and there is no part to rack, so it is
    stuck from then on.
- **The shot today** is `WM_Gun.WM_TryFire` (weapon.zs ~168):
  `A_FireProjectile("WM_Bullet", ..., FPF_NOAUTOAIM)` per pellet, then `ScatterShot`,
  `WM_Bullet.Launch` and `ApplyShotDamage`. Launch and ApplyShotDamage cast and do nothing for
  any other class.
  - `A_FireProjectile`, `A_RailAttack` and `A_Saw` each pick the off hand themselves from
    `invoker == player.OffhandWeapon` (stateprovider.zs ~265, ~449; weaponchainsaw.zs ~88).
    So all three leave the hand holding the gun.
- **No per-card no-casing key exists.** There is `casingsound` (parsed, noted dead) and the global
  `wm_casings` cvar. `Brass` (rig.zs ~1235) runs on every shot of a gun that neither keeps its
  case nor has a manual action.
- **Voxels:** become.zs:22 refuses when `HasModelFrame() || HasVoxelFrame()`, and `HasModelFrame`
  is true for a voxel too (actor.zs ~2190). The magazine it spawns uses sprite `WMMG` and its
  own MODELDEF mesh, so no pack has a voxel for it.

---

## 1. FLICK TO CLOSE

### 1a. What the owner gets

- **SSG, Moonlight and Sunset:** with the barrels or barrel open and no hand on them, snap the
  gun up and they shut, with the close sound.
- **Cola:** snap the gun sideways, toward the side the crane shuts to, and the crane shuts.
- A hand still shuts any of them exactly as today. The flick adds a way; it takes nothing away.

**Why "the way it shuts" is the right direction.** An open part is against its open stop, so the
jerk cannot open it further and the frame carries it along. When the hand stops, the part keeps
going and shuts. That is up for a barrel that tips down, and toward the frame for a crane.

### 1b. Card grammar (open verb)

```
open break
  close      = flick        # EXISTING KEY, now acted on: a flick shuts it, and a hand still does
  flickaxis  = up           # NEW. up | side | x, y, z (gun model axes: x barrel, y across, z up)
  flickscale = 1.0          # NEW. how hard, times wm_flick_speed. Default 1.0
end
```

- **`flickaxis`:**
  - `up` = (0, 0, 1). Unstated with `close = flick`, it means `up`.
  - `side` = (0, ±1, 0), the sign resolved from the part's own motion: the y of its grab point
    shut minus its grab point fully open. For the Cola's crane (axis -x, +90 degrees, pivot
    (0, 0.029, -4.347)) the grab goes from (-0.54, 4.57, -4.32) open to (-0.54, 0, 0.19) shut,
    so `side` is -y.
  - A slide part's shut direction is -dof.axis, so `side` uses the sign of -axis.y.
  - A vector is taken literally and made unit.
- **`flickscale`:** a number above 0, at most 4.
- **Refusals** (parser.zs VerbProblem, OPEN branch):
  - `flickaxis` or `flickscale` on an open verb without `close = flick`: "flickaxis says which
    way a flick shuts it -- this open verb has no close = flick".
  - `close = flick` with `rest = spring`: "a spring shuts it by itself".
  - `flickaxis = side` on a part whose shut direction has no y component: "this part does not
    shut sideways -- give flickaxis a vector".

### 1c. Cvars (RS_VR_Reload/CVARINFO.txt, `---- FIRING` section, after `wm_recoil_travel`)

```
// A FLICK SHUTS AN OPEN GUN (an open verb with close = flick). How fast the open part must move
// along its flickaxis, hand and wrist together, in METRES A SECOND whatever vr_vunits_per_meter
// is. Script, read on the tic it is measured -- nothing drawn moves by it, so it sits on no live
// page. Off: only a hand shuts it.
user float wm_flick_speed = 1.5;
user bool  wm_flick_close = true;
```

MENUDEF.txt, `OptionMenu "WM_FireMenu"`, `THE ACTION` block, after the `wm_recoil_travel` slider.
WM_FireMenu is not a LINT-LIVE page.

```
	Option "A flick shuts an open gun",       "wm_flick_close", "OnOff"
	Slider "How hard a flick (metres a second)", "wm_flick_speed", 0.5, 5.0, 0.1, 1
```

### 1d. How it is measured (rig.zs, new `private void FlickByVerbs(PlayerPawn pmo)`)

**Where it is called:** from `WM_Rig.Automatic` (~956), in the `WM_Verb.Enabled()` branch, straight
after the eject-by-tilt call. It runs once a tic per rig. The rig is the gun, and `rig.hand` is the
hand holding it: the owner's hand, read off `pmo`, which is the container's own pawn.

**Every OPEN verb with `closeBy == "flick"` and a part, each tic:**

1. **Skip** if any of these holds: `!prop`, `!resolved`, `stowed`, or `!Cvb("wm_flick_close", true)`.
2. **Reset** (quiet = `FLICK_GRACE_TICS`, calm = false, last = 0, then continue) when either:
   - `heldPart == v.partIndex` (a hand has it), or
   - `DrawnValue(part) <= v.closeAt` (already shut).
3. **The flick direction in the world:** `dirW = WorldDir(part.dof.pivot, FlickAxisModel(v, part))`,
   made unit; skip if near zero. It is the gun frame's axis as drawn (controller, placement
   sliders, all of it).
4. **The open part's own velocity**, map units a second, at its grab point:
   - `lin`, `ang` and `handAt` are the gun hand's AttackVel / AttackAngularVel / AttackPos, or
     the Offhand ones. Assign them with if/else, never `?:` on vectors.
   - `partAt = World(CarriedBy(v.partIndex, part.grabAt))`
   - `linAlong = lin dot dirW`
   - `spinAlong = (ang cross (partAt - handAt)) dot dirW`
   - `along = linAlong + spinAlong`
   - **Why the wrist term matters:** a sideways wrist roll barely moves the grip pose, since the
     controller's origin is near the roll axis. The cylinder several centimetres above it moves a
     lot. Linear velocity alone would miss the Cola's flick.
5. **The threshold:** `need = wm_flick_speed × vr_vunits_per_meter × v.flickScale`.
   `vr_vunits_per_meter` is read through `Cvf` with fallback 34. It is an engine cvar;
   menu_lint only checks `wm_` reads.
6. **The window:** `mean = (along + verbFlickLast[k]) / 2`, then `verbFlickLast[k] = along`. A
   two-tic mean halves a one-sample tracking spike. A real flick lasts about 3 tics.
7. **Guards, in order:**
   - `if (verbFlickQuiet[k] > 0) { verbFlickQuiet[k]--; continue; }`. This grace follows letting
     go of the part, or the part leaving shut: the jerk that yanked it open, or the thumb on the
     button, does not shut it again.
   - `if (!verbFlickCalm[k]) { if (along < need * 0.5) verbFlickCalm[k] = true; continue; }`. The
     hand has to settle once after the grace.
8. **Fire:** `if (mean >= need) FlickShut(pmo, k, mean, linAlong, spinAlong, need)`.
9. **No fallback for zero velocity.** No valid velocity means no flick: an honest zero, never a
   differenced guess.

**`FlickShut`:**
- Sets `part.value = 0.0`.
- If `IsHeldOpen(k)`, calls `SetOpen(pmo, k, false, drawn, how)`. Otherwise (part-open, never
  past openat) it does `PlaySnd(card.closeSound)` and logs the same line itself.
- Then `level.VRHaptic(hand, 0.6, 14.0)` and resets quiet and calm.

**`SetOpen` gains `String how = ""`**, appended to its CLOSED or OPENED line. Existing callers
are unchanged. **One log line per flick:**

`main gun: [verbs] open break CLOSED at drawn 0.93 -- FLICKED up at 2.1 m/s (needs 1.5: hand 1.3, wrist 0.8) -- under the hammer 0 (live); stores cylinder [...]`

**Rig state:**
- `Array<int> verbFlickQuiet; Array<double> verbFlickLast; Array<bool> verbFlickCalm;`
- `const FLICK_GRACE_TICS = 6;` (about 0.17 s, a constant with a comment, not a second slider).
- Sized and zeroed wherever the other verb arrays are: `BindVerbs` (~182), `Unbind` (~319),
  `Reset` (~335).

**`FlickAxisModel(v, part)`:** the `side` sign from the hinge math `CarriedBy` already uses
(pivot + WM_Space.Rotate(grab - pivot, axis, degrees) for fully open). Otherwise `v.flickAxis`,
otherwise (0, 0, 1).

**HUD:** `WM_System.VerbHoldText` OPEN (~1223) appends
`" -- or let go and flick it <up|side>"` when `closeBy == "flick"`.

### 1e. verb.zs / parser.zs / archetypes

- **verb.zs WM_Verb:**
  - Fields: `Vector3 flickAxis; bool flickAxisSide; double flickScale;`
  - `Init`: (0,0,0), false, 1.0. `Copy`: copies all three.
  - `Describe` OPEN: "closes by a flick along up|side|(x,y,z) at N× wm_flick_speed, or by hand",
    replacing the step-11 "not yet acted on" text.
- **parser.zs:**
  - `VerbTakesKey(OPEN)`: add `flickaxis`, `flickscale`, `button` (the last for item 3).
  - `VerbKey`: parse `flickaxis` (`up` / `side` / triple) and `flickscale` (a positive number,
    at most 4; ReadFraction does not fit, so parse like `IsNumber`).
  - Header comment (~41) grammar line: `close(flick|hand|none) flickaxis(up|side|x,y,z) flickscale button(yes|no)`.
- **RS_VR_Reload/WMCARD.txt:**
  - `archetype breakaction` `open break`: add `close = flick`, `flickaxis = up`.
  - `archetype breaktop_revolver` `open break`: see 2c.
  - `archetype swingout_revolver` `open crane`: see 2c.
- **RS_VR_Weapons/WMCARD.txt:** no card line needed. All four guns take it from their archetype.

---

## 2. ORIENTATION-GATED DUMP

### 2a. The general condition: `by = tilt`

```
eject extractor
  by       = tilt          # NEW word. The gun itself, not a part: an axis of it pointed up past `at`
  tiltaxis = down          # NEW. barrel | up | down | x, y, z -- a gun model-space axis
  at       = 0.10          # the SINE of that axis's elevation above horizontal, 0..1 (existing key)
  from     = cylinder
  needs    = open:break
end
```

- **`by = muzzleup` stays accepted,** as shorthand for `by = tilt` + `tiltaxis = barrel`. The
  Cola's archetype is unchanged in meaning.
- **"Past its side, or upside down"** is the gun's DOWN axis rising above horizontal. At
  `at = 0.10`, the top of the gun is about 6 degrees past vertical-sideways. Inverted reads 1.0.
  Level or muzzle up reads at most 0.
- **verb.zs:**
  - Replace `bool ejectByMuzzleUp` with `bool ejectByTilt; bool tiltAlongBarrel; Vector3 tiltAxis;`.
  - Update `Init`, `Copy` and `Describe` ("the gun's down axis pointed up past 0.10 throws out
    every case in cylinder").
- **parser.zs:**
  - `by`: `hand` sets false. `muzzleup` sets tilt with `tiltAlongBarrel = true`. `tilt` sets tilt.
  - `tiltaxis`: `barrel` sets `tiltAlongBarrel`; `up` / `down` / a triple sets `tiltAxis`, unit.
  - `VerbTakesKey(EJECT)`: add `tiltaxis`, `button`.
  - VerbProblem ~553: the "names no part" rule keys on `ejectByTilt`.
  - New refusals: `by = tilt` without `tiltaxis` ("say which axis of the gun has to point up");
    `tiltaxis` with `by = hand`.
- **rig.zs:** `EjectByMuzzle` becomes `private void EjectByTilt(PlayerPawn pmo)`. The body stays;
  only the axis changes:
  - `axisW = tiltAlongBarrel ? BarrelWorld() : WorldDir(card.muzzle, tiltAxis).Unit()`, written
    with if/else.
  - `rise = axisW.Z`.
  - Same gate, same once-per-tilt, same re-arm at at - 0.15.
  - Its `how` text: `"tilted -- its down axis 0.34 up, throws at 0.10"`.
  - Rename the call in `Automatic`.
  - `DumpVerbs` needs no change.

### 2b. The gun's attitude comes from the drawn prop

`WorldDir` goes through `prop.ModelPointToWorld`: the prop is `FollowHandMode = hand + 1`, so this
is the owner's own controller pose plus MODELDEF and the placement sliders. That is the gun as the
owner sees it. No `consoleplayer` read is added. The pawn is the one passed into `Automatic`.

### 2c. Archetypes (RS_VR_Reload/WMCARD.txt)

**breaktop_revolver**, with `onopen = ejectall` and `from = cylinder` removed from `open break`:

```
  open break
    part      = barrel
    openat    = 0.85
    closeat   = 0.05
    rest      = stay
    close     = flick
    flickaxis = up
    button    = yes
  end

  # THE EXTRACTOR, BY GRAVITY: open, and turn the gun past its side or over, and every case
  # falls out. `at` is the sine of how far the gun's DOWN axis is above horizontal.
  eject extractor
    by       = tilt
    tiltaxis = down
    at       = 0.10
    from     = cylinder
    needs    = open:break
    button   = yes
  end
```

**swingout_revolver:**
- `open crane`: add `close = flick`, `flickaxis = side`, `button = yes`.
- `eject rod`: add `button = yes`. Keep `by = muzzleup`, `at = 0.70`.

**breakaction (SSG): keep `onopen = ejectall`.** A real ejector double throws its hulls as it
opens, and the owner asked only for the flick on it. **Recommendation: leave it.**

What still holds after the change:
- `WM_Card.KeepsCaseOnShot` stays true for break-tops (they have an EJECT verb), so a fired case
  still waits in its chamber.
- The load zone still needs `open:break`.
- A break-top reloaded muzzle-down with its top up never re-arms the tilt, so fresh rounds stay in.

---

## 3. DROP-MAG ON EVERY FAMILY

### 3a. Magazine guns

Pistols, rifles, SMGs, and later the chaingun, plasma, rocket, BFG and railgun: **already work**
(section 0), as long as the magazine part is `role = feed`. That is the grammar the weapons lane
uses (section 5). No code change.

### 3b. Revolvers: the button opens the gun and dumps it

The general key is `button = yes` on an OPEN verb and on an EJECT verb. Default no: `WM_Verb.Init`
sets `button = (kind == SWAP)`, which is already true.

- **OPEN with button:** the button opens it if shut.
- **EJECT with button:** once its gate is open, the button throws everything out, whatever the
  gun's attitude.

**system.zs `ButtonDrop` (~564),** new first branch before the `magIn` / `MagDetaches` tests:

```
if (WM_Verb.Enabled() && ButtonWorksVerbs(ph, pmo, r)) return;
```

**`private bool ButtonWorksVerbs(WM_PlayerHands ph, PlayerPawn pmo, int r)`:**

- Returns false when the card has no OPEN or EJECT verb with `button`. Every magazine gun, the
  pumps and the SSG fall through to today's path untouched.
- **For each OPEN verb with button,** if it is not open:
  - If the other hand (1 - r) holds its part: `rig.StopDrive`, `hstate.Clear()`,
    `rig.heldPart = -1`, `ReleaseClaim`. This is the same release ButtonDrop already does for a
    magazine part.
  - `part.value = 1.0`.
  - `rig.SetOpen(pmo, k, true, -1.0, "by the drop-mag button")`. That also runs `onopen` if the
    verb has one.
- **Then, for each EJECT verb with button** whose gate is open (`rig.LoadGateOpen`):
  - If `ammo.SlotHeld(from, -1)`: `rig.SetEjectThrown(k, true)` and
    `rig.ThrowOutAll(pmo, k, v.fromStore, rig.GateCarrier(v), "by the drop-mag button")`.
  - Otherwise one line: "drop-mag button -- nothing in cylinder to throw out".
- Returns true.

**What a press gives:**
- Moonlight / Sunset: the barrel drops open and every case flies.
- Cola: the crane swings out and dumps.
- Then load, and flick shut: a whole revolver reload with one hand on the gun.
- The flick's grace starts when the part leaves shut, so the press itself never shuts it again.

**Log:** SetOpen's OPENED line and ThrowOutAll's EJECTED line, both tagged "by the drop-mag
button". Once per press, never per tic.

### 3c. The placeholder magazine stays

`WM_Store.SynthPlaceholder` is not a button hack. It is the facade's null guard: `WM_Ammo`
dereferences `magStore` everywhere, and `Adopt` rebuilds when it is null. A synthesised
detachable `mag` in its place would fill itself and show on the HUD. **The new branch runs before
the placeholder's refusal, so nothing needs removing.** Only its comment's mention of the button
is updated. Step 1 extends the same idea to a placeholder chamber.

---

## 4. G1 -- MAGAZINE-ONLY GUNS: `firesfrom`

**One weapon-block card key says what a trigger pull spends.** It also covers G5.

```
firesfrom = chamber     # DEFAULT, unstated: today's rules exactly
firesfrom = magazine    # no chamber: a pull takes WM_Gun.RoundsPerShot straight from the magazine
firesfrom = reserve     # no stores: a pull takes RoundsPerShot from the owner's Weapon.AmmoType1 (G5)
firesfrom = none        # fires with no ammunition at all -- a chainsaw (G5)
```

Chosen over a synthesised part-less cycle, because a part-less cycle would need:
- a parser exception,
- a feed-on-seat rule,
- a fake chamber shown on the HUD (a 100-round box plus 1),
- and holdopen edge cases.

`magazine` needs none of that. Seating is "ready" because there is nothing to chamber, and the
drop button already drops a `role = feed` magazine.

**card.zs WM_Card:**
- One constant per line: `const FIRES_CHAMBER = 0;` `const FIRES_MAGAZINE = 1;`
  `const FIRES_RESERVE = 2;` `const FIRES_NOTHING = 3;`
- Field `int firesFrom;`. It defaults to 0 because WM_Card is made by `new`; no initialiser.
- `String FiresFromWord()`.
- `SynthesiseStores` (~298): for `FIRES_RESERVE` / `FIRES_NOTHING`, push only
  `WM_Store.SynthPlaceholder(...)`.

**parser.zs:**
- `CardKey` (~748): `firesfrom` accepts chamber | magazine | reserve | none. Anything else:
  "firesfrom is chamber, magazine, reserve or none".
- `FinishCard`, after step 3:
  - `magazine`: refuse any CYCLE verb ("a cycle strokes a round into a chamber -- firesfrom =
    magazine has none: drop the cycle, or the card's role = action part, which synthesises one").
  - `magazine`: refuse a card with no COUNTED store in `card.stores`.
  - `reserve` / `none`: refuse any CYCLE, SWAP, LOAD or EJECT verb, and any declared store ("a
    gun that fires from the reserve keeps no rounds of its own").
  - Header comment: add the key.

**store.zs / ammo.zs:**
- `WM_Store.SynthPlaceholderChamber()`: InitSlotted 1, `synthesised = true`, `placeholder = true`
  (Fill already leaves a placeholder empty).
- `Describe()` placeholder text is worded per kind.
- `WM_Ammo.Build` (~542): when `!chamberStore`, use `SynthPlaceholderChamber()` if
  `card && card.firesFrom != WM_Card.FIRES_CHAMBER`, else `SynthChamber()`.
- New, in the Adopt / body / Sync shape:
  - `bool MagazineHolds(int n)`: attached and `Live() >= n`.
  - `int SpendFromMagazine(int n)`: takes n, returns how many went (0 when short: nothing moves).

**system.zs `CanFire` (~236)** gains `int rounds = 1`. The firesFrom branch comes first, on both
wm_verbs paths:
- NOTHING: `loaded = true`
- RESERVE: `loaded = ReserveHolds(pn, rig.card, rounds)`. That is
  `players[pn].mo.FindInventory(WM_LooseMag.ReserveFor(card.weaponClass))` with Amount >= rounds,
  or `sv_infiniteammo`.
- MAGAZINE: `loaded = rig.ammo.MagazineHolds(rounds)`
- CHAMBER: today's lines, unchanged.
- It still ends `loaded && (!Enabled || InBattery())` and keeps the `stowed` and `prop` tests.

**system.zs `OnShot` (~272)** gains `int rounds = 1` and passes it to `rig.OnShot`.

**rig.zs `OnShot` (~1065)** gains `int rounds = 1`:
- MAGAZINE: `ammo.SpendFromMagazine(rounds)`, `hammerFell = true`; no ShotByVerbs, no Fire.
- RESERVE / NONE: nothing to spend here (the weapon action already took inventory, G5).
- CHAMBER: today's lines.
- Sound, haptic, Flash, Brass (G4 gate), Sparks are shared.
- Log for MAGAZINE: `"main gun: SHOT -- %d round%s from the magazine, %d left"`.

**rig.zs `OnDry` (~1122):** MAGAZINE: "click -- magazine out" or "click -- magazine has N, a shot
needs M". RESERVE: "click -- the Cell reserve is empty". Both come before the chamber texts.

**Seat, drop and HUD texts:**
- `Seat` (~1308): "One already chambered / Rack the slide" becomes "ready -- it fires straight
  from the magazine".
- `DropMagazine` (~1303) and `PullOut` (system.zs ~1261): "one still chambered / chamber empty"
  becomes "the gun is empty until one goes in".
- Phase 2: grep `chambered` in system.zs `BuildHud` / `LogHud` / `Dump` and word each for the
  firesFrom mode.

**weapon.zs `WM_TryFire`:** passes `invoker.RoundsEachShot()` to `CanFire` and `OnShot` (G2).

**Pouch:** unchanged for MAGAZINE (it has a swap, so the pouch hands a magazine).

---

## 5. G2, G3, G4, G5 -- THE SHOT AND WHAT IT SPENDS

All on `WM_Gun` (weapon.zs), in the `THE SHOT` comment block. Field names never match property or
method names.

| Property | Field | Unset | Meaning |
|---|---|---|---|
| `WM_Gun.RoundsPerShot N` | `roundsPerShotCount` | 1 | **G2.** What one pull takes from the magazine (`firesfrom = magazine`) or the reserve (`reserve`). A chamber gun fires chambers (ChambersPerPull) and ignores it; ShotText says so. `RoundsEachShot()` = clamp(1, 1000). BFG: 40 from a 160 battery. |
| `WM_Gun.ShotClass "<actor>"` | `shotClassName` (String) | `WM_Bullet` | **G3.** The projectile each pellet is. Resolved BY NAME at fire (`FindClass`), so a class in another package, such as the ballistics lane's future RSB_Bullet, is never a compile-time reference. Not found: log once, fire WM_Bullet. `Rocket`, `PlasmaBall` and `BFGBall` bring their own speed, damage and death (BFGBall's spray aims by the player's view angle, vanilla behaviour, noted). |
| `WM_Gun.ShotRail true` | `railShotOn` | false | **G3.** `A_RailAttack` per pellet instead of a projectile. Damage from ShotDamage rolled `random[WMRail](lo, hi)`; unset is 100 (a placeholder the weapons lane replaces). `useammo false`; spread = ShotSpread. Colours: see the phase-2 check below. |
| `WM_Gun.ShotSaw true` | `sawShotOn` | false | **G6.** `A_Saw` instead of a projectile; see section 7. |

**WM_TryFire's pellet loop (~192), in order:**
1. `if (sawShotOn) { saw; }`
2. `else if (railShotOn) { A_RailAttack(...); }`
3. `else { A_FireProjectile(ShotActor(), 0, false, 0, 0, FPF_NOAUTOAIM); ScatterShot; WM_Bullet.Launch; ApplyShotDamage; }`

The else branch is today's code with the class name swapped. **That call site is the seam the
ballistics lane swaps at; keep it one block.**

**Rail colours, checked (p_effect.cpp `P_DrawRailTrail` ~784-900): no property needed.**
`color1 = 0` / `color2 = 0` are turned into -1 there, which draws the engine's stock trail: a blue
spiral (rblue1-4) and a grey core. Its colour picks use `M_Random`, the non-playsim RNG, so it is
safe in netplay. Approved (coordinator): expose it anyway, since it is cheap.

- **Property:** `WM_Gun.RailColors spiral, core`.
- **Fields:** `int railSpiralColor; int railCoreColor;`. Two ints, 0xRRGGBB. Unset 0 means the
  engine's default rail colour.
- **Call:** passed as `A_RailAttack`'s color1 (the outer spiral) and color2 (the core).
- **Comment at the call:** says 0 is the engine default.
- **ShotText:** prints them only when set.

**G4 -- `casing = yes | none`** (weapon-block card key, default yes):
- card.zs: `bool noCasing;`. parser.zs CardKey: yes/no/none.
- rig.zs `Brass()` (~1235): `if (card.noCasing) return;`.
- `ThrowOutAll`'s spent branch (~1640): skip when `card.noCasing`.
- For plasma, BFG, rail, rocket, flamethrower, chainsaw.

**G5 -- `firesfrom = reserve | none`** (section 4 for the key):
- **Inventory is taken in the weapon action, which runs on every machine,** never in the rig.
  In `WM_TryFire`, after CanFire says yes and before the shot:
  `if (sys.FiresFrom(invoker.GetClassName()) == WM_Card.FIRES_RESERVE) invoker.DepleteAmmo(false, true, rounds, true);`
  `Weapon.DepleteAmmo(altFire, checkEnough, ammouse, forceammouse)` (weapons.zs ~1167) honours
  sv_infiniteammo and PowerInfiniteAmmo.
- New `int WM_System.FiresFrom(String weaponClass)`: through `CardForWeapon`, and
  `FIRES_CHAMBER` for no card. The card set is loaded on every machine (WorldLoaded -> LoadCards).
- **Pouch:** system.zs `DrawFromPouch` (~1364) returns first for RESERVE / NONE with one Once line:
  "the <gun> fires from the <Ammo> reserve -- the pouch has nothing for it".
- **HUD:** `ReserveText` already shows the reserve.
- **A card is still required,** for the prop. A chainsaw's card is a weapon block, a prop, a
  model and `firesfrom = none`.

---

## 6. G7 AND G8 -- CHARGE, AND FIRE HOLD / RELEASE HOOKS

### G7 -- `WM_Gun.ChargeTics N` + `WM_Gun.ChargeSound "snd"`

Fields `chargeTicCount`, `chargeSoundName`; unset 0 and "".

**States** (weapon.zs ~270). The 0-tic first state costs no tic, so every existing gun's cadence
is untouched, including a FullAuto refire through `ResolveState("Fire")`:

```
Fire:
	TNT1 A 0 WM_Charge();
	TNT1 A 1 WM_TryFire();
	TNT1 A 18 WM_FireWait();
	TNT1 A 0 WM_HoldFire();
	Goto Ready;
Charge:
	TNT1 A 1 WM_ChargeWait();
	Goto Fire+1;
```

`Goto Fire+1` is valid ZScript (arachnotron.zs:57).

**`action State WM_Charge()`:**
- `if (invoker.chargeTicCount <= 0) return null;`
- `invoker.mustRelease = true;`
- Ask `sys.CanFire(pn, h, most, rounds)`. No: `sys.OnDry`, then `ResolveState("Dry")`. An empty
  BFG does not charge.
- Yes: `sys.OnCharge(pn, h, invoker.chargeSoundName, invoker.chargeTicCount)`, then
  `ResolveState("Charge")`.

**`action void WM_ChargeWait()`:** `A_SetTics(max(invoker.chargeTicCount, 1))`.

WM_TryFire asks CanFire again after the charge. A magazine dropped mid-charge clicks. The trigger
coming back mid-charge does not cancel, as in vanilla.

**`WM_System.OnCharge` -> `WM_Rig.OnCharge(String snd, int tics)`:** `PlaySnd(snd)` at the prop
plus one line, "main gun: CHARGING -- 30 tics, then the shot". Presentation only, like the fire
sound.

For the BFG, the weapons lane sets `ChargeTics 30`, `ChargeSound "weapons/bfgf"`.

### G8 -- `virtual void FireHeld(int heldTics)` and `virtual void FireReleased(int heldTics)` on WM_Gun

Both empty by default. They are called from a new `override void DoEffect()`. p_mobj.cpp:4733 calls
it on every inventory item each tic, on every machine.

**Fields:** `bool fireStarted; int fireHeldTics;`.
- Set `fireStarted = true` in WM_TryFire when a shot leaves.
- Clear it in `WM_Ready` and on the `Dry` paths.

**DoEffect:**
- `held` = owner is a player **and** this gun is that player's `ReadyWeapon` or `OffhandWeapon`
  **and** `fireStarted` **and** its attack bit is down in `owner.player.cmd.buttons`. Add a plain
  method `bool TriggerIsDown()`, since the action version needs an action context.
- `held`: `fireHeldTics++; FireHeld(fireHeldTics);`
- Otherwise, if `fireHeldTics > 0`: `FireReleased(fireHeldTics); fireHeldTics = 0; fireStarted = false;`

It reads the player's usercmd, so every machine calls it alike. The flamethrower subclass (weapons
lane) calls the ballistics lane's `RSB_Flame.Stream` / `Stop` in these by name.

---

## 7. G6 -- CHAINSAW

`WM_Gun.ShotSaw true` + `WM_Gun.SawSounds "full", "hit"`. Fields `sawShotOn`, `sawFullSound`,
`sawHitSound`; unset sounds are `weapons/sawfull` and `weapons/sawhit`.

**In WM_TryFire's loop, once per pull (not per pellet):**

```
int dmg = 2; int sflags = SF_NOUSEAMMO | SF_NOTURN | SF_NOPULLIN;
if (invoker.shotDamageLo > 0) { dmg = random[WMSaw](lo, max(lo, hi)); sflags |= SF_NORANDOM; }
A_Saw(invoker.sawFullSound, invoker.sawHitSound, dmg, "BulletPuff", sflags);
```

- `SF_NOTURN` and `SF_NOPULLIN`, because vanilla A_Saw turns and pulls the PLAYER toward the
  target. In a headset that yanks the view.
- A_Saw picks the off hand itself.
- **Idle and run sounds need no new code:** the class sets `Weapon.ReadySound "weapons/sawidle"`
  (played by A_WeaponReady inside WM_Ready) and `Weapon.UpSound "weapons/sawup"`.
- The class also sets `WM_Gun.FullAuto true` and `WM_Gun.FireTics 4` (vanilla's A_Saw every 4 tics).

---

## 8. G10 -- TWO-HANDED GUNS: `hands = 2`

**The smallest useful version:** the other hand must be holding the gun's support grip for the
trigger to fire. Aim is unchanged; the shot still leaves the gun hand.

**Card:** weapon-block key `hands = 1 | 2`.
- card.zs: `int handsNeeded;` (0 or 1 means one).
- parser: refuse other values, and refuse `hands = 2` on a card with no `role = support` part:
  "hands = 2 needs a part with role = support -- where the other hand holds it".

**Holding the support grip** (system.zs):
- `WorkHand` press path (~743): `NearestPart(ph, pmo, h, rig, true, rig.card.handsNeeded >= 2)`.
- `NearestPart` (~835): `if (part.role == "support" && rig.card.handsNeeded < 2 && (!withSupport || !BraceOn())) continue;`
- A squeeze in the support oval then goes `Take` -> ONPART on the support part, whatever
  `wm_brace` says. Everything downstream already copes:
  - `StartDrive` returns with no surfaces.
  - `HoldByVerbs` with no verb releases when the squeeze opens.
  - `PinHand` seats it with the support seat set.
  - `PutAway` stows that hand's own gun while it holds, so it cannot fire.

**Firing:** `CanFire` adds, after the stowed test:

```
if (rig.card.handsNeeded >= 2 && ph.hstate[1 - h].HeldPart() != rig.card.FindRoleIndex("support")) return false;
```

`OnDry` says "click -- it needs both hands: take the support grip" before the other texts.

**Dual-wield:** unchanged. A two-hander sits in its card's hand, and the other hand keeps its own
gun, stowed while it holds the grip. Two two-handers, one per hand: neither fires while one hand
can hold only one grip. It is logged, not prevented.

**Bind log:** "hands 2 -- fires only while the other hand holds its support".

**Later, not in this build:** aiming along the line from the rear hand to the front hand. That is
an engine piece.

**Netplay:** the grip is local hand input, so the refusal is decided on the owner's machine only
(section 10).

---

## 9. A VOXEL CLIP BECOMES A MAGAZINE (become.zs)

**The owner's rule: the magazine outranks the voxel.** Only a mod's own MODELDEF model still keeps
a clip as it is.

become.zs `GetObject`, line 22:

```
// A MOD'S OWN MODEL keeps its clip. A VOXEL does not: HasModelFrame is true for a voxel too, so
// the test is "has a model, and that model is not a voxel". With a pack loaded (RS_Main's has
// clipa), a grabbed clip becomes our magazine like a sprite clip does.
if (inv.HasModelFrame() && !inv.HasVoxelFrame()) return null;
```

After `m.Setup(...)`, add `m.VoxelOverride = false;`. The replacement starts as our mesh even if
the engine's coming change keeps VoxelOverride on held and grabbed actors. The original clip,
override and all, is destroyed by `RS_GrabPolicy.Become`. RS_Held re-derives VoxelOverride each
tic from `HasVoxelFrame()`, which is false for `WMMG`. Update the header comment ("A mod that gives
its clips a model keeps them; a voxel pack's clip becomes ours").

**Netplay:** no RNG. The decision is identical whether a machine has voxels on or off: a sprite
clip becomes ours, a voxel clip becomes ours, a model-only clip stays. So it cannot depend on a
local render setting. The grab itself is RS_WorldHands' local hand input: known gap, section 10.

---

## 10. NETPLAY -- what is local input, and what changes game state

**Decided from LOCAL-ONLY input.** VR hand data is not in usercmd_t, and the velocity fields are
renderer-owned, never serialised, and written only when `!multiplayer`:
- **Flick to close:** velocity plus the drawn gun's pose. **In a netgame the velocity reads zero,
  so a flick never shuts anything;** the hand shut still works.
- **Tilt dump:** the drawn gun's pose, from the local controller frame.
- **Two-handed support grip:** the hand's grip on the part.
- **The clip-to-magazine become:** RS_WorldHands' grab.

**Deterministic INPUT:**
- The drop-mag button (BT_*DROPMAG in usercmd).
- The trigger, and what G2, G3, G5, G6, G7 and G8 do with it.
- Rail and saw damage use named RNG inside the weapon action, which runs on every machine.
- Reserve ammo is taken with `DepleteAmmo` in that same action.
- The G8 hooks read the owner's usercmd.

**What changes game state, and how it is keyed:**
- Part values, open state and stores live on the gun's WM_Ammo and the owner's WM_Rig. They are
  mutated only by the container of the pawn passed in (`Automatic(pmo)`, `ButtonDrop(ph, pmo, r)`,
  `CanFire(pn, ...)`, `OnShot(pn, ...)`), never by a new `players[consoleplayer]` read.
- Thrown cases and rounds (`ThrowOutAll`) scatter by `WM_Jitter` hash, never playsim RNG.
- New cvars go through the existing `Cvf` / `Cvb` helpers. Those read the console player's user
  cvars: a known gap, which per-player cvars via userinfo fixes later.

**The co-op limitation, stated, not solved:** the reload system still runs only the console
player's hands (WM_System.WorldTick). Anything decided above by hand input happens on the owner's
machine only, until Engine docs/NETWORK_HAND_INPUT_PLAN.md networks per-hand pose, grip and
velocity. Gating hand verbs in a netgame is the owner's call, still owed to him.

---

## 11. CARD GRAMMAR FOR THE WEAPONS LANE (roster cards)

Magazine part is `role = feed` (drop button, seat and guide all key on it). No `role = action`
part: it would synthesise a cycle, which `firesfrom = magazine` refuses. No mechanism, no verbs.

```
weapon "WM_Chaingun"
  hand      = main
  prop      = "WM_PropChaingun"
  model     = "..." "..."
  capacity  = 100
  magfamily = "chaingun"
  firesfrom = magazine
  hands     = 2
  muzzle / barrel / ejectport / ejectdir / magmodel / magskin / magscale / magcenter / firesound ...
end
part box
  role    = feed
  subject = magazine
  take    = no
  surface = <box surface>
  grab = ...   grabradius = ...
  dof
    kind = slide   axis = ...   distance = ...   detach = 0.9
  end
end
part support
  role    = support
  subject = support
  grab = ...   grabradius = ...
end
```

**Class Default lines per gun:**

| Gun | Card | Class |
|---|---|---|
| Chaingun | above | `Weapon.AmmoType1 "Clip"`, `WM_Gun.FullAuto true`, `WM_Gun.FireTics 4` |
| Plasma rifle | `firesfrom = magazine`, `capacity = 50`, `casing = none` | `Weapon.AmmoType1 "Cell"`, `WM_Gun.ShotClass "PlasmaBall"`, `WM_Gun.FullAuto true`, `WM_Gun.FireTics 3` |
| Rocket launcher | `firesfrom = magazine`, `capacity = 6`, `casing = none`, `hands = 2` | `Weapon.AmmoType1 "RocketAmmo"`, `WM_Gun.ShotClass "Rocket"`, `WM_Gun.FireTics 20` |
| BFG | `firesfrom = magazine`, `capacity = 160`, `casing = none`, `hands = 2` | `WM_Gun.RoundsPerShot 40`, `WM_Gun.ShotClass "BFGBall"`, `WM_Gun.ChargeTics 30`, `WM_Gun.ChargeSound "weapons/bfgf"` |
| Railgun | `firesfrom = magazine`, `casing = none` | `WM_Gun.ShotRail true`, `WM_Gun.ShotDamage lo, hi`, `WM_Gun.RoundsPerShot N` |
| Flamethrower | `firesfrom = reserve`, `casing = none` | `WM_Gun.FullAuto true`, `WM_Gun.FireTics 2`, then `ShotClass "<flame projectile>"` or override `FireHeld` / `FireReleased` |
| Chainsaw | `firesfrom = none`, `casing = none` | `WM_Gun.ShotSaw true`, `WM_Gun.FullAuto true`, `WM_Gun.FireTics 4`, `Weapon.ReadySound "weapons/sawidle"`, `Weapon.UpSound "weapons/sawup"` |

---

## 12. HEADSET TESTS (no typing: the wheel or number keys; RS_VR_Weapons' WM_Player carries every gun)

**Revolvers and SSG (slots 4 and 3)**
1. **Moonlight (slot 4, main).** Pull the barrel down with the off hand: it opens and nothing
   comes out. Roll the gun onto its side and past it: every case falls out. Load a speedloader.
   Let go of the barrel, then snap the gun upward: the barrel shuts with the close sound, and it
   fires.
2. Moonlight open, held level or muzzle up: nothing falls out.
3. Moonlight open, the off hand still holding the barrel: snap the gun up. It must NOT shut.
4. Moonlight open, let go, raise the gun slowly: it must NOT shut. Snap it: it shuts.
5. Sunset (off hand): tests 1 to 4 with the hands swapped.
6. **Cola (slot 4, off).** Swing the cylinder out. Point the muzzle up: the cases fall out
   (unchanged). Snap the gun sideways toward the side the cylinder closes into: it shuts. Snap it
   the other way: it stays open.
7. **SSG (slot 3).** Break it open: both hulls come out as it opens (unchanged). Load, let go,
   snap the gun up: it shuts.

**Drop-mag button**
8. Moonlight shut and loaded, press drop-mag: the barrel drops open and every round flies out.
   Snap up: shut.
9. Cola shut, press drop-mag: the cylinder swings out and dumps.
10. M4A3, Pistolet, Rifle, M16, SMG, Tec9, press drop-mag: the magazine drops (unchanged).

**Flick settings (Options -> VR Weapon Mechanisms -> Firing, flash and brass -> THE ACTION)**
11. "How hard a flick" at 3.0: a normal snap no longer shuts. Back to 1.5.
12. "A flick shuts an open gun" off: no flick shuts anything; the hand still does.

**Roster, once the weapons lane's cards exist**
13. **Chaingun:** hold the trigger, it fires its whole box without a rack. Drop-mag drops the box.
    Seat a box: it fires at once.
14. **Plasma:** no casings. **BFG:** a 30-tic charge sound then the ball, 4 shots a battery; an
    empty BFG clicks and does not charge.
15. **Rocket launcher / BFG / chaingun:** with the other hand off the support grip, the trigger
    clicks. Take the grip: it fires.
16. **Chainsaw:** idle sound in hand; the trigger saws and the view is not yanked.
17. **Voxel clip** (RS_Main voxel pack loaded): grab a map clip, and it becomes the pistol
    magazine in your hand.

**Log lines added** (each once per event, never per tic):
- `open <id> CLOSED at drawn N -- FLICKED <up|side> at X m/s (needs Y: hand A, wrist B)`
- The EJECTED line with `tilted -- its down axis N up, throws at M`
- `open <id> OPENED ... by the drop-mag button` and `EJECTED ... by the drop-mag button`
- `drop-mag button -- nothing in <store> to throw out`
- `SHOT -- N rounds from the magazine, M left`
- `click -- magazine has N, a shot needs M` / `click -- the <Ammo> reserve is empty` /
  `click -- it needs both hands: take the support grip`
- `CHARGING -- N tics, then the shot`
- Once per bind: `hands 2 ...`, `fires from <mode>`, `no casing`, and ShotText gains
  RoundsPerShot / ShotClass / rail / saw / charge.
- Once: `ShotClass '<name>' is not an actor -- firing WM_Bullet`
- Once per gun: `the pouch has nothing for it`
- Become: existing line + " (a voxel clip)" when `HasVoxelFrame()`.

---

## 13. PHASE 2 -- ORDER, FILES, CHECKS

**Before any edit:**
- `git -C E:\DOOMWork status --short RS_VR_Reload RS_VR_Weapons`
- Re-read each file right before editing it, and edit by exact string, never a whole-file write.
  The hand-seat agent's hunks in system.zs, rig.zs, parser.zs, card.zs, CVARINFO and MENUDEF must
  survive.
- RS_VR_Weapons/WMCARD.txt is re-read right before any edit, one line per card; items 1 to 3 need
  none.

| Step | Files |
|---|---|
| 1. G1 | card.zs (consts, firesFrom, SynthesiseStores), parser.zs (CardKey, FinishCard refusals, header), store.zs (SynthPlaceholderChamber, Describe), ammo.zs (Build, MagazineHolds, SpendFromMagazine), system.zs (CanFire, OnShot, texts), rig.zs (OnShot, OnDry, Seat, DropMagazine texts), weapon.zs (pass rounds) |
| 2. G3, G2, G4, G5 | weapon.zs (properties, ShotActor, rail branch, DepleteAmmo, ShotText), card.zs (noCasing), parser.zs (casing, firesfrom reserve/none refusals), rig.zs (Brass, ThrowOutAll), system.zs (FiresFrom, ReserveHolds, DrawFromPouch guard) |
| 3. Flick, dump, button | verb.zs, parser.zs, rig.zs (FlickByVerbs, FlickAxisModel, FlickShut, SetOpen how, EjectByTilt, arrays), system.zs (ButtonDrop, ButtonWorksVerbs, VerbHoldText), RS_VR_Reload/WMCARD.txt (three archetypes), CVARINFO.txt, MENUDEF.txt (WM_FireMenu), BUILD.md ("Keys added" list, G15 marked built) |
| 4. G7, G8, G6 | weapon.zs (states, WM_Charge, WM_ChargeWait, DoEffect, hooks, saw branch), system.zs (OnCharge), rig.zs (OnCharge) |
| 5. G10 | card.zs, parser.zs, system.zs (NearestPart, WorkHand press, CanFire, OnDry text via rig), rig.zs (OnDry, bind log) |
| 6. Voxel | become.zs |

**Walk every new key through parser.zs by reading:**
- `VerbTakesKey` / `VerbKeyOwners` (open: flickaxis, flickscale, button; eject: tiltaxis, button).
- `VerbKey` branches.
- `CardKey` (firesfrom, casing, hands).
- `FinishCard` / `VerbProblem` refusals.
- The archetype replay (`FinishCard` step 1 replays card keys through `VerbKey`, so new keys
  override per card for free).

**ZScript traps, checked per hunk:**
- No class field initialisers (defaults in Init, NewCard or Default blocks).
- No case-insensitive collisions (the field and property names above were chosen apart).
- One identifier per const.
- No `out Vector3` (FlickAxisModel returns a vector).
- No vector `?:`: velocity, position and axis picks are if/else.
- No cross-package class literals: ShotClass is a String resolved by FindClass; ChargeSound and
  SawSounds are strings.
- No local named `up`.

**Lint:**
- `python E:\DOOMWork\tools\menu_lint.py E:\DOOMWork\RS_VR_Reload --prefix wm_`
- RS_VR_Weapons with its build.ps1 line: `--prefix 'wm_pump,wm_moonlight,...' --dep <reload> --dep E:\DOOMWork\UZDXREMA\wadsrc\static`

**Pack and compile check, only when `Get-Process doomxr` is empty:**
`& E:\DOOMWork\RS_VR_Reload\build.ps1`, then `& E:\DOOMWork\RS_VR_Weapons\build.ps1`.

**Never:** commit, touch the engine, or touch doomxr.ini.
