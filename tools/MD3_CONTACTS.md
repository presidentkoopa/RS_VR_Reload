# Where the md3 guns' contact points land (reload lane, 2026-09-18)

The md3 half of the hand-posing survey, same treatment as the Breach IQM pass. md3 has no skeleton, so a frame's vertices ARE the space the card's points were measured in -- nothing is carried anywhere, and a part's grab can be checked against its OWN named surface.

`off surface` is the distance to the nearest point on the whole mesh, `off its own` to the surface the part names. `off (map)` applies the gun's MODELDEF Scale, so it is comparable to a grab radius of 3.0. A blank normal with `enclosed` means the mesh wraps that point and no single surface faces it -- for those, the wall found by firing rays out from the point is the real surface.

These points are HAND OPINIONS: never confirmed in a headset, fitted to the RS hand's size. The mesh columns are facts; the points themselves are what is in question.

| Gun | Type | Part | Field | Landed on | off surface | off its own | off (map) | Normal | |
|---|---|---|---|---|---|---|---|---|---|
| WM_PumpDoom | shotgun | forend | handseat | doomshot | 1.407 | 2.197 | 1.90 | - | ENCLOSED wall 0.00 |
| WM_AssaultShotgun | shotgun | magazine | grab | mag | 1.393 | 1.393 | 1.39 | -0.026, 0.006, -1.000 |  |
| WM_BullpupPump | shotgun | forend | grab | forend | 1.254 | 1.254 | 1.38 | - | ENCLOSED wall 1.13 |
| WM_BullpupPump | shotgun | forend | handseat | forend | 1.254 | 1.254 | 1.38 | - | ENCLOSED wall 1.13 |
| WM_PumpM37 | shotgun | forend | grab | m37a2_pump | 1.243 | 1.243 | 1.37 | - | ENCLOSED wall 1.18 |
| WM_PumpM37 | shotgun | forend | handseat | m37a2_pump | 1.238 | 1.238 | 1.36 | 0.015, -0.048, -0.999 |  |
| WM_PumpDoom | shotgun | forend | grab | doomshot | 0.880 | 2.492 | 1.19 | - | ENCLOSED wall 0.61 |
| WM_Pistolet | pistol | support | grab | rec | 0.873 | - | 1.18 | 0.854, 0.012, -0.519 | wall 0.91 |
| WM_M4A3 | pistol | support | grab | m4a3 | 1.157 | - | 0.95 | - | ENCLOSED wall 1.56 |
| WM_Pistolet | pistol | magazine | grab | mag | 0.675 | 0.675 | 0.91 | -0.210, 0.043, -0.977 |  |
| WM_M4A3 | pistol | magazine | grab | m4a3_magazine | 0.627 | 0.627 | 0.51 | -0.291, -0.006, -0.957 |  |
| WM_AssaultShotgun | shotgun | support | grab | body | 0.374 | - | 0.37 | - | ENCLOSED wall 0.00 |
| WM_M4A3 | pistol | slide | grab | m4a3_slide | 0.358 | 0.358 | 0.29 | -0.910, 0.038, 0.412 |  |
| WM_Pistolet | pistol | slide | grab | slide | 0.155 | 0.155 | 0.21 | - | ENCLOSED wall 0.05 |
| WM_AssaultShotgun | shotgun | charginghandle | grab | chargehandle | 0.202 | 0.202 | 0.20 | -0.022, 0.942, 0.336 |  |
