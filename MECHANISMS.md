# RS_VR_PistolTest — review from the code

Read in full: `log.zs`, `space.zs`, `card.zs`, `parser.zs`, `ammo.zs`, `loose.zs`,
`fx.zs`, `weapon.zs`, `rig.zs`, `system.zs`, `become.zs`, `menu.zs`, plus
`WMCARD.txt`, `MODELDEF.txt`, `MENUDEF.txt`, `CVARINFO.txt`, `SNDINFO.txt` and
`build.ps1`. Nothing changed on disk.

---

## 1. The goal

Take a system proven on one mechanism — detachable box magazine feeding a
reciprocating slide — and make the mechanism a thing a weapon *declares* rather
than a thing the system knows. Pump, break, bolt, revolver, lever, tube, and the
rest on the same code. The hands read the weapon's kind, apply the right profile
of grab volumes for it, and lock onto the right part at the right moment in
whatever sequence that weapon's reload actually is.

---

## 2. How it works, traced

`WM_System` is an EventHandler. Every `WorldTick` runs a fixed order: equip guns
into hands, bind each hand's weapon to its card, find the grip arbiter, record
hand positions for the throw fallback, then per rig — spawn the prop, resolve
surface names to indices, run the automatic parts. Then the props get
`SetOrigin(pmo.Pos)` purely so the renderer doesn't cull them, buttons are
edge-detected, then `WorkHand` for each hand, then stow, pose, pin the hand,
publish the grip subject, drag pouches, publish proximity, draw markers, buzz,
build the HUD.

The whole interaction grammar lives in `WorkHand(pmo, h)` at `system.zs:491`,
and it is a priority chain on `rigs[1-h]` — hand *h* always works the *other*
hand's gun. In order: if this hand is guiding a magazine into a well, `Guide`.
Else if carrying one, `Carry`. Else if holding a part, `Hold`. Else if
RS_WorldHands has put a magazine in this hand, check the well and maybe
`BeginGuide`. Else if one was just released inside the pouch, `PouchIt`. Else if
squeezing and a magazine is falling nearby, `CatchFalling`. Else on a fresh
squeeze: pouch first (`DrawFromPouch`), then `NearestPart` → `TakeAllowed` →
`Take`. Else, if the nearest part is a support point and bracing is enabled, set
bracing.

Beneath that sit the primitives in `rig.zs`, and these are the good part.
`StartDrive` hands a part's surfaces to the renderer to be placed from the live
controller pose every drawn frame, with `distance` serving as both how far the
part travels and how far the hand travels, so the part is glued 1:1.
`StopDrive` reads back `GetModelSurfaceDrawnValue` — what was actually on
screen, never script's estimate. `Pose` writes every part's offset and rotation
every tic into the same slot the drive uses, so releasing hands the part
straight back to a pose that already agrees with the screen. `PartPoint` runs
grab points through `ModelPointToWorld`, the renderer's own object-to-world
matrix, so a grab point is on the drawn part however the gun is seated.
`GrabDepth` tests an oval in the gun's own axes; `HandPartDepth` in `system.zs`
composes that with the hand's own reach oval asked of the arbiter, so a grab is
two volumes meeting.

None of those primitives care what kind of weapon it is. Everything above them
does.

---

## 3. What already generalises

There are no weapon names in `rig.zs` or `system.zs` — I checked every string
literal. The only class names are `Actor`, `Weapon`, `Inventory`, `Clip`, the
package's own `WM_*` actors, and `RS_HandWorldMain`/`Off` looked up at runtime.
That claim holds.

The DOF abstraction is wider than the guns using it. A slide is an axis and a
distance; a hinge is an axis, an angle and a pivot. That already covers a pump's
forend, a break action's barrel group, a top lever, an extractor, a revolver's
crane and ejector rod, and a lever gun's lever. `PartOffset` folds the pivot into
the offset in MD3 space before conversion, and `WM_Space.EngRot` flips the angle
sign because the y/z swap is a reflection — both correct and both written once.

The oval machinery is complete and per-part. `grabsize` gives three half-sizes
along the barrel, across and up; `grabradius` gives a ball when no oval is
stated; `GrabAxes` and `DrawAxes` resolve the same precedence the renderer
resolves, so the shape you drag is the shape that grabs. This is the "profile of
ovals" you described, and it exists at the part level already.

`WM_Part` already carries `subject` separately from `role`, with the comment
naming the exact reason: *"A pump's forend and a pistol's slide are both the
action and are held completely differently, so this is not inferred from the
role."* The subject vocabulary is `slide | forend | foregrip | magazine | shell |
round | support`, and `SubjectFor` maps it onto the engine's `GRIPSUBJ_*`, which
also has Forend, Foregrip, Shell and Round. The vocabulary for pump and shell-fed
weapons was written before any code needed it.

Magazine interchange is already by family, not by gun — `magFamily`, defaulting
to `"pistol"` — and a carried magazine re-dresses itself to the gun the hand
works, so it looks right whichever gun it came out of.

The slot discipline is right: one override slot per (part, surface), for life,
shared by the pose and the drive, reserved in `Bind` by *named* surface so
numbering never depends on what the mesh turned out to contain.

The diagnostics are built for a system that can only report in text — `log.zs`
says so explicitly, and it's correct that a headless run can't observe a grab.
Per-hand HUD with distance against required reach for every part, mirrored to the
log on a timer and on the exact tic either grip changes, wire markers coloured by
state, a haptic buzz on entering reach, a gun-to-hand sanity line, and five
netevents.

And the build refuses dead controls: `menu_lint.py` fails on undeclared cvars,
unread cvars, unlinted placement sets, slider ranges excluding their default, and
MODELDEF/WMCARD classes no ZScript declares; then the pack step verifies every
entry landed in the zip; then a `-norun` load must produce "script parsing took"
with no `pk3:zscript` line. I spot-checked seventeen cvars read from code and all
seventeen are declared.

---

## 4. Where the pistol is baked in

**Role lookup is a singleton.** `WM_Card.FindRole` and `FindRoleIndex` return the
*first* matching part, and every consumer uses them — the well point, the seated
point, `Cycle`, `DropMagazine`, `Seat`, `ButtonDrop`, `BeginGuide`, `Guide`,
`PinHand`, the HUD. One action, one feed, structurally. Two chambers, six
chambers, a tube plus a chamber, a bolt handle plus a bolt release: none can be
written.

**`WM_Ammo` is four fields.** Rounds in the seated magazine, chambered boolean,
magazine-in boolean, action-lock boolean. `Fire()` hardcodes the semi-auto rule
that the action strips the next round from the magazine on its way back. There is
no way to say "six chambers with an index", "two barrels each with a chamber", "a
tube loaded one at a time that never detaches", or "a belt".

**The action's behaviour is a semi-auto slide in three places.**
`WM_Rig.Cycle()` auto-cycles on every shot, out fast then back slower, and
re-asserts 1.0 while locked. `Hold()` uses literal thresholds — 0.6 is "far
enough to rack", 0.95 is the apex. `Release()` implements a spring with two rest
states: `part.value = ammo.actionLock ? 1.0 : 0.0`. A pump doesn't auto-cycle and
must be pushed home by hand. A break action doesn't move on a shot and stays open
until closed. A bolt stays where you leave it.

**`Racked()` means one thing.** Release the lock and chamber, or extract-and-feed.
It is a single function for what will need to be several distinct events.

**The single-round path is deliberately closed.** `WM_LooseRound` exists and is a
`WM_LooseMag` subclass, and `PoseHand` even has a
`carried[h].IsRound() ? GRIPSUBJ_Round : GRIPSUBJ_Magazine` branch — but nothing
ever puts a round in `carried[]`. `CatchFalling` filters rounds out at line 597;
`CanSeat` rejects them at 869; `SeatRefusal` has a written message for it. Rounds
are produced by `EjectRound` and consumed by walking over them, and that is all.
Loading one round at a time is exactly what pump, break, revolver and lever all
need, and it's the branch that's shut.

**The hand's hold has three shapes and they're string literals.** In `PinHand`:

```
kind = (part.role == "feed") ? "mag" : "slide";
```

giving one of six placement prefixes — `wm_main_slide`, `wm_main_mag`,
`wm_main_support` and the off-hand mirrors — each backed by a declared set of
seat, rotation and scale cvars, and each with its own block in
`MENUDEF.txt:130-193`. So the seat of a hand on a part is keyed by hand × three
fixed kinds. It is not keyed by part, and it is not keyed by `subject`, even
though `subject` is on the card already saying `forend` or `shell`. A forend and a
slide would share a wrist angle. A break barrel or a bolt handle has no seat at
all.

This is the sharpest single blocker against "the hands lock to the right parts."
The card already says the right thing; `PinHand` doesn't read it.

**Eight tunable parts, sixteen surfaces, and it's expensive.** `SEL_PER_GUN = 8`
and `WM_GrabMenu` loops `i < 8` twice, so part nine gets no sliders and no edit
marker. `WM_Rig.SLOTS = 16` caps named surfaces per gun, and `Bind` logs an error
and *continues* when it overflows — a gun over budget silently loses its later
parts' movement rather than being refused, which is inconsistent with the
parser's own refuse-and-say-so philosophy. Today the M4A3 uses four surfaces and
the Pistolet five, five parts each.

The cost matters for the profile idea: **259 of the 382 declared cvars — 68% of
the whole configuration surface — are the per-part grab tuning for the existing
sixteen part slots**, at roughly sixteen cvars per slot. CVARINFO is static text,
so the ceiling is whatever you pre-declare. Doubling to sixteen parts per gun
adds about 260 more declarations, every one of which lint requires to be both
declared and read.

**Two guns, one per hand, assigned by the card.** `WM_Rig rigs[2]`, and
`card.hand` decides. `Equip()` forces each gun into its stated hand every tic.
This is shallower than it looks — `BindRig` already binds whatever weapon is in a
hand to whatever card matches its class, fully generally, and `card.hand` is
consumed only by `Equip` and log strings. The deeper assumption is `WorkHand(h)`
always operating on `rigs[1-h]`, which is right for dual pistols and only
approximately right for a two-handed long gun: there's no notion of a weapon that
*requires* two hands, and `PutAway` stows the working hand's own gun, which is
correct for a pistol pair and wrong for a shotgun where that hand should be empty.

**Ammunition is always `Clip`.** `WM_LooseMag : Clip`; the pouch adds to and
draws from `Clip`; the HUD counts `Clip`; `WM_Gun.AmmoType1 "Clip"`;
`WM_Player` starts with 200. `CardForAmmo` is already generic — it reads
`AmmoType1` off the weapon class — but the pouch, the reserve readout and the
loose-magazine base class are hard-bound.

**The sound vocabulary is a pistol's.** fire, dry, magout, magin, slideback,
slidefwd, rackapex, rackreset, magdrop, casing. Nothing for break open or close,
shell insert, shell into tube, cylinder open or close, ejector rod, lever throw,
bolt lift/pull/push/close. The per-gun namespacing in SNDINFO (`wm/m4a3/*`,
`wm/pistolet/*`) is clean and a third gun just adds its own — but the *kinds* are
fixed, and `NewCard` defaults unstated ones to the M4A3's sounds, so a shotgun
that omits a line gets a pistol noise rather than a complaint.

**Hammer and trigger are decoration.** `Automatic()` drives the trigger from the
analog value and the hammer from `hammerCocked`, which is set true on every shot
and every rack. No rule that a hammer must be cocked to fire, no safety, no
selector. Fine for a semi-auto; a gap the moment a single-action revolver exists.

---

## 5. The actual gap: the card has nouns and no verbs

The card says what parts exist and how each one *can* move. It never says what a
*sequence* is. Every sequence — drop, carry, guide, seat, rack — is compiled into
`WorkHand`'s priority chain and the role tests inside `Hold`, `Release`, `Cycle`
and `Racked`.

And `role` is doing two jobs. It means both *what a part is* and *what the system
does with it*. `action` doesn't mean "the reciprocating group"; it means "the
thing `Cycle` animates, `Hold` measures against 0.6, `Release` springs home, and
`Racked` acts on." That's why a pump needs an edit to `system.zs` rather than a
card.

The precedent for the fix is already in the tree: `subject` was split out of
`role` for exactly this reason, with the pump forend named as the motivating
case. The same split needs to happen one level up.

---

## 6. There are fewer verbs than mechanisms

This is the part I think is most useful for putting the design together. Working
through what each mechanism actually needs, they collapse into five verbs.

**Cycle** — a part travels out and back; at one extreme something ejects, at the
other something chambers. That is a pistol slide, a pump forend, a lever, and a
bolt. A pump and a lever are the *same verb over different DOFs* — a slide and a
hinge — which means if you build the two-stroke cycle generically over the DOF
abstraction, the lever gun comes free with the pump.

**Open and close** — a part moves to a held-open state and stays there, and while
it's open the chambers are reachable. That is a break action, a revolver cylinder
swinging out, and a slide locked back. The distinguishing property is the rest
behaviour: this verb needs a part that does *not* spring home.

**Detach and attach a container** — the current magazine drop and seat, fully
built. Also covers a drum, and a speedloader if you model it as a container.

**Insert one** — put a single round or shell into a named target. Tube loading
gate, break chambers, revolver chambers, topping off a partly loaded gun. This is
the closed branch from §4.

**Eject** — empty one chamber or all of them onto the floor. Extractor throw,
break ejectors, revolver ejector rod. `EjectRound` already does the one-round
case with a real world object.

Mapped against the mechanisms:

| Mechanism | Verbs it needs | What's expressible today |
|---|---|---|
| Mag + slide | cycle (auto), detach/attach | all of it |
| Pump | cycle (manual, two-stroke), insert one, eject | forend as a slide DOF; nothing else |
| Lever | cycle (manual, hinge), insert one, eject | lever as a hinge DOF; nothing else |
| Break | open/close, insert one ×N, eject all | barrel and lever as hinge DOFs; nothing else |
| Revolver | open/close, eject all, insert one ×N | crane and rod as DOFs; no indexed chambers |
| Bolt | cycle (sequential multi-DOF), detach/attach | detach/attach only |

Two things fall out of that table. First, `insert one` appears in four of six
rows and is the single highest-value thing to build — and its scaffolding
(`WM_LooseRound`, `GRIPSUBJ_Round`, `GRIPSUBJ_Shell`, the held-round placement
sets in `MENUDEF.txt:238-254`) already exists. Second, the only DOF shape that
genuinely doesn't fit is the bolt handle: lift, pull, push, turn down is *two
DOFs in sequence on one part*, and `twist` is simultaneous rotation during a
slide, not sequential. Bolt actions are the one mechanism that needs new
kinematics rather than new grammar.

---

## 7. On keying off the slot

You floated slot, and said "or something else." Slot is the weaker option. Doom
slots are a UI concept, mods assign them by taste, and you load a weapon-selection
mod that can reassign them — two guns in slot 3 can be a chaingun and a pump.
Keying the reload grammar off that makes it depend on something neither you nor
the gun's author controls.

The card is the better key, and it's already the pattern for everything else: one
word, `mechanism = pump`, beside `hand` and `magfamily`. That gives the archetype
a place to supply defaults — its parts, their subjects, their oval shapes, their
seat sets, its verb sequence — which a card then overrides where the gun differs.
Checkable at load, survives a slot reshuffle, and it keeps the cvar surface from
growing per-gun, which §4 says it otherwise will.

Slot could still earn a place as a fallback guess for weapons with *no card at
all*, so a mod's unmodified shotgun gets roughly shotgun-shaped hands. That's a
much less load-bearing job and worth keeping separate.

---

## 8. Smaller findings

`MENUDEF.txt` names both guns in four places — lines 46, 47, 81 and 106. The
ZScript is clean of weapon names; the menu isn't. Cosmetic now, wrong on the
third gun.

`WM_GrabMenu` only lists parts whose role is `action` or `feed` (`menu.zs:103`),
so any new role gets no tuning page.

`CVARINFO.txt:186` has two comments run together — the trailing fragment belongs
to `wm_catch_radius` on the line above.

`WM_Rig.Reset()` doesn't clear `pastBack` or `atApex`, so `wm_reset` mid-hold can
leave a stale apex flag.

`CatchFalling`, `ForeignInHand` and `PreviewMags` each walk the full
`WM_LooseMag` thinker list per hand per tic — six full walks a tic — and
`WM_LooseRound` is a subclass, so it's in the same iterator, with
`wm_round_life` at 3150 tics. Not a problem now; a scaling smell for a system
about to start dropping individual shells and hulls everywhere.

Everything reads `players[consoleplayer]`, `PlayerSpawned` only acts on
consoleplayer, and the netevents assume one player. Single-player is a reasonable
choice; right now it's an implicit one.

---

## 9. Judgement

The primitives are done and done properly — the space conversion, the draw-rate
hand drive with drawn-value read-back, the shared pose/drive slot, the
drawn-equals-tested ovals, the arbiter handshake, the build gates. Nothing in the
expansion needs those rebuilt.

What exists above them is a *magazine-and-slide* system rather than a general one,
and the genericity it demonstrates is across meshes rather than across mechanisms.
Two guns, one mechanism.

The expansion isn't a rewrite. Role lookup stops being a singleton. `WM_Ammo`
becomes named containers with capacities and transfer rules instead of four
fields. `WorkHand`'s priority chain becomes an interpreter over the five verbs in
§6. `PinHand` reads the `subject` the card is already writing. Rest behaviour —
spring home, spring open, stay put — becomes a card property instead of the
constant in `Release`. And the closed single-round path opens, which unlocks four
of the six mechanisms on its own.

The one thing that needs new kinematics rather than new grammar is the bolt
handle's sequential lift-pull-push-turn. Everything else in the table is
expressible with the DOFs you already have.
