# Vanilla+ mechanics: what the reload system needs

Doc only, reload lane, 2026-09-14. It's for the build lane (doomwork-5e) to relay when the owner turns to Vanilla+.
**Nothing here is built.**

- **Companion doc:** `RS_VR_Weapons/_pending/VANILLA_PLUS_SET.md` (weapons lane). It covers the gun list, slots,
  pickups, sounds, looks and each card's grab status.
- **This doc covers** how the guns work in the hands: alt fires, fire modes, checks, bolt release, launcher reloads,
  speedloaders, the pump toss, and the card itself.

---

## In plain words

- **Most Vanilla+ guns already reload by hand today:**
  - box magazines drop by the button and seat by hand;
  - bolts rack, and lock back on an empty magazine;
  - revolvers open, dump and take a speedloader;
  - the Machine Gun's launcher opens, loads and fires.
- **What's missing is mostly modern handling:**
  - a fire-mode switch;
  - checking a magazine or chamber;
  - a bolt release;
  - a reload for the two rotary guns;
  - alt fires beyond the one launcher.
- **Each should be built once, as a general card feature,** never as code for one gun.
- **The owner's direction today (section 3):** one card per model, saying how the physical gun works, plus a small
  weapon sheet saying what it shoots. Recommended as the first Vanilla+ job, so every Vanilla+ gun is built that way
  from the start.

---

## 1. What works today, by kind of gun

Read from WMCARD.txt, the weapon classes and the reload code on 09-14.

- **Synthesised** means the card declares no verbs, so the reload system builds them from the card's action and feed
  parts, with the pistol's numbers.
- **Full auto** is the class's `WM_Gun.FullAuto`, fixed per gun.

| Kind | Guns | How it works today | Missing for Vanilla+ |
|---|---|---|---|
| **Box-magazine rifle** | Rifle, M16 | Synthesised:<br>• the magazine drops by the drop-mag button and seats by hand;<br>• the charging handle racks;<br>• it locks back when the magazine runs dry;<br>• racking a locked-back gun with a loaded magazine in chambers a round.<br>Both full auto only. | Fire-mode switch, bolt release, magazine check, chamber check. Their own cycle feel: they use the pistol's thresholds. |
| **SMG** | SMG, Tec9 | SMG: its own `cycle rack` (holds open when empty, cycles on the shot) and `swap magwell`. Tec9: synthesised. Both full auto. | As the rifles. |
| **Magazine shotgun** | Assault Shotgun | Synthesised: box magazine and charging handle, as the rifles. Full auto, 28 tics a shot. | Fire-mode switch, bolt release, checks. Its own hand seats: it shares the pump shotguns' today (section 4.2). |
| **Revolver** | Moonlight, Sunset (`breaktop_revolver`), Cola (`swingout_revolver`) | • Open by hand or by the drop-mag button; a flick shuts it.<br>• Cases fall out when the open gun is tilted (break-top) or muzzle up (swing-out).<br>• **A speedloader at the cylinder's rear face fills every empty chamber at once; one loose round fills one.**<br>• The pouch hands a revolver a loader.<br>• The cylinder turns on the shot, and the trigger cocks the hammer. | Nothing mechanical. The break-top and swing-out revolvers share one hand calibration (section 4.2). Options: thumb-cocking the hammer, spinning the cylinder by hand. |
| **Flamethrower** | Flamer, Flamethrower | Fire from the canister, with no chamber. The canister drops by the button and seats by hand. The Flamethrower's swap waits on its lever latch. Both full auto. | Nothing mechanical. Grab estimates (weapons lane's table). |
| **Cell gun** | Railgun, Bolter, BFG Rifle, Unmaker | Fire straight from the cell. The cell drops by the button and seats by hand. | Nothing mechanical. The BFG Rifle's charge look is the ballistics lane's. |
| **Grenade launcher** | the Machine Gun's underbarrel (alt fire) | `open breech`: the latch springs back, and opening throws out what's in it. `load grenade` from the pouch while open. `barrel launcher` on alt fire fires only when shut. Grabs measured 09-14. | A standalone launcher: RS_Main's M79 model is parked with the model pause. Once a model exists it is a card only: the `breakaction` archetype, a one-slot store and a grenade shot. |
| **Rocket launcher** | Rocket Launcher (vanilla), Rotary Launcher | The Rocket Launcher swaps its rack. **The Rotary Launcher fires from the reserve: it has no reload at all.** Its tubes spin as a look only. | A Rotary Launcher reload (section 2.6). |
| **Rotary gun** | Rotary Gun | **Fires from the reserve: no reload.** Full auto. | A box or belt swap, as the vanilla Chaingun's (section 2.6). |
| **Saw** | Longbar Chainsaw | No rounds, no ripcord; its own idle. | Nothing. |

**The three buttons a hand has today:** fire, alt fire and drop-mag. All three are in use. A new input (a fire-mode
switch, say) has to be a part the other hand works, or share one of those buttons.

---

## 2. The missing pieces, as general card features

Each item: what it does, a grammar sketch (not final), what the weapon class needs, netplay, and a rough size.

### 2.1 More alt fires

- **Today:** a `barrel <id>` block is a second barrel with:
  - its own store, trigger part, shot, muzzle and sound;
  - `needs` (for example, fire only when shut);
  - `input = altfire`, the only input, one barrel per input.
  - That covers any underbarrel launcher.
- **Missing, as the owner designs each gun's alt fire:**
  - **A second shot from the main magazine:** an overcharged rail shot, a slug, a burst. It needs a barrel whose
    `from` is the gun's own feed store, with its own rounds per shot, charge and shot class. Check first whether the
    parser allows a barrel to name the main store; today's one user has its own.
  - **An alt fire that is not a shot:** the fire-mode switch (2.2), or a bash. It needs `input = altfire` on a block
    other than `barrel`.
- **Weapon class:** alt-fire rounds per shot and charge, mirroring the main shot's properties.
- **Netplay:** the fire action already reads the owner's usercmd and pays inside the fire action. The same rules apply.
- **Size:** small to medium.

### 2.2 A fire-mode switch (semi / burst / auto)

- **Today:** `WM_Gun.FullAuto` is fixed per class. The Rifle, M16, SMG, Tec9, Assault Shotgun and Rotary Gun are
  full auto only, and nothing fires a burst.
- **Grammar sketch:**
  ```
  selector
    modes = semi, burst 3, auto      # the order the switch steps through; the first is where it starts
    part  = selector                 # optional: a hinge part with one detent a mode, flicked by a hand
    input = altfire                  # optional instead: for a gun with no second barrel
  end
  ```
- **Weapon class:** `FullAuto` becomes "the mode when the card has no selector". A burst count stops the refire after
  N shots.
- **Input:** no button is free (section 1). The choices:
  - the other hand flips a switch on the model;
  - alt fire, on guns with no second barrel.
- **Netplay:** the mode is gameplay state. It lives on the weapon (NETPLAY_SPEC P1) and is changed by a command
  (P2), like a rack. The refire check reads it inside the fire action, the same on every machine. Never a local
  cvar.
- **Size:** medium.

### 2.3 Checking a magazine

- **Today:** a magazine pulled part-way, short of `detachat`, can go back in. It shows its rounds only where the
  magazine mesh has round surfaces (`roundsurface`) or a meter (`metersurface`).
- **Sketch:** on a swap, `check = haptic`: while the magazine is part-way out, one buzz per N rounds (or a long buzz
  for full and a short one for low). No new state.
- **Netplay:** looks and haptics only, local. Safe today.
- **Size:** small.

### 2.4 Checking the chamber

- **Today:** pulling the action past `outat` throws the chambered round out. Short of that, nothing shows whether
  one is there.
- **Sketch:** on a cycle, `peekat = 0.3` and `chambersurface = <surface>`. The round is drawn in the port while the
  action is between `peekat` and `outat` and the chamber holds a live round. A buzz as it shows.
- **Netplay:** looks only, local. Safe today.
- **Size:** small. It needs a round surface near the port on each mesh, which is card work per model.

### 2.5 Bolt catch and bolt release

- **Today:** the catch works. Every synthesised cycle, and the SMG's declared one, holds open when there was nothing
  to feed. The only way to close it is to rack it again with a loaded magazine in: seating a magazine leaves the
  bolt back ("Rack the slide.").
- **Missing:** a release, one of these:
  - a part on the model (a lever or paddle) the hand presses;
  - a tap of the drop-mag button while locked back with a loaded magazine in;
  - closing by itself as the magazine seats (arcade).
- **Sketch:** on a cycle, `boltrelease = part <id> | button | onseat`. Not `release`: that's already the grenade
  lever's verb.
- **Netplay:** a store change (it chambers a round), so it's a command like a rack in P2.
- **Size:** small.

### 2.6 Launcher and rotary reloads

- **Rotary Launcher:** probably card only, no new code, using the grammar the revolvers already have:
  - a slotted store of six, indexed and turning on the shot;
  - `firesfrom` the store instead of the reserve;
  - one `load` at the tubes' rear, one rocket at a time from the pouch.
  - Or, if the owner prefers: swap the whole cluster as one magazine.
  - Check the mesh first: the tubes' rear faces must be reachable.
- **Rotary Gun:** a box or belt swap, as the vanilla Chaingun's (a counted store, `swap`, belt links). Card work.
- **A standalone grenade launcher:** see section 1. A card on the `breakaction` archetype once a model is picked,
  after the model pause.
- **Netplay:** the same as every store today. Stores are still local until P1; loads become commands in P2.
- **Size:** small (cards), plus the weapons lane's sounds.

### 2.7 Speedloaders

- **Built** in both revolver archetypes (section 1).
- Vanilla+ needs only the headset pass: a full loader, a part loader from a short reserve, and a loose round.
- Nothing new is proposed.

---

## 3. The one card, and the weapon sheet (the owner, 2026-09-14)

**The owner's words:**
- "i don't want 'these cards' 'those cards' i just want The Card".
- Once a model's surfaces are understood, it works the same whatever gun it's coded to be.

**Today a gun is two things:**
- its card: parts, surfaces, stores, verbs, grabs, magazine and round meshes, handling sounds, and also capacity,
  `firesfrom` and the second barrel's shot;
- its class's Default block: damage, pellets, spread, fire tics, full auto, charge, rail, saw, shot class and the
  look profiles.

**The proposal:** a **model card** says only what the physical gun is, and a **weapon sheet** says what it shoots. A
gun is "this model card + this sheet".

| Model card (the physical gun: measured once) | Weapon sheet (the design: quick to write) |
|---|---|
| Parts, surfaces, dofs, grabs, hand seats, `type` (hand calibration) | Main or off hand |
| Stores as built: magazine well, tube, cylinder size | Ammo type, capacity (a skull that holds 100), `firesfrom` |
| Verbs or archetype: how it reloads | Damage, pellets, spread, fire rate, modes (2.2), charge, rail, saw or projectile |
| Muzzle, eject port, load zones, magazine and round meshes | Alt fire's shot (2.1) |
| Handling sounds: magazine out and in, rack, open, close | Fire sound, look profiles (RS_Ballistics) |

**What that gives:**
- **Each model is measured once.** Every gun on it gets the reload, grabs and calibration for free. That's the
  pipeline for the owner's ~100 models and many sets.
- **A new gun is a few lines,** with no code and no measuring. Vanilla and Vanilla+ can be different sheets on the
  same models.
- **Changes can't break each other:** a damage tune can't break a reload, and a re-measured grab can't change
  balance. The two lanes stop sharing one file.
- **"The Card" with n/a:** a printout tool that shows every field for any gun, as its value or "n/a / default". The
  files stay short.
- **An HTML editor** (the owner's idea): a sheet is small and flat, so an editor can pick a model, set the numbers and
  export the sheet. That comes later.

**Build shape:**
- **(a) Recommended:** a sheet lump read by the same parser, which WM_Gun reads instead of its Default properties.
  Each gun keeps a three-line class, because the game needs a named class per weapon; the editor could export that
  too.
- **(b)** A tool writes today's Default blocks from the sheets.

**Other mods' guns:** the owner is taking "our models on another mod's guns, with reloading" to ModelSwapper. Only
the reload side is listed here, for then:
- which of that mod's weapons a model card serves;
- where that mod keeps the loaded rounds and the reserve;
- how its own reload is switched off.

**Netplay:** cards and sheets are data that load the same on every machine. Nothing is per player.

**Size:** medium to large. It covers the parser, WM_Gun's property path, and moving about 38 classes and cards. It
comes after Vanilla done, so the Vanilla set isn't disturbed mid-test.

---

## 4. Parked items, as options (not decisions)

### 4.1 The one-handed pump toss

- **The move** (the owner, "doesn't have to be now"): fire one-handed, toss the gun forward, catch it by the forend
  so the catch strokes the pump, then toss it back to the grip.
- **What it rests on:**
  - **Throwing and catching a held gun.** The throwable grammar's parser half is in (throw.zs). Its play half isn't
    built (THROWABLE_PLAN §8 steps 3-5).
  - **A throwable today is a weapon that leaves as its shot.** A toss you keep is a new `throw` use: it doesn't
    spend, and it's caught in a chosen grip.
  - **A catch that seats the hand on the forend** and drives the pump's cycle from the catch's motion.
- **Options:**
  - **(a) The real move:** after throwable steps 3-5.
  - **(b) A quick stand-in:** a sharp downward flick of the gun with the forend free strokes the pump, like
    flick-to-close.
- **Netplay:** hand speed reads zero in a netgame (NETPLAY_SPEC problem 9). Either option must measure on the owner's
  machine and send a command, as `wm_throw` does.

### 4.2 The hand-seat subtype split

- **The plan** (build lane approved, nothing written):
  - **Five subtypes:** shotgun_sideload (Doom pump), shotgun_bottomload (M37A2, Bullpup Pump), shotgun_magazine
    (Assault Shotgun), revolver_breaktop (Moonlight, Sunset), revolver_swingout (Cola).
  - **Fallback by declaration:** a subtype with no declared set reads its base type, then the default. Never compare
    values against the default.
  - **The revolver archetypes** derive their subtype; the held-ammo sets don't split.
- **Why it matters for Vanilla+:** the Assault Shotgun and the Cola would otherwise share hand seats with guns held
  quite differently. Calibrating them before the split means calibrating them twice.
- **Netplay:** hand seats are placement, local to each player's own hands. They decide no gameplay.

### 4.3 F6: the first load comes from the pickup

- **Drafted:** `_pending/F6_FIRST_LOAD/` (patch plus note, compile-checked on a scratch copy at 4aa2fb1).
- **How it works:** the pickup's ammo fills the gun first, and the rest goes to the reserve. The start guns come full.
- **Vanilla+ angle:** the new pickup pairs (weapons lane's section 4) would need the weapons lane's half of F6 in the
  same pass.
- **Netplay:** the split runs in the pickup's own TryPickup, the same on every machine. Stores stay local until P1.

---

## 5. Netplay at a glance

| Item | Changes gameplay state? | Safe today? | Waits on |
|---|---|---|---|
| 2.1 alt fires | yes, a shot and its rounds | as safe as today's fire path | P1/P2, like every shot |
| 2.2 fire-mode switch | yes, the mode | no | P1 (mode on the weapon), P2 (the command) |
| 2.3 magazine check | no, looks and haptics | yes | nothing |
| 2.4 chamber check | no, looks | yes | nothing |
| 2.5 bolt release | yes, it chambers | as a rack is | P2 |
| 2.6 launcher and rotary reloads | yes, stores | as every store is | P1/P2 |
| 3 model card and weapon sheet | no, data loaded everywhere | yes | nothing |
| 4.1 pump toss | yes, the pump's cycle | no, it reads hand speed | throwable steps 3-5, a command |
| 4.2 hand-seat split | no, local placement | yes | nothing |
| 4.3 F6 | yes, starting rounds | yes, the split is deterministic | P1 for the stores |

**The rules:**
- NETPLAY_SPEC §3 applies throughout: no playsim RNG on local paths, and gameplay is keyed to the owner, never
  consoleplayer.
- The owner won't play netgames until P2 lands (§10), so nothing here needs a netgame gate.

---

## 6. A suggested order (the build lane orders the work)

1. **The model card and weapon sheet (3),** first thing after Vanilla done.
2. **The hand-seat split (4.2),** before any Vanilla+ gun is calibrated.
3. **The fire-mode switch and bolt release (2.2, 2.5):** the modern-handling core, used by six guns.
4. **Magazine and chamber checks (2.3, 2.4):** small, looks only.
5. **The Rotary Launcher and Rotary Gun reloads (2.6):** cards, if the grammar holds.
6. **Alt fires (2.1),** as the owner designs each gun's.
7. **The pump toss (4.1),** after the throwable's play half.

NETPLAY P1/P2 keep their own place in the build lane's order. Items 3, 5 and 6 add commands to P2's list.

---

## 7. Choices for the owner

1. **One card per model, plus a weapon sheet per gun.** Build it first thing in Vanilla+?
   **Recommend: yes.** Every Vanilla+ gun then starts as a few lines.
2. **Changing fire modes:**
   - flip the switch on the gun with your other hand;
   - use alt fire;
   - or each gun keeps one mode.
   **Recommend:** flip the switch on the model where the model has one. Guns without one keep one mode.
3. **A locked-back bolt with a fresh magazine in:**
   - rack it (today);
   - hit a release on the gun;
   - or it closes by itself.
   **Recommend:** keep racking, and add the release on guns whose model has one.
4. **Magazine and chamber checks:** a buzz count and the round showing in the port, or skip them?
   **Recommend: add them.** They're cheap and change no gameplay.
5. **The Rotary Launcher and Rotary Gun:** give them a reload, or leave them feeding from your reserve?
   **Recommend: a reload:** rocket by rocket into the tubes, and a box swap on the gun.
6. **Split shotgun and revolver calibration** before you calibrate the Vanilla+ guns?
   **Recommend: yes,** or the Assault Shotgun and Cola get calibrated twice.
7. **A picked-up gun's first load (F6):** from its pickup in both sets, Vanilla+ only, or neither?
   **Recommend: both sets,** wired together with the Vanilla+ pickups.
8. **The one-handed pump toss:** wait for real throw and catch, or a quick flick version sooner?
   **Recommend: wait** for the real one.
