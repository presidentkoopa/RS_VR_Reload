# Making it universal — an approach

Derived from the source as it stands, 2026-09-12. Everything here is a proposal;
nothing in it is a claim about what currently runs.

---

## 1. What "universal" has to mean

Today a weapon declares its parts and how each one *can* move, and the system
knows what to do with them. The knowing is the problem: `action` doesn't mean
"the reciprocating group", it means "the thing `Cycle` animates, `Hold` measures
against 0.6, `Release` springs home, and `Racked` acts on". That is why a pump
costs an edit to `system.zs` rather than a text block.

Universal means the weapon declares its *sequences* too, and the system becomes
an interpreter. The target is that a pump shotgun, a break-action double, a
revolver, a lever gun and a bolt rifle are all text, and the last line of ZScript
that knows what kind of weapon it is has been deleted.

There is one honest cap on that ambition, stated up front so it doesn't surprise
anyone later: sixteen surface-override slots per weapon is an engine constant
(`WM_Rig.SLOTS`), and a genuinely complex mechanism — a break-action double with
two hammers, two triggers, two ejectors, barrels, top lever, forend and safety —
lands around nine or ten. It fits. A belt-fed with animated links does not.

---

## 2. The one structural change

The card needs a verb language, and the verbs are fewer than the mechanisms.
Working through what each mechanism actually requires, they collapse to five.

**Cycle** — a part travels out and back; at one extreme something ejects, at the
other something chambers. A pistol slide, a pump forend, a lever, a bolt. Pump
and lever are the *same verb over different DOFs*, a slide and a hinge, so
building the two-stroke cycle generically over the existing DOF abstraction gets
the lever gun for free.

**Open / close** — a part moves to a held state and stays there, and while it is
open the stores are reachable. A break action, a revolver crane, a slide locked
back. The distinguishing property is rest behaviour: this verb needs a part that
does *not* spring home, which `Release()` currently makes impossible.

**Swap** — detach and attach a container. Fully built today as the magazine drop
and seat. Also covers a drum, a cell, and a speedloader modelled as a container.

**Load** — put one round or shell into a named store. A tube gate, break
chambers, revolver chambers, topping off. This appears in four of the six
mechanisms and is the single highest-leverage thing to build.

**Eject** — empty one slot or all of them into the world. Extractor throw, break
ejectors, revolver ejector rod. Mostly a consequence of cycle and open; only the
ejector rod is a player action in its own right.

| Mechanism | Verbs | Expressible today |
|---|---|---|
| Mag + slide | cycle (auto, spring), swap | all of it |
| Pump | cycle (manual, hand-return), load, eject | forend as a slide DOF |
| Lever | cycle (manual, hinge), load, eject | lever as a hinge DOF |
| Break | open/close, load ×N, eject all | barrels and lever as hinge DOFs |
| Revolver | open/close, eject all, load ×N | crane and rod as DOFs |
| Bolt | cycle (sequential DOF), swap | swap only |

The bolt handle is the only entry needing new kinematics rather than new grammar
— lift, pull, push, turn down is two DOFs in sequence on one part, and the
existing `twist` is simultaneous rotation *during* a slide, not sequential.
Section 10 covers it.

---

## 3. Ammunition becomes named stores

`WM_Ammo`'s four fields — rounds, chambered, magIn, actionLock — describe one
mechanism. Replace them with a set of declared **stores**, of two kinds.

A **counted** store holds fungible rounds in a number: a box magazine, a tube, a
belt, a cell. It has a capacity, and it may or may not detach.

A **slotted** store holds a fixed set of positions each of which is empty, live
or spent: a chamber (one slot), a revolver cylinder (six, with an index that
advances), a double's barrels (two, selected rather than indexed). Slotted is
what makes a revolver possible, because a cylinder with three live and three
spent is not a count.

Everything the current ammo model does falls out of two stores — a counted
detachable `mag` and a slotted one-slot `chamber` — plus the transfers between
them. `Fire()` becomes "spend the selected slot of `chamber`", and the semi-auto
rule that the action strips the next round on its way back becomes a `feed`
transfer named by the cycle block rather than a line of ZScript.

Action lock stops being a boolean and becomes a property of a cycle: *hold at
full travel when the feed store is empty*. That generalises correctly — a pump
doesn't lock back, and now it simply doesn't declare it.

Reserve stays as ordinary Doom ammunition so pickups keep working, but the class
comes from the weapon rather than being `Clip` everywhere. `CardForAmmo` already
reads `AmmoType1` off the weapon class, so the lookup exists; the pouch, the HUD
count and `WM_LooseMag`'s base class are what need unbinding.

---

## 4. The card grammar

Same shape as today — lowercase `key = value`, blocks closed by `end`, `#`
comments, an unknown key refuses that weapon and only that weapon.

Stores are declared at card level:

```
store mag
  kind     = counted
  capacity = 15
  detach   = yes
  family   = pistol
end

store chamber
  kind  = slotted
  slots = 1
end
```

Parts keep everything they have — `surface`, `grab`, `grabradius`, `grabsize`,
`subject`, and a `dof` block — and lose the mechanism meaning of `role`. `role`
survives only for the genuinely descriptive cases the automatics use: `trigger`,
`hammer`, `hidden`, `support`. Everything else a part does comes from being
*named by a verb*, which is what kills the singleton problem: verbs reference
parts by id, and there can be as many as you like.

One addition parts need is dependency, because a pump's bolt tracks its forend
and a break's extractor tracks its barrels:

```
part bolt
  surface = bolt
  follows = forend        # its value is the forend's value
  dof kind = slide  axis = -1, 0, 0  distance = 4.2 end
end
```

Then the five verbs.

```
cycle rack
  part    = slide
  outat   = 0.60          # counts as worked past here
  apex    = 0.95          # where the hand feels it stop
  onout   = eject
  from    = chamber       # what the eject empties
  onhome  = feed
  feed    = mag           # where the fed round comes from
  into    = chamber
  return  = spring        # spring | hand | stay
  holdopen = whenempty    # the lockback; omit and it never holds
  auto    = onshot        # the shot works it; omit for a manual action
end

open break
  part     = barrels
  latch    = toplever     # optional: must be past its own threshold first
  openat   = 0.90
  rest     = stay
  onopen   = ejectall
  from     = barrels
end

swap magwell
  part     = magazine
  store    = mag
  seatat   = 0.25
  button   = yes          # the drop-mag button works this
  handtake = no
end

load gate
  into    = tube
  at      = 1.2, 0.0, -2.4
  size    = 2.5, 2.0, 2.0
  subject = shell
  needs   = open:break     # optional: only while that open-state is open
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
Spring is today's behaviour, hand means the player must push it home, stay means
it holds wherever it was left. Without that one key, no mechanism that stays open
can exist.

---

## 5. Worked cards

**The existing pistol, unchanged in behaviour.** This is the important one,
because it is how the grammar gets proved without risking anything: express what
already works, and the headset should not be able to tell the difference.

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

**Pump shotgun.** Tube plus chamber, a hand-returned cycle, a loading gate.

```
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

Note what is *absent*: no `auto`, so nothing cycles on a shot; no `holdopen`, so
it never locks back; `return = hand`, so the forend stays where you leave it and
the chambering happens when you push it home. Three keys are the whole difference
between a pistol and a pump.

**Lever action** is the pump with a hinge:

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

Same verb, different DOF. If the interpreter is written over the DOF abstraction
rather than over "slides", this card costs nothing extra to support.

**Break-action double.** Two slotted chambers, an open verb, two load points.

```
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
  into = barrels  slot = 0  at = 0.5, -0.7, 0.4  size = 2, 1.5, 1.5  subject = shell
  needs = open:break
end

load right
  into = barrels  slot = 1  at = 0.5,  0.7, 0.4  size = 2, 1.5, 1.5  subject = shell
  needs = open:break
end
```

Two `load` blocks naming the same store and different slots is what a
non-singleton part model buys you, and it is impossible today.

**Revolver.** A slotted, indexed store, a crane that opens, an ejector rod.

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

`slot = next` means the load finds the first empty slot, which is what fumbling
rounds into a cylinder actually is. `advance = onshot` on the store is what makes
the trigger index it — and note this is the first mechanism where the hammer has
to become functional rather than decorative, since a single action needs cocking
before the trigger does anything.

---

## 6. The runtime

**One state per hand.** There are currently about eighteen parallel per-hand
arrays, and the mutually exclusive ones — `holding`, `carried`, `guidingOn`,
`foreign`, `bracing` — are kept exclusive only by the return-order of the
if-chain in `WorkHand`. Nothing structural forbids two being true. Every verb
added multiplies that: `load` alone introduces carrying-a-shell, shell-at-the-
port and shell-going-in.

Replace them with one value per hand — free, on a part, carrying, guiding a
container, loading a round, bracing — plus a payload naming the part, object or
target. Transitions become a single function with a switch, and the illegal
states stop being reachable rather than being merely unreached.

**`WorkHand` becomes an interpreter.** Instead of a priority chain over
hardcoded verbs, it asks: given this hand's state and what it is near, which
declared verb applies? The primitives it drives are already written and already
verb-agnostic — `StartDrive`, `StopDrive`, `DrawnValue`, `GrabDepth`,
`HandPartDepth`, `PartPoint`, `Pose`. None of them need to change.

**`PinHand` reads `subject`.** Today it computes the hold as
`(part.role == "feed") ? "mag" : "slide"` — three literal shapes — while the card
already carries `subject` with seven values and the engine carries `GRIPSUBJ_*`
with ten. A forend and a slide currently share a wrist angle. Keying the seat off
`subject` is a small change that directly delivers "the hands lock to the right
part in the right shape", and the data for it is already being written.

**Rest behaviour comes from the card.** `Release()`'s
`part.value = ammo.actionLock ? 1.0 : 0.0` becomes a read of the governing verb's
`return`.

---

## 7. Where the numbers live

There are three tiers tangled together in the current 382 cvars, and they belong
in three different places.

**Gun facts** — where a grab point sits in model space, the oval's three
half-sizes, an axis, a distance, a pivot. These belong in the card, and mostly
already are. The exception is the per-part nudge and shape sets, which are cvars
today: `wm_gp_m3_ofs_x` and friends.

**Player ergonomics** — where the gun sits on your controller, the wrist angle
you like on a slide. These are per-*player*, not per-weapon; arm length and grip
preference don't belong baked into a weapon someone else will load.

**Scratch** — the live nudge you are dragging right now, before you commit it.

The current scheme puts all three in static cvars keyed by *hand*, and that is
the concrete bug to fix before weapon #3: `PartTag()` builds `wm_gp_m3_*` from
`hand == 0 ? "m" : "o"` plus the part *index*. It says "main hand, part 3", not
"M4A3, slide". Put a different weapon in that hand and it inherits every tuned
number; reorder parts within a card and the tuning shifts under them.

The fix is forced by the medium: CVARINFO is static text, so there is no way to
pre-declare `wm_gp_<anyweaponclass>_<partid>_*`. Keying the tuning to the weapon
therefore *requires* moving the baked values out of cvars and into the card. Do
it as one move: the sliders collapse to a single scratch set pointed at whichever
part the tuner has selected, and a `wm_bake_card` netevent prints the tuned card
block to the console for pasting. That fixes the keying bug, deletes roughly 259
of the 382 declarations, and removes the eight-part ceiling in the same change.

That ceiling matters: `SEL_PER_GUN = 8` and `WM_GrabMenu`'s two `i < 8` loops
mean part nine gets no sliders and no edit marker, and each part slot costs about
sixteen declared cvars. A revolver reaches eight parts before it has a support
point.

---

## 8. Mechanism profiles

With verbs in the card, `mechanism = pump` becomes worthwhile: one word that
supplies default verb blocks, default subjects, default oval shapes and default
seats, which a card then overrides where its weapon differs. That is what stops
every new weapon needing twenty sliders dialled by hand, and it is the honest
version of "the hands know what kind of gun this is".

Keying that off the Doom slot would be weaker. Slots are a UI concept, mods
assign them by taste, and a weapon-selection mod can reassign them — two weapons
in slot 3 can be a chaingun and a pump. Slot is worth keeping only as a fallback
guess for weapons with *no card at all*, so an unmodified third-party shotgun
gets roughly shotgun-shaped hands. That is a much less load-bearing job.

---

## 9. Order of work

The property that makes this tractable is that most of it changes no behaviour.
Steps one to six below should leave the existing pistols bit-for-bit identical in
the headset, which means each is verifiable against a known-good baseline — the
right shape for a system that can only be tested by wearing it.

**Nothing first.** Write the pump card and the break card on paper, in today's
grammar, and note every line you cannot write. That list is the specification for
everything below, and it costs an hour. Both independent reviews of this system
landed on it.

**One.** Collapse the eighteen per-hand arrays into one state plus a payload.
Pure refactor. Do it before adding verbs, not after — it is what makes verbs
addable.

**Two.** Replace `WM_Ammo` with declared stores, expressing the pistol as counted
`mag` plus slotted `chamber`. Pure refactor.

**Three.** Express the pistol's existing behaviour as a `cycle` block and a `swap`
block, and replace the hardcoded `Hold` / `Release` / `Cycle` / `Racked` with the
interpreter. This is the pivot: after it the pistol is data-driven and behaves
identically, and the grammar has been proved by the weapon you already trust.

**Four.** Demote `role`, reference parts by id from verbs. The singleton problem
in `FindRole` disappears as a side effect.

**Five.** Move tuned values into the card, collapse the sliders to a scratch set,
add the bake netevent. Fixes the hand-keying bug and the part ceiling together.

**Six.** `PinHand` keys off `subject`; add the missing seat sets.

**Seven.** Build the `load` verb and single-round carry. First new capability, and
it unlocks four of the six mechanisms. The scaffolding is already framed —
`WM_LooseRound`, `GRIPSUBJ_Round` and `GRIPSUBJ_Shell`, the held-round placement
sets, and the currently dead `carried[h].IsRound()` branch in `PoseHand`. What is
shut is deliberate: `CatchFalling` filters rounds out, `CanSeat` rejects them, and
`SeatRefusal` has a written message for it.

**Eight.** Build the `open` verb and `return = stay`.

**Nine, ten, eleven.** Pump, then break, then revolver. Revolver last of the three
because slotted-indexed stores and a functional hammer are the most new ground.

**Twelve.** Bolt action, once section 10 is settled.

Two decisions want making before step one. Both cards currently carry
`take = no` on the magazine, so `NearestPart` skips it and pulling a magazine out
by hand is off *in data*; `wm_brace` defaults false, so bracing is off the same
way. Are those abandoned or parked? It changes whether the `swap` verb needs a
hand-take path at all, and whether `support` survives as a role.

---

## 10. What needs capability beyond the pk3

Two things, and only one of them is certain.

**The bolt handle's sequential DOF.** Lift then pull is two DOFs in sequence on
one surface, and `SetModelSurfaceDrive` takes one axis and one distance. Two
parts naming the same surface would each get a slot and fight, since the lowest
slot wins. There is a script-side answer that needs no engine change: a
two-stage DOF where the card declares both stages, `PartOffset` composes them by
mapping 0–0.5 to the first and 0.5–1 to the second, and the drive is handed off
at the midpoint — stop the stage-one drive, start the stage-two drive. Worth
trying before asking for anything native.

**The hand seat from card data.** For the hand to sit on a part at a point the
*card* names, in the weapon's own model space, the follow frame needs to accept
an offset expressed in parent model space — the follow frame otherwise drops the
parent's scale, mirror and MODELDEF base orientation, and the M4A3 is drawn at
Scale −0.82. Without it the seat stays what it is now: per-hand sliders someone
tuned by eye, which is tolerable at three seat kinds and is not at seven subjects
across six mechanism families. Whether that capability exists in the engine tree
is not something the pk3 can tell you; it is the one dependency worth confirming
before committing to step six.

---

## 11. What this does not fix

Sixteen surface slots per weapon is a ceiling, and the error path in `Bind` logs
and continues rather than refusing, so a weapon over budget silently loses its
later parts' movement. That should become a refusal, matching the parser's own
philosophy.

Two rigs, one per hand, with hand *h* always working gun *1−h*. Fine for dual
pistols, approximate for a two-handed long gun, and there is no notion of a
weapon that *requires* two hands — `PutAway` stows the working hand's own weapon,
correct for a pistol pair and wrong for a shotgun where that hand should simply be
empty.

Single-player. Everything reads `players[consoleplayer]`, `PlayerSpawned` acts
only on consoleplayer, and the netevents assume one player.

The interop with the hands package fails soft: the arbiter is found by string and
retried every 350 tics, and when it is absent `HandPartDepth` silently drops to a
point-in-oval test and `Claim` takes the hand anyway. That is the right call for
load safety — a hard class reference across pk3s is a fatal global load error —
but it means a broken contract degrades quietly instead of saying so. A loud
one-time startup assertion would cost nothing.

Loose magazines never despawn by design, and `CatchFalling`, `ForeignInHand` and
`PreviewMags` each walk the full `WM_LooseMag` thinker list per hand per tic, with
`WM_LooseRound` in the same iterator. Six walks a tic is nothing today. It is
worth revisiting before a system that drops individual shells and hulls
everywhere.
