# Hand units inventory

vr_vunits_per_meter = 34, so L = 0.34 (one legacy hand unit in map units)

## Hand-path MODELDEF blocks: 117

- RS_Lance/MODELDEF: 2 (LNC_LanceProp, LNC_LancePropOff)
- RS_Lightsaber/MODELDEF.txt: 34 (RS_SaberHilt, RS_SaberHiltOff, RS_SaberBlade_Blue, RS_SaberBlade_Green, RS_SaberBlade_Red, RS_SaberBlade_Purple ...)
- RS_Modern/MODELDEF.txt: 10 (WM_PropBreachGlock, WM_PropBreachGlockS, WM_PropBreachKimber, WM_PropBreachMK18, WM_PropBreachMK18S, WM_PropBreachHK416S ...)
- RS_ShieldSaw/MODELDEF.txt: 3 (RS_ShieldForearmActor, RS_ShieldSawProp, RS_ShieldSawPropOff)
- RS_VRBody/MODELDEF.txt: 12 (RS_HandWearGloveMain, RS_HandWearGloveOff, RS_PartHandIQMMain, RS_PartHandIQMOff, RS_HandWearMarineMainA, RS_HandWearMarineMainE ...)
- RS_VRPanels/MODELDEF.txt: 20 (RS_PanelTestA, RS_PanelTestB, RS_PanelWristA, RS_PanelWristB, RS_PanelGunMainA, RS_PanelGunMainB ...)
- RS_VR_Weapons/MODELDEF.txt: 11 (WM_PropM4A3, WM_PropPumpDoom, WM_PropSSG, WM_PropDoubleBarrel, WM_PropPlasmaRifle, WM_PropChaingun ...)
- RS_VR_Weapons/wardusted/MODELDEF.txt: 13 (WD_PropDL44, WD_PropDarkBlaster, WD_PropE22, WD_PropE11, WD_PropZ6, WD_PropDLT19 ...)
- RS_VR_Weapons/xim/MODELDEF.txt: 7 (XM_PropPistol, XM_PropShotgun, XM_PropSuperShotgun, XM_PropChaingun, XM_PropRocketLauncher, XM_PropPlasmaRifle ...)
- RS_WorldHands/MODELDEF.txt: 5 (RS_HandWorldMain, RS_HandWorldOff, RS_GrabOvalMain, RS_GrabOvalOff, RS_StabOval)

## Placement prefixes found: 50

lnc_prop, lnc_prop_off, rs_bp_handmain, rs_bp_handoff, rs_grab_m, rs_grab_o, rs_hw_main, rs_hw_off, rs_panel_test, rs_pgun_fitmain, rs_pgun_fitoff, rs_pwrist_topoff, rs_saber, rs_saber_off, rs_ss_prop, rs_ss_prop_off, rs_ss_stow, rs_stab, rsvg_hm, rsvg_ho, wd_assaultcannon, wd_bowcaster, wd_concussion, wd_darkblaster, wd_disruptor, wd_dl44, wd_dlt19, wd_e11, wd_e22, wd_mines, wd_sniper, wd_thermal, wd_z6, wm_bfg, wm_chaingun, wm_chainsaw, wm_doublebarrel, wm_main, wm_off, wm_plasmarifle, wm_pumpdoom, wm_rocketlauncher, wm_ssg, xm_chaingun, xm_pistol, xm_plasmarifle, xm_rocketlauncher, xm_shotgun, xm_supershotgun, xm_thermal

Plus patterns: rs_pwrist_*, wm_ha_*, wm_grab_all, wm_tune

## CVARINFO defaults to change: 128
## MENUDEF sliders to rescale: 336
## ini values to change: 129

## REVIEW: prop/hand-named blocks with no FollowMainHand/OffHand (hand-drawn if script sets FollowHandMode on them; add to CHILD_CLASSES if so): 2

- RS_WorldHands/MODELDEF.txt: RS_HandIdleMain
- RS_WorldHands/MODELDEF.txt: RS_HandIdleOff

## Manual ZScript edits

- RS_VRBody/zscript/body_holsters.zs -- SolveScale(): asHeld = vr_vunits_per_meter * 0.01: set asHeld = 1.0 when vr_hand_units is 1 (a held gun and a holstered gun are then the same scale)
- RS_VR_Reload/zscript/wm/rig.zs -- recoil slide: prop.FollowHandOfs = (0, slide, 0): FollowHandOfs is in hand-frame units: multiply slide by L, or migrate the recoil profiles' 'back' values in RSBDEFS by L
- RS_VR_Reload/zscript/wm/loose.zs -- worldScale / wm_world_factor: no code change: wm_world_factor becomes 1.0 (CVARINFO and ini), done by apply
- RS_VR_Reload/zscript/wm/rig.zs -- FrameUnits() fallback wm_world_factor: no code change: FrameUnits() measures the real frame, so it reads 1.0 by itself
- RS_VRPanels/zscript/watch.zs -- Mount(): FollowActorOfs when not in-model: check the fallback seat (no hand model): it is in hand-frame units; multiply by L if it is ever non-zero
