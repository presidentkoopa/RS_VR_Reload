# Netplay spec: the VR reload system and its guns

Author: reload lane `uzdxrema-11`, 2026-09-13, at the owner's request ("I do want everything netplay safe. Maybe
spec that out while I am positioning ovals and hands").

Status: **spec only.** Nothing in the code has changed for it. The owner decides §10; engine work goes through the
main lane.

Sources:
- A read-only sweep of every `.zs` file in RS_VR_Reload and RS_VR_Weapons, both CVARINFOs, both WMCARDs, and the
  engine code that settles cvar lookup, spawning and network IDs (2026-09-13).
- The engine-side plan, `Engine docs/NETWORK_HAND_INPUT_PLAN.md`. This spec corrects several points in its §6 (§11
  below).

Anchors are **function names**. Line numbers move; find the function, then read it.

---

## In plain words (for the owner)

**Today, co-op breaks on the first trigger pull.**
- The machine wearing the headset keeps the gun's rounds and the hands' state to itself.
- When you pull the trigger, every machine runs the shot. The other machines look for your hands, don't find
  them, and click dry.
- From that moment the machines disagree: about your ammo, about whether a shot left, and about the damage
  rolls that follow.

**The fix, in one idea: your machine decides, and every machine applies.**
- Your machine keeps working your hands exactly as it does now: the live controllers, the drawn gun, your
  sliders.
- It no longer changes the gun directly. When a hand does something that matters, it sends a network command
  that names the result: "slide racked", "magazine seated with 12", "grenade drawn from the pouch".
- Every machine, yours included, applies that command to your gun, the same way, on the same tic.
- The gun's rounds and its open/shut state live on the weapon itself, which every machine has. So the shot,
  the ammo and the damage agree everywhere.

**What stays on your machine only:** how things look (your gun model, hands, ovals, flashes, casings, sparks),
your feel sliders, and the tuning menus.

**What you'd notice in single-player:** almost nothing. A reload's *result* lands one tic (1/35 s) after your
hand does it. The part you're moving still moves at once, because the renderer draws it straight from your
controller.

**What co-op players would see of each other** at first: guns firing, reloading correctly and running out
correctly. Seeing another player's hands and gun parts move is a later step that needs the engine plan.

---

## 1. What's broken today, worst first

| # | Problem | Where |
|---|---|---|
| 1 | **Every carded shot desyncs.** `WM_TryFire` runs on every machine. `CanFire` needs the shooter's hand containers (`HandsIfAny(pn)`), which exist only on the shooter's machine. Elsewhere it goes to `Dry`: no projectile, no `DepleteAmmo`, no draw on the named RNGs. | `WM_System.CanFire`, `HandsIfAny`; `WM_Gun.WM_TryFire` |
| 2 | **The gun's rounds exist on one machine.** `WM_Ammo` is created in `WM_Rig.Bind`, which only runs for the console player, so `WM_Gun.wmAmmo` is null everywhere else. Every store, verb and reserve change (`DrawFromPouch`, `PouchIt`, `DrawBarrelRound`) happens on one machine. | `WM_Rig.Bind`; `WM_System.WorldTick` |
| 3 | **Magazines and rounds on the floor exist on one machine.** `WM_LooseMag` / `WM_LooseRound` are real pickups (they derive from `Clip`), spawned, moved, picked up and destroyed only locally. RS_WorldHands' grab also turns a map clip into one locally. | `DropMagazine`, `PullOut`, `ThrowOutAll`, `EjectRound`, `DrawFromPouch`, `WM_GrabBecomeService` |
| 4 | **Weapon-in-hand writes come from the local loop.** `ReadyWeapon`, `OffhandWeapon`, `PendingWeapon` and `SetPsprite`. | `WM_System.Equip`, `EquipInstantly` |
| 5 | **Network events act on the wrong player.** `NetworkProcess` takes the pawn from `e.Player` but the hands from `consoleplayer`. One player's drop or rack hits *every* machine's local guns, and `wm_reset` refills every gun with no cheat gate. | `WM_System.NetworkProcess` |
| 6 | **The fire gate reads the renderer.** `CanFire` → `InBattery` → `DrawnValue` (the engine's drawn surface value). It also requires `rig.prop` and `rig.resolved`. | `WM_Rig.OutOfBattery`; `CanFire` |
| 7 | **Gun part state is shared between players.** `WM_Part.value`, `present`, `driveSlot`, `poseSlot`, `pastSplit`, `spinSpeed` and `spinAngle` live on the card: one object per weapon class. Two players holding the same gun would fight over them. This blocks any per-player fix. | `card.zs WM_Part` |
| 8 | **Gameplay cvars are read through the console player,** including on the fire path (`wm_verbs` in `WM_Verb.Enabled`). The per-type thresholds `wm_feel_*` are `nosave`, and the engine only resolves `user` (userinfo) cvars per player (`c_cvars.cpp GetCVar`), so those can never be read "for the owner". | `WM_Verb.Enabled`; `WM_Rig.FeelThreshold` |
| 9 | **Hand speed and tilt decide things.** Flick-to-close reads `AttackVel` / `AttackAngularVel`, which read zero in multiplayer. Tilt-dump reads the drawn gun's attitude. Thrown magazines take the controller's speed. | `FlickByVerbs`, `EjectByTilt`, `HandVel` |
| 10 | **Looks are spawned as network actors.** `WM_Casing`, `WM_BeltLink`, `WM_MuzzleFlash`, `WM_Smoke`, `WM_Marker` and the gun props use `Actor.Spawn`. That shifts network IDs, thinker order and saves. The flash's beam slot is global, so two players' flashes collide. | `rig.zs Brass`, `FlashAt`, `EnsureProp`; `system.zs NextMarker` |

**Already right:**
- Damage, spread, rail and saw rolls use named RNGs inside the weapon's fire action.
- Refire, alt fire and flame hold read the owner's usercmd.
- `firesfrom = reserve` pays with `DepleteAmmo` in the fire action.
- Cards load on every machine.
- Cosmetic scatter uses `WM_Jitter` hashes, not the RNG.
- RS_VR_Weapons' loadout handler is keyed to `e.Player`.

All of these only help once problem 1 is fixed.

---

## 2. Two ways to fix it, and which I recommend

### A. Every machine simulates every player's hands

This is `NETWORK_HAND_INPUT_PLAN.md`: put each player's hand pose, grip and trigger into `usercmd_t`, then run the
hand loop for every player on every machine.

For gameplay it also needs:
- a gun transform the playsim can compute without the renderer;
- the drive evaluator at tic time (engine step N4);
- every placement slider and threshold moved into card data or userinfo;
- a deterministic replacement for every renderer read in §1 row 6 and 9.

**Cost:** large engine work, and the largest mod rewrite. Every decision the hands make today would have to be
reproduced from quantised network data. That includes decisions tuned against what the headset draws.

### B. The owner's machine decides, every machine applies — **recommended for gameplay**

- The hand loop keeps its live inputs: controllers, drawn gun, feel sliders, tuning. It changes only looks, and
  when something happens it **sends a network command** (`EventHandler.SendNetworkCommand`, engine 4.12 API,
  present in this tree).
- `NetworkCommandProcess` applies it to `cmd.Player`'s gun, on every machine, the sender included.
- The gun's gameplay state lives on the weapon. `CanFire` reads only that, the card and the owner's usercmd.
- A loose magazine is spawned by the apply handler, at the position, velocity and turn the command carries. Its
  network ID (`Object.GetNetworkID`, `GetNetworkEntity`) names it in later commands: "seat that magazine",
  "pouch that round".

**Why B:**
- The decisions stay exactly what you tune in the headset.
- Commands are rare: one per rack, seat, load or draw, not one per tic.
- They travel in the same lockstep stream as net events (`DEM_ZSC_CMD`), so they apply on the same tic
  everywhere.
- Single-player runs the same path, so a single-player test proves the netplay logic.
- It needs **no engine change**.

**What B costs:**
- The result lands one tic later.
- A modified client could send false commands. Co-op peers are trusted, and the apply side still sanity-checks
  every number against the gun (§4).

**A still has a place,** for looks: seeing other players' hands and gun parts move needs their hand pose, which
is engine steps N1–N5. That is §9 step P5, after gameplay is safe.

---

## 3. The rules every change is checked against

1. **R1:** gameplay state changes only in a command handler, or in the weapon's own fire action (which already
   runs on every machine). It is keyed by `cmd.Player` or the weapon's owner, and never happens in the
   `WorldTick` hand loop.
2. **R2:** the hand loop may read anything local (hands, renderer, sliders). It writes only looks, and sends
   commands.
3. **R3:** a command carries every number its apply needs: positions, velocities, angles, rounds, slot, store.
   The apply never re-derives them from local data.
4. **R4:** no RNG in the hand loop or on looks. Scatter for a *gameplay* pickup is computed by the sender and
   carried in the command.
5. **R5:** actors that are only looks are `+CLIENTSIDE` and spawned with `Actor.SpawnClientSide`. Gameplay actors
   are spawned only in apply handlers.
6. **R6:** `CanFire`, `CanAltFire`, `OnShot`, `OnDry`, `ChambersToFire` and `ReserveHolds` read weapon state, the
   card and the owner's usercmd only: no rig, no prop, no drawn value, no local cvar.
7. **R7:** a cvar read in an apply handler or the fire path must give the same value on every machine: a
   server cvar, card data, or carried in the command. Feel thresholds read in the hand loop are fine, because
   they only shape what the owner sends.
8. **R8:** nothing gameplay is keyed on `consoleplayer`. Menus stay UI and send nothing that changes gameplay.
9. **R9:** no mutable per-player state on cards.

---

## 4. The command set, first cut

Each command is sent by the owner's hand loop and applied to that player's gun (`cmd.Player`).

**Every command names its gun by network ID** (`WM_Gun.GetNetworkID()`), not only by hand, **and states the
pre-state it expects.** For example: "seat loose magazine M into gun G, whose magazine is out"; "stroke verb k of
gun G home, whose stroke is out".

**The apply checks everything before it changes anything:**
- gun G exists, belongs to `cmd.Player`, and is in the hand named;
- the gun's state matches the stated pre-state;
- rounds ≤ capacity, and the slot and store exist on the card;
- the reserve holds what's taken;
- a named loose actor still exists and belongs to that player.

**Any mismatch refuses the whole command and logs it**, naming the player, gun, command and what differed.
**Nothing is ever half-applied:** all the checks come first, then every change, with no early return between
the changes. That's the shape `WM_Ammo` already uses (Adopt / body / Sync). (Build lane review, 2026-09-13.)

| Command | Sent when (today's detection) | Carries | Applies (today's mutation) |
|---|---|---|---|
| `wm_equip` | the local loop picks the weapon for a hand | hand, weapon class | `ReadyWeapon` / `OffhandWeapon` / psprite (`Equip`, `EquipInstantly`) |
| `wm_stroke` | a hand-returned cycle passes out or home (`HoldByVerbs`, `ReleaseByVerbs`) | hand, verb k, out/home | `StrokeOut` / `StrokeHome` (eject, feed, lock) |
| `wm_rack` | a spring cycle is let go past outat | hand, verb k | `RackByVerbs` |
| `wm_part` | a cycle leaves or reaches home; an open verb crosses openat / closeat (flick included) | hand, verb k, state (home / out / open / shut / part-open) | the weapon's battery flags (§5) and `SetOpen`'s store effects |
| `wm_eject` | tilt, rod, button or open-ejectall throws a store | hand, verb k, every thrown object's position and velocity | `ThrowOutAll`: empties the store, spawns the rounds |
| `wm_load` | a round or loader is let go at a load point (`LoadFrom`) | hand, verb k, loose actor ID, count | `LoadRound` ×count; destroys or updates the loose actor |
| `wm_seat` | the guide seats a magazine (`Guide`) | hand, loose actor ID | `Seat`; destroys the actor |
| `wm_drop` | the button or a release drops the magazine (`ButtonDrop`, `ReleaseByVerbs`) | hand, position, velocity, angle / pitch / roll | `TakeMagazine`; spawns the `WM_LooseMag` |
| `wm_pullout` | a hand pulls the magazine all the way out | hand | `TakeMagazine`; spawns it in that hand |
| `wm_draw` | a squeeze in the pouch (`DrawFromPouch`, `DrawBarrelRound`) | hand, what (magazine / loader / round / barrel round), count | reserve `Amount -=`; spawns it in the hand |
| `wm_pouch` | a carried object is let go in the pouch (`PouchIt`) | loose actor ID | reserve `Amount +=`; destroys it |
| `wm_catch` / `wm_throw` | a hand catches or lets go of a loose object | loose actor ID, hand, position, velocity | holder player and hand on the actor (§5) |
| `wm_grip` | the other hand takes or leaves a `hands = 2` support grip | hand, held | the weapon's `supportHeld` |
| `wm_stow` | the working hand puts its own gun away | hand, stowed | the weapon's `stowed` |
| `wm_engine` | a start verb catches; the gun leaves the hand | hand, running | `WM_Ammo.engineRunning` |

**Not commands, because they don't change the game:** latch thrown (it only gates the owner's own decisions),
spin, flip, meter, drawn part values, markers, haptics.

**Firing needs no command.** The trigger is already in the usercmd; R6 makes `CanFire` answerable on every
machine.

---

## 5. Where state moves

- **`WM_Ammo` on every machine:** made by the weapon itself when it reaches its owner (for example
  `WM_Gun.AttachToOwner`, or its first `DoEffect`), from `CardForWeapon`. Cards are already loaded everywhere.
  `WM_Rig.Bind` adopts it and never creates it.
- **The weapon's action state**, a new small object on `WM_Gun` beside `wmAmmo`, set only by commands:
  - per verb: stroke out/home, held open, not-home / not-shut;
  - `supportHeld`, `stowed`, and the hammer state if `OnDry` still needs it.
  - `engineRunning` and `actionLock` already live in `WM_Ammo`.
  - `InBattery` is answered from these flags, not from drawn values.
- **`WM_Rig` keeps only looks and local-detection memory:**
  - the prop and drives;
  - `pastBack`, `atApex`;
  - the shot's stroke clock (`verbTics`);
  - flick filters, latch tics, meter, spin, flip;
  - `firedTic`.
- **`WM_Part` live fields move off the card:**
  - `value`, `driveSlot`, `poseSlot`, `pastSplit`, `spinSpeed`, `spinAngle` into per-rig arrays;
  - `present` is derived from `WM_Ammo.magIn`, which is the gameplay truth.
- **Loose objects** carry their holder's player number as well as the hand. `FollowHandMode` names a hand, not a
  player, and today it's used as ownership (`CatchFalling`, `ForeignInHand`, `TryPickup`).
  - The grace timer and pickup rules become card data or server cvars (`wm_walk_grace`, `wm_round_life`,
    `wm_bounce`).

### 5.1 P1's state containers, designed up front

§1 row 7 is P1's real blocker (build lane review). `WM_Part`'s live fields sit on the card, one object per
weapon class. P1 splits them by what they are:

| Field | What it is | Moves to | Written by today | Read by today |
|---|---|---|---|---|
| `present` | **gameplay**: is the magazine in the gun | **derived** from `WM_Ammo.magIn` for the feed part; no stored copy | rig `Bind`, `Reset`, `DropMagazine`, `Seat`; system `PullOut`, `BeginGuide`, `Guide`; parser `NewPart` | rig `Pose`, `Dump`; system `NearestPart`, `PinHand`, `DrawMarkers`, `BuildHud` |
| `value` | looks and the owner's local decisions: where the part is drawn, 0..1 | a per-rig array | rig `Bind`, `Reset`, `Pose`, `StartDrive`, `StopDrive`, `Automatic`, `Spin`, `CycleByVerbs`, `Cycle`, `DropMagazine`, `Seat`, `FlickShut`; system `ButtonWorksVerbs`, `Release`, `ReleaseByVerbs`, `PullOut`, `Guide` | rig `PartPointRaw`, `PartOffset`, `PartRotation`, `NoteSplitCrossing`, `DrawnValue`, `Dump`; system `Take` |
| `driveSlot` | looks: the renderer drive slot while a hand holds the part | a per-rig array | rig `Bind`, `StartDrive`, `StopDrive`; system `WorldLoaded`; parser `NewPart` | rig `Reset`, `NoteSplitCrossing`, `DrawnValue`, `Pose`, `DropMagazine`; system `PinHand` |
| `poseSlot` | looks: the part's surface-override slots | a per-rig array | rig `Bind`; parser `NewPart` | rig `Pose`, `StartDrive`, `DriveSecondStage`; system `PinHand` |
| `pastSplit` | looks: a log-once flag | a per-rig array | rig `Bind`, `NoteSplitCrossing` | rig `NoteSplitCrossing` |
| `spinSpeed`, `spinAngle` | looks | per-rig arrays | rig `Bind`, `Spin` | rig `Spin` |

From a grep on 2026-09-13. Grep again at P1: the list moves with the code.

**The gameplay container, on the weapon** beside `WM_Ammo`. It's made on every machine when the weapon reaches
its owner, and changed only by command applies:

| State | Where it lives today | Read by after P1 |
|---|---|---|
| stores, `actionLock`, `engineRunning` | `WM_Ammo`, but made only in `WM_Rig.Bind` | `CanFire`, `OnShot`, `OnDry`, applies |
| per verb: stroke out or home, held open, not home, not shut | `WM_Rig.verbStroke`, `verbOpen`, and drawn values | `InBattery` (from these flags), applies |
| hammer cocked / fallen | `WM_Rig.hammerCocked`, `hammerFell` | `OnDry`, `ShotByVerbs` |
| `supportHeld`, `stowed` | `WM_System.SupportHeld()` from the other hand; `WM_Rig.stowed` | `CanFire`, `CanAltFire` |

`WM_Rig.Bind` adopts both objects and creates neither. The rig keeps the per-rig arrays above, plus its
local-detection memory: `pastBack`, `atApex`, `verbTics`, flick filters, latch tics, meter, `firedTic`.

---

## 6. Cvars

| Kind | Cvars | Under B |
|---|---|---|
| Looks | flash, smoke, sparks, casing, glow, markers, HUD, log, hand seats, placement sets, `wm_world_factor`, muzzle trims, `wm_hand_*` | stay local |
| The owner's feel, read only in the hand loop | `wm_feel_*`, `wm_seat_at`, `wm_well_radius`, `wm_well_letgo`, `wm_catch_radius`, `wm_palm_gate` / `_cos`, `wm_flick_*`, `wm_reach_override`, grab tuning (`wm_tune_*`, `wm_grab_all_*`), the pouch position (`wm_belt_*`, `wm_hip_*`) | stay local: they shape what the owner sends |
| Numbers the owner computes and sends | `wm_throw_mult`, `wm_drop_speed`, `wm_eject_speed`, `wm_eject_mirror_off`, `wm_loader_spent_drops`, `wm_stow_working_hand`, `wm_brace` | read by the sender, carried in the command |
| Read where every machine must agree | `wm_verbs` (on the fire path), `wm_walk_grace`, `wm_round_life`, `wm_bounce`, `wm_clip_becomes_mag` | server cvars, or card data; `wm_verbs` ideally retired (§10) |
| Userinfo churn | `wm_gp_name_*` (written as parts bind); belt and hip cvars written every tic while dragging a pouch | make them `nosave` / `noarchive`: they're UI and local. **Done 2026-09-14 (§8 fix 3):** `wm_belt_*`, `wm_hip_*`, `wm_gp_name_*`, `wm_gp_sel_*` (and `_color`), `wm_tune_gun` / `_part` |

**Thresholds and the fire path.** The build lane's review asks that every threshold on the fire path, `wm_feel_*`
above all, become card data or userinfo before P2.
- Under B the better move is for **P1 to take them off the fire path entirely.** `CanFire` answers `InBattery`
  from the weapon's flags (§5.1), which only commands set, so no machine but the owner's ever reads a threshold.
- The thresholds then only shape what the owner's machine sends, and can stay `nosave` and local.
- Making them userinfo instead would broadcast every slider drag to every peer, and a remote machine would still
  be comparing them against a value only the owner's renderer drew.
- If §5.1's flags are rejected: then yes, userinfo (`user`) per player, never `nosave`.

**Userinfo size at connect (measured 2026-09-13, corrected the same day by the build lane).** When a player joins, the host sends each player's userinfo in **its own packet**, and a joining client sends only its own. Userinfo is every `user` cvar as a bare value, sorted, with no names (`Net_SetUserInfo` -> `D_GetUserInfoStrings(compact)`).
- **Evidence.** In `i_net.cpp` the host loops over players, resetting `NetBufferLength` to 3 and calling `SendPacket` once per player (about lines 1356-1382). The client sends its own (about 1720-1725). Receivers read one player per packet.
- **The budget is per player, not summed across players:**
  - under `MAX_MSGLEN`, 14,000 bytes uncompressed (`i_net.h`; going over is a fatal "Netbuffer overflow");
  - under `MaxTransmitSize`, 8,000 bytes after zlib level 9 (`i_net.cpp`; going over is an error).
- **Today.** The load order (run.ps1 `-Full` plus RS_VR_Weapons, RS_VR_Reload, RS_Ballistics) declares 1,392 `user` cvars. That's about 4.2 KB per player from their defaults, and short numbers compress well. Any player count fits, with roughly 3x headroom uncompressed.
- **What would use the headroom up:** a very large `user` set with long values. VR Weapon Sound Selection's 575 `wm_snd_*` picks as `user`, every one filled with a ~20-character name, would add up to about 11.5 KB, near the uncompressed cap. Real use fills far fewer slots, and repeated sound names compress well. So their scope is a presentation choice, not a size problem:
  - `user`: every machine hears each player's own picks;
  - `nosave`: each machine applies its local picks to everyone's guns.
  Both are netplay safe, since sounds never touch the simulation.
- **Hygiene still holds.** Keep pure tuning (hand seats, ovals, thresholds) off `user`, and retire the `wm_gp_*` sets (259 `user`) once baked. No engine change is needed.

---

## 7. Looks

- **Client-side actors:**
  - `WM_Prop` (and RS_VR_Weapons' prop subclasses, which inherit it), `WM_Marker` and `WM_BeltLink` get
    `+CLIENTSIDE`; `Actor.Spawn` then makes them client-side on its own. The rig's flash and casings are
    RS_Ballistics' `RSB_Flash` and `RSB_LocalEjecta` since 2026-09-13, so flagging those is the ballistics lane's.
  - Read from the engine source (7.1): a client-side actor is drawn, honours `FollowHandMode` and the surface
    drives, and bounces. The headset proof remains.
- **The beam slot** (`wm_flash_slot`) is global per level. Offset it by player number so two players' flashes
  don't clear each other.
- **Haptics** only for the console player (engine plan N4's owner guard).
  **Checked 2026-09-14: already so, no change needed.**
  - All 34 `level.VRHaptic` calls are in rig.zs and system.zs.
  - The hand-loop ones root in `WorkHand`, which only `WorldTick` calls, and `WorldTick` works only the console player's hands.
  - The weapon's every-machine entry points (`OnShot`, `OnDry`, `OnAltShot`, `OnAltDry`, `OnCharge`) return unless
    `HandsIfAny(pn)` has a bound rig, and a machine makes hands only for its own console player (`ForPlayer`).
  - The drop and UI events are keyed to their sender since §8 fix 1.
- **Other lanes:**
  - RS_Ballistics' `RSB_Flame.Stream` / `Pilot` are called from `DoEffect` on every machine at positions that
    differ per machine. Confirm its actors are client-side and use no RNG (the ballistics lane's check).
  - RS_WorldHands' arbiter calls (`grip.claim`, `grip.near`) and its become service run from the local loop.
    That lane must make its grabs of gameplay items netplay-safe the same way.

### 7.1 Section 8 fix 2, client-side looks: design note (2026-09-14)

**Design only, no code.** The engine was read, never changed; the engine is the build lane's.

**What moves client-side, and why each is only a look:**

| Class | What it is | Spawned by |
|---|---|---|
| `WM_Prop`, and RS_VR_Weapons' 22 prop subclasses (they inherit it and set no flags of their own) | the gun drawn in the hand | the owner's rig only (rig.zs `EnsureProp`); nothing in the playsim reads it |
| `WM_Marker` | grab ovals and pouch markers | WM_System's marker pool (`NextMarker`, `selMark`) |
| `WM_BeltLink` | belt links | the rig's `Brass`, on the shooter's machine |

- **Not client-side:** `WM_LooseMag` / `WM_LooseRound`. They're pickups, which is gameplay, and the engine refuses
  a client-side Inventory class at compile time (zcc_compile_doom.cpp:917). They're P3's.
- **The ballistics lane's to flag:** RS_Ballistics' local looks, such as `RSB_Flash`, `RSB_Smoke`,
  `RSB_LocalEjecta`, and the impact lights and sound spots spawned by local settings.

**The change is one flag per class:** `+CLIENTSIDE` in the Default blocks of `WM_Prop`, `WM_Marker` and
`WM_BeltLink`. No spawn call changes:
- `Actor.Spawn` of a class with the flag already makes a client-side thinker, takes no network ID (only world
  actors get `EnableNetworking`), and uses the client-side RNGs for its spawn and state tics (p_mobj.cpp:5737-5744
  and :5583; info.h:143).
- `SpawnClientSide` only adds a refusal for a class without the flag (p_mobj.cpp:5762-5767).

**The engine read:**

| Question | Answer | Evidence |
|---|---|---|
| Is it drawn? | Yes. It's kept out of the sector thinglist and the blockmap, but still linked into the render sectors the renderer walks, while its render radius is >= 0 (default 0). | p_maputl.cpp:440-477; actor.zs:877; hw_bsp.cpp:920, :1088 |
| `FollowHandMode`? | Unchanged. It rides THIS machine's controllers, whoever owns the actor. | models.cpp, the `followHandMode` block calling `GetWeaponTransform` (about :1790-1830) |
| Surface drives, `A_ChangeModel`, `ModelPointToWorld`, sounds? | Unchanged: no client-side branch anywhere in them. | no `IsClientSide` in src/rendering, src/r_data, src/common/models, src/sound or src/common/audio |
| Bounce movement? | Runs: the same `AActor::Tick`, and the movement code has no client-side branch. | p_map.cpp: 0 `IsClientSide`; ticked by `RunClientSideThinkers` (dthinker.cpp:226), called from p_tick.cpp:86 |
| While paused? | Frozen, like world actors: the client-side loop ticks only when the world isn't paused. | dthinker.cpp `RunClientSideThinkers` |
| A savegame? | Not saved. A pointer to one saves as null, and the reload system re-spawns props and markers when it finds null. | serializer.cpp:252 (OF_Transient, set on client-side thinkers at g_levellocals.h:851); rig.zs `EnsureProp`; system.zs `NextMarker`, `selMark` |
| World and client-side pointers? | Allowed. The only rules found: Behaviors can't move between them, and a replacement must match. | p_mobj.cpp:689; info.cpp:585 |
| Net lag? | Still drawn interpolated. | d_net.cpp:527 |

**What it buys in a netgame.** A gun, oval or link spawned on one machine stops being a world actor there:
- it consumes no network ID (§4 names guns and loose actors by network ID);
- it isn't in the world thinker list other mods iterate;
- it isn't in the blockmap.

**Risks the headset has to clear:**
1. **The flag is declared protected** (thingdef_data.cpp:406), and no shipped ZScript sets `+CLIENTSIDE` in a
   Default block yet. The code step's compile check proves the engine accepts it there.
2. **A world actor parents to the prop:** RS_WorldHands' hand, in system.zs `PinHand`
   (`hand.FollowActor = rig.prop`). No engine rule forbids that; the headset proves hands still ride the parts.
3. **A link lying on a lift isn't carried.** `P_ChangeSector` walks `touching_thinglist` (p_map.cpp:7446-7545),
   which client-side actors aren't in. Cosmetic.
4. **The shared spawn counter still counts client-side spawns** (p_mobj.cpp:5541). Its only readers are the sprite
   sort (hw_sprites.cpp:1868) and savegames (p_saveg.cpp:1073), and ZScript can't read it, so no desync.

**The headset proof, single-player: everything must look as it does today.**
1. Draw a pistol, a pump, the SSG, a revolver, the machine gun, the BFG and a chainsaw.
   - Each is in the hand.
   - The slide, pump, break, crane and magazine move under the hand, and the hand rides the part.
   - The fire and rack sounds come from the gun.
2. The grab-point page: the picked oval breathes on the gun with the menu open. Placement mode shows the gold pouch
   markers.
3. The machine gun's links fly, bounce, lie and fade.
4. Save mid-reload and load: the gun, ovals and hand come back. Change map: the gun is there.
5. The bind log says the prop is client-side (a line added in the code step).

**Two instances, after P2:** the gun-state hash (§9) names loose actors by network ID. Those IDs match only if the
looks no longer take IDs on one machine.

**Engine changes: none needed for fix 2.** Two proposals for later, for the build lane to take to the owner:
- **Client-side actors riding moving floors.** A general capability: a per-sector client-side list that
  `P_ChangeSector` moves in Z (no crushing), so every mod's client-side debris rides lifts. Low priority.
- **Seeing other players' guns (P5).** `FollowHandMode` uses this machine's controllers, so drawing another player's
  gun at their hands needs per-player hand transforms. That's NETWORK_HAND_INPUT_PLAN N1-N5, already on paper.

**The code step, when approved:**
1. The three `+CLIENTSIDE` lines (weapon.zs `WM_Prop`; fx.zs `WM_Marker` and `WM_BeltLink`), plus a bind-log line.
2. The staged build.
3. The headset proof above. FEEL_PLAN gets row 24 then.

---

## 8. Small, safe fixes that don't wait for the design

1. **`NetworkProcess` keyed to `e.Player`**, and `wm_reset`, `wm_rack_*`, `wm_drop_*` gated to single-player or
   cheats.
   **Status: COMPILED and installed 2026-09-13 23:59:40 (FEEL_PLAN row 20).** As built:
   - the drop-mag buttons are **keyed to the sender, not gated**. A drop is gameplay, keyed to the sender it can
     no longer touch another player's gun, and gating it would pre-empt section 10.4's "reload by button only";
   - `wm_rack_*` and `wm_reset` are refused in a netgame without `sv_cheats`;
   - the UI events (pouch placement, bakes, dump, self test) run only on the sender's own machine.
2. **Looks go client-side** (§7), class by class.
   **Status: design note written 2026-09-14 (§7.1); no code yet.** It's three flags and a log line, waiting on the
   build lane's go and a headset proof.
3. **UI-only cvars stop churning userinfo** (§6, last row).
   **Status: COMPILED 2026-09-14 (FEEL_PLAN row 23).** 43 cvars went `user` → `nosave`. Each one's saved value
   loads by name on the first run.
   **§10 stays open.** This scope fits today's readers, which are all the console player's, and the "owner's
   machine decides" direction. If §10 picks networked hands (A), these go back to `user`. It's a flag change, so
   it's reversible.

None of these changes what a single-player game does.

---

## 9. Rollout, each step testable in single-player first

| Step | What | Single-player change | Test |
|---|---|---|---|
| **P0** | §8's small fixes (fix 1 built 2026-09-13, fix 3 2026-09-14; fix 2 not started) | none | every reload loop as today; a `wm_reset` in a netgame refused |
| **P1** | `WM_Ammo` and the action state on the weapon, made on every machine; part state off the card; `CanFire` family reads only weapon state (R6); `firesfrom = magazine` pays in the fire action | none expected | every gun fires, clicks and runs dry exactly as before; two instances in a netgame: firing with nothing reloaded stays in sync |
| **P2** | The command layer (§4): the hand loop sends, handlers apply; single-player through the same path | results one tic later | a **gun-state hash** per player (stores, the weapon's flags, reserve, loose actors held), logged every 35 tics and after every applied command as `tic, player, command or "tick", hash`, so the two instances' logs diff cleanly, through: rack the pistol, pump two shells, break and load the SSG, dump and speedload the Cola, drop and catch a magazine, draw a grenade and fire the launcher, start the chainsaw |
| **P3** | Loose objects spawned in handlers, holder player on the actor, ownership rules | none | a dropped magazine's position matches on both instances 70 tics later; the other player can pick it up |
| **P4** | §6's "every machine must agree" cvars moved | none | change one on one instance mid-game: no desync |
| **P5** | Looks for other players: their guns and hands drawn at their own hands (engine plan N1–N5) | none | watch a VR peer reload from a flat peer |

Across all steps: **no consistency failure over 10 minutes of reloading** on the engine plan's §8 two-instance
setup, and identical gun-state hash logs.

---

## 10. Decisions for the owner

1. **The approach:** B (your machine decides, every machine applies) for gameplay, with A later only for seeing
   other players' hands. Or A for everything.
2. **One tic:** is a reload's result landing one tic after the hand, in single-player too, acceptable? (The part
   still moves at once.)
3. **Retire the `wm_verbs` switch** (the old role path)? Keeping both paths doubles every netplay change and puts
   a local cvar on the fire path.
4. **Until P2 lands, in a netgame:**
   - carded guns off (vanilla firing);
   - reload by button only;
   - or leave it, knowing it desyncs on the first pull.
5. **Trust:** co-op peers are trusted, and applies only sanity-check. Or do you want stricter validation?

---

## 11. Corrections to `NETWORK_HAND_INPUT_PLAN.md` §6 (for when that plan resumes)

1. Its anchors are stale. Use function names.
2. A remote shot is not "dropped", it's a **desync**: `DepleteAmmo`, the RNG draws and the psprite state all
   sit behind the gate.
3. `WM_Ammo` exists only on the owner's machine, so "state on the weapon" is not synced state today.
4. Live part state sits on the shared card and must move first.
5. `wm_verbs` is read through the console player inside the fire action on every machine.
6. Its rule that cvar reads switch to the owner can't work for `nosave` cvars. The engine resolves only userinfo
   cvars per player.
7. The weapon-slot writes (`Equip`, `EquipInstantly`) come from the local loop.
8. `NetworkProcess` is cross-wired and `wm_reset` is ungated.
9. Angular velocity *is* read by script: `FlickByVerbs`.
10. The drop-mag button is not deterministic, even though the button is synced: its handler, geometry and latch
    reads are local.
11. `TurnLikeDrawn` sets a gameplay pickup's orientation from `ModelPointToWorld`.
12. `FollowHandMode` names a hand, not a player, and is used as ownership.
13. `Actor.SpawnClientSide` with `+CLIENTSIDE` exists, and nothing uses it.
14. A menu does not freeze a netgame: the grab page's ticker writes cvars and sends bake events while play goes
    on.
15. `firesfrom = magazine` guns pay in `WM_Rig.OnShot`, not in the weapon action.
16. RS_Ballistics was not swept.

---

## Related, not netplay: hands grabbing and locking to parts

Questions put to the owner on 2026-09-13. Under B these stay local decisions, so the answers don't change the
command set.

1. When a hand is inside two ovals at once, which wins?
2. Should every grabbable part get a measured hand spot, with sliders only trimming it?
3. Should a grab also have a small "magnet" distance to that spot?
4. While holding a part, is the drawn hand glued to the part or following the controller?
5. Do support grips lock the hand the same way?
