# Vanilla parity audit: the 16 vanilla-set guns against Doom's own

**Status:** READ-ONLY AUDIT, 2026-09-14 (reload lane uzdxrema-11, for the build lane doomwork-5e). Nothing has been
changed. Fixes go in only after the build lane has read this, as small steps.

**Sources:**
- **Vanilla:** this engine's own Doom weapons: `wadsrc/static/zscript/actors/doom/weapon*.zs`, `doomammo.zs`,
  `doomplayer.zs`, the natives they call (`p_pspr.cpp`, `p_map.cpp`, `p_mobj.cpp`), and the VR branches in them.
  Every number was read with a file:line citation.
- **Ours:**
  - the RS_VR_Weapons classes (`pistols.zs`, `shotguns.zs`, `ssg.zs`, `chainguns.zs`, `launchers.zs`, `plasma.zs`,
    `bfg.zs`, `chainsaws.zs`, `weaponset.zs`, `loadout.zs`) and `WMCARD.txt`;
  - WM_Gun in `RS_VR_Reload/zscript/wm/weapon.zs`;
  - RS_Ballistics' `RSBDEFS.txt` and `zscript/rsb/{bullet,projectiles}.zs`, read only.

**Verdicts:**
- **SAME:** matches vanilla as this engine runs it in VR.
- **DELIBERATE:** differs because the owner asked (pumps hold 8, 15-round pistol magazines, SSG 2, chaingun 100,
  plasma 50, BFG 4 shots, rockets 6, vanilla sounds for rocket, plasma and BFG, manual reload, one shot per pull for
  pistols and shotguns, a full magazine in each start pistol, RS_Ballistics rounds).
- **DRIFT:** differs, and nobody asked. A fix is proposed, with the file it lives in.
- **QUESTION:** differs and isn't vanilla, but may be intended. It needs the owner or the lane that owns it.

---

## 0. The baseline: vanilla as this engine runs it in VR

These are engine rules. They apply to Doom's own guns in a headset as much as to ours, so they aren't drift:
- **No autoaim.** With VR aiming on (OverrideAttackPosDir, single player), hitscan pitch follows the controller
  (p_map.cpp 4710-4722). Missiles fly along the controller and drop their horizontal autoaim (p_mobj.cpp 8415-8420).
  WM_Gun sets +NOAUTOAIM, so it's the same.
- **Shots start at the controller** (AttackPos). Spread keeps its size and triangular distribution around the
  controller's aim.
- **The chainsaw neither turns the player nor pulls them in,** in VR unless `vanilla_melee_attack` is on (default off)
  (weaponchainsaw.zs 169, player.zs 1785). Ours passes SF_NOTURN | SF_NOPULLIN: same.
- **Vertical spread on the pistol, shotgun and chaingun needs `vertspread`,** which defaults to off (weaponpistol.zs 88).
  None of ours has any: same.
- **The BFG's spray fans out from the controller,** because the rays are traced from the player (weaponbfg.zs 237).
  Ours fires Doom's own BFGBall: same.
- **Defaults, checked afterwards:** `sv_fastweapons` is 0 (p_pspr.cpp 99), and `dmflags2` is 0 (d_main.cpp 759). So
  `sv_nobfgaim` (799) and `sv_novertspread` (820) are both off, and the vanilla numbers above stand as written.

---

## 1. Rules shared by all 16 guns

| # | What | Vanilla | Ours | Verdict |
|---|---|---|---|---|
| G1 | When the shot leaves | After a wind-up frame: pistol t=4, shotgun and SSG t=3, rocket t=8, BFG t=30. Chaingun, plasma and chainsaw fire on the first frame. | On the pull (t=0) for every gun except the BFG, which charges 30. | **QUESTION.** Recommend keeping it: in VR a trigger that fires 3-8 tics late feels broken. For the rocket, one line restores vanilla exactly: ChargeTics 8, FireTics 12. |
| G2 | Hitscan or not | Pistol, shotgun, SSG and chaingun are hitscan. | RS_Ballistics rounds are real projectiles: pistol_45 245 u/tic, pistol_9mm 340, buckshot 380, rifle_762 800, rifle_556 900 (RSBDEFS 1177-1203). | **DELIBERATE** ("good ballistics"). The damage roll is identical (G3). |
| G3 | Bullet damage roll | 5 × random(1,3): 5, 10 or 15 (weaponpistol.zs 81) | 5 × 1d3 from every round's ballistics block (RSBDEFS 1159; bullet.zs 217) | **SAME** |
| G4 | Spread distribution | Random2 × spread / 256: triangular (m_random.h 166) | (frandom − frandom) × spread: triangular, same maximum (weapon.zs 845-856) | **SAME** |
| G5 | **A gun comes LOADED FOR FREE the first time it's in a hand** | A weapon pickup gives only its AmmoGive: pistol 20, shotgun 8, SSG 8, chaingun 20, rocket 2, plasma 40, BFG 40. | The pickup's AmmoGive goes to the reserve, **and** the gun's first bind fills every store free (ammo.zs 76-81, rig.zs Bind). Pistols 15+1, pumps 8+1, SSG and Double Barrel 2, chaingun 100, launchers 6, plasma 50, BFG 160. | **DRIFT (ammo economy); PARKED by the owner 09-14**, see §3 fix F6. Examples: a BFG pickup is 40 cells in vanilla and 200 here (one shot against five); a chaingun is 20 bullets against 120; a plasma rifle 40 against 90. The owner asked for a full magazine only in each start pistol. |
| G6 | Two fire sounds on projectile guns | One: the projectile's SeeSound as it spawns (p_mobj.cpp 8452). | The card's `firesound` plays at the gun (rig.zs 1603), and the same sound plays again as the projectile's SeeSound. Affects the Rocket Launcher, RPG, Plasma Rifle and Plasma Carbine (all "weapons/rocklf" or "weapons/plasmaf"). | **DRIFT**, see F3. Confirmed in code, not heard. |
| G7 | Weapon slots | Fist and Chainsaw 1, Pistol 2, Shotgun and SSG 3, Chaingun 4, Rocket 5, Plasma 6, BFG 7 (doomplayer.zs 40-46) | Saws 1, pistols 2, shotguns 3, chaingun pair **7**, launchers **8**, plasma **9**, BFGs **0** (class SlotNumber; loadout.zs 105-114) | **QUESTION** (weapons lane). Possibly room left for the Vanilla+ guns. |
| G8 | Two-handed | None | `hands = 2` on the chaingun pair, both launchers and both BFGs: they fire only while the other hand holds the support grip (system.zs CanFire). | **QUESTION** (VR handling, no owner request on record) |
| G9 | Out of ammo | CheckAmmo fails and the game switches weapon. | A dry click (8 tics) and a manual reload. | **DELIBERATE** (manual reload) |
| G10 | Knockback | DoomWeapon Kickback 100 | WM_Gun inherits Weapon.DefaultKickback, the game's 100 | **SAME** |
| G11 | Raise and lower | 6 per tic, 1-tic frames | WM_Gun's Select/Deselect: A_Raise/A_Lower, 1 tic | **SAME** |
| G12 | Pickup scaling | Monster drop ×0.5, deathmatch ×5/2, skill AmmoFactor × sv_ammofactor (weapons.zs 879-886, 1219-1238) | The same three factors (weaponset.zs 113-125, 283-290) | **SAME** |
| G13 | A new game's start | Fist, pistol, 50 Clip | Fists, M4A3 and 9mm Handgun, 50 Clip (weaponset.zs ApplyStart), each pistol loaded 15+1 | **DELIBERATE** (the owner: a full magazine each and 50 Clip) |

---

## 2. Per gun

### Pistol → WM_M4A3 (main) and WM_Pistolet, "9mm Handgun" (off)

| What | Vanilla (weaponpistol.zs) | Ours | Verdict |
|---|---|---|---|
| Damage | 5 × 1d3 (81) | pistol_45 / pistol_9mm, 5 × 1d3 | SAME |
| Bullets | 1 | 1 | SAME |
| Spread | ±5.603° horizontal on refires; the first shot of each press is dead on (86, 116) | none: every shot dead on | **DELIBERATE.** With one shot per pull every shot is a first shot, and vanilla tapping is dead on too. |
| Refire | Held: a shot every 14 tics (A_ReFire at t=14); a tap's sequence is 19 | Semi-automatic, 19-tic cycle, release and pull again | **DELIBERATE** (one shot per pull) |
| Ammo | Clip, 1 a shot | Clip reserve → 15-round magazine + chamber, reloaded by hand | **DELIBERATE** |
| Pickup | AmmoGive 20 | pair pickup, Clip 20 | SAME (and see G5) |
| Sound | weapons/pistol | wm/m4a3/fire, wm/pistolet/fire | **DELIBERATE** (vanilla sounds were asked for rocket, plasma and BFG only) |
| Alt fire | none | none | SAME |

### Shotgun → WM_PumpM37 (main) and WM_PumpDoom (off)

| What | Vanilla (weaponshotgun.zs) | Ours | Verdict |
|---|---|---|---|
| Damage | 5 × 1d3 a pellet | buckshot 5 × 1d3 | SAME |
| Pellets | 7 (99) | 7 | SAME |
| Spread | ±5.603° horizontal, never accurate (101) | 5.6, 0 | SAME |
| Cadence | Fires at t=3; held refire every 37 tics; full sequence 44 | 19-tic cycle, then a hand-worked pump | **DELIBERATE** mechanism, **QUESTION** on rate: the 19-tic floor lets a fast rack fire about twice vanilla's 37-tic rate. For parity: FireTics 37 (shotguns.zs, weapons lane). |
| Ammo | Shell, 1 a shot | 8-round tube + chamber | **DELIBERATE** (8) |
| Pickup | AmmoGive 8 | pair pickup, Shell 8 | SAME |
| Sounds | weapons/shotgf | weapons/shotgf; pump weapons/shotgr | SAME |
| Alt fire | none | none | SAME |

### Super Shotgun → WM_SSG (main) and WM_DoubleBarrel (off)

| What | Vanilla (weaponssg.zs) | Ours | Verdict |
|---|---|---|---|
| Damage | 5 × 1d3 a pellet (112) | buckshot 5 × 1d3 | SAME |
| Pellets | 20 a shot (110), and it needs 2 shells to fire | 10 a chamber, every loaded chamber fires: 20 with two loaded, 10 with one | **DELIBERATE** (a hand-loaded break action fires what's in it) |
| Spread | ±11.206° horizontal × ±7.070° vertical, always (113, 121) | 11.25, 7.097 | SAME |
| Cadence | Fires at t=3; held refire at 51 (57 on a re-press); full 62, reload built in | FireTics 20, then open, load and close by hand | **DELIBERATE** (manual reload) |
| Ammo | Shell, 2 a shot | 2 chambers from the Shell reserve | SAME / DELIBERATE |
| Pickup | AmmoGive 8 | pair pickup, Shell 8. As of 2026-09-14 (owner), the pickup's pair is the SSG and the **Bullpup Pump**; the Double Barrel is off the pickup. | SAME. FYI: the Bullpup isn't in this audit's 16. |
| Sounds | sshotf / sshoto / sshotl / sshotc | SSG: the same four. Double Barrel: wm/dbarrel/* | SSG SAME; Double Barrel **DELIBERATE** (own sounds) |
| Alt fire | none | none | SAME |

### Chaingun → WM_Chaingun (main) and WM_MachineGun (off)

| What | Vanilla (weaponchaingun.zs) | Ours | Verdict |
|---|---|---|---|
| Damage | 5 × 1d3 | rifle_556 / rifle_762, 5 × 1d3 | SAME |
| Spread | ±5.603° horizontal | 5.6, 0 | SAME |
| First-shot accuracy | Both shots of the first 8-tic cycle dead on (104) | FirstShotsAccurate 2 | SAME |
| Cadence | A shot every 4 tics while held, first on t=0 | FireTics 4, FullAuto | SAME |
| Ammo | Clip, 1 a shot | Chaingun: 100-round magazine, reloaded by hand. Machine Gun: fed straight from the Clip reserve, no magazine (card `firesfrom = reserve`). | Chaingun **DELIBERATE** (100). Machine Gun **QUESTION** (the owner's spec says chaingun 100). |
| Hands | one | both need the support grip (`hands = 2`) | **QUESTION** (G8) |
| **Alt fire** | **none** | Chaingun none. **Machine Gun: an underbarrel grenade launcher** (card `barrel launcher`, altfire, WM_LauncherGrenade, RSVG_Ammo). | **DRIFT for the Vanilla set.** The owner's roadmap puts alt fires in Vanilla+. See F5. **PARKED 09-14: the owner keeps it.** |
| Pickup | AmmoGive 20 | pair pickup, Clip 20 | SAME |
| Sounds | weapons/chngun | wm/chaingun/fire + spin-up, spin, spin-down | **DELIBERATE** |
| Comments | none | chainguns.zs 17-18 says "every shot takes the spread", but FirstShotsAccurate 2 is set. WMCARD.txt ~1845 says "5 x 1d3 hitscan", but it fires RSB_Bullet. | **DRIFT (docs)**, F7 |

### Rocket Launcher → WM_RocketLauncher (main) and WM_RPG (off)

| What | Vanilla (weaponrlaunch.zs) | Ours | Verdict |
|---|---|---|---|
| Projectile | Rocket: radius 11, height 8, speed 20, damage 20 × 1d8; A_Explode 128 damage, 128 radius, hurts the shooter (70-73, 89; attacks.zs 721-731) | RSB_Rocket: Doom's Rocket unchanged, plus the RS_Ballistics look (projectiles.zs 76-92) | SAME |
| Cadence | 20-tic cycle, **refires while held** (A_ReFire; NOAUTOFIRE only gates the first shot, player.zs 511-521) | FireTics 20, **semi-automatic** | **DRIFT**: FullAuto is missing (F1). The owner's one-shot rule named pistols and shotguns only. |
| Shot delay | The rocket spawns at t=8 | t=0 | QUESTION (G1). Parity option: ChargeTics 8, FireTics 12 keeps the 20-tic cycle. |
| Ammo | RocketAmmo, 1 a shot | 6-rocket magazine, reloaded by hand | **DELIBERATE** (6, the weapons lane's pick on the owner's say) |
| Pickup | AmmoGive 2 | pair pickup, RocketAmmo 2 | SAME |
| Sound | weapons/rocklf once, as the rocket's SeeSound | the card's rocklf **and** the rocket's SeeSound | **DRIFT** (G6, F3) |
| Hands | one | `hands = 2` | QUESTION (G8) |

### Plasma Rifle → WM_PlasmaRifle (main) and WM_PlasmaCarbine (off)

| What | Vanilla (weaponplasma.zs) | Ours | Verdict |
|---|---|---|---|
| Projectile | PlasmaBall: radius 13, height 8, speed 25, damage 5 × 1d8 (67-70) | RSB_PlasmaBall: Doom's PlasmaBall unchanged | SAME |
| Cadence | A shot every 3 tics while held; 20 more tics after release (23 total) | FireTics 3, FullAuto, ReleaseTics 20 | SAME |
| Ammo | Cell, 1 a shot | 50-cell magazine, reloaded by hand | **DELIBERATE** (50) |
| Pickup | AmmoGive 40 | pair pickup, Cell 40 | SAME |
| Sound | weapons/plasmaf once, as the ball's SeeSound | the card's plasmaf **and** the ball's SeeSound | **DRIFT** (G6, F3) |

### BFG9000 → WM_BFG (main) and WM_BFGHeavy (off)

| What | Vanilla (weaponbfg.zs) | Ours | Verdict |
|---|---|---|---|
| Projectile | BFGBall: radius 13, height 8, speed 25, damage 100 × 1d8. Spray: 40 rays of 15 × 1d8 over 90°, reach 1024, 16 tics after impact (162-165, 219-272) | RSB_BFGBall: Doom's BFGBall unchanged | SAME |
| Charge | weapons/bfgf at t=0, the ball at t=30 (52-54) | ChargeSound weapons/bfgf, ChargeTics 30 | SAME |
| Cadence | **Refires while held**, every 40 tics (A_ReFire at t=40); 60 on a single press | **Semi-automatic**: 30 charge + FireTics 30 = 60, then pull again | **DRIFT** (F2): FullAuto true, FireTics 10, ReleaseTics 20 gives 40 held and 60 released, as vanilla. |
| Ammo | Cell, 40 a shot | RoundsPerShot 40 from a 160-cell magazine | **DELIBERATE** (4 shots) |
| Pickup | AmmoGive 40 | pair pickup, Cell 40 | SAME (and see G5: 200 cells in effect) |
| Sounds | bfgf at the charge, no separate fire sound | the same; the card sets no firesound | SAME |
| Hands | one | `hands = 2` | QUESTION (G8) |

### Chainsaw → WM_Chainsaw (main) and WM_ChainsawHeavy (off)

| What | Vanilla (weaponchainsaw.zs) | Ours | Verdict |
|---|---|---|---|
| Damage | 2 × random(1,10) (77-84) | A_Saw damage 2, random kept (no SF_NORANDOM) | SAME |
| Range and spread | MeleeRange + MELEEDELTA + ε = 64; ±2.8125° (87, 93) | A_Saw's defaults | SAME |
| Cadence | An attack every 4 tics while held | FireTics 4, FullAuto | SAME |
| Turn and pull-in | none in VR (§0) | SF_NOTURN, SF_NOPULLIN | SAME |
| Puff | BulletPuff | RSB_SawPuff: hidden sprite, impact look, same damage | SAME |
| Ammo | none | none (Clip inherited, never spent) | SAME |
| Sounds | sawup, sawidle, sawfull, sawhit | wm/saw/* (cord, start, idle, stop, loop, hit) | **DELIBERATE** |
| Starting it | always running | Chainsaw: a ripcord (card `start` verb) before it cuts. Heavy Chainsaw: no ripcord. | **QUESTION** (not vanilla, and the pair differs) |
| **Idle sound** | once every 8 tics (4-tic Ready frames; weapons.zs 486-491) | Heavy Chainsaw: `Weapon.ReadySound "wm/saw/idle"` **restarts every tic**, because A_WeaponReady replays it whenever the psprite is in Ready and WM_Gun's Ready is a 1-tic loop. The Chainsaw uses its card `idlesound` instead. | **DRIFT (bug)**, F4. From code, not heard. |
| Slot | 1 | 1 | SAME |

---

## 3. Proposed fixes. None applied; each is a small step once the build lane has read this.

| # | Fix | Where | Whose | Size |
|---|---|---|---|---|
| F1 | Rocket Launcher and RPG refire while held: `WM_Gun.FullAuto true;` | RS_VR_Weapons `launchers.zs` | weapons lane | 2 lines |
| F2 | BFG and Heavy BFG refire while held, on vanilla's clock: `WM_Gun.FullAuto true; WM_Gun.FireTics 10; WM_Gun.ReleaseTics 20;` (charge 30 + 10 = 40 held; + 20 = 60 released) | RS_VR_Weapons `bfg.zs` | weapons lane | 6 lines |
| F3 | One fire sound, not two. **Preferred:** `SeeSound ""` on RSB_Rocket and RSB_PlasmaBall, so the card's sound is the only one and the owner's Sound Selection pick keeps working. Only our guns fire those classes. **Not preferred:** blanking the card sound, because an owner pick would still double with the SeeSound. | RS_Ballistics `zscript/rsb/projectiles.zs` | ballistics lane (uzdxrema-45) | 2 lines |
| F4 | The Heavy Chainsaw's idle sound: remove `Weapon.ReadySound` from WM_ChainsawHeavy and give its card `idlesound = "wm/saw/idle"`, as the Chainsaw's card has | `chainsaws.zs` (weapons lane) + `WMCARD.txt` (reload lane) | both | 2 lines |
| F5 | **PARKED by the owner 09-14, revisit later.** The Machine Gun's underbarrel launcher stays as it is and working, because people see it on the model and want to use it. The original question: the launcher in the Vanilla set, the owner's call. Either take the `barrel launcher` block (and its `gl` store, breech and load verbs) off the card for now, or move the Machine Gun to Vanilla+. | `WMCARD.txt` | reload lane, on the owner's word | card block |
| F6 | **PARKED by the owner 09-14, revisit later; no change now.** A draft is saved in `_pending/F6_FIRST_LOAD/` and is not installed. The original question: the free first fill (G5), the owner's call, since it changes every map's ammo economy. Proposal: a gun's first fill comes from what its pickup gave (up to the gun's capacity) and the rest goes to the reserve; the start pistols keep the owner's full magazine. | RS_VR_Reload `rig.zs` Bind / `ammo.zs` Init; pickup amounts in `weaponset.zs` | reload lane (+ weapons lane) | a design step |
| F7 | Stale comments: chainguns.zs 17-18 ("every shot takes the spread") and the chaingun card's "5 x 1d3 hitscan" | `chainguns.zs`; `WMCARD.txt` | weapons lane; reload lane | comments |

**Questions for the owner or the owning lane:**
- **G1:** does the shot leaving on the pull stay? Recommended yes.
- **Shotgun rate:** the 19-tic floor against vanilla's 37.
- **G7:** slot numbers 7, 8, 9 and 0.
- **G8:** two-handed chaingun, launchers and BFGs.
- **Machine Gun feed:** reserve-fed, against "chaingun 100".
- **Chainsaw:** a ripcord on one saw only.
