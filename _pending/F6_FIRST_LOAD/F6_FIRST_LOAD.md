# F6: a picked-up gun loads from its own pickup's ammo (DRAFT, not installed)

**Status: PARKED by the owner 2026-09-14** ("we can do both but we don't have to wire either one right now ... we will
come back to it"). This is a draft only: it is not in RS_VR_Reload's working tree and not installed.

**Compile-checked on a scratch copy of RS_VR_Reload at 4aa2fb1:** COMPILED, script parsing took 824.78 ms, exe 09-14 07:09.
It installed only into that scratch copy. To use it later, apply `F6.patch` (from the RS_VR_Reload root:
`git apply _pending/F6_FIRST_LOAD/F6.patch`) and check it again against the tree as it is then. The weapons lane's half
below is still to write.

**The problem (VANILLA_PARITY G5):** a gun's first bind fills every store for free, and its pickup's ammo goes to
the reserve on top. A BFG pickup is 40 cells in Doom and 200 here; a chaingun is 20 against 120.

**The recommendation:** the first fill comes from what the pickup gave. The start pistols stay full.

## How it works

- **The pickup offers its ammo to the gun first,** before handing the gun over, on every machine (playsim):
  `int took = WM_Gun(gun).TakeFirstLoad(amount)`. The gun keeps up to what its main barrel holds, and the pickup
  gives `amount - took` to the reserve.
- **`WM_Gun.TakeFirstLoad`** reads only the class's card (loaded on every machine). It sizes a full gun and records
  `firstLoadSet` / `firstLoadRounds` on the weapon. It returns 0 for a gun that has already been in a hand, or one
  that keeps no rounds (firesfrom reserve or none).
- **`WM_Rig.Bind`, fresh gun:** after `Init`, `ammo.LoadFirst(firstLoadRounds, card)` when one was set. That empties
  the main barrel's stores, then fills the chamber first, then the magazine, then any other store of the gun's own.
  A second barrel's store (the Machine Gun's grenade) is left as Init filled it (F5 is separate).
- **A gun given any other way never sets it and comes full, as today:** the start pistols (the owner's full
  magazine), `Player.StartItem`, the wm_give* commands and the test arsenal. No special case is needed.

**What a pickup would give** (Doom's AmmoGive, before skill, drop and deathmatch factors, which apply first as
today):

| Pickup | Gun gets | Reserve gets | Doom |
|---|---|---|---|
| Pistol pair, Clip 20 | 16 (15 + 1) | 4 | 20 |
| Shotgun pair, Shell 8 | 8 (chamber 1 + tube 7) | 0 | 8 |
| Super shotgun pair, Shell 8 | 2 | 6 | 8 |
| Chaingun pair, Clip 20 | Chaingun 20 of 100; Machine Gun 0 (reserve-fed) | 0 / 20 | 20 |
| Rocket pair, RocketAmmo 2 | 2 of 6 | 0 | 2 |
| Plasma pair, Cell 40 | 40 of 50 | 0 | 40 |
| BFG pair, Cell 40 | 40 of 160 (one shot) | 0 | 40 |

## Files

- **Reload lane, drafted and compile-checked on the scratch copy** (`F6.patch` beside this note, against 4aa2fb1):
  - `zscript/wm/weapon.zs`: WM_Gun `firstLoadSet`, `firstLoadRounds`, `TakeFirstLoad`;
  - `zscript/wm/ammo.zs`: WM_Ammo `MainRounds`, `LoadFirst`, `LoadInto`, `MainStore`;
  - `zscript/wm/rig.zs`: Bind's fresh path.
- **Weapons lane, proposed only** (their file, not compiled here). In `weaponset.zs` `WM_PairPickup.TryPickup`:
  1. Split `GiveAmmoTo` into the amount (with its deathmatch and skill factors) and the give.
  2. When a gun is coming (`next`), spawn it first and call `TakeFirstLoad(amount)` on it.
  3. Give `amount - took` to the reserve. The "both carried and the reserve full, it stays" rule is unchanged.
  4. If `CallTryPickup` fails and the gun is destroyed, give `took` back to the reserve.

## Netplay

- **Deterministic:** the split happens in the pickup's own TryPickup, which runs on every machine alike. It reads
  only the card and the pickup's amount, keyed to the toucher, with no RNG and no console player.
- **Stores stay local, as today:** the gun's store contents are still made in the local rig's Bind, until P1 moves
  WM_Ammo onto the weapon on every machine.
