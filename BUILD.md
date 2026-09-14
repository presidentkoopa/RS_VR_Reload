# RS_VR_PistolTest — universal weapon interaction: complete build spec

**Self-contained.** Everything needed to do the work is in this file. It assumes
no prior knowledge of the package and references no other document.

Written against the tree as of 2026-09-12, from the source. Line numbers will
drift; function names will not. Where this document and the code disagree, the
code wins. Nothing here is a claim about what does or does not currently work at
runtime.

---

## 0. Orientation

### What this mod is

`RS_VR_PistolTest` is a VR weapon-mechanism package for a GZDoom fork
(`doomxr`, source tree `E:\DOOMWork\UZDXREMA`). It packs to
`RS_VR_PistolTest.pk3` via `build.ps1`.

It implements a **card-driven immersive reload**. A weapon opts in by shipping a
text lump (`WMCARD.txt`) naming its moving parts and how each one travels — an
axis and a distance for a slide, an axis, angle and pivot for a hinge. There is
no per-weapon mechanism code: grabbing, driving, dropping, seating, racking and
firing are written exactly once. Two weapons ship today, one per hand, as proof
the mesh layer generalises.

Every number in a card is *measured off the mesh* by rigid fit, never taken from
animation frames. This matters and is not stylistic: on `m4a3.md3` the receiver
drifts 24.41 units from frame 8, so "play the magazine-out frames" hurls the whole
weapon sideways. On `pistolet.md3` the second magazine piece collapses to a point
five frames before the first.

### File inventory

| File | What |
|---|---|
| `zscript/wm/log.zs` | `WM_Log`, levels 0-4, said-once and every-N helpers |
| `zscript/wm/space.zs` | `WM_Space` — the one MD3↔renderer conversion |
| `zscript/wm/card.zs` | `WM_Dof`, `WM_Part`, `WM_Card`, `WM_CardSet` |
| `zscript/wm/parser.zs` | `WM_Parser` — line-oriented, refuses per weapon |
| `zscript/wm/ammo.zs` | `WM_Ammo` — magazine, chamber and action lock kept apart |
| `zscript/wm/loose.zs` | `WM_LooseMag`, `WM_LooseRound` — both derive from `Clip` |
| `zscript/wm/fx.zs` | muzzle flash, smoke, casings, and `WM_Marker` (the wire ovals) |
| `zscript/wm/weapon.zs` | `WM_Gun`, the two weapons, the prop actors, `WM_Player` |
| `zscript/wm/rig.zs` | `WM_Rig` — one weapon in one hand, ~880 lines |
| `zscript/wm/system.zs` | `WM_System` — the interaction state machine, ~1850 lines |
| `zscript/wm/become.zs` | turns a map's sprite clip into one of our magazines |
| `zscript/wm/menu.zs` | `WM_GrabMenu` — the code-built grab-point page |
| `WMCARD.txt` | the two cards |
| `CVARINFO.txt` | 382 declared cvars |
| `MENUDEF.txt` | seven menu pages |
| `MODELDEF.txt` | which class is drawn as which mesh |
| `build.ps1` | lint, pack, verify, compile-check |

### How it works today

`WM_System` is an EventHandler. Each `WorldTick`: equip weapons into hands, bind
each hand's weapon to its card, find the grip arbiter, record hand positions for
the throw fallback; per rig spawn the prop, resolve surface names to indices, run
the automatic parts; `SetOrigin` both props to the player so the renderer does not
cull them; edge-detect buttons; `WorkHand` per hand; stow, pose, pin the hand,
publish the grip subject; drag pouches, publish proximity, draw markers, buzz,
build the HUD.

The interaction grammar is a priority chain in `WorkHand(pmo, h)`, and **hand *h*
always works `rigs[1-h]`** — the other hand's weapon. In order: guiding a
magazine into a well, carrying one, holding a part, a magazine the hands mod put
in this hand, one just released into the pouch, catching a falling one, then on a
fresh squeeze the pouch or the nearest part, then bracing.

Beneath that sit the primitives in `rig.zs`, and these are the good part — all of
them mechanism-agnostic. `StartDrive` hands a part's surfaces to the renderer to
be placed from the live controller pose every drawn frame, with `distance`
serving as both how far the part travels and how far the hand travels, so it is
glued 1:1. `StopDrive` reads back `GetModelSurfaceDrawnValue`. `Pose` writes every
part's offset and rotation every tic into the same slot the drive uses.
`PartPoint` runs grab points through `ModelPointToWorld`. `GrabDepth` tests an
oval in the weapon's own axes, and `HandPartDepth` composes it with the hand's own
reach oval.

### Engine dependencies

This package will not work on stock GZDoom. It needs, from the fork:
`SetModelSurfaceDrive` / `ClearModelSurfaceDrive` / `SetModelSurfaceDriveRotation`
/ `GetModelSurfaceDrawnValue`; `SetModelSurfaceOffset` / `SetModelSurfaceHidden`
and sixteen override slots; `FindModelSurfaceIndex` / `GetModelSurfaceCount` /
`GetModelSurfaceName`; `ModelPointToWorld` and `ModelFollowFrameToWorld`;
`FollowActor` / `FollowActorSlot` / `FollowActorOfs` / `FollowActorOfsCVar` /
`FollowHandMode` / `PlacementPrefix`; the renderer-read tuning fields
`ScaleCVar`, `ScaleAxes`, `AlphaCVar`, `VisibleCVar`, `PulseHz`, `PulseDepth`;
`AttackPos` / `OffhandPos`, `AttackVel` / `OffhandVel`, `TriggerValueMain` /
`Off`, `GripHeldMain` / `Off`, `GripClaimMain` / `Off`, `HmdPos`; the
`GRIPSUBJ_*` enum; `BT_MAINHANDDROPMAG` and `BT_OFFHANDDROPMAG`;
`level.VRHaptic` and `Level.SetVolumetricBeam`.

### Interop

Three loose contracts with **RS_WorldHands**, all reached by string so a missing
pk3 cannot refuse the load: a grip arbiter found via
`ServiceIterator.Find("RS_GripArbiterService")`, the hand actors
`RS_HandWorldMain` / `RS_HandWorldOff` found via `Object.FindClass`, and
`WM_GrabBecomeService` answering that mod's `grab.become` request. Placement mode
borrows three netevents from **RS_VRBody**. A gesture package,
**RS_GESTURES**, exists separately and is referenced only as an option in step 11.

### Building

`build.ps1` runs `menu_lint.py`, packs an allowlisted entry-by-entry zip,
verifies every expected entry landed, then runs a `doomxr -norun` compile check
from a scratch folder. `-NoCompileCheck` skips the last step. Section 7 covers
what each gate rejects.

**This package cannot have automated tests.** A headless run of the engine dies
at Vulkan init — no window, no OpenXR runtime — so no automated test can ever
observe a grab, a drive, a dropped magazine or a pose. The only machine that can
run it is the one with the headset on it, and the only thing that comes back out
is text. That is why `log.zs` is as elaborate as it is, and why every step below
has a manual verification list.

### How to use this document

Sections 1 to 4 are reference — the invariants you must not break, the target
design, the card grammar, and worked cards for six mechanisms. Read them once.

Section 5 is the work: twelve steps, in order, each with files, changes,
verification and risk.

**Steps 1 to 6 change no behaviour.** When each is finished the two existing
pistols must behave identically in the headset — same grabs, same seat, same
rack, same sounds, same HUD numbers. If anything feels different, the step is
wrong, not the baseline. That property is what makes this safe to do without an
automated test harness, and this system cannot have one: a headless run of the
engine dies at Vulkan init, so no automated test can ever observe a grab, a
drive, a dropped magazine or a pose. The only machine that can run it is the one
with the headset on it.

The mechanism that buys behaviour-neutrality is **synthesis fallback**: in steps
2 and 3, a card that declares nothing new gets the old behaviour synthesised for
it at load. `WMCARD.txt` is not touched until step 9.

---

## 1. Invariants

These are properties the existing system paid for in bugs. Every step must
preserve them. Breaking one produces something that passes review and fails in a
headset, which is this project's most expensive failure mode.

**One space conversion, in one place.** MD3 model space is x-along-barrel,
y-across, z-up. The renderer swaps y and z (`models_md3.cpp` loads every vertex
as `Set(vert->x, vert->z, vert->y)`). `WM_Space.Eng` and `WM_Space.EngRot` are
the only conversions, and `EngRot` negates the angle because a two-axis swap is a
reflection and a reflection turns a clockwise turn anticlockwise. Never convert
anywhere else; never skip the sign. This was a real bug before it was a comment —
the slide's axis is pure −X so it moved correctly by luck, and the magazine,
whose axis is mostly −Z, travelled sideways out of the gun with nothing errored.

**The drawn volume is the tested volume.** Whatever oval the marker draws must be
the oval `GrabDepth` tests, resolved in the same precedence order. If a new
tuning channel is added, both readers get it or neither does.

**Read the drawn value, never script's estimate.** Any decision about how far a
part has travelled comes from `GetModelSurfaceDrawnValue`. `StopDrive` returns it
for exactly this reason. A seat or a rack decided on script's number fires while
the part is visibly somewhere else.

**One override slot per (part, surface), for life, shared by pose and drive.**
`ClearModelSurfaceDrive` only switches the drive off — the slot still names its
surface, and the lowest slot wins. Separate slots for pose and drive is how the
slide lost the ability to lock back.

**No compile-time class references across pk3 boundaries.** A class literal, or a
name literal in a `class<T>` position, resolves at compile time against the whole
load and refuses every pk3 after this one when it misses. Use `Object.FindClass`
with a Name *variable*, or `ServiceIterator.Find` by string.

**Publish a grip subject only while actually holding.** Never on hover. A subject
published for a hand merely near a part stands the hands package down entirely
and kills its catch, pull and pass.

**ZScript identifiers are case-insensitive.** A field `rounds` and a method
`Rounds()` are the same identifier and the compiler refuses the file — fatally
and globally, taking every pk3 after it. Watch this every time a field gains an
accessor.

**Vectors by value, never through `out`.** `out Vector3` crashes the ZScript JIT
at class load in this engine.

---

## 2. The target design

### The problem

The card says what parts exist and how each can move. It never says what a
*sequence* is. Every sequence — drop, carry, guide, seat, rack — is compiled into
`WorkHand`'s priority chain and the role tests inside `Hold`, `Release`, `Cycle`
and `Racked`.

`role` is doing two jobs. It means both *what a part is* and *what the system
does with it*. `action` does not mean "the reciprocating group"; it means "the
thing `Cycle` animates, `Hold` measures against 0.6, `Release` springs home, and
`Racked` acts on." That is why a pump costs an edit to `system.zs` rather than a
text block.

### Five verbs cover every mechanism

**Cycle** — a part travels out and back; at one extreme something ejects, at the
other something chambers. A pistol slide, a pump forend, a lever, a bolt. Pump
and lever are the same verb over different DOFs, a slide and a hinge, so building
the two-stroke cycle over the DOF abstraction gets the lever gun free.

**Open / close** — a part moves to a held state and stays, and while open the
stores are reachable. A break action, a revolver crane, a slide locked back. The
distinguishing property is rest behaviour: it must not spring home.

**Swap** — detach and attach a container. Fully built today as the magazine drop
and seat.

**Load** — put one round or shell into a named store. A tube gate, break
chambers, revolver chambers, topping off. Appears in four of six mechanisms and
is the highest-leverage single build.

**Eject** — empty one slot or all into the world. Mostly a consequence of cycle
and open; only the ejector rod is a player action in its own right.

| Mechanism | Verbs | Expressible today |
|---|---|---|
| Mag + slide | cycle (auto, spring), swap | all of it |
| Pump | cycle (manual, hand-return), load, eject | forend as a slide DOF |
| Lever | cycle (manual, hinge), load, eject | lever as a hinge DOF |
| Break | open/close, load ×N, eject all | barrels and lever as hinge DOFs |
| Revolver | open/close, eject all, load ×N | crane and rod as DOFs |
| Bolt | cycle (sequential DOF), swap | swap only |

The bolt handle is the only entry needing new kinematics rather than new grammar.

### Ammunition becomes named stores

Two kinds. A **counted** store holds fungible rounds in a number — a box
magazine, a tube, a belt, a cell — with a capacity, and may or may not detach. A
**slotted** store holds fixed positions each empty, live or spent — a chamber
(one slot), a revolver cylinder (six, indexed), a double's barrels (two).

Slotted is what makes a revolver possible: a cylinder with three live and three
spent is not a count.

Everything the current model does falls out of a counted detachable `mag` plus a
slotted one-slot `chamber`. Action lock stops being a boolean and becomes a
property of a cycle — *hold at full travel when the feed store is empty* — which
generalises correctly, because a pump simply does not declare it.

---

## 3. Card grammar reference

Same shape as today: lowercase `key = value`, blocks closed by `end`, `#`
comments, case-insensitive keys, an unknown key refuses that weapon and only that
weapon with the lump and line named. All points and axes are MD3 model space;
grab radii are map units.

### Card level

Unchanged from today: `hand`, `prop`, `model`, `skin`, `capacity`, `magfamily`,
`muzzle`, `barrel`, `ejectport`, `ejectdir`, `magmodel`, `magskin`, `magscale`,
`magcenter`, `roundmodel`, `roundskin`, `roundscale`, and the sound keys.

New:

```
mechanism = pump        # archetype supplying defaults; optional
hands     = 2           # this weapon occupies both hands; default 1
```

### Stores

```
store mag
  kind     = counted
  capacity = 15
  detach   = yes
  family   = pistol
end

store cylinder
  kind    = slotted
  slots   = 6
  indexed = yes
  advance = onshot
end
```

### Parts

Unchanged: `surface` (repeatable), `model`, `grab`, `grabradius`, `grabsize`,
`subject`, `take`, and the `dof` block (`kind`, `axis`, `distance`, `degrees`,
`pivot`, `detach`, `rest`, `twist`, `twistaxis`).

`role` keeps only descriptive values after step 4: `trigger`, `hammer`,
`hidden`, `support`, or blank.

New:

```
follows = forend        # this part's value tracks that part's
dof2 ... end            # a second, sequential stage (step 12; built -- see "Two-stage parts: `dof2`" below)
```

`subject` vocabulary, which already exists and maps to the engine's `GRIPSUBJ_*`:
`slide | forend | foregrip | magazine | shell | round | support`.

### The five verb blocks

```
cycle rack
  part     = slide
  outat    = 0.60          # counts as worked past here
  apex     = 0.95          # where the hand feels it stop
  onout    = eject
  from     = chamber       # what the eject empties
  onhome   = feed
  feed     = mag           # where the fed round comes from
  into     = chamber
  return   = spring        # spring | hand | stay
  holdopen = whenempty     # the lockback; omit and it never holds
  auto     = onshot        # omit for a manual action
end

open break
  part    = barrels
  latch   = toplever       # optional: must be past its own threshold first
  openat  = 0.90
  rest    = stay
  onopen  = ejectall
  from    = barrels
  close   = flick          # optional: a gesture closes it (see step 11)
end

swap magwell
  part     = magazine
  store    = mag
  seatat   = 0.25
  button   = yes           # the drop-mag button works this
  handtake = no
end

load gate
  into    = tube
  slot    = next           # slotted targets: an index, or `next`
  at      = 1.2, 0.0, -2.4
  size    = 2.5, 2.0, 2.0
  subject = shell
  needs   = open:break     # optional gate on an open verb's state
end

eject rod
  part  = ejectorrod
  at    = 0.85
  from  = cylinder
  all   = yes
  needs = open:crane
end
```

`return = spring | hand | stay` is the fix for the constant in `Release()`.
Spring is today's behaviour. Hand means the player pushes it home. Stay means it
holds wherever it was left. Without this key, no mechanism that stays open can
exist.

### Keys added for the revolvers (2026-09-13, built and compile-checked)

All additive and default-off: a card that states none of them runs exactly as
before. `archetype breaktop_revolver` and `archetype swingout_revolver` in
`WMCARD.txt` use them; RS_VR_Weapons' Moonlight, Sunset and Cola cards are the
first users.

```
# card
opensound  = "..."          # an open verb opening; silent unless stated
closesound = "..."          # ...and shutting

# part
cock = trigger              # a hammer: follows the finger back, falls on the shot
                            # or the click (double action). `action`, the default,
                            # is today's: cocked by the action, falls on the shot.
roundsurface = python.008, cylinder, 0
                            # one more surface of this part, moving with it (same
                            # drive), drawn only while that slot holds a case, live
                            # or spent. `any` for any slot. Repeatable.

# open
closeat = 0.05              # shut again only back to here (default 0.05). Between
                            # closeat and openat it is neither -- and does not fire.
                            # `rest` is stay or spring; `hand` is refused.
onopen  = ejectall          # NOW ACTED ON: opening throws out every case in `from`,
from    = cylinder          # live rounds as WM_LooseRound, spent as brass, from the
                            # card's ejectport/ejectdir CARRIED by the open part.

# load
subject = loader            # takes a LOADER (a speedloader: one WM_LooseMag holding
                            # several rounds, drawn as the card's magmodel) and fills
                            # every empty slot it can at once; one round fills one.
rides   = barrel            # the zone is `at` with that part at rest and goes where
                            # the part goes (a cylinder face tipping with the barrel).

# eject
by = muzzleup               # no part: the gun pointed up past `at` (the sine of the
                            # bore's elevation) while `needs` holds open throws every
                            # case out, once a tilt. `by = hand` (the default) is a
                            # part worked past `at`, once a stroke -- also acted on now.
```

What else the machinery does for them, with no key: a hand-taken **hinge** part
is driven with `SetModelSurfaceDriveHinge` (read by the hand's angle round the
pin); a gun with no auto cycle and a verb that ejects keeps its fired case in the
chamber (`WM_Card.KeepsCaseOnShot`); a chamber store that is `indexed` with
`advance = onshot` turns one position per shot **and per in-battery click**, and
back to slot 0 when it is emptied; an open verb not shut puts the gun out of
battery; the pouch hands a loader to a gun whose load verb takes one
(`WM_Card.PouchGivesLoader`); an emptied loader drops (`wm_loader_spent_drops`)
or vanishes; a part with `subject = foregrip` seats the hand on its own sets,
`wm_main_foregrip` / `wm_off_foregrip`; a card that declares stores but no
counted one gets an empty placeholder magazine instead of a synthesised
detachable one (so the drop-mag button does nothing on a revolver).

### The break-action double and full auto (2026-09-13, built and compile-checked)

**No new card key.** `archetype breakaction` in `WMCARD.txt` is written entirely in
the keys above: `open break` (part `barrels`, `onopen = ejectall from = chambers`,
`rest = stay`) and ONE `load breech` (`into = chambers`, `slot = next`, `subject =
shell`, `rides = barrels`, `needs = open:break`). One zone over both breeches rather
than a `load` per barrel: two ovals a map unit apart overlap, and a shell let go of
between them would pick a barrel by a hair. `slot = next` fills slot 0 then slot 1.
Each card states `load breech` / `at`, `dir`. RS_VR_Weapons' `WM_SSG` is the first
user.

**Two new weapon-class properties** (`weapon.zs`, a WM_Gun subclass's Default block).
Both default off, and a class that sets neither fires exactly as before:

```
WM_Gun.ChambersPerPull N   # one pull fires up to N LIVE chambers at once (at most 8).
                           # 0/1 (unset) = one, today's pull. Pellets are ShotPellets
                           # PER CHAMBER FIRED: a double says ShotPellets 10 +
                           # ChambersPerPull 2 -> 20 with both barrels loaded, 10 with
                           # one. Counted over the chamber store (the first slotted
                           # store), in slot order from the selected slot. wm_verbs on
                           # only; the old path fires one.
WM_Gun.FullAuto true       # held, the trigger fires again every FireTics while the
                           # chamber and verbs allow; the first empty pull clicks once
                           # and the trigger must come back. Unset = one pull, one shot.
```

How they are wired, so nothing else can drift:

- `WM_TryFire` asks `WM_System.CanFire(pn, h, ChambersEachPull())` -- with more than
  one it fires while ANY chamber is live, not only the selected one -- then
  `ChambersToFire(pn, h, most)` for how many, fires `PelletsPerShot() x chambers`, and
  hands the same count to `OnShot(pn, h, chambers)` -> `WM_Rig.OnShot` ->
  `ShotByVerbs`, which spends that many with `WM_Ammo.DischargeChambers`. A class of
  one never calls either new method: `CanFire`'s third argument defaults to 1 and
  `Discharge` runs as it did.
- `FullAuto` is one zero-tic state at the end of `Fire` (`WM_HoldFire`): trigger held
  (`WM_TriggerDown`, the owner's own player cmd -- netplay-safe), alive, no weapon
  change pending for this hand (A_ReFire's test) -> back to `Fire`; otherwise on to
  `Ready`, which for every other class is exactly the old `Goto Ready`. No gun sets it
  yet; the weapons lane decides per gun.
- A click on a gun with an open verb and no cycle (a break action) logs "open it, load,
  shut it" instead of "work the action".

### Two-stage parts: `dof2` (2026-09-13, step 12)

Additive and default-off. A part with no `dof2` block runs exactly the single-stage
code it always did -- every consumer asks `part.dof2` first -- so the pistols'
slides, the pump's forend, the revolvers' hinges and the SSG's barrels are
untouched. First intended users: an SMG charging handle that folds out 90 degrees
and then pulls back, and the bolt action (lift about 137 degrees, then draw back).

```
part charginghandle
  role = action
  subject = slide
  surface = charginghandle
  grab = ...
  grabradius = ...
  dof                     # STAGE ONE: driven exactly as any dof is today
    kind = hinge
    axis = 0, 0, 1
    degrees = 90
    pivot = 9.91, -1.18, 0
  end
  dof2                    # STAGE TWO: the same surfaces, the same drive slots
    kind = slide          # slide (the default) | hinge
    axis = -1, 0, 0       # required; normalised on the way in
    distance = 5          # slide: model units. A hinge takes degrees (non-zero,
                          # under 180 either way) and pivot instead.
    split = 0.5           # the share of the pull stage one gets; default 0.5,
                          # 0.001..0.999
  end
end
```

**dof2's axis and pivot** are in the gun's model space, where the part stands once
stage one is complete -- the frame `SetModelSurfaceDriveStage` reads them in. A
handle that folds out and then pulls straight back has `axis = -1, 0, 0` however it
folded.

**Refused at the part's `end`, with the line**, because the engine would otherwise
refuse the stage at the grab and the part would silently stay one stage in the hand:
a dof2 with no axis, a zero distance or degrees, a hinge of 180 degrees or more, a
split outside 0.001..0.999, or a stage one that is not itself a drive that moves (no
axis, a zero slide, a hinge of 180 or more). Also refused: `detach`, `rest`, `twist`,
`twistaxis` inside `dof2` (they are the part's, on its `dof`), an unknown `kind`, a
second `dof2`, `dof2` opened inside `dof`, and words after `dof2` on its line.

**One value.** The part's value is ONE drawn value 0..1 over the whole path.
`outat`, `apex`, `homeat`, `openat`, `at`, `detach` and the rack decision read that
combined value exactly as they read a single-stage part's. On the handle above,
`outat = 0.6` means folded out and a fifth of the way back: pick thresholds on the
combined scale.

**The pose rule** (`WM_Rig.TwoStagePoint`, `TwoStageRotation`). At value v and split
S, stage one is at `min(v / S, 1)` and stage two at `clamp((v - S) / (1 - S), 0, 1)`,
applied on top of stage one: `x' = R2 (R1 x + o1) + o2`, turn `q2 q1`. That is the
engine's `SurfaceStagedDrivePose` in script, so the part at rest, locked open,
springing home and in the hand agree at every value. `PartOffset`, `PartRotation`,
`PartPointRaw` (the grab oval rides the part through both stages) and `CarriedBy` all
route a dof2 part through it. `WM_Rig.Pose` is the only place a part is posed, so no
preview pose exists apart from it.

**The hand** (`WM_Rig.DriveSecondStage`). Stage one is driven as today
(`SetModelSurfaceDrive`, or `SetModelSurfaceDriveHinge` for a hinge), then
`SetModelSurfaceDriveStage` on the same slots with stage two's kind, axis, amount (a
hinge's degrees negated, as stage one's are), pivot and split. The engine follows the
hand along the true piecewise path, at display rate: a hinge stage by the hand's
ANGLE round the pin (the part turns exactly as far as the hand swings, at any grip
radius), a slide stage by the hand's travel along its axis. The track is L-shaped:
stage two cannot move until stage one is complete, stage one is locked while stage
two is under way, pushing back past the split returns to stage one, and a pull that
crosses the corner inside one frame is cut at the corner, so nothing snaps. A card
`handseat` rides both stages, because the hand follower reads the same staged pose.
There is no script-side handoff and so no seam.

**Logs.** Once per bind, per two-stage part: `two-stage part <id> -- dof <stage one>,
then dof2 <kind, amount, axis[, pivot]>, split S`. Once per crossing, either way, held
or not: `<hand> gun: <id> crossed its split S into its dof2` / `back into its dof --
value V, in the hand` / `not held`. The engine adds its own `[DRIVESTAGE]` line when a
grab sets the stage.

---

## 4. Worked cards

### The existing pistol, unchanged in behaviour

The important one — express what already works and the headset should not be able
to tell the difference.

```
weapon "WM_M4A3"
  hand = main   prop = "WM_PropM4A3"
  model = "models" "m4a3.md3"   skin = "models" "m4a3.png"
  muzzle = 18.99, -0.07, 4.27   barrel = 1, 0, 0
  ejectport = 2.0, -1.4, 5.3    ejectdir = -0.3, -0.9, 0.4
end

store mag      kind = counted  capacity = 15  detach = yes  family = pistol end
store chamber  kind = slotted  slots = 1 end

part slide
  subject = slide   surface = m4a3_slide
  grab = -6.09, 0.09, 6.20   grabradius = 3.0
  dof kind = slide  axis = -1, 0, 0  distance = 6.784  detach = 0.95 end
end

part magazine
  subject = magazine   surface = m4a3_magazine
  grab = -10.5, 0.0, -12.0   grabradius = 3.0
  dof kind = slide  axis = -0.354, 0, -0.935  distance = 17.0  detach = 0.9 end
end

cycle rack
  part = slide   outat = 0.60   apex = 0.95
  onout = eject  from = chamber
  onhome = feed  feed = mag  into = chamber
  return = spring   holdopen = whenempty   auto = onshot
end

swap magwell
  part = magazine  store = mag  seatat = 0.25  button = yes  handtake = no
end
```

### Pump shotgun

```
hands = 2

store tube     kind = counted  capacity = 5  detach = no end
store chamber  kind = slotted  slots = 1 end

part forend
  subject = forend   surface = forend
  grab = -2.0, 0.0, -1.5   grabsize = 3.5, 2.0, 2.0
  dof kind = slide  axis = -1, 0, 0  distance = 4.2 end
end

part bolt
  surface = bolt   follows = forend
  dof kind = slide  axis = -1, 0, 0  distance = 4.2 end
end

cycle pump
  part = forend   outat = 0.85   apex = 0.95
  onout = eject   from = chamber
  onhome = feed   feed = tube  into = chamber
  return = hand
end

load gate
  into = tube   at = 1.2, 0.0, -2.4   size = 2.5, 2.0, 2.0   subject = shell
end
```

Three keys are the entire difference from the pistol: no `auto`, no `holdopen`,
`return = hand`.

### Lever action

The pump with a hinge. Same verb, different DOF — this card costs nothing extra
to support if the interpreter is written over the DOF abstraction.

```
part lever
  subject = foregrip   surface = lever
  grab = -3.0, 0.0, -4.0   grabsize = 2.0, 1.5, 4.0
  dof kind = hinge  axis = 0, 1, 0  degrees = 55.0  pivot = -2.1, 0, -0.6 end
end

cycle throw
  part = lever   outat = 0.80
  onout = eject  from = chamber
  onhome = feed  feed = tube  into = chamber
  return = hand
end
```

### Break-action double

Two `load` blocks naming the same store and different slots is what a
non-singleton part model buys, and it is impossible today.

```
hands = 2

store barrels  kind = slotted  slots = 2 end

part toplever
  subject = slide   surface = toplever
  grab = -4.0, 0.0, 2.5   grabsize = 1.5, 2.0, 1.5
  dof kind = hinge  axis = 0, 0, 1  degrees = 32.0  pivot = -4.0, 0, 1.8 end
end

part barrelgroup
  subject = forend   surface = barrels
  grab = 6.0, 0.0, -1.0   grabsize = 5.0, 2.5, 2.5
  dof kind = hinge  axis = 0, 1, 0  degrees = 28.0  pivot = -1.4, 0, 0.2 end
end

open break
  part = barrelgroup   latch = toplever   openat = 0.90
  rest = stay   onopen = ejectall   from = barrels
end

load left
  into = barrels  slot = 0  at = 0.5, -0.7, 0.4  size = 2, 1.5, 1.5
  subject = shell  needs = open:break
end

load right
  into = barrels  slot = 1  at = 0.5,  0.7, 0.4  size = 2, 1.5, 1.5
  subject = shell  needs = open:break
end
```

### Revolver

```
store cylinder  kind = slotted  slots = 6  indexed = yes  advance = onshot end

part crane
  subject = foregrip   surface = cylinder_crane
  grab = -1.0, -1.2, 0.0   grabsize = 2.0, 2.5, 2.0
  dof kind = hinge  axis = 0, 0, 1  degrees = 45.0  pivot = -1.8, -0.4, 0 end
end

part ejectorrod
  subject = slide   surface = ejector
  grab = 4.5, -1.2, 0.0   grabsize = 1.5, 1.5, 1.5
  dof kind = slide  axis = -1, 0, 0  distance = 2.4 end
end

open crane
  part = crane   latch = cylinderlatch   openat = 0.85   rest = stay
end

eject rod
  part = ejectorrod  at = 0.85  from = cylinder  all = yes  needs = open:crane
end

load chamber
  into = cylinder  slot = next  at = -1.0, -1.2, 0.0
  size = 2.5, 2.5, 2.5  subject = round  needs = open:crane
end
```

`slot = next` finds the first empty chamber, which is what fumbling rounds into a
cylinder actually is.

### Bolt action

```
part bolthandle
  subject = slide   surface = bolt
  grab = -3.2, 1.1, 1.4   grabsize = 1.5, 2.0, 2.0
  dof   kind = hinge  axis = 1, 0, 0  degrees = 70.0  pivot = -3.0, 0, 0 end
  dof2  kind = slide  axis = -1, 0, 0  distance = 5.6 end
end
```

---

## 5. The twelve steps

### Step 1 — one state per hand

**Why.** `WM_System` carries eighteen parallel per-hand arrays. Five are mutually
exclusive modes — `holding`, `carried`, `guidingOn`, `foreign`, `bracing` — kept
exclusive only by `WorkHand`'s priority chain returning early. Every verb added
later multiplies the combinations.

**Files.** New `zscript/wm/hand.zs`, included in `zscript.txt` after `loose.zs`
and before `system.zs`. Edits to `system.zs` only.

```
class WM_HandState play
{
    const FREE = 0, ONPART = 1, CARRY = 2, GUIDE = 3, FOREIGN = 4, BRACE = 5;

    int          mode;
    int          part;       // ONPART: index into the worked card's parts
    WM_LooseMag  mag;        // CARRY, GUIDE, FOREIGN
    bool         ours;       // GUIDE: it was ours before the guide began
    bool         preview;    // CARRY: a tuning preview, not a real carry
    bool         leftPouch;  // CARRY: has left the pouch since being drawn

    void Clear() { mode = FREE; part = -1; mag = null; ours = false; preview = false; leftPouch = false; }

    void OnPart(int i)                        { Clear(); mode = ONPART;  part = i; }
    void Carrying(WM_LooseMag m)              { Clear(); mode = CARRY;   mag = m; }
    void Guiding(WM_LooseMag m, bool wasOurs) { Clear(); mode = GUIDE;   mag = m; ours = wasOurs; }
    void Foreigner(WM_LooseMag m)             { Clear(); mode = FOREIGN; mag = m; }
    void Bracing()                            { Clear(); mode = BRACE; }

    bool IsFree()  const { return mode == FREE; }
    bool HasHand() const { return mode != FREE; }
    WM_LooseMag Held() const { return (mode == CARRY || mode == GUIDE || mode == FOREIGN) ? mag : null; }
}
```

`Clear()` inside every setter is the point: it makes illegal combinations
unrepresentable rather than merely unreached.

**Fields.** Delete `holding[2]`, `carried[2]`, `guiding[2]`, `guidingOn[2]`,
`guidingOurs[2]`, `foreign[2]`, `bracing[2]`, `carryLeftPouch[2]`, `preview[2]`.
Add `private WM_HandState hstate[2];`, allocated in `WorldTick`'s rig-ensure
block. Keep `lastForeign[2]`, `gripArm[2]`, `pinned[2]`, `handActors[2]`,
`bonesAsked[2]`, `lastReach[2]`, `placingSite[2]`, `palmFacing[2]`,
`lastGripHud[2]`, `trail[8]` — incidental, not modes.

| Old | New |
|---|---|
| `holding[h] >= 0` | `hstate[h].mode == WM_HandState.ONPART` |
| `holding[h]` as an index | `hstate[h].part` |
| `holding[h] = idx` | `hstate[h].OnPart(idx)` |
| `holding[h] = -1` | `hstate[h].Clear()` |
| `carried[h]` | `hstate[h].mode == CARRY ? hstate[h].mag : null` |
| `carried[h] = m` | `hstate[h].Carrying(m)` |
| `carried[h] = null` | `hstate[h].Clear()` |
| `guidingOn[h]` | `hstate[h].mode == GUIDE` |
| `guiding[h]` | `hstate[h].mag` while GUIDE |
| `guidingOurs[h]` | `hstate[h].ours` |
| `foreign[h]` | `hstate[h].mode == FOREIGN ? hstate[h].mag : null` |
| `bracing[h]` | `hstate[h].mode == BRACE` |
| `preview[h]` | `hstate[h].preview` |
| `carryLeftPouch[h]` | `hstate[h].leftPouch` |

**Call sites.** `WorldLoaded` (~219), `LetGoOf` (422), `ButtonDrop` (456),
`WorkHand` (491), `CatchFalling` (586), `Take` (669), `Hold` (681), `Release`
(713), `PullOut` (749), `Carry` (780), `DrawFromPouch` (840), `BeginGuide` (901),
`EndGuide` (919), `Guide` (926), `PutAway` (983), `PinHand` (1021), `PoseHand`
(1152), `PublishNear` (1441), `PreviewMags` (1472), `ReachBuzz` (1575),
`BuildHud` (1615), `Dump` (1788).

**Four that need care.**

`WorkHand` becomes `switch (hstate[h].mode)`, with `FREE` carrying the pouch /
catch / take / brace logic now at the bottom. **The order of the free-hand tests
is load-bearing** — pouch-draw before nearest-part, and a squeeze takes a part
before an open hand braces. The comment at 558 records the bug from the other
order: the support point sits about three units from the magazine floorplate with
both reaches three wide, so over most of the magazine's own volume a squeeze
braced instead of taking it, while the HUD said "squeeze to take it".

`EndGuide` mostly disappears into `Clear()`. But `Guide`'s let-go path (962-978)
reassigns the magazine to `carried[h]` before releasing, so it becomes
`Carrying(m)` then possibly `Clear()`. That block has four exits; read them all.

`PutAway`'s busy test (986) is exactly "not FREE" — becomes
`hstate[r].HasHand()`. The index is `r`, the working hand, not the rig. Correct,
and must stay.

`PoseHand`'s early return (1154) and its subject ladder both become switches on
the same enum.

**Verify.** Both weapons. Drop by button, catch in the other hand, pouch it, draw
a fresh one, seat it, rack. Then drop a magazine by button while the other hand
is on the slide. `netevent wm_dump` and confirm the state lines read as before.
No HUD wording should change.

**Risk.** Low. Pure refactor, no new data, no cvars touched.

---

### Step 2 — stores replace `WM_Ammo`'s fields

**Why.** Four booleans and an int describe one mechanism.

**Files.** New `zscript/wm/store.zs`, included after `card.zs` and before
`ammo.zs`. Edits to `card.zs`, `parser.zs`, `ammo.zs`.

```
class WM_Store play
{
    const COUNTED = 0, SLOTTED = 1;
    const SLOT_EMPTY = 0, SLOT_LIVE = 1, SLOT_SPENT = 2;

    String     id;
    int        kind;
    int        capacity;       // COUNTED
    bool       detach;
    String     family;         // interchange family, when detachable
    bool       indexed;        // SLOTTED: has a selected position that advances
    bool       advanceOnShot;

    int        rounds;         // COUNTED
    Array<int> slots;          // SLOTTED
    int        index;          // SLOTTED + indexed
    bool       attached;       // detachable: is it in

    void InitCounted(String i, int cap, bool det, String fam);
    void InitSlotted(String i, int n, bool idx, bool adv);

    int  Live() const;         // COUNTED: rounds. SLOTTED: count of SLOT_LIVE.
    bool IsEmpty() const;
    bool IsFull()  const;

    int  Take(int n);          // COUNTED: remove up to n, return how many came out
    int  Put(int n);           // COUNTED: add up to capacity, return the leftover
    void Fill();

    int  Selected() const;     // SLOTTED: index, or 0 when not indexed
    int  SlotAt(int i) const;
    void SetSlot(int i, int v);
    int  FirstEmpty() const;   // for `slot = next`
    int  FirstLive() const;
    void Advance();            // SLOTTED + indexed
    int  EmptyAll();           // SLOTTED: clear every slot, return how many were live

    bool Detached() const { return detach && !attached; }
}
```

**`WM_Ammo` becomes a facade.** Do not change its public signatures here —
`WM_Rig`, `WM_System` and `WM_Gun` all call it, and rewriting those is step 3.
Keep `Init`, `Fire`, `Cycle`, `ReleaseLock`, `CanFire`, `Total`, `TakeMagazine`,
`SeatMagazine`, implemented over two stores.

The four public fields (`rounds`, `chambered`, `magIn`, `actionLock`) have about
thirty read sites. Either mirror them — keep the plain fields, re-derive after
every store mutation, zero call-site churn, no collision risk — or replace with
accessors named so they cannot collide (`RoundsIn()`, `IsChambered()`,
`HasMag()`). **Recommend mirroring for this step**, dropping the mirror in step 3
when the call sites are being rewritten anyway. Remember that `rounds` and
`Rounds()` are the same identifier to this compiler.

`actionLock` stays a plain field; step 3 moves it onto the cycle verb.

**Parser.** `WM_Card` gains `Array<WM_Store> stores` and
`WM_Store FindStore(String id)`. `WM_Parser` gains
`StoreKey(WM_Store s, String key, String val)` beside `CardKey` / `PartKey` /
`DofKey`, plus a `curStore` local and a third arm in `ParseAll`'s `end` handler.
Keep the refusal semantics.

**Synthesis.** If a card declares no stores, `WM_Card` synthesises a COUNTED
`mag` of `capacity`, detachable, family `FamilyOfMags()`, plus a SLOTTED one-slot
`chamber`. `WMCARD.txt` needs no edits.

**Verify.** Step 1's checklist, plus: fire to lockback and confirm the slide
holds back; seat a fresh magazine and rack; confirm 15+1 on the HUD before and
after; rack a loaded weapon and confirm one live round leaves the port.

**Risk.** Low-moderate. The mirror is the fragile part — a mutation path that
forgets to re-derive gives a HUD that disagrees with reality.

---

### Step 3 — verbs and the interpreter

The pivot. Larger than 1 and 2 together. Only once both are proven.

**Files.** New `zscript/wm/verb.zs` after `store.zs`. Edits to `card.zs`,
`parser.zs`, `rig.zs`, `system.zs`.

```
class WM_Verb play
{
    const CYCLE = 0, OPEN = 1, SWAP = 2, LOAD = 3, EJECT = 4;
    const RET_SPRING = 0, RET_HAND = 1, RET_STAY = 2;

    int     kind;
    String  id;

    String  partId;    int partIndex;     // resolved at Bind
    String  latchId;   int latchIndex;    // OPEN

    double  outAt, apex, openAt, seatAt, at;
    int     ret;
    bool    autoOnShot;                   // CYCLE
    bool    holdOpenWhenEmpty;            // CYCLE
    bool    all;                          // EJECT

    String  fromStore, feedStore, intoStore;

    int     slot;      bool slotNext;     // LOAD
    String  subject;                      // LOAD
    Vector3 loadAt, loadSize;             // LOAD

    String  needsOpen;                    // gate: an OPEN verb's id
    bool    button, handTake;             // SWAP
}
```

`WM_Card` gains `Array<WM_Verb> verbs`, `WM_Verb VerbForPart(int partIndex)`,
`WM_Verb FindVerb(String id)`. `WM_Rig.Bind` resolves `partId` and `latchId` to
indices alongside its slot reservation, logging an error per verb naming a part
the card lacks.

**Live OPEN state goes on the rig, not the verb.** Cards are shared objects and a
verb is card data. `WM_Card.parts[i].value` is already shared mutable state,
which works only because one card binds to one hand at a time — do not add more.
Keep an `Array<bool> openState` on `WM_Rig`, indexed by verb.

**What it replaces.**

`WM_Rig.Cycle()` (630) — becomes "advance any CYCLE verb with `autoOnShot`". The
lockback re-assert at 647 and 651 becomes `holdOpenWhenEmpty`.

`WM_Rig.Racked()` (822) — splits into the CYCLE verb's `onout` and `onhome`
transfers against named stores.

`WM_System.Hold()` (681) — the `role == "action"` thresholds at 687 and 695 read
`outAt` and `apex` from the verb governing the held part. The `role == "feed"`
pull-out at 704 becomes the SWAP verb's detach threshold.

`WM_System.Release()` (713) — the role ladder at 723-743 becomes a switch on the
governing verb's kind, and `part.value = ammo.actionLock ? 1.0 : 0.0` becomes a
read of `ret`. `RET_SPRING` reproduces today exactly.

`WM_System.BeginGuide` / `Guide` (901, 926) — `seatAt` from the SWAP verb, with
`wm_seat_at` as the fallback when the card is silent.

**Synthesis.** No verbs declared, synthesise from today's constants: a CYCLE on
the `role = action` part (`outAt` 0.60, `apex` 0.95, `ret` RET_SPRING,
`autoOnShot`, `holdOpenWhenEmpty`, from `chamber`, feed `mag`, into `chamber`)
and a SWAP on the `role = feed` part (`seatAt` from `wm_seat_at`, `button` true,
`handTake` from the part's flag).

**Verify.** The full loop on both weapons. Specifically: a **fast** rack must
still rack. The `pastBack` memory (set at 687, read at 729) exists because a fast
pull is already on its way home by the tic you release; lose it and fast racks
silently stop working while slow ones still do — a miserable bug to chase. And a
short pull must still spring back without racking.

**Risk.** High. A subtle threshold change here is invisible in review and obvious
in a headset. Consider a cvar switching between the old path and the interpreter
for one build, so a regression can be A/B'd rather than bisected.

---

### Step 4 — parts by id, `role` demoted

**Why.** `FindRole` and `FindRoleIndex` return the first match and every
mechanism consumer uses them. That singleton is what makes two chambers, six
chambers, or a tube-plus-chamber impossible.

**What changes.** `WM_Part.role` keeps only `trigger`, `hammer`, `hidden`,
`support`, or blank. It survives as a **parse-time legacy hint** — step 3's
synthesis reads `role = action` and `role = feed` for old cards — and that is the
only place it may be consulted after this step.

`WM_Card` gains `int FindPartIndex(String id)` and `bool PartIsWorkable(int i)`
(true when any verb names the part, or its role is `support`).

Rewrite through verbs: `rig.WellPointRaw` / `WellPoint` / `SeatedPoint` (469,
477, 484) take the SWAP verb's part index; `rig.Bind` (106-109) takes initial
`present` and `value` from the governing verb; `rig.DropMagazine` (778) and
`Seat` (811) take the SWAP verb's part. `system.NearestPart` (648) — the filter
`role != "action" && role != "feed" && role != "support"` becomes
`!card.PartIsWorkable(i)`; same for `DrawMarkers` (1519), `BuildHud` (1670),
`rig.Dump` (860), and `menu.zs` `Build` (103) so new part kinds get tuning pages.

Leave `system.PinHand` (1042, 1058) alone; step 6 rewrites it.

**Verify.** Behaviour-neutral. Same checklist, plus confirm the grab-points menu
still lists slide and magazine by name.

**Risk.** Low. Mostly deletion.

---

### Step 5 — tuning into the card, sliders become a scratch pad

**Why.** `PartTag()` builds `wm_gp_m3_*` from `hand == 0 ? "m" : "o"` plus the
part *index*. That is "main hand, part 3", not "M4A3, slide". Put a different
weapon in that hand and it inherits every tuned number; reorder parts in a card
and the tuning shifts under them.

The fix is forced by the medium: CVARINFO is static text, so
`wm_gp_<anyweaponclass>_<partid>_*` cannot be pre-declared. Keying tuning to the
weapon **requires** moving baked values into the card. One change, two halves.

It also lifts the ceiling — `SEL_PER_GUN = 8` and `WM_GrabMenu`'s two `i < 8`
loops mean part nine gets no sliders and no edit marker, at about sixteen cvars
per slot. 259 of the 382 declarations are this one system.

**Files.** `CVARINFO.txt`, `MENUDEF.txt`, `menu.zs`, `rig.zs`, `system.zs`,
`fx.zs`.

**New shape.** One scratch set applying only to the part selected by
`wm_tune_gun` and `wm_tune_part`:

```
wm_tune_ofs_x / _y / _z            the nudge
wm_tune_sh_scale_x / _y / _z       the oval's three axes
wm_tune_sh_ofs_x / _y / _z         placement-set suffixes the renderer needs
wm_tune_sh_yaw / _pitch / _roll
wm_tune_sh_scale
wm_tune_r                          reach as a ball
wm_tune_sel                        gate for the breathing marker
wm_tune_name                       "role|id" for the page to read
```

Delete all 259 `wm_gp_*`, all sixteen `wm_gp_sel_*`, all sixteen `wm_gp_name_*`,
and `selMark[16]` / `selNamed[16]` in `system.zs`.

**Runtime.** `rig.PartTag(int)` disappears. `GrabModel(i, part)` returns
`part.grabAt + (i is selected ? scratch offset : (0,0,0))`. Same for `GrabAxes` /
`DrawAxes` — only the selected part reads the scratch multipliers.
`RadiusCVar(i)` returns `'wm_tune_r'` for the selected part, `'None'` otherwise.
`WM_Marker.PlaceInFrame`'s `ownCVar` and `shapePrefix` become `'wm_tune'` and
`'wm_tune_sh'` for the selected part, `'None'` for the rest. `MarkEdited` (1252)
collapses to one marker.

**Bake.** A `wm_bake` netevent printing the selected weapon's complete card block
— current `grab`, `grabsize`, `grabradius` with the scratch folded in — to the
console with `PRINT_LOW | PRINT_NONOTIFY`, so it lands in `log-debug.txt` for
pasting. ZScript cannot write files; printing is the whole mechanism. Add it to
`WM_Options`' test-controls block beside `wm_dump`.

**The bake ledger (built 2026-09-13, after step 5 compiled).** Printing alone did not keep the lines.
- The engine opens `doomxr-log.txt` and `log-debug.txt` fresh on every launch, so a bake nobody copied out
  was gone at the next launch.
- Picking another part auto-bakes the old one and clears its nudge, so that print was the only copy.

So every bake is also kept as a string cvar, `wm_bake_ledger_00`..`_63` (`nosave`), one entry per gun class
and part: `WM_M4A3|part slide|grab = ...|grabradius = ...` (`WM_BakeLedger`, menu.zs).
- A re-bake of the same part replaces its entry. The ini is saved at once (`CVar.SaveConfig`, the same
  write as quitting), so a crash keeps it too.
- Only the machine that sent the bake keeps it (`e.Player == consoleplayer`).
- `E:/DOOMWork/tools/bake_defaults.py --ledger --cards <WMCARD>` prints each entry as a card block and says
  whether the card already has those numbers. The grab-point page clears the ledger, on a second press.

**Menu.** `WM_GrabMenu` keeps its part picker but the sliders now point at one
scratch set, so `Build()` no longer rebuilds rows on selection change — only the
title and the picker highlight. That removes the `WM_RowsBegin` cut-and-rebuild
machinery entirely.

**Lint.** E1 and E2 fire loudly if CVARINFO and MENUDEF do not change in the same
commit. E4 requires the new `wm_tune_sh` placement set to carry every suffix. E5
requires each slider's range to include its default. The 259 dead names linger in
the player's `doomxr.ini` harmlessly; the new names are new, so no saved value
can outrank them.

**Verify.** Select the slide, drag every slider, confirm the oval moves live with
the menu open. Select the magazine and confirm the slide's oval snaps back to its
card value rather than following. Bake, paste into `WMCARD.txt`, restart, confirm
the oval is where you left it with every slider at zero.

**Risk.** Moderate. Largest surface area, but failures are visible immediately.

---

### Step 6 — the hand seat reads `subject`

**Why.** `PinHand` computes the hold as `(part.role == "feed") ? "mag" : "slide"`
— three literal shapes, six placement prefixes — while the card already carries
`subject` with seven values and `SubjectFor` already maps it to `GRIPSUBJ_*`. A
forend and a slide currently share a wrist angle; a break barrel or bolt handle
has no seat at all.

**What changes.** `PinHand`'s `kind` comes from `part.subject`, falling back to
the governing verb's kind when a card omits it.

Seat sets keyed by **subject**, not hand: `wm_seat_slide`, `wm_seat_forend`,
`wm_seat_foregrip`, `wm_seat_magazine`, `wm_seat_shell`, `wm_seat_round`,
`wm_seat_support`. Seven sets of seven cvars is 49, replacing six sets of seven.

Hands mirror, so a wrist angle tuned for the right hand is wrong for the left.
Apply a mirror for the off hand rather than declaring fourteen sets — and if the
mirror proves wrong in a headset, fall back to fourteen. Test it, do not guess.

`wm_hand_preview` (`WMPinPreview`: Off / On the slide / On the magazine) becomes
a subject picker built from the loaded weapon's parts. MENUDEF's `WM_HandSeats`
page (130-193) is six hardcoded blocks today; it becomes a code-built page like
`WM_GrabMenu`, listing only the subjects the loaded weapons use.

**Dependency — confirm before starting.** For the seat to come from a card grab
point in the weapon's own model space, the follow frame must accept an offset
expressed in **parent model space**; the follow frame otherwise drops the
parent's scale, mirror and MODELDEF base orientation, and the M4A3 is drawn at
Scale −0.82. Whether the engine offers that is not answerable from the pk3.
Without it the seat stays slider-tuned, tolerable at three kinds and not at
seven.

**Verify.** Hold the slide, then the magazine, then the support point, and
confirm each has its own wrist angle. With two weapons loaded, confirm the off
hand's seat is mirrored and not inverted.

**Risk.** Moderate, and gated on the engine question.

---

### Step 7 — the `load` verb, one round at a time

The first step that changes what the player can do. Unlocks four of six
mechanisms.

**What exists already.** `WM_LooseRound` is a `WM_LooseMag` subclass with its own
mesh, scale, glint and lifetime. `GRIPSUBJ_Round` and `GRIPSUBJ_Shell` are in the
engine enum. `MENUDEF.txt:238-254` already declares held-round placement sets for
both hands. `PoseHand` (1158) already has a
`carried[h].IsRound() ? GRIPSUBJ_Round : GRIPSUBJ_Magazine` branch. What is shut
is deliberate: `CatchFalling` (597) filters rounds out, `CanSeat` (869) rejects
them, `SeatRefusal` (885) has a written message for it.

**What changes.**

*Carry a round.* `CatchFalling` stops filtering rounds; `hstate.Carrying()`
accepts one; `PoseHand`'s round branch stops being dead.

*A load target.* The LOAD verb's `loadAt` and `loadSize` define a point and oval
in model space, drawn as a marker exactly like the well (`DrawMarkers` 1528-1535
is the template), gated by `needsOpen` when stated.

*Insertion.* Bring the round inside the load oval and open your hand. **Do not
start with a driven surface** — most meshes have no shell surface to drive, and
the guided path needs one. Proximity plus release first.

*`CanSeat` generalises* into "is there a LOAD or SWAP verb this carried object
satisfies, whose gate is open and whose target store has room". `SeatRefusal`
grows matching messages; it is what tells someone in a headset why nothing
happened, and it should stay as specific as it is.

*The pouch must know what shape to hand you.* `DrawFromPouch` (840) always makes
a magazine of `card.capacity`. It becomes: a SWAP verb means a magazine, only
LOAD verbs means a single round. A weapon with both needs a rule; simplest is
that the pouch gives a magazine and topping up uses rounds off the floor.

*Reserve accounting* against the weapon's own `AmmoType1` rather than `Clip`.
`CardForAmmo` (175) already reads it off the weapon class; `PouchIt`,
`DrawFromPouch` and the HUD's `CountInv("Clip")` need unbinding.

**Verify.** Drop a round, pick it up with the hands mod, bring it to the load
point, open your hand, watch the store count rise. Then with the store full, and
confirm the refusal says so.

**Risk.** Moderate. First real behaviour change, so no identical-to-baseline
fallback.

---

### Step 8 — the `open` verb and `return = stay`

**What changes.**

`Release()` honours `ret`. `RET_SPRING` is today; `RET_HAND` leaves the value
where the hand left it; `RET_STAY` the same plus latching. This one key is why
nothing can currently stay open.

OPEN state lives on the rig (see step 3's note about shared card state).

The latch: `latchId` must be past its own `openAt` before the main part accepts a
grab. Implement in `NearestPart`'s filter, so the barrels simply are not
grabbable until the lever is thrown.

`onopen = ejectall` calls `store.EmptyAll()` and spawns that many loose objects
from the eject port with a small spread. `rig.EjectRound` (757) is the template;
it needs a loop and a live/spent distinction so spent hulls differ from live
shells.

Markers for the open part and the latch, from the existing part-marker path.

**Verify.** Open, confirm it stays open with your hand off it. Close, confirm it
latches. Open with rounds in and confirm they land on the floor.

**Risk.** Moderate.

---

### Step 9 — pump shotgun, the first non-pistol

**Beyond steps 1-8.**

*`follows` on parts.* Add `String followsId; int followsIndex;` to `WM_Part`,
resolve at `Bind`, have `Pose` copy the leader's value before computing the
offset. The leader may be hand-driven, so the follower must read the **drawn**
value, not the posed one.

*`hands = 2`.* `PutAway` (983) stows the working hand's own weapon while it works
the other — correct for a pistol pair, wrong for a long gun where that hand is on
its fist and should stay there. With `hands = 2`, skip the stow.

*Bracing back on.* A pump's support hand is the working hand; bracing and working
are the same posture. **Before designing anything, flip `wm_brace` true in a
headset** — both bugs that killed it look fixed. `NearestPart` (641) now bails on
a stowed weapon, and the ordering is inverted so a squeeze picks a part with
support excluded while bracing is only set for an open hand. It may simply work.

*Sound vocabulary.* New card keys for pump out, pump home, shell into tube.
`NewCard` currently defaults unstated sounds to the M4A3's, so a shotgun that
omits a line gets a pistol noise rather than a complaint — make the new keys
default to silence instead.

*Assets.* A mesh with separable forend and bolt surfaces, measured the way both
existing cards were: rigid fit with the receiver's motion divided out, never
frame numbers. The existing cards' comment explains why — on `m4a3.md3` the
receiver drifts 24.41 units from frame 8, so playing the magazine-out frames
hurls the whole weapon sideways.

**Verify.** Fire, pump, hull ejects, chambers from the tube. Load the tube shell
by shell. Fire dry and confirm nothing chambers.

---

### Step 10 — break-action double

**BUILT 2026-09-13** as `archetype breakaction` (section 3, "The break-action double
and full auto"), first card RS_VR_Weapons' `WM_SSG`. Built differently from the plan
below in three places: ONE `load breech` with `slot = next` instead of two zones (they
would overlap); no barrel selection -- the pull fires every live barrel at once
(`WM_Gun.ChambersPerPull 2`, the Doom SSG's identity); no hammers or latch (the mesh
has none that move). Not built: the flick close (G15) -- push the barrels up by hand.

*A two-slot store* and two LOAD verbs naming it with explicit `slot = 0` and
`slot = 1`. The first thing that is impossible before step 4.

*Barrel selection.* Alternate on each shot is the simple rule; a card key can
override later.

*Multiple hammers.* After step 4 two `role = hammer` parts are legal, but
`Automatic()` (607) drives every hammer part from one `hammerCocked`, so they
move together. Either give each hammer state keyed to a chamber slot, or accept
unison for the first pass and say so.

*Ejectors* as a `follows` part on the barrel group, throwing both hulls at
`onopen`.

**Verify.** Load both, fire both, break open, both hulls eject, reload. Then load
one barrel only and confirm the empty one clicks.

---

### Step 11 — revolver

**BUILT 2026-09-13** as two archetypes, not one: `breaktop_revolver` (open
ejects all, speedloader zone rides the barrel) and `swingout_revolver` (open,
then `eject by = muzzleup`, loader zone rides the crane). See "Keys added for the
revolvers" in section 3. Not built from the list below: a single-action hammer
gate (both meshes are double action), and the flick close (G15).

The most new ground, which is why it is last of the three.

*An indexed slotted store* with `advance = onshot`, so the trigger walks the
cylinder.

*A functional hammer.* Every other mechanism treats it as decoration —
`hammerCocked` is set true on every shot and every rack. A single action needs
cocking before the trigger does anything, so the hammer becomes a part with a
grab point and a real gate on `CanFire`.

*Crane and ejector rod* as OPEN and EJECT verbs with `needs = open:crane`.

*`slot = next` loading.*

*Spent cases.* `EmptyAll` must throw spent hulls for fired chambers and live
rounds for unfired ones. The store distinguishes `SLOT_SPENT` from `SLOT_LIVE`;
the spawn path must honour it.

*Optional: the flick.* Closing a cylinder is a wrist flick in life and a 1:1 drag
feels wrong. RS_GESTURES' capture ring already stores per-tic hand roll, so a
flick is a derivative rather than a DTW match. Entirely optional, dependent on
another package, and the drag must work first.

**Verify.** Open, eject six, load six, close, fire six. Then fire three, open,
and confirm three spent and three live come out correctly distinguished.

---

### Step 12 — bolt action

**Built (2026-09-13), on the engine's chained drive rather than the handoff below.**
The fork's `SetModelSurfaceDriveStage` hands over between the stages in the renderer
on the frame being drawn, so the seam described under "The risk" never arises. The
grammar and what the script does are in section 3, "Two-stage parts: `dof2`". The
text below is the plan as first written.

**The one thing needing new kinematics.** Lift, pull, push, turn down is two DOFs
in sequence on one surface. The existing `twist` is simultaneous rotation
*during* a slide, a different shape. And `SetModelSurfaceDrive` takes one axis and
one distance, so a single drive cannot express it. Two parts naming the same
surface would each get a slot and fight, because the lowest slot wins.

**The script-side answer, to try before asking for engine work.** A two-stage
DOF: the card declares both stages (`dof` and `dof2`), `PartOffset` composes them
by mapping 0.0-0.5 to stage one and 0.5-1.0 to stage two, and the hand drive is
handed off at the midpoint — `StopDrive` on stage one, `StartDrive` on stage two,
seeded from the drawn value.

**The risk.** The handoff is a visible seam if it is not smooth, and it happens
mid-motion with the player's hand on the part. Read the drawn value across the
boundary carefully; a one-tic discontinuity reads as the bolt snapping. If the
seam cannot be hidden, the fallback is an engine-side chained drive, which is
genuinely new engine work and should not be assumed available.

**Verify.** Slow bolt throw and fast bolt throw. The fast one is where the
handoff breaks.

---

## 6. Dependencies and parallelism

Steps 1 and 2 are independent and can be done in either order or concurrently.
Step 3 needs both.

Step 4 needs 3. Step 5 needs 4 (it wants part ids). Step 6 needs 4 and its engine
confirmation; it does not need 5.

Step 7 needs 3 and benefits from 4. Step 8 needs 3.

Steps 9, 10 and 11 each need 7 and 8, are independent of each other, and can run
in parallel.

Step 12 needs nothing after 3 and can be prototyped early — it is a kinematics
question, not a grammar question.

---

## 7. Build gates, every step

`build.ps1` runs `menu_lint.py` first and fails on: an undeclared cvar behind a
menu row (E1), a declared cvar nothing reads (E2), code reading an undeclared
cvar (E3), a placement set missing a suffix or with no sliders (E4), a slider
range excluding its default or a size reaching zero (E5), a MODELDEF or WMCARD
class no ZScript declares (E6).

Steps 1 through 4 add and remove no cvars, so lint should stay silent. If it
complains, something was deleted that a slider still points at. Step 5 changes
the surface massively — CVARINFO and MENUDEF must change in the same commit. Step
6 adds seat sets; E4 catches a half-added one.

Then the pack step verifies every entry landed in the zip, then a `-norun` load
must produce `script parsing took` with no `pk3:zscript` line. Compile errors
never contain the word "error", which is why the check greps for the pk3 name.

**Every new .zs file must be added to `zscript.txt` and to whatever allowlist
`build.ps1` packs from.** Miss the second and the file is silently absent from
the pk3 — the classes simply do not exist at runtime, with no error.

---

## 8. Known limits this plan does not fix

Sixteen surface-override slots per weapon is an engine constant (`WM_Rig.SLOTS`).
`Bind` (115) logs and continues when a weapon exceeds it, so later parts silently
stop moving. Make it a refusal, matching the parser's philosophy — a five-line
change worth doing during step 2. A break-action double with two hammers, two
triggers, two ejectors, barrels, top lever, forend and safety lands around nine
or ten surfaces. It fits. A belt-fed with animated links does not.

Two rigs, one per hand, with hand *h* always working `rigs[1-h]`. `hands = 2` in
step 9 patches the worst of it; a genuinely general model would let a weapon
occupy both hands.

Single-player. Everything reads `players[consoleplayer]`, `PlayerSpawned` acts
only on consoleplayer, and the netevents assume one player.

Loose magazines never despawn by design, and `CatchFalling`, `ForeignInHand` and
`PreviewMags` each walk the full `WM_LooseMag` thinker list per hand per tic,
with `WM_LooseRound` in the same iterator and `wm_round_life` at 3150 tics. Six
walks a tic is nothing today. Step 7 onward drops shells and hulls everywhere, so
revisit it then — an index kept by the system rather than a thinker walk is the
obvious fix.

Weapon passing — moving a held weapon from one hand to the other — is
deliberately out of scope here and belongs in the gesture package, since it is a
transfer of any held object rather than a weapon-mechanism concern. It is
independent of all twelve steps. The only change it will want on this side is a
carve-out in `Claim()` (1195), which currently takes a hand even when the arbiter
refuses — *"a denial is advice, not a veto"* — which is right for a weapon's own
parts and wrong for a transfer in progress.
