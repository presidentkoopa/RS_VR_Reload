# Cards on paper — a pump and a break action in today's grammar

Written 2026-09-12. Step zero of UNIVERSAL.md section 9: write the next two
mechanisms as cards using only what the parser accepts today, and list every line
that cannot be written. **That list is the specification for the rebuild.**
Nothing in the code changed.

Numbers marked `MEASURE` are placeholders; they come from `tools/md3.py` on a real
mesh once one is chosen. The gaps do not depend on them.

Every "✗" names the code that blocks it, as of RS_VR_PistolTest 9d1b42c.

Decisions taken for this pass (owner, 2026-09-12): hand-pulling a magazine
(`take = no`) and bracing (`wm_brace`) are **parked, not abandoned**. So `swap`
keeps a hand-take path, and `support` survives as a concept.

---

## 1. Pump shotgun

```
weapon "WM_Pump"
  hand      = main
  prop      = "WM_PropPump"
  model     = "models" "pump.md3"                 # MEASURE
  capacity  = 6                                   # ✓ key exists -- but see G1
  magfamily = "12ga"                              # ✓ key exists
  muzzle    = MEASURE
  barrel    = 1, 0, 0
  ejectport = MEASURE
  ejectdir  = MEASURE
  roundmodel = "models" "shell.md3"               # ✓ the hull, as a "round"
  firesound  = "wm/pump/fire"
  rackapexsound  = "wm/pump/back"                 # ✓
  rackresetsound = "wm/pump/forward"              # ✓

  pellets   = 8                                   # ✗ G9
  spread    = 6, 4                                # ✗ G9
  hands     = 2                                   # ✗ G10
end

part forend
  role    = action                                # ✓ -- but see G3, G4, G5
  subject = forend                                # ✓ GRIPSUBJ_Forend exists
  surface = pump_forend
  grab     = MEASURE
  grabsize = MEASURE
  dof
    kind     = slide
    axis     = -1, 0, 0
    distance = MEASURE
  end
  cycle    = manual                               # ✗ G3
  return   = hand                                 # ✗ G4
  onback   = eject chamber                        # ✗ G5
  onfront  = feed tube -> chamber                 # ✗ G5
end

part tube                                         # ✗ G1 -- no store that is not a magazine
  store    = counted, fixed                       # ✗ G1
  capacity = 6
end

part loadgate                                     # ✗ G6 -- a second feed-like part
  role    = feed                                  # ✗ FindRoleIndex returns the first only
  subject = shell
  surface = pump_gate
  grab    = MEASURE
  accepts = round 12ga -> tube                    # ✗ G2
end

part trigger
  role    = trigger                               # ✓
  surface = pump_trigger
  dof
    kind = hinge ...                              # ✓
  end
end
```

## 2. Break-action double (SSG)

```
weapon "WM_SSG"
  hand      = main
  prop      = "WM_PropSSG"
  model     = "models" "ssg.md3"                  # MEASURE
  capacity  = 2                                   # ✓ key exists -- but it is not one count, see G7
  magfamily = "12ga"
  muzzle    = MEASURE                             # ✗ two muzzles, G8
  roundmodel = "models" "shell.md3"
  pellets   = 7                                   # ✗ G9
  hands     = 2                                   # ✗ G10
end

part barrels
  role    = action                                # ✗ it is not a cycling action -- G11
  subject = foregrip
  surface = ssg_barrels
  surface = ssg_forend                            # ✓ several surfaces move as one part
  grab    = MEASURE
  dof
    kind    = hinge                               # ✓
    axis    = 0, 1, 0
    degrees = 40                                  # MEASURE
    pivot   = MEASURE
    rest    = 0                                   # ✓ parsed -- but read by NOTHING, see G12
  end
  return   = stay                                 # ✗ G12
  locked   = until latch                          # ✗ G13
  onopen   = eject spent chamber*                 # ✗ G14
  closeby  = flick                                # ✗ G15
end

part latch
  role    = lever                                 # ✗ no role, G13
  surface = ssg_toplever
  dof
    kind    = hinge ...                           # ✓
  end
end

part chambers                                     # ✗ G7
  store = slotted, 2, selected by trigger
  well  = MEASURE, MEASURE                        # ✗ one well point per gun, G6
  accepts = round 12ga                            # ✗ G2
end

part hammer_l                                     # ✗ one hammer role per gun, G6
part hammer_r
```

---

## 3. The gaps

Grouped by the verb they need (UNIVERSAL.md's five: cycle, open/close, swap,
load, eject). Numbered G1–G16 so later work can cite them.

### Ammunition model

- **G1. No store that is not a magazine.** `WM_Ammo` is four fields — `rounds`,
  `chambered`, `magIn`, `actionLock` — and one `capacity`. A fixed tube has no
  `magIn`, and `Fire()` sets `actionLock` whenever the magazine is empty, which
  on a pump would lock the forend back. (`ammo.zs Fire`, `Cycle`.)
- **G7. No slotted store.** `chambered` is one bool. Two barrels, each live or
  spent and chosen by trigger, and a revolver cylinder are not counts.
- **G2. No `load`.** Nothing puts one round into a store. `CatchFalling` filters
  rounds out, `CanSeat` rejects them, and `SeatRefusal` has a written refusal for
  "a loose round, not a magazine". `WM_LooseRound`, `GRIPSUBJ_Round`/`_Shell` and
  the held-round placement sets exist and are unused. **Pump and break both need
  it; this is the highest-leverage single build.**

### Cycle

- **G3. Every action is automatic.** `OnShot` starts `cycleTics` whenever an
  `action` part exists and `rig.Cycle()` animates it back and forth; a pump's
  forend must not move on firing. No card key says manual.
- **G4. Every action springs home.** `Release()` writes
  `part.value = actionLock ? 1 : 0` on letting go. A forend is returned by the
  hand; a break action stays open.
- **G5. A rack is one event.** `Release()` calls `Racked()` once, past 0.6, and
  `WM_Ammo.Cycle()` ejects and chambers in the same call. A pump ejects at the
  back of the stroke and chambers at the front; a half stroke must do half.
- **G16. No "in battery" rule.** `CanFire` is `chambered && !actionLock`, so a gun
  with its forend halfway back, or broken open, still fires.

### Parts and roles

- **G6. One part per role.** `FindRole` / `FindRoleIndex` return the first match,
  and `WellPoint`, `SeatedPoint`, `Guide`, `DropMagazine`, `Hold` and the menu all
  key off `"feed"` / `"action"`. A second feed-like part (a load gate), two
  hammers or two wells cannot be declared. UNIVERSAL.md step four (verbs name
  parts by id) removes this.
- **G11. Roles hard-code behaviour.** 30+ `role == "..."` tests across `rig.zs`
  and `system.zs`, plus `menu.zs:103`, decide what a part *does*. A break action's
  barrels are neither `action` nor `feed`.
- **G12. `rest` is parsed and unused.** `DofKey` reads `rest` into `WM_Dof.rest`;
  nothing reads it back. No part can have a held-open state.
- **G13. No condition between parts.** No way to say "the barrels only open while
  the latch is pushed", or "the forend is locked until the trigger is released".

### Eject, grip and the weapon

- **G14. Ejection is only a rack.** `EjectRound` throws a live round on a rack;
  `Brass` throws a casing per shot. Nothing ejects spent hulls when an action
  opens past a point.
- **G15. No gesture closes a part.** Closing a break action with a flick of the
  wrist needs the hand's velocity to drive a part. `HandVel` exists; nothing uses
  it for parts.
- **G8. One muzzle.** `muzzle` / `barrel` are single; flash, sparks and aim all
  assume one bore.
- **G9. The shot is not in the card.** `WM_Gun.WM_TryFire` hard-codes
  `A_FireBullets(5.6, 0, 1, 5, "BulletPuff")`: one bullet, fixed spread and damage.
  Pellets, spread, damage and puff belong on the card.
- **G10. One gun per hand, always.** Two rigs, and hand *h* always works gun
  *1−h*; `PutAway` stows the working hand's own gun. A two-handed weapon needs
  `hands = 2`: the second hand is on the gun, not holding another.

### Carried over, not new

- **The hand seat cannot come from the card.** `FollowActorOfsInModel` is proposed
  in HANDOFF.md and **not in the engine** (checked 2026-09-12). Seats stay per
  hand-slot × part-index sliders tuned by eye. Tolerable for a pump forend and
  SSG barrels; not at seven subjects across six families.
- **Palm direction per part** is one global (`wm_palm_cos`), not in the card.
- **Cycle timing** (`wm_cycle_tics`, `wm_recoil_travel`) is global, not per card.
- **16 surface slots** per gun is enough for both of these.

---

## 4. What this says about order

Unchanged from UNIVERSAL.md section 9, now with the evidence:

1. Steps one to three (collapse per-hand state, named stores, cycle/swap
   interpreter) cover G1, G3, G4, G5, G7, G16 — **and change nothing in the
   headset for the pistols**, so each is testable against today's behaviour.
2. Step four (verbs name parts) covers G6 and G11.
3. Step seven, `load`, covers G2, and unlocks both guns above.
4. Step eight, `open` with `return = stay`, covers G12, G13 and G14.
5. G9 (the shot in the card) and G10 (two-handed) are small and independent; they
   can go in whenever a long gun is first loaded.
6. G15 (flick to close) is polish after the break action works with a hand close.
