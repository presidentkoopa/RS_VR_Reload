# Weapon passing — moving it to GESTURES.pk3

Written 2026-09-12. The RS_VR_PistolTest side is from its source. The GESTURES
side is designed against the interface, not against its code — GESTURES.pk3 was
not available to read.

---

## 1. Why it belongs there

Passing is not a weapon-mechanism concern. It is a hand-to-hand transfer of any
held thing — a gun, a magazine, a grenade, a flashlight. If it lives in the
weapon mod, every other mod with holdable objects reimplements it, and the
gesture means something different depending on what you happen to be holding.

It also removes the reason hand-pull was disabled. The magazine grab was turned
off because a squeeze near the gun read as "take the gun". Once passing is its
own gesture, a squeeze is only ever a squeeze, and the two stop competing.

---

## 2. The gesture

Both palms up, hands within reach of each other, one hand holding something
transferable, the other free. On the gesture, the object moves to the free hand.

Palms up is the right shape because nothing else wants it — a grip hold is palm
sideways, a rack is palm down, a hand under a magazine is palm up but *one*
hand, near a gun, mid-squeeze. Two open palms facing the ceiling is unclaimed.

The one thing this needs that nothing currently provides is a real palm normal
for a hand that is not holding one of WM's guns. WM derives palm direction from
the held gun's frame (`TakeAllowed` reads `own.FrameBasis()`), so an empty hand
returns no reading at all — and it takes `abs()` of the result, so palm-up and
palm-down are the same number. Neither is usable here.

The source that does work is the hand actors themselves. `RS_HandWorldMain` and
`RS_HandWorldOff` support bone info — WM's `PinHand` already sets
`IQM_GET_BONE_INFO | IQM_GET_BONE_INFO_RECALC` on them — so a palm bone's
orientation is readable directly, independent of what the hand holds.

GESTURES will have to settle the left/right mirror once, since "palm up" is
opposite in each hand's bone space. WM ducked that with `abs()`; a signed
gesture cannot.

---

## 3. What GESTURES builds

**Detection.** Per tic: read both palm normals from the hand bones, check both
are within some cone of world up, check hand separation is under a threshold,
check exactly one hand holds something transferable. Fire on the rising edge,
with a short cooldown so one gesture doesn't fire twice.

**The weapon move.** For a `Weapon`, the sequence is fiddly and already solved —
lift it from `WM_System.EquipInstantly` (`system.zs:382-398`), which took it from
RS_TestPistol, which took it from the weapon wheel. Setting the pointer is not
enough; `SetPsprite` is what hands the layer over. It also handles
`bOffhandWeapon` on both the weapon and its `SisterWeapon`, and clears the
weapon out of the hand it is leaving. Copy it rather than rediscover it.

**Held world objects.** For a magazine or a grenade, the move is
`FollowHandMode = hand + 1` and telling whoever owns it. That is RS_WorldHands'
territory, and how far GESTURES should reach into it is a question for that mod,
not this one.

**Claiming the hands.** Claim both hands through the existing grip arbiter for
the duration, under a new subject — call it `GRIPSUBJ_Passing`. Section 5
explains why that one addition does most of the interop work for free.

---

## 4. What changes in RS_VR_PistolTest

Three things, and only one is more than a line.

**`Claim()`'s denial rule needs a carve-out.** Today, when the arbiter refuses a
hand, WM takes it anyway — *"a denial is advice, not a veto ... nothing else
drives them, and making the gun unusable is not the answer to someone else
holding the hand."* That reasoning is right for a gun's own parts and wrong for
a pass in progress. A refusal carrying the pass subject has to be a real veto.

**`take = no` comes off both magazine parts** in `WMCARD.txt`, restoring
pull-the-magazine-out-by-hand. This is the payoff, and it should be the last step
so the gesture is proven first.

**The pass subject goes in `IsOurs()`'s exclusion** — which is automatic, since
`IsOurs()` lists WM's own subjects and anything absent already reads as foreign.
Nothing to write.

---

## 5. What already works and needs nothing

Worth knowing before anyone plans defensively, because the mod is shaped better
for this than it looks.

**WM already stands down for a foreign grip claim.** `CatchFalling` bails when
the claim is not `IsOurs()`. `PoseHand` only overwrites a claim that is empty or
its own. So a `GRIPSUBJ_Passing` claim is respected in the places that matter
without touching either function.

**Rebinding after the swap is automatic.** `BindRig` compares both the card and
the weapon *instance* — `if (rig.card == want && rig.gunItem == w) return;` — so
a weapon arriving in a different hand triggers a rebind on the next tic.

**Ammunition survives the move.** Rounds, chamber and lock live on
`WM_Gun.wmAmmo`, not on the rig, specifically because a fresh rig used to mean a
free reload. A passed gun arrives exactly as it left.

**The hand model already handles it.** Hand *h* works `rigs[1-h]`, and `rigs[h]`
binds from whatever is actually in hand *h*. Pass a gun to the off hand and the
main hand — now on its fist, with no card — works it. That is the correct
outcome and it falls out of the existing structure.

**`Equip()` will not yank it back.** After the 35-tic spawn window it only fills
a hand holding `null`, and only when the other hand does not already have that
weapon. A passed gun fails that second test, so the card's `hand` line stops
being enforced. Worth confirming in the headset rather than trusting on a read,
since it depends on whether a vacated hand ends up `null` or on its fist.

---

## 6. Order

Build detection first and prove it in isolation — palms up, both hands, log a
line, move nothing. Getting a stable signed palm normal out of the hand bones,
with the mirror settled, is the only genuinely unknown part of this.

Then move a magazine, which is the low-stakes object: `FollowHandMode` and
nothing else breaks if it goes wrong.

Then move a weapon, using `EquipInstantly`.

Then add the arbiter claim and WM's veto carve-out, so the two mods stop
competing during the transfer.

Then take `take = no` off the cards and confirm the magazine pull works without
being mistaken for a pass.

---

## 7. Open questions

Whether GESTURES already has a palm-orientation reader, and whether it already
owns a two-hand posture this can extend rather than sit beside. Both are
answerable by reading it; neither changes the plan's shape.

Whether a two-handed weapon should pass differently — one hand releasing while
the other keeps it — is worth deciding once `hands = 2` exists in the card, but
it is a refinement, not a blocker. Both palms up works for a shotgun too.
