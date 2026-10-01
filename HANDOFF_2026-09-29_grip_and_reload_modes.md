# Handoff 2026-09-29: grip adjuster saving + reload modes

Everything below is written to disk. **None of it has been compiled.** Your job is to
build both packages, fix any compile errors, and run the test list.

## Build

Build RS_WorldHands first, then RS_VR_Reload. Both scripts lint, pack, compile-check, and
install only if the check passes.

```powershell
cd E:\DOOMWork\RS_WorldHands ; .\build.ps1
cd E:\DOOMWork\RS_VR_Reload  ; .\build.ps1
```

If RS_VR_Weapons' build loads the Reload pk3, rebuild it afterwards too, so the whole load
order is checked together.

## What changed

### RS_WorldHands

- `zscript/hands/rs_ovaledit.zs` (grip adjuster, stick tuning)
  - **Level change.** A level change or quit while holding the adjust button no longer
    leaves the sticks taken or the oval viz stuck on. See `WorldUnloaded`, `WorldLoaded`,
    and the new `rs_oval_pending` cvar.
  - **Part stops.** Gun-part stops are built from Reload's `wm_gp_name_<m|o><n>` cvars.
    Both hands are covered, parts are named, and there are two stops per part: WHERE and
    SHAPE.
  - **Size.** Size scales `wm_tune_sh_scale_x/y/z` together. It never touches `wm_tune_r`,
    which turns an oval into a ball.
  - **Axes.** The part axes were swapped and are now fixed: `ofs_x` = along the barrel,
    `ofs_y` = across.
  - **Saving.**
    - Letting go, or stepping to another part, saves by sending Reload's own bake events
      (`wm_bake_ofs`, `wm_bake_shape`, `wm_bake_go`). These are sent by name; no Reload
      class is named.
    - Releasing also calls `CVar.SaveConfig()`.
- `CVARINFO.txt`: adds `user string rs_oval_pending`.
- `GRIP_ADJUSTER.md`: updated to match.

### RS_VR_Reload

- **`zscript/wm/rig.zs`**
  - `BakeSlot` is split into `BakedSlot`, which returns the numbers. It has a `forCard`
    flag that leaves out `wm_grab_all` and `wm_reach_override`. The printed text is
    unchanged.
  - `FlickSnapLoad` is retuned. See the flick-reload item in the test list.
  - In `OnShot`, when `wm_reload_mode 0` is set, gun stores are not spent.
- **`zscript/wm/system.zs`**
  - `BakePrint`:
    - In single player, it writes the baked numbers into the live card via
      `ApplyBaked`.
    - It keeps the `forCard` lines in the ledger.
    - It clears the scratch when the card has taken it.
  - `ApplyLedger()` runs in `WorldLoaded` after `LoadCards`. It lays `wm_bake_ledger_*`
    over the cards, in single player only.
  - Stock reload (mode 4) uses `StockReloadPress` and `StockReloadTick`.
    - It is driven by the engine `BT_RELOAD` edge in `Buttons()`.
    - It reloads every hand whose gun has room.
    - The gun's fire is blocked through `PublishFireBlock` while it reloads.
    - When done it sends `wm_snapload`.
    - The drop-mag buttons are unchanged.
  - `ArcadeChambers()` is new.
  - `PublishFireBlock` no longer blocks on `!InBattery` in mode 0.
- **`zscript/wm/weapon.zs`**: in mode 0, `WM_TryFire` charges the reserve on every pull
  (`DepleteAmmo`, playsim, all machines).
- **`zscript/wm/hand.zs`**: adds `stockReloadTics[2]` and `stockReloadGun[2]`.
- **`zscript/wm/ammoservice.zs`**: in mode 0 the HUD reads the gun as fires-from-reserve.
- **`CVARINFO.txt`**
  - New cvars: `wm_snapload_speed` (2.8), `wm_snapload_tics` (3), `wm_snapload_dist`
    (0.15), `wm_stockreload_tics` (35).
  - The mode comments are updated.
- **`MENUDEF.txt`**
  - Mode 4 is labelled "Reload button (stock)".
  - New sliders: "Flick must travel" and "Reload button takes".

## Where a compile error is most likely

These spots were reviewed by reading only; no compiler was run on them.

- **`rig.zs` `BakedSlot`:** the multi-return signature `int, int, Vector3, Vector3` with a
  default `bool forCard = false` parameter.
- **`system.zs` `BakePrint`:** function-local `static const String zero[] = {...}` inside
  an `if`.
- **`system.zs` `ApplyLedger`:** `String.Split(..., TOK_SKIPEMPTY)` and `ToDouble()`.
- **`rs_ovaledit.zs`:** `private static String, String PartName(...)` and
  `Array<int>` members on an EventHandler.
- **Menu lint:** the two new sliders point at cvars read in `rig.zs` and `system.zs`. The
  lint may want them listed under a `LINT-CVARS` comment if it can't see the read.

## Test list (single player unless noted)

1. **Adjuster: stretch an oval.**
   1. Hold the adjust button and step to a part on the **off-hand** gun.
   2. Stretch it on the SHAPE stop and let go.
   3. It stays stretched. The console prints `WM BAKE ...` and "kept in the bake ledger".
2. **Adjuster: survives a map change.** Change maps; the part is still stretched. Quit and
   relaunch; it is still stretched.
3. **Adjuster: map change mid-hold.** Hold the adjust button and `changemap`. On the new
   map you can walk and turn, and `rs_stab_viz` / `wm_show_grabs` are back to your
   settings.
4. **Adjuster: size keeps the shape.** On the WHERE stop, the size stick grows the oval
   without turning it into a ball.
5. **Mode 0 (arcade).** The reserve drops on every shot and the gun stops at 0. A double
   with 1 shell left fires one barrel. The HUD shows the reserve count.
6. **Mode 4 (stock).**
   - Press `+reload`: about 1 second with no fire, then the gun is topped up. Nothing is
     thrown away.
   - Dual pistols: both reload.
   - A full gun is ignored.
   - An empty reserve gives a dry click.
   - Swapping guns mid-reload cancels it.
7. **Mode 3 (flick).**
   - Lowering the gun, recoil, and crouching do NOT reload.
   - A deliberate hard downward flick of about 15 cm does.
   - "Flick effort" and "Flick must travel" change it.
8. **Netgame (two instances).**
   - Mode 0 and mode 4 fire and reload identically on both machines with no desync.
   - The ledger is NOT applied: cards play as shipped.
   - Flick reload does nothing in a netgame, which is a known engine gap (controller
     velocity reads zero there).

## Known limits, not bugs

- The whole-gun grab offset (`wm_grab_all_ofs_*`) and `wm_reach_override` are not baked
  into the card. They stay live on top of it.
- Clearing the bake ledger does not undo cards already changed in this session. They go
  back to shipped on the next map load.
- Tuning left in the scratch across a level change is saved at the next claim, against
  whatever gun is then in that hand.
