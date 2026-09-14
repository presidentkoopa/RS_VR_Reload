# Vanilla done: the punch list

**What stands between today and "Vanilla done".** Doc only, reload lane (uzdxrema-11), 2026-09-14, for the build lane (doomwork-5e).

**Scope:** the 16 vanilla guns, plus the Bullpup Pump (now on the Super Shotgun pickup), the grenade and the ShieldSaw. The Unmaker and the Assault Shotgun are Vanilla+ or extras, not here.

**Marks:**
- **DONE**
- **FIRST PASS**: built to the owner's direction and installed, never seen in the headset, open to tuning after the owner's test.
- **IN PROGRESS**: built but not played, or waiting on a fix or commit.
- **MISSING**
- **OWNER**: only the owner can do it (the headset pass, calibration, a decision).
- **AFTER**: not needed for Vanilla done.

**Where the facts come from:**
- the cards (RS_VR_Weapons/WMCARD.txt) and the card parser's defaults;
- FEEL_PLAN.md's status rows;
- VANILLA_PARITY.md and VANILLA_TEST_CHECKLIST.md;
- a read-only `tools/bake_defaults.py` run on both packages against the owner's ini (never written);
- the ballistics lane's per-gun table (uzdxrema-45);
- the weapons lane's answers on sounds, the grenade, the ShieldSaw and commits (rs-vr-weapons-c5).

**Profile check:** every vanilla class names the RS_Ballistics profiles in the ballistics lane's table (checked against the classes' Default blocks).

---

## 1. Across all guns

| # | Item | Mark | Owner | What it means |
|---|---|---|---|---|
| X1 | The headset pass on VANILLA_TEST_CHECKLIST.md | **OWNER / MISSING** | owner | Not run yet, so no bug reports exist. Each gun's "a bug" line is the pass or fail. |
| X2 | Built since 09-13, never played | **IN PROGRESS** until X1 | reload lane | FEEL_PLAN rows 27-33: held fire, the rail trail, catch-to-equip (never tried in a headset), the smoking barrel, the grip gate, the saw idle hum, belt links in the casing cap (committed 4c2699d). Also 13 (grab ovals), 17 (baking), 18-19 (sound picks, eject sound). |
| X3 | Hand seats (where your hand sits on a part, per kind of gun) | **OWNER / MISSING** | owner | 0 hand-seat values differ from their defaults in any profile. The revolver set already carries the owner's older revolver tuning. The side-load / bottom-load split is parked, so both vanilla pumps and the Bullpup share one shotgun set. |
| X4 | Grab ovals (where a hand can take each part) | **OWNER / MISSING** | owner | The bake ledger is empty; nothing is baked into a card yet. 16 grab-page values sit unbaked in the ini. ESTIMATE grabs are marked per gun. |
| X5 | Placement (where each gun sits in your hand) | **OWNER / MISSING** | owner | No tuned placement values are waiting in the ini for RS_VR_Weapons. The weapons lane: placement calibration is the owner's. |
| X6 | Baking the calibration as the defaults | **MISSING**, after X3-X5 | build lane's go | `tools/bake_defaults.py --write` and the ledger, only on the build lane's go. |
| X7 | Parity fixes | **DONE** in source, installed; **OWNER** to feel in X1 | weapons, ballistics, reload lanes | See the list below. |
| X8 | The grenade and ShieldSaw's first headset try | **OWNER / MISSING** | owner + weapons lane | Folded into RS_VR_Weapons, committed 93ff50e, installed. Both START ON (server switches `rsvg_start` and `rs_ss_start` on the weapon-set page), and are also on the arsenal page. No headset try reported since the fold. |
| X9 | The launchers' new looks | **IN PROGRESS** | weapons lane | rocket_launcher and rocket_rpg flashes and RSB_RocketRPG are wired but not yet checked or committed; they go in the weapons lane's next check. |
| X10 | Sound picks heard in the headset (Sound Selection) | **IN PROGRESS** until X1 | weapons lane | A slot's menu default is the card's own sound. Rows 18-19 were never heard. |
| X11 | Effects the engine hasn't built yet | **OWNER** decides whether Vanilla done waits for any | ballistics lane + build lane | Lasting bullet holes and scorch (#17), debris that bounces and stays (#8, #9), room-filling smoke (smoke volumes 13b), generated flash shapes (particle looks build B), casings as mesh particles, bullet hits on monsters ("later", the owner). |
| X12 | Netplay | **AFTER** | build lane | NETPLAY_SPEC P1/P2. Catch-to-equip is single-player only, and an off-hand rail comes from the main hand in a netgame. The owner isn't playing netplay yet. |

**Parity fixes (X7):**
- **F1 (rocket refire), F2 (BFG refire), F7 (stale comments):** committed, weapons lane 922e200.
- **F3 (one fire sound for rockets and plasma):** committed, RS_Ballistics 40475e0.
- **F4 (the saw idle hum):** RS_VR_Reload 4aa2fb1, plus the weapons lane's 546499f and its distinct hums in 388c040.
- **F5, F6:** parked by the owner, not needed.

**Sounds shared by every gun on purpose, not flagged:** `wm/dry` and `wm/magdrop`. The card parser gives them to any card that leaves them out.

---

## 2. Per gun

Columns:
- **Reload:** manual reload end to end.
- **Mechanics:** VANILLA_PARITY's verdict.
- **Sounds:** the weapons lane's read of the card and SNDINFO.
- **Looks:** the ballistics lane's table.
- **Owner calibration:** what the calibration session needs.

### M4A3 (main hand)
- **Reload: DONE.** The pistol reload the owner uses daily.
- **Mechanics: DONE.** Vanilla damage and rate; one shot per pull is deliberate.
- **Sounds: DONE.** Its own fire, magazine and slide set. Whether it's "mean" enough is the owner's pick in the sound menu.
- **Looks: FIRST PASS (showpiece).**
  - pistol_45 flash, with per-shot variety and flame roll;
  - the pistol_45 round: streak, vapour, air shimmer;
  - pistol_45 impacts by surface;
  - the brass_45 3D case, with port smoke and a wisp;
  - the smoking barrel.
- **Owner calibration:** pistol hand seats (slide, magazine, support); grab ovals on 3 parts; placement.

### 9mm Handgun (off hand)
- **Reload: DONE.** Either pistol's magazine seats in either gun.
- **Mechanics: DONE.**
- **Sounds: DONE.** Its own set.
- **Looks: FIRST PASS (the showpiece).** pistol_9mm flash, round and impact; brass_9mm; flash, barrel and port smoke.
- **Owner calibration:** as the M4A3, off-hand side.

### M37A2 pump (main hand)
- **Reload: IN PROGRESS.** Loading at the gate and racking were tried 09-13 (FEEL_PLAN row 14); replay at 8 shells.
- **Mechanics: DONE.** 7 pellets, 5.6°; 8 + 1 is deliberate.
- **Sounds: flag.**
  - Doom's shotgun fire and rack, IDENTICAL to the Doom pump's.
  - No shell-insert sound and no pump-home sound.
  - The weapons lane names the pumps the owner's first "make it mean" candidates.
- **Looks: FIRST PASS.** shotgun_m37 (a long fire gout, white strobe); buckshot, varied per pellet; hull_12ga with port smoke; it smokes.
- **Owner calibration:** shotgun hand seat on the forend; the forend grab; the load-gate zone; placement.

### Doom pump (off hand)
- **Reload: IN PROGRESS.** As the M37A2.
- **Mechanics: DONE.**
- **Sounds: flag.** IDENTICAL to the M37A2's; no shell-insert sound.
- **Looks: FIRST PASS.** shotgun_doom (a fat orange fireball, lingering strobe); buckshot; hull_12ga; all smoke.
- **Owner calibration:** as the M37A2, off-hand side.

### Super Shotgun (main hand)
- **Reload: IN PROGRESS.** Break, tilt out, load and flick shut were tried 09-13 (row 14); replay.
- **Mechanics: DONE.** 20 pellets over two chambers; firing what's loaded is deliberate.
- **Sounds: DONE.** Doom's fire, open, load and close.
- **Looks: FIRST PASS.** shotgun_ssg (a twin fireball, the biggest strobe, a ground kick); buckshot_magnum; hull_12ga_magnum; the barrel smokes every shot.
- **Owner calibration:** break-action seat on the barrels; the barrels grab (**ESTIMATE**); the breech load zone; placement.

### Bullpup Pump (off hand; on the Super Shotgun pickup since 09-14)
- **Reload: IN PROGRESS.** A 4-shell pump loaded from under the stock. Never played.
- **Mechanics: not audited.** It wasn't among VANILLA_PARITY's 16; a follow-up audit could add it.
- **Sounds: flag, all borrowed.** The Super Shotgun's blast and the pumps' rack. No sounds of its own, and no shell-insert sound.
- **Looks: FIRST PASS.** shotgun_bullpup (a muzzle-brake ring of fire and smoke, a ground kick); buckshot_magnum; hull_12ga_magnum; all smoke.
- **Owner calibration:** shotgun seat on the forend (a measured vertical foregrip); the eject port and the load gate are partly **ESTIMATE** (no port on the mesh); placement.

### Double Barrel (off hand; the test arsenal only)
- **Reload: IN PROGRESS.** Shrunk 09-14 so its shells match; never played at the new size.
- **Mechanics: DONE.**
- **Sounds: DONE.** Its own set.
- **Looks: FIRST PASS.** shotgun_doublebarrel (a dirty red fireball, soot, embers, a ground kick); buckshot_magnum; hull_12ga_fouled; a black barrel ribbon. The blast may read big at the new size (owner check).
- **Owner calibration:** as the Super Shotgun, off-hand side. The barrels grab is an **ESTIMATE**, rescaled with the model.

### Chaingun (main hand)
- **Reload: IN PROGRESS.** Swap the 100-round box; two hands to fire. No headset report.
- **Mechanics: DONE.** 4 tics a shot, the first two dead on.
- **Sounds: DONE.** Its own fire, box out and in, spin up, spin, spin down.
- **Looks: FIRST PASS.**
  - chaingun_556: a stuttering flicker, then barrel smoke, shimmer and a red-hot glow;
  - a tracer every 4th round, with its own light;
  - brass_556;
  - belt links in the casing cap (4c2699d).
- **Owner calibration:** chaingun seats (magazine, support); grabs on 2 parts; placement.

### Machine Gun (off hand)
- **Reload: IN PROGRESS.** No bullet reload (it feeds from reserve); the grenade launcher opens, loads and closes. No headset report.
- **Mechanics: DONE.** The launcher is kept (F5 parked).
- **Sounds: flag, borrowed.** It fires the Chaingun's sound, and the launcher's open, close and load are one borrowed sound. No fire sound of its own.
- **Looks: FIRST PASS.** machinegun_762, tracer every 5th, barrel glow; launcher_40mm alt flash; brass_762. The grenade itself is RS_Grenade's.
- **Owner calibration:** chaingun seats; grabs on 3 parts (**2 ESTIMATE**); placement.

### Rocket Launcher (main hand)
- **Reload: IN PROGRESS.** Pull the rack, seat a fresh one; two hands. No headset report.
- **Mechanics: DONE.** Refires while held (F1).
- **Sounds: flag.** Doom's fire (vanilla, single since F3), plus its own rack out and in, IDENTICAL to the RPG's.
- **Looks: FIRST PASS (X9, not yet committed).**
  - rocket_launcher flash: flare, exhaust rolling back, a ground kick;
  - a voxel rocket with motor flame, shimmer and a hanging smoke trail;
  - rocket impacts by surface, with 3D slabs and shards.
  - The voxel's orientation and scale are unseen (owner check).
- **Owner calibration:** launcher seats; grabs on 2 parts (**both ESTIMATE**); placement.

### RPG (off hand)
- **Reload: IN PROGRESS.** Pull the drum, seat a fresh one; it turns a step each shot.
- **Mechanics: DONE.** F1.
- **Sounds: flag.** IDENTICAL to the Rocket Launcher's.
- **Looks: FIRST PASS (X9).**
  - rocket_rpg backblast behind the tube: fire, smoke, sparks, rear heat;
  - RSB_RocketRPG: a booster thread, then ignition and a heavy trail;
  - harder impacts.
  - The backblast doesn't follow the RPG's scale setting yet (ballistics lane).
- **Owner calibration:** launcher seats; grabs on 2 parts (**1 ESTIMATE**); placement.

### Plasma Rifle (main hand)
- **Reload: IN PROGRESS.** Swap the cell. No headset report.
- **Mechanics: DONE.** A shot every 3 tics held, a 20-tic cool-down.
- **Sounds: flag.** Doom's fire (vanilla) plus its own cell out and in, IDENTICAL to the Carbine's.
- **Looks: MISSING (placeholder).** A shared plasma flash, Doom's plasma sprite (the owner: vanilla sprites for now) with trail motes, plasma impacts, no smoke. No per-gun identity. Next in the owner's order (ballistics lane).
- **Owner calibration:** plasma seats; grabs on 2 parts (**1 ESTIMATE**); placement.

### Plasma Carbine (off hand)
- **Reload: IN PROGRESS.**
- **Mechanics: DONE.**
- **Sounds: flag.** IDENTICAL to the Plasma Rifle's.
- **Looks: MISSING (placeholder).** As the Plasma Rifle.
- **Owner calibration:** as the Plasma Rifle (**1 ESTIMATE**).

### BFG (main hand)
- **Reload: IN PROGRESS.** Swing the cover open, swap the cell, shut. It won't fire open; two hands. No headset report.
- **Mechanics: DONE.** Refires while held on vanilla's clock (F2).
- **Sounds: MISSING.** The card states none. The charge is Doom's, from the class; dry and the cell drop get the parser's defaults. Cover open and close and cell out and in are silent.
- **Looks: MISSING (placeholder).** A shared bfg flash, Doom's sprite with a trail, bfg impacts, no smoke. Missing: a charge glow, per-gun identity, anything on the BFG's rays.
- **Owner calibration:** BFG seats; grabs on 3 parts (**1 ESTIMATE**); placement.

### Heavy BFG (off hand)
- **Reload: IN PROGRESS.** Swap the cell; no cover.
- **Mechanics: DONE.** F2.
- **Sounds: MISSING.** As the BFG: cell out and in are silent.
- **Looks: MISSING (placeholder).** As the BFG.
- **Owner calibration:** BFG seats; grabs on 2 parts (**1 ESTIMATE**); placement.

### Chainsaw (main hand)
- **Reload: IN PROGRESS.** Pull the ripcord with the other hand; it catches and idles. No headset report.
- **Mechanics: DONE.** 2 × 1d10, range 64, 4 tics; no turn or pull-in in VR.
- **Sounds: DONE.** Its own cord, start, idle, stop, running, hit.
- **Looks: MISSING (placeholder).** Saw impacts only: sparks off stone and metal, splinters and dust off wood. Missing: exhaust smoke, engine haze, chips off the chain, per-saw identity.
- **Owner calibration:** chainsaw seats; grabs on 2 parts (the ripcord, support); placement.

### Heavy Chainsaw (off hand)
- **Reload: IN PROGRESS.** No ripcord; hums while drawn with its own heavy idle (F4).
- **Mechanics: DONE.**
- **Sounds: DONE.** Its own heavy idle and start; running and hit are the saw pair's.
- **Looks: MISSING (placeholder).** As the Chainsaw.
- **Owner calibration:** chainsaw seats; the support grab; placement.

### Grenade (slot 9; starts on)
- **Use: IN PROGRESS (X8).**
  - Pull the pin; the cook timer starts on the pull (`rsvg_cook`).
  - Thrown by your hand's speed.
  - No reload.
  - `wm_givegrenade` puts it in the main hand with 10 grenades.
  - Grenades also feed the Machine Gun's launcher.
  - Whether any Doom pickup gives it hasn't been checked.
- **Sounds and looks:** RS_Grenade's own. Its blast is RSVG_Blast, not RS_Ballistics; no flight trail.
- **Owner calibration:** its own mod's placement. The throwable card (THROWABLE_PLAN step 3) is held.

### ShieldSaw (slot 1; starts on)
- **Use: IN PROGRESS (X8).**
  - Worn on the forearm; drawn into the off hand with its own key.
  - Held as a shield; saws.
  - Thrown along your swing with route lock; it returns and you catch it.
  - No reload.
  - `wm_giveshieldsaw` puts it on the forearm.
  - Its grip lease blocks the reload system's pouch draws only while it's drawn.
- **Sounds and looks:** its own. Nothing of RS_Ballistics is named for it (the ballistics lane: unknown or not wired).
- **Owner calibration:** its own mod's placement and draw.

---

## 3. For the owner: Vanilla is done when…

- You've played every vanilla gun, the Bullpup Pump, the grenade and the ShieldSaw through the test checklist, and none of its "a bug" lines happened.
- Every reload works start to finish in your hands, especially the pumps at 8 shells, the Double Barrel at its new size, the BFG's cover, and the chainsaw's ripcord.
- Every gun sounds right to you:
  - the BFG and Heavy BFG need their mechanical sounds;
  - the two pumps (identical, and your first "make it mean" candidates) need shell-insert sounds;
  - the Bullpup Pump, Machine Gun, RPG and Plasma Carbine each get their own sounds, or you say borrowing is fine.
- The looks are there for every gun. The pistols, shotguns, chainguns and launchers have a first pass to judge in the headset. The plasma guns, BFGs and chainsaws are still placeholders the ballistics lane has next.
- You've calibrated where your hands sit on each kind of gun, where you grab each part, and where each gun sits in your hand, and we've baked that in as the default.
- The rocket launchers and BFGs keep firing while you hold the trigger, and that feels right.
- You've decided whether Vanilla waits for any effect the engine doesn't have yet: lasting bullet holes, debris that stays, room-filling smoke.
- Netplay comes after, not part of Vanilla done.
