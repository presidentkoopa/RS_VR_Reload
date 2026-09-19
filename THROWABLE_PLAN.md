# A throwable archetype for the card system

**Design note, no code.** Written 2026-09-14 by the reload lane (uzdxrema-11) for the build lane (doomwork-5e);
revised the same day for the owner's calls below.

**Read, never edited:**
- RS_Grenade's `zscript/rs_vrgrenade.zs`;
- RS_ShieldSaw's `zscript/*.zs` (at 52eaf2e) and README;
- RS_WorldHands' `hands/rs_throw.zs` and `hands/rs_swing.zs`;
- the reload system's own catch (`WM_System.CatchFalling`);
- the build lane's model report, and the weapons lane's `_pending/THROWABLE_MESHES.md`;
- the engine's VR device code.

**The owner's calls (2026-09-14):**
- **Both the grenade and the shield saw throw by the hand's real velocity at release:** "make sure they are both
  velocity based", "we want real vr mechanics". No button throw, no scripted arc.
- **The shield saw keeps its throw, its route lock and its return:** "the most interesting thing about it". It comes
  back to the throwing hand and is caught by the hand.
- **The grenade builds on RS_Grenade:** its ammo store, pin, lever and throw.

## In plain words

A throwable is a weapon whose shot is the weapon leaving your hand, at the speed and in the direction your arm sent
it. Around the throw sit a few reusable pieces:
- **a part you pull off and drop** (a grenade's pin);
- **a part your grip holds shut** that springs off when you let go (its lever);
- **a fuse;**
- **a route painted while you hold fire,** which steers a thrown weapon onto those targets after it leaves your hand;
- **a return to your hand,** and a catch;
- **a place the weapon lives on your body** (a pouch or a mount) that you reach to.

**How it stays in sync:** everything that changes the game is decided by the thrower's machine and sent as a network
command: arming, the fuse, the throw with its measured velocity, the route, where the returning weapon is heading,
the catch. Every machine then flies the same object.

---

## 1. How the two mods work today, from their code

### RS_Grenade

| Step | What happens | Where |
|---|---|---|
| Held | A Weapon in slot 9 whose ammo is `RSVG_Ammo` (topped up to 10 on spawn). The grenade IS the weapon. | rs_vrgrenade.zs header; its event handler's `PlayerSpawned` |
| Safety | Holding fire opens a "pin window". With the finger off, nothing can happen. | `DoEffect` |
| Pin | Pulled by the other hand's trigger at the grenade, or by bringing it to your mouth. The ring takes a short clock to come out, then it's cooking. | `DoEffect`, `PullPin` |
| Fuse | Starts at the pin (`rsvg_cook`, the default) or when the lever flies, and ticks audibly. | `PullPin`, `DoEffect` |
| Throw | Letting go of fire. Velocity and wrist spin come from `RS_ThrowService`, with a local fallback. It spawns the thrown grenade at the palm and spends one `RSVG_Ammo`. | `ThrowIt` |
| Cook-off | The fuse runs out in the hand: `RSVG_Blast` at the player, one grenade spent. | `DoEffect` |
| In flight | A Projectile that bounces and tumbles, then explodes (`A_Explode` 85/200 then 75/255). Unarmed, it leaves an `RSVG_Pickup` dud. | its thrown-grenade actor |

### RS_ShieldSaw (at 52eaf2e)

| Step | What happens | Where |
|---|---|---|
| Stowed | On a mount over the off shoulder, or the forearm, placed from the head position and body yaw. | rs_shieldsaw_mount.zs `AnchorPos` |
| Draw | Reach to the mount and squeeze. The thrower's machine polls the grip and sends `rs-ss-draw`; every machine remembers the weapons in both hands and raises the shield. | rs_shieldsaw_state.zs `pollLocalGrip`, `NetworkProcess`, `Draw` |
| Held | Fire deploys the blades, then loops two things: a grind (five `LineAttack`s from the player's aim, 22° apart) and a sweep that paints locks. | rs_shieldsaw.zs `Fire`, `GrindLoop`, `A_ShieldGrind`, `A_ShieldSweep` |
| Guard | A shootable deflector held in front of the hand blocks missiles. | `holdDeflector` |
| Locks | Every 3 tics, the nearest visible hostile inside `lockRange` and `lockCone` of the hand's aim joins the route, with a lock mark on it. | `acquire` |
| Throw | Letting go of the grip while the hand is moving sends `rs-ss-throw`. `LaunchNow` then:<br>• spawns the disc;<br>• **with nothing locked, sets it off along the release velocity from `RS_ThrowService`**, its speed clamped to 0.5-2x the flight speed (52eaf2e: "a throw, not a point and fire");<br>• with locks, flies the route;<br>• takes the disc's plane from the wrist's roll and its spin from the service;<br>• brings the previous weapon back at once. | `pollLocalGrip`; `LaunchNow` |
| Flight | `+RIPPER` through each route target in turn:<br>• it re-aims every 4 tics and cuts each target once per pass (damage `random[ShieldCut]` 24-44);<br>• with no route, it flies straight on for 35 tics;<br>• it flies home at 1.6x speed;<br>• if stalled, `NOCLIP` for 20 tics;<br>• it comes back after 12 seconds whatever happens. | `RS_ShieldInFlight` `Launch`, `aimAt`, `advance`, `GoHome`, `Tick` |
| Return | It steers to the throwing hand's position and, within max(40, 1.2x its speed), is **stowed back on the mount. No catch in its code yet.** | `steerHome`, `Tick`, `Landed` |
| Recall | A grip press while it flies sends `rs-ss-recall` and turns it home early. | `pollLocalGrip`, `RecallNow` |

### The shared thrower (RS_WorldHands)

`RS_Swing` keeps a window of per-tic hand motion from the engine's `AttackVel` / `OffhandVel`. From it:
- **Speed:** the window's peak (`PeakVelocity`).
- **Direction:** the last 3 samples averaged, the tangent of the arc at release (`ThrowVelocity`).
- **Spin:** the wrist's rotation averaged over the same samples (`ThrowSpin`).
- **Throw or drop:** `throw.iscast` compares the peak against `rs_throw_min`.

`RS_ThrowService` hands these out by service, in thousandths.

**Whose hand it measures:** it's asked with the thrower's pawn, but the swing window is this machine's own player's.
`RS_Swing.WorldTick` samples `players[consoleplayer]` only (rs_swing.zs:333). The pawn passed in adds just its body
velocity (`RS_Throw.VelocityFor`, rs_throw.zs:49).

### Why a netgame breaks both

This changes the plumbing, not the play.

- **Controller data is local only.** `AttackPos`, `OffhandPos`, `HmdPos`, the hand rolls and `AttackVel` /
  `OffhandVel` are written by this machine's VR device code (vk_openxrdevice.cpp:4690-4806,
  hw_vrmodes.cpp:1422-1461) and are in no net stream. The thrower above therefore only knows the thrower's hand, on the
  thrower's machine.
- **RS_Grenade** decides everything in `DoEffect`, which runs on every machine, from local hand data. Each machine
  throws differently. Its thrown grenade also draws unnamed `random(0, 359)` at spawn and reads `consoleplayer`.
- **RS_ShieldSaw** sends its state changes as network events, which is the right shape. But `rs-ss-throw` carries
  nothing, so `LaunchNow` runs on every machine and asks **its own** `RS_ThrowService`:
  - the thrower's machine gets the real release velocity;
  - every other machine gets **its own player's** hand swing plus the thrower's body velocity:
    - if that player is standing still, the result is about zero, so the disc falls back to the aimed line;
    - if that player is swinging, the disc leaves along their arm.

  The lock route, the plane and spin, the guard's position and where the flight goes home are local data too.

---

## 2. The card grammar

A throwable is a WM_Gun card, on a class the weapons lane declares, with a `throw` block. Everything here is
additive and default-off: a card without `throw` is exactly today's gun.

### 2.1 `throw`: the weapon leaves the hand at the hand's velocity

```
throw
  on        = trigger | grip          # the let-go that throws: RS_Grenade's fire, RS_ShieldSaw's grip
  minspeed  = 1.2                     # metres a second; slower is a drop (grenade) or a stow at the mount (shield)
  flight    = <class>                 # the flying actor, by name (section 3)
  speedband = 0.5, 2.0                # optional: the release speed clamped to this share of the flight's own speed
  spin      = wrist | none            # the wrist's spin at release
  plane     = wrist | none            # a disc's face held in the wrist's roll at release
  spends    = 1 | 0                   # reserve spent per throw: a grenade 1, a returning shield 0
  after     = next | empty | previous # the hand then holds the next one, nothing, or the weapon from before
  returns   = no | yes                # it flies back to the throwing hand
  catch     = grip | none             # a returning weapon is caught by closing the hand on it
  catchat   = 6                       # the catch radius, map units (the reload system's wm_catch_radius)
  miss      = stow | drop             # not caught: back on its mount (RS_ShieldSaw today), or falls
  recall    = grip | none             # a grip press while it flies turns it home early
end
```

The release velocity is **always** RS_WorldHands' measurement, asked by service on the thrower's machine: the same
thrower both mods already use. Nothing throws without it.

### 2.2 `route`: targets painted while fire is held, steering the thrown weapon

```
route
  paint = fire       # painted while fire is held (the grind loop)
  range = <units>    # RS_ShieldSaw's lockRange
  cone  = 14         # degrees off the hand's aim
  max   = <n>        # RS_ShieldSaw's maxLocks
  every = 3          # tics between scans
  mark  = <class>    # the lock mark, by name; a look only
end
```

**After release:**
- **With targets:** it leaves along the throw, then steers onto each target in turn, as `RS_ShieldInFlight` does.
- **Without:** it keeps the release velocity for the outbound time, then comes home.

The list is painted on the thrower's machine and **sent with the throw** (section 4).

### 2.3 Two verbs

**`pulloff`**: a part pulled along its dof and, past `offat`, taken off and dropped (a pin).

```
pulloff pin
  part  = pin
  offat = 0.9            # past here it comes away
  by    = hand | head    # the other hand, or brought to the mouth (RS_Grenade's teeth)
  needs = trigger        # only inside the holding hand's trigger window (RS_Grenade's safety)
  arms  = yes            # a throw after this is live
end
```

**`release`**: a part the grip holds shut, which springs off when that hand lets go (a lever). The part's own `dof`
drives the swing.

```
release lever
  part   = lever
  heldby = grip
end
```

### 2.4 `fuse`

```
fuse
  tics    = 105                       # RS_Grenade's 3 seconds
  starts  = pulloff | release | throw
  blast   = <class>                   # RSVG_Blast, by name; its damage is its own
  cookoff = player                    # it runs out in the hand: the blast at the player, as RS_Grenade does
  dud     = <class>                   # an unarmed throw lands as this pickup (RSVG_Pickup)
end
```

### 2.5 Where it lives: a mount, or the pouch

```
mount shoulder
  at    = back_left | forearm_off   # a place on the body, drawn from by reaching there and gripping
  holds = weapon                    # the weapon itself (the shield)
end
```

- **The pouch:** `pouch = whole`. The existing pouch hands a fresh throwable into the reaching hand, one from
  `Weapon.AmmoType1` (`RSVG_Ammo`), beside today's magazine, one-round and loader rules.
- **A hardpoint store:** the same rule, asked of RS_HardPoints by service.

### 2.6 The held weapon's own parts: existing grammar

The weapons lane's meshes are in `_pending/THROWABLE_MESHES.md`.

- **The shield saw's deploy:** `bladesstowed` + `rim` against `blades` + `rimopen`, shown by state. The existing `flip`
  parts switch between pose surfaces on fire or trigger. If deploy has to follow the fire state rather than a beat, it
  needs one small addition: `flip = fire` holding a pair while fire is held, and the other pair otherwise.
- **The spin:** `blades` against `blades2` (or `blades3`), the two-part flip the chainsaw's chain uses.
- **The grind:** RS_ShieldSaw's is five `LineAttack`s from the player's aim, already deterministic. Two options, the
  weapons lane's to pick:
  - a general WM_Gun shot property, a fan of melee traces (`ShotSweep count, step, range`);
  - `ShotSaw`, if one trace is enough.
- **The guard:** `guard = <class>`, held in front. It needs a place every machine agrees on (section 4).
- **The grenade:** `grenade_wm.md3`'s `pin` slides **5.92** along +Y. Its `lever` hinges 45° about +Y through
  **(-1.812, 0, 7.680)**.
  - **Corrected 2026-09-18, re-measured off the mesh** (`_drafts/WMCARD.grenade.txt` carries the full card and the
    workings). The earlier 24.65 and (2.08, -0.02, 7.02) are `nade.md3`'s numbers, in that file's own scale and
    origin — right about that mesh, wrong for this one.
  - The pin's axis comes from the **shaft alone**, split off by triangle connectivity. Ring and shaft averaged
    together give (-0.022, -0.761, 0.649), a diagonal belonging to neither.
  - 5.92 is what **frees** it: at the pin's height the body reaches y 3.94 and the lever's lugs y 0.91, and the pin's
    trailing end starts at y -1.48.
  - The pivot is the lever's one **still point** once the body's own motion is removed from `nade.md3` (Kabsch against
    frame 0) — the retaining lugs, which sit at (-1.812, ±0.83, 7.68) in this mesh.
  - **Blocker for both:** MODELDEF draws the held grenade as `nade.md3`, not `grenade_wm.md3`. Until the weapons lane
    points the prop at the three-surface mesh, none of these numbers address anything.

### 2.7 Draft cards (the weapons lane fills in the numbers)

```
weapon "WM_Grenade"
  type      = grenade
  firesfrom = none
  pouch     = whole
  # part pin:   dof slide, axis 0, 1, 0, distance 24.65
  # part lever: dof hinge, axis 0, 1, 0, degrees 45, pivot 2.08, -0.02, 7.02
  pulloff pin     # part pin, offat 0.9, by hand, needs trigger, arms yes
  release lever   # part lever, heldby grip
  fuse            # tics 105, starts pulloff, blast RSVG_Blast, cookoff player, dud RSVG_Pickup
  throw           # on trigger, minspeed 1.2, flight WM_ThrownWeapon, spin wrist, spends 1, after empty
end

weapon "WM_ShieldSaw"
  type = shield
  mount shoulder  # at back_left, holds weapon
  # parts: deploy (bladesstowed + rim / blades + rimopen), spin (blades / blades2)
  route           # paint fire, range ..., cone 14, max ..., every 3, mark RS_ShieldLockMark
  throw           # on grip, minspeed 1.2, flight WM_ReturningFlight, speedband 0.5, 2.0, plane wrist, spin wrist,
                  # spends 0, after previous, returns yes, catch grip, catchat 6, miss stow, recall grip
end
```

---

## 3. The flying actors: modelled on the mods, general in the reload system

A card can't name either mod's own flying actor:
- **`RS_ShieldInFlight`** holds `RS_ShieldSaw launcher` and calls its `Landed()` and `ClearLocks()`
  (rs_shieldsaw_actors.zs:31, :202, :251, :264): a typed link to that one weapon class.
- **RS_Grenade's thrown grenade** takes its fuse, arming and spin through typed fields set by its weapon, and draws
  unnamed `random` at spawn.

So the reload system gets two general actors that copy the mods' rules, with looks and damage named by the card.
RS_Grenade and RS_ShieldSaw stay exactly as they are for anyone who loads them on their own.

- **`WM_ThrownWeapon`** (the grenade):
  - it leaves at the command's position and velocity;
  - the thrown grenade's Doom bounce as a Projectile;
  - its lazy tumble plus the wrist spin, with a hashed starting angle and no RNG;
  - the fuse carried in from the throw;
  - blast and dud classes by name, and the thrower credited.
- **`WM_ReturningFlight`** (the shield saw), with `RS_ShieldInFlight`'s rules on a velocity launch:
  - it leaves at the command's position and velocity, the speed clamped to `speedband`;
  - route legs re-aimed every 4 tics, one cut per target per pass, `+RIPPER`;
  - with no route, it keeps the release velocity for 35 tics;
  - home at 1.6x, towards the thrower's hand (section 4), caught there or missed;
  - `NOCLIP` for 20 tics when stalled, and a 12-second cap;
  - damage `24, 44` on a named RNG, the plane held with the spin turning within it, and a trail class by name.
  - **The flying disc's mesh:** the card names it. The weapons lane has brought in `shield_weapon.md3` (56.56
    across) and `shield_weapon_glow.md3` (72.7 across), in `RS_VR_Weapons/models/shieldsaw/ShieldSaw/`. A total
    scale of 0.3483 matches the held shield's 19.70 map units.

---

## 4. Netplay: what is sent and what stays local

**Answering the weapons lane's check:**
- `RS_ThrowService` reads the engine's controller velocity, which exists only on the thrower's machine, through a
  swing window that samples only each machine's own player (rs_swing.zs:333).
- `rs-ss-throw` makes every machine call `LaunchNow`, and each asks its own service. So a throw from that path
  desyncs.
- The card version measures once, on the thrower's machine, and **sends the result.**

**The rule:**
- The thrower's machine decides from its hands and sends a command.
- Every machine applies it to the weapon's state and spawns or steers the same actor.
- The apply path reads no `consoleplayer`, and draws no RNG except the named RNG of actors spawned on every machine.
- The shape is NETPLAY_SPEC §4's: its expected state stated, and the whole command refused on any mismatch. **But
  nothing is named by network ID alone** (§4.2).
- It uses `EventHandler.SendNetworkCommand` with typed arguments, read back in `NetworkCommandProcess`
  (events.zs:221, :245).

| Command | Carries | Applied on every machine |
|---|---|---|
| `wm_draw` / `wm_stow` | gun, hand, from (mount or pouch) | the weapon raised or put away; the previous weapons remembered |
| `wm_arm` | gun | the pin is off: armed, and the fuse starts if `starts = pulloff` |
| `wm_fuse` | gun, tics left | the fuse starts, or is set |
| `wm_throw` | gun, hand, and then:<br>• the release position and **velocity** (from `RS_ThrowService`);<br>• spin, plane roll, fuse tics left, armed;<br>• the route (a count plus target network IDs) | validate; spawn the flying actor with exactly these; spend the reserve; do `after` |
| `wm_hand` | hand, the owner's hand position | **every 4 tics while something follows that hand** (a returning flight, a held guard): the point it steers to or sits at |
| `wm_catch` | hand, the flight's serial | the thrower's hand closed within `catchat` of it (tested on the thrower's machine): the flight ends and the weapon is back in that hand |
| `wm_recall` | the flight's serial | it turns home early |

**Returning to the real hand, in sync.** The flight steers to the last `wm_hand` point for its hand. The thrower's
machine sends one every 4 tics while the flight is on its way home, which is one small command. Every machine steers to the same
point on the same tic, so it comes back to your actual hand.
- **If the updates stop** (lag, a dropped player), it steers to the last point, then to a point on the player's
  body built from game state.
- **If it reaches the point uncaught,** `miss` applies: stowed on the mount, or dropped.

**Local only, looks and never gameplay** (client-side once NETPLAY_SPEC §7.1's code step lands):
- the pin and lever flying off;
- lock marks and the trail;
- the fuse light and ticking;
- the mounted prop and the held prop.

**The guard's position** is the one hand-placed gameplay object left. While it's held it sits at the last `wm_hand`
point for its hand, and before the first one arrives it sits in front of the player's body.

The cook-off blast is at the player, which is deterministic. A thrown grenade that doesn't go off becomes its dud
pickup by its own rule (at rest, or after a set time), never by how near `consoleplayer` is. Fuse length, throw scale
and arming come from the card or the command, never a local cvar (NETPLAY_SPEC R7).

### 4.1 The wire format, version 1

Every argument is typed, as `SendNetworkCommand` requires (events.cpp:399). Positions, velocities and angles are
doubles: every machine reads the same bytes, and a gentle lob isn't rounded away.

```
wm_throw   INT8 version 1 | INT8 hand (0 main, 1 off) | STRING the weapon class leaving that hand
           INT serial: this player's throw count including this one; applied only as the last + 1
           DOUBLE x3 release position, world map units
           DOUBLE x3 release velocity, map units a tic, after the thrower's own throw scale
           DOUBLE x3 spin: yaw, pitch, roll, degrees a tic
           DOUBLE plane roll, degrees
           INT16 fuse tics left (-1: not lit)
           INT8 flags: 1 armed, 2 a cast (at or over minspeed; otherwise a drop or a stow)
           INT8 route count (0-16), then per target: INT network ID, DOUBLE x3 its position at release
wm_hand    INT8 version 1 | INT8 hand | DOUBLE x3 the hand's position
wm_catch   INT8 version 1 | INT8 hand | INT serial
wm_recall  INT8 version 1 | INT serial
wm_draw    INT8 version 1 | INT8 hand | STRING weapon class | INT8 from (0 mount, 1 pouch)
wm_stow    INT8 version 1 | INT8 hand | STRING weapon class
wm_arm     INT8 version 1 | INT8 hand | STRING weapon class
wm_fuse    INT8 version 1 | INT8 hand | STRING weapon class | INT16 tics
```

The largest, a `wm_throw` with a 16-target route, is about 560 bytes.

### 4.2 Naming things the same on every machine

**Network IDs can differ between machines today.** The engine gives every actor that isn't client-side an ID as it
spawns, first come first served from a free list (p_mobj.cpp:5744, dobject.cpp:731). An actor spawned on one machine
only shifts every later ID there, and the reload rig still spawns its props and markers on the owner's machine only
(NETPLAY_SPEC §7.1). So:
- **A gun** is named by player, hand and weapon class: the player's inventory holds the same classes everywhere.
- **A flight** is named by player and throw serial. Every machine applies the same `wm_throw`s in the same order,
  so the counts agree.
- **A route target** carries its ID and its position at release. The apply takes the ID's actor only if it's alive,
  shootable, not the thrower, and within 64 units of that position. Otherwise it takes the nearest such actor
  within 64 units, and with none it skips that leg. Either way every machine picks the same actor from the same
  gameplay things.

Once §7.1's client-side looks land, the IDs line up and the position check just confirms them.

**Against NETPLAY_SPEC §10:** this is approach B's shape (§2). It's a new path, so single-player runs through the
same commands and it doesn't wait on §10's other answers. If §10 picks approach A, these commands become local
simulations instead.

---

## 5. The inputs it claims (for the gestures lane)

**Already claimed by the reload rig** (grepped 2026-09-14):
- `BT_ATTACK` / `BT_OFFHANDATTACK`: fire and trigger parts; a hand holding fire also isn't reaching.
- `BT_ALTATTACK` / `BT_OFFHANDALTATTACK`: a second barrel.
- `BT_MAINHANDDROPMAG` / `BT_OFFHANDDROPMAG`: the drop button and button verbs.
- **Grip:** `GripHeld*`, plus RS_WorldHands' grip arbiter (`grip.hello`, `near`, `claim`, `mine`, `release`).
- **Controller position and speed:** `AttackPos` / `OffhandPos` and `AttackVel` / `OffhandVel` (flick-to-close,
  throwing loose objects).
- **Head position:** `HmdPos` (pouch placement).
- **The gun frame's tilt** (tilt dump).
- No KEYCONF.

**The throwable adds no button:**
- **Hold fire:** the grenade's safety window, and painting a route.
- **Fire let-go at speed:** the grenade's throw.
- **Grip at a mount or the pouch:** draw.
- **Grip let-go:** at speed, the shield saw's throw; still, or at the mount, a stow.
- **Grip press while it flies, OUTSIDE the catch radius:** recall.
- **Grip closing INSIDE the catch radius of the returning weapon:** catch.
- **The other hand (or the head) at the pin:** pull it off.

**Room for a recall gesture:**
- **Catch and recall never compete.** Catch only exists within `catchat` of the returning weapon; recall only outside
  it, while it flies.
- **A gesture recall can sit alongside the grip-press recall, or replace it,** provided it's tested only while the
  weapon is flying and outside the catch radius.
- **The throw itself stays velocity**, as the owner decided, so a throw gesture has no place.

---

## 6. Decisions

**Decided 2026-09-14** by the build lane (doomwork-5e), which the owner put in charge ("real vr mechanics"). The owner
can override.
1. **Slot 9: replace.** The card-driven grenade is the slot 9 grenade, using RS_Grenade's `RSVG_Ammo`, `RSVG_Blast`
   and `RSVG_Pickup` by name. RS_Grenade itself isn't edited.
2. **A missed catch: stow** on the mount (`miss = stow`), as RS_ShieldSaw already does.
3. **After a grenade throw: reach the pouch** for the next one (`after = empty`). No refill in the hand.

The options as they were put:

1. **The grenade: REPLACE or WRAP in slot 9.** The same question applies to the shield saw's weapon.
   - **Replace:** the card sits on a weapons-lane WM_Gun using `RSVG_Ammo`, `RSVG_Blast` and `RSVG_Pickup` by name,
     and the mod's own weapon isn't given.
   - **Wrap:** the mod's weapon keeps its own state machine, and the card can't drive it. Its netplay also can't be
     fixed without editing the mod.
   - **Recommended: replace.**
2. **The shield saw not caught: `miss = stow` or `drop`.** Stowed on the mount, as RS_ShieldSaw's code does today, or
   falling to be picked up. **Recommended: stow.**
3. **After a grenade throw:**
   - `after = next`: the next one is in the hand at once, as RS_Grenade does today;
   - `after = empty`: you reach the pouch for the next one, the model report's "reload".
4. **NETPLAY_SPEC §10's approach**, still open.

---

## 7. Engine

**None required.** Networked hand poses (NETWORK_HAND_INPUT_PLAN N1-N5, already on the build lane's list for the
owner) would retire `wm_hand` and let the guard follow the real hand in a netgame. Until then the commands above do
the job.

---

## 8. Build order (the build lane's go, 2026-09-14)

1. **The parser:**
   - `throw`, `route`, `pulloff`, `release`, `fuse`, `mount` and `pouch = whole`, each with its refusals;
   - no behaviour yet;
   - the weapons lane's card_lint mirrors it.
2. **New hand-seat, held-ammo and feel sets** for the kinds `grenade` and `shield`. Today's 14 kinds don't include
   them. Done after the owner's calibration bake, so the new cvars don't land mid-tuning.
3. **The command layer** for section 4's commands, which are the first real users of NETPLAY_SPEC §4. Single-player
   runs through it too.
4. **`WM_ThrownWeapon` and the grenade card.** The meshes are ready (`grenade_wm.md3`).
5. **`WM_ReturningFlight`, route, catch and mount, and the shield saw card** (`shieldsaw_wm.md3`, plus the flying disc
   meshes), and the sweep shot if chosen.
6. **The proof:**
   - a headset check for each weapon: a lob and a hurl, a painted route, a catch and a miss;
   - two instances once P2 exists.
