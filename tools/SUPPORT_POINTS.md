# Where a gun's SUPPORT point actually sits (reload lane, 2026-09-18)

For every card with a support point: the distance to the NEAREST other part, and which part it was. Nothing is snapped -- a support point far from everything is reported as FAR.

Distances are MAP units (a gun's MODELDEF Scale applied to its model-space points), because a grab radius is map units and 3.0 is typical. **SAME PLACE** = within one grab radius, so a hand reaching one would touch the other. **NEAR** = within two. **FAR** = further.

A support point is a HAND OPINION, unconfirmed in a headset and fitted to the RS hand's size. The trustworthy column here is the part identity, not the number.

| Gun | Nearest part | Its subject | Map units | Model units | Scale | |
|---|---|---|---|---|---|---|
| WM_MachineGun | launcherlatch | - | 3.34 | 3.34 | 1.000 | NEAR |
| WM_Pistolet | trigger | trigger | 5.13 | 3.80 | 1.350 | NEAR |
| WM_M4A3 | trigger | trigger | 5.89 | 7.19 | 0.820 | NEAR |
| WM_SMG | charginghandle | slide | 6.19 | 6.19 | 1.000 | FAR |
| WM_BreachGlockS | magazine | magazine | 8.04 | 7.02 | 1.145 | FAR |
| WM_BreachGlock | magazine | magazine | 8.04 | 7.02 | 1.145 | FAR |
| WM_BreachKimber | magazine | magazine | 8.07 | 7.04 | 1.145 | FAR |
| WM_BreachMP5 | charginghandle | slide | 9.75 | 4.26 | 2.290 | FAR |
| WM_Tec9 | bolt | slide | 10.27 | 9.33 | 1.100 | FAR |
| WM_RotaryLauncher | tubes | - | 12.61 | 11.47 | 1.100 | FAR |
| WM_RotaryGun | trigger | trigger | 14.23 | 12.94 | 1.100 | FAR |
| WM_BreachG36C | magazine | magazine | 14.89 | 13.00 | 1.145 | FAR |
| WM_BreachMCX | magazine | magazine | 14.93 | 13.04 | 1.145 | FAR |
| WM_BreachHK416S | magazine | magazine | 15.31 | 13.37 | 1.145 | FAR |
| WM_ChainsawHeavy | trigger | trigger | 17.24 | 17.24 | 1.000 | FAR |
| WM_AssaultShotgun | charginghandle | slide | 17.69 | 17.69 | 1.000 | FAR |
| WM_M16 | charginghandle | slide | 17.89 | 13.25 | 1.350 | FAR |
| WM_BreachMK18 | magazine | magazine | 18.00 | 15.72 | 1.145 | FAR |
| WM_BreachMK18S | magazine | magazine | 18.00 | 15.72 | 1.145 | FAR |
| WM_BreachBenelli | bolt | slide | 18.28 | 6.98 | 2.620 | FAR |
| WM_Chainsaw | ripcord | - | 19.96 | 14.79 | 1.350 | FAR |
| WM_Chaingun | barrels | - | 19.99 | 19.99 | 1.000 | FAR |
| WM_Bolter | magazine | magazine | 21.86 | 19.87 | 1.100 | FAR |
| WM_Railgun | magazine | magazine | 23.09 | 23.09 | 1.000 | FAR |
| WM_Rifle | trigger | trigger | 25.22 | 25.22 | 1.000 | FAR |
| WM_PlasmaRifle | cell | magazine | 26.64 | 26.64 | 1.000 | FAR |
| WM_Flamethrower | canister | magazine | 30.05 | 30.05 | 1.000 | FAR |
| WM_PlasmaCarbine | cell | magazine | 30.33 | 30.33 | 1.000 | FAR |
| WM_Flamer | canister | magazine | 32.28 | 29.35 | 1.100 | FAR |
| WM_BFGHeavy | cell | magazine | 32.31 | 32.31 | 1.000 | FAR |
| WM_Unmaker | skull | magazine | 35.49 | 35.49 | 1.000 | FAR |
| WM_BFGRifle | cell | magazine | 35.80 | 32.54 | 1.100 | FAR |
| WM_RPG | drum | magazine | 49.75 | 49.75 | 1.000 | FAR |
| WM_LongbarChainsaw | - | - | ? | - | 1.100 | ONLY PART |

## What it says

- 34 cards carry a support point; 12 carry none.
- **0 of 34 land on an existing part** (within one grab radius), 3 within two, 30 further off.
