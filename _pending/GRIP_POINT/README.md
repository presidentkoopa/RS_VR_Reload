# GRIP_POINT — RS_VR_Reload side of the grip (CardPipeline/GUN_IN_HAND_PLAN.md 1.2)

**Apply only after the engine with `Actor.FollowHandGrip` is built.** These files name engine
fields an older doomxr.exe does not have, and an unknown field fails the whole pk3.

What it does: a card's `grip` block `seat = x, y, z` (already parsed, read by nothing until now)
becomes the gun's grip. `WM_Rig.MakeProp` hands it to the prop, and the engine holds the gun by
that point. Cards without a seat are untouched.

Apply `GRIP_POINT.patch` (13 lines across card.zs, parser.zs, rig.zs) rather than copying the
three files over — rig.zs moves often, and a copied file would undo anything written to it since
2026-09-29 09:10. The full files are here only for reference.

    cd E:\DOOMWork\RS_VR_Reload
    git apply _pending\GRIP_POINT\GRIP_POINT.patch
