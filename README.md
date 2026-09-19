# RS_VR_Reload

**Hand-driven VR reloading for the UZDXREMA (DoomXR) mod family.** Every part of a gun that a hand works (a slide,
a magazine, a pump, a break-open barrel, a revolver's crane, cylinder and ejector, a ripcord) is described by
data. The reload system reads that data, drives the model's own surfaces under your hands, and keeps the ammunition
honest:

- a chambered round is separate from the magazine;
- loose magazines and rounds fall, can be caught, thrown, put back in the pouch or seated;
- revolvers and break-actions dump their cases when tilted;
- a flick shuts an open gun;
- and more: second barrels, charge-up shots, saws, spinning barrels, fill meters, latches.

It carries **no guns**. The guns are **RS_VR_Weapons**.

## Requirements

- **UZDXREMA**, a VR fork of GZDoom. The reload system calls about twenty engine features stock GZDoom doesn't have
  (controller-following models, surface drives, haptics, per-actor placement sets, off-hand buttons), so it does
  not run on stock GZDoom.
- **RS_Ballistics**, loaded before it. The guns' rounds, muzzle flashes, casings and impacts are RS_Ballistics'.

## Load order

1. `RS_Ballistics`
2. `RS_VR_Reload`
3. `RS_VR_Weapons`

Load them explicitly. Nothing here autoloads.

## How it works

- **Cards.** A weapon package ships a `WMCARD` lump with one block per gun. It names the gun's parts, where they are
  on the model and how far they move, its ammunition stores, and the actions a hand performs: `cycle`, `open`,
  `swap`, `load`, `eject`, `start`.
- **Archetypes.** This package's `WMCARD.txt` holds the shared ones: `pump`, `breaktop_revolver`,
  `swingout_revolver` and `breakaction`. A gun takes one with `mechanism = <name>` and states only its own
  geometry. A plain slide-and-magazine gun needs no archetype.
- **The grammar** is `zscript/wm/parser.zs`: every key, and the reason any bad card is refused. The archetypes here
  and the guns in RS_VR_Weapons are worked examples.

## In game

- **Options → VR Weapon Mechanisms:** grab points (with Bake, to write a tuned grab oval back into its card), hand
  seats per kind of gun, held ammunition, the pouches, firing and brass, and how far back an action still counts
  as closed.
- **Console:** `netevent wm_dump` prints the full state of both guns; `netevent wm_selftest` re-runs the setup checks.

## Building

```
powershell -File build.ps1
```

`build.ps1` lints the menus, packs `RS_VR_Reload.pk3` from an allowlist, verifies the entries, compile-checks it
with RS_Ballistics loaded first, and installs it only when that passes.

The tool paths it and `run.ps1` use (`E:\DOOMWork\tools\...`, the engine build folder) are the author's local
layout; change them to yours.

## Netplay

- **The rules it keeps:** no playsim RNG on a path that runs on one machine, and anything that changes the game is
  keyed by the gun's owner, never the console player.
- **Status:** made for single-player today. The hands are local, so carded guns desync in a netgame. The fix is
  specified in `NETPLAY_SPEC.md`.

## Credits

- **Sounds:**
  - the dry click (`AKEMPT`) and casings (`DSCASIN1`-`3`) come from the author's ART SOURCE collection;
  - the magazine drops (`DSBOUNC1`-`3`) from RS_Main's `combatfx` sounds.
- **Sprites:**
  - `WMCS` (the belt link's frame) is from RS_Main's `combatfx` sprites;
  - the placeholder sprites (`WMMG`, `WMMK`, `WMPR`, `WMRD`) and the marker skins are generated flat swatches;
  - `rs_wiresphere.obj` is a generated three-ring mesh.
- **Rounds, flashes, casings and impacts:** RS_Ballistics'.

## Dev notes

These are working documents, kept as written. Several are from when this package was called RS_VR_PistolTest.

| File | What it is |
|---|---|
| `FEEL_PLAN.md` | the build record: one row per step, with what compiled and when |
| `NETPLAY_SPEC.md` | the netplay design, its open decisions, and the client-side looks note |
| `BUILD.md` | the full build spec for making the system universal |
| `ACCEPTANCE.md` | the original finish line for the pistol reload loop |
| `UNIVERSAL.md`, `CARDS_ON_PAPER.md`, `MECHANISMS.md` | the design history behind the card grammar |
| `PASSING.md`, `GESTURES-INTEGRATION.md`, `SHOTGUN_CANDIDATES.md` | notes on neighbouring work |
| `HANDOFF.md`, `BUILD-1-3.md` | superseded handoff notes |
| `PUBLISH_CHECKLIST.md` | what making this repo public needed |
| `THROWABLE_PLAN.md` | the design for throwable weapons: a grenade and a returning shield saw |
