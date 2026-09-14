# The Card: one model card per model, one weapon sheet per gun

Plan only, reload lane, 2026-09-14, at the owner's request, for the owner to hand to the weapons lane.
- **Nothing is built.**
- **It covers every gun,** Vanilla included. It isn't Vanilla+ work.
- **Commits:** the build lane.
- **Engine:** no changes needed. It's ZScript and data only.

---

## In plain words

- **Today a gun lives in two places:** its card in WMCARD.txt, and the numbers in its weapon class code (the
  Default block).
- **After the switch:**
  - a **model card** says how the physical gun works;
  - a **weapon sheet** says what it shoots;
  - a gun is a model card, a sheet, and a tiny class the game needs for its name.
- **No gun changes how it plays, looks or sounds.** The numbers are the same, proven by a printout of every gun
  before and after that must match exactly.
- **None of the owner's calibration is lost.** Hand seats, grab points, placement and the bake ledger keep their names
  (section 2).
- **Later, as its own step:** picking a different model or sheet for a gun inside the game (section 7).

---

## 1. What goes where

Step 1 turns this into the final table, one row per card key and class property, which the owner OKs. Keys whose home is
unclear (`casing`, `pouch`, the throwable blocks) stay on the model card for now.

| Model card: the physical gun, measured once | Weapon sheet: the design, quick to write | Stays in the tiny class |
|---|---|---|
| `prop`, `model`, `skin` | `model =` which model card it uses | `Weapon.SlotNumber`, `SelectionOrder` |
| Parts: surfaces, dofs, grabs, hand seats, round surfaces | `hand` (main or off) | `Weapon.AmmoType1` |
| Stores as built (kind, slots, indexed), verbs, `mechanism`, load zones | `capacity`, `firesfrom` | `Inventory.PickupMessage`, `PickupSound`, `MaxAmount`, `Weapon.UpSound` |
| `muzzle`, `barrel`, `ejectport`, `ejectdir` | `firesound` | Any code a class overrides (FireHeld, DoEffect and so on) |
| Magazine, round and link meshes, skins, scales, `magcenter` | Every `WM_Gun.*` property: ShotDamage, ShotPellets, ShotSpread, FireTics, FullAuto, FirstShotsAccurate, ChambersPerPull, RoundsPerShot, ShotClass, ShotRail, RailColors, ChargeTics, ChargeSound, ShotSaw, SawSounds, SawPuff, ReleaseTics, ScatterShot | |
| Handling sounds: dry, magazine out and in, slide, rack, open, close, load, eject, spin, pull, start, idle, stop | Looks: RoundProfile, FlashProfile, AltFlashProfile, EjectaProfile, TrailProfile | |
| `type` (hand calibration), `hands = 2`, `magfamily` (which magazines physically fit) | A second barrel's shot: `shotclass`, `ammo`, `firesound`, `firetics` | |
| A second barrel's geometry: `muzzle`, `barrel`, `trigger` part, `from` store, `needs` | | |

**Why the class keeps those lines:** the engine builds weapon slots, selection order and pickups from a class's
defaults at startup, before any sheet is read.

---

## 2. Names: nothing is renamed in the switch

- **Model card ids start as today's weapon class names** (`weapon "WM_Pistolet"` becomes the model card
  `WM_Pistolet`). These keep working unchanged:
  - the bake ledger (`WM_M4A3|part slide|grab = ...`);
  - `tools/bake_defaults.py --ledger --cards`;
  - the weapons lane's card_lint;
  - every part id.
- **A sheet with no `model` line** uses the model card with its own class's name.
- **Hand seats** (`wm_hs_<type>_<main|off>_<seat>`) are keyed by the card's `type`: unchanged.
- **Grab-point page** (`wm_gp_m0` ...): keyed by hand and slot: unchanged.
- **Placement** (`wm_<gun>_ofs_*`): read by the renderer from each prop class's MODELDEF, so it belongs to the model:
  unchanged.
- **Renaming model cards after their models** (say `python` for the Moonlight's mesh) is a later, separate choice. It
  needs the ledger and tools moved to the new keys.

---

## 3. The sheet, sketched

A separate lump, `WMSHEET`, so the two lanes edit different files. Keys are today's property names in lower case,
with the same meanings and no new ones:

```
gun "WM_Pistolet"
  model      = WM_Pistolet        # unset: the model card of this class's own name
  hand       = off
  capacity   = 15
  firesfrom  = chamber
  firesound  = "wm/pistolet/fire"
  shotdamage = 5, 15
  firetics   = 14
  fullauto   = no
  flashprofile  = "pistol_9mm"
  roundprofile  = "9mm"
  ejectaprofile = "brass_9mm"
end
```

(The values above only show the shape. The real ones are moved from the class and card in step 3.)

---

## 4. How it runs

- **Loading:** sheets load where the cards do, in `WM_System.LoadCards` at WorldLoaded on every machine, into the same
  `WM_CardSet`.
  - The set is saved with a game. A set from a save written before sheets is read again, the rule already used for
    saves from before verbs, gun types and throwables.
- **Applying:** a gun applies its sheet the first time it asks the system for its card (`CardForWeapon`, weapon.zs),
  never in BeginPlay.
  - Weapons placed in a map spawn before WorldLoaded loads the set.
  - The fire code reads each gun's own fields (`invoker.fireTicCount` and so on). Nothing reads gun numbers through
    `GetDefaultByType` (checked 09-14), so setting them on the gun changes nothing else.
- **Priority while both exist (step 3):** the sheet wins over the class default, and the check in section 5 lists
  every place they disagree.
- **Netplay:**
  - the data loads the same on every machine, and applies in the playsim the same way on every machine;
  - no RNG, no consoleplayer, no cvar reads;
  - a gun's numbers are identical everywhere.

---

## 5. The printout: "The Card", with n/a

- **`wm_card <class>`** in the console, or **`wm_card all`** to the log: every model card and sheet field for that gun.
  - Each field shows its value, or "default" or "n/a".
  - Each shows where it came from: sheet, card, archetype, synthesised or class default.
- **It is also the switch's proof:**
  - print every gun before step 2 and again after steps 3 and 4;
  - apart from the "came from" column, the two must be identical.
- **`wm_card check`:** lists every gun whose sheet value differs from its class default. It must be empty before step
  4 deletes the class lines.
- **card_lint** (weapons lane) learns the sheet: known keys, the model card exists, values in range.
- **Netplay:** prints only.

---

## 6. Steps, and who does each

| Step | Who | What | Proof |
|---|---|---|---|
| 1 | reload + weapons lanes, on paper | The final section 1 table: every card key and `WM_Gun` property marked model card, sheet or class. The owner OKs it. | the owner's yes |
| 2 | reload lane | The parser reads `WMSHEET`, a gun applies its sheet, plus `wm_card` and `wm_card check`. No sheet exists yet, so no gun changes. | compile check; `wm_card all` matches today's guns |
| 3 | weapons lane | `WMSHEET.txt` for all 34 carded guns, with today's numbers copied from each class's Default block and each card's gameplay keys. card_lint learns sheets. | `wm_card check` is empty; the printout is unchanged |
| 4 | weapons lane | The copied lines come out of the classes and cards. Each class keeps only section 1's last column. | printout unchanged; the fire rows of VANILLA_TEST_CHECKLIST in the headset |
| 5 | later, the owner's call | Picking cards in the game (section 7). | its own plan |

Each step is compile-checked, installed and committed by the build lane before the next starts. WMCARD edits follow
the usual one-lane-at-a-time rule.

---

## 7. Later: picking a different model or sheet in the game

- **What:** per gun, a menu or command picks which model card or which sheet it uses. Swapping the model changes the
  look and the reload; swapping the sheet changes the gun.
- **When it lands:** the next time that gun is drawn. The loaded rounds go back to the reserve, because a
  six-chamber cylinder and a 15-round magazine don't map onto each other.
- **What exists already:** a rig rebinds to a new card on its next tic (`LoadCards` relies on this).
  - The model card's `prop` brings its own placement.
  - Its `type` brings its own hand seats.
- **Netplay:** it changes gameplay, so every machine must agree. It goes through a network command applied on every
  machine, or a server setting, never a local-only read.
- **New files** from an HTML editor still need a restart, until a live reload is built (possibly engine work, planned
  separately).

---

## 8. What doesn't change

- How any gun plays, looks or sounds.
- The owner's calibration and saved tuning (section 2).
- RS_Ballistics: profile names are unchanged.
- NETPLAY_SPEC's rules and its P1/P2 plan.

## 9. Risks, and what catches them

| Risk | Caught by |
|---|---|
| A number copied wrong in step 3 | `wm_card check` and the before/after printout, before any commit |
| A class line deleted in step 4 that the sheet didn't cover | the printout's "came from" column turns to "default" for that field |
| An old save with no sheets | the set is read again (section 4) |
| A map weapon asking before the set loads | the sheet is applied when the gun first asks for its card (section 4) |

---

## 10. Choices for the owner

1. **The sheets in their own file** (`WMSHEET.txt`), or as blocks inside the card file?
   **Recommend: their own file,** so the two lanes stop editing the same file.
2. **Model cards keep today's gun class names for now?**
   **Recommend: yes.** The bake ledger and tools keep working, and nothing calibrated is lost.
3. **Slot, ammo type and pickup message stay in the tiny class for now?**
   **Recommend: yes.** The engine reads them before any sheet loads.
4. **Picking cards in the game** as its own step after the switch?
   **Recommend: yes.**
