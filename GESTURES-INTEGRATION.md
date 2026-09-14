# RS_GESTURES × RS_VR_PistolTest — integration notes

From the source of both, 2026-09-12. RS_GESTURES is ~550 lines of pure ZScript,
no assets, `rsg_enabled` defaulting false.

---

## 1. What RS_GESTURES actually is

Two separable halves, and the distinction matters more than anything else here.

**The capture half.** `RSG_Ring` keeps 105 tics — three seconds — per hand of
hand position, hand pitch/yaw/roll, head position, head yaw/pitch/roll, the
button word and the tic. `RSG_Capture` pushes both hands every `WorldTick`. It
reads only what the engine already publishes and writes nothing. This half is
useful to anything that wants to know how a hand has been moving.

**The matcher half.** `RSG_Normalizer` resamples the last *N* tics into a
32-step body-relative stroke (hand minus head, head yaw rotated out).
`RSG_Matcher` runs DTW against registered templates and fires
`SendNetworkEvent("rsg_matched", index, confidence*100, 0)`. Templates carry a
book, per-template tolerance overrides, and a virtual `ContextValid(PlayerPawn)`
explicitly designed for gating.

Crucially the matcher is **modal**: nothing matches until gesture mode is opened
by holding the main hand above head height with grip held for
`rsg_entry_hold` tics, and it closes on idle or on taking damage. And it is
**main-hand only** — `WorldTick` builds a stroke from
`cap.GetRing(RSG_Capture.HAND_MAIN)` and never looks at the off-hand ring, even
though the off-hand ring is captured.

---

## 2. The honest headline

**Most of reloading should not be gestures, and this system says so itself.**

WM's approach — put a hand on a real part, drag it, let the renderer glue the
part to the controller 1:1 — is strictly better than recognition for anything
with a part to hold. It gives partial travel, a readable position at every
instant, the apex where the hand feels the slide stop, and a decision made from
the value that was actually drawn. DTW gives you a yes/no after the fact. Racking
a slide by drawing a shape in the air would be a downgrade in every dimension.

So the integration is not "reload by gesture." It is: **gestures cover the
actions that have no part to grab, or whose real-world motion is ballistic
rather than quasi-static.**

That second clause is where the genuine wins are, and there are fewer than you'd
think — but they're good ones.

---

## 3. Where gestures actually win

**Snapping a break action shut, and flicking a revolver cylinder home.** These
are the strongest cases in the whole set. In life both are a wrist flick — the
weapon's own mass swings the part closed and the latch catches. A 1:1 grab makes
you slowly drag the barrels up until a threshold trips, which is exactly the
wrong feel for the one motion every shooter does fast. A flick is a hand angular
velocity about a known axis, and the ring already stores per-tic hand roll and
pitch, so this needs no DTW at all — just a derivative.

**Slinging a lever.** Same family. The Winchester flip is ballistic.

**Weapon passing.** Already the plan, and §5 corrects two things I got wrong
about it.

**Accessibility.** A one-motion reload for a player who cannot do the two-handed
sequence. This undercuts the physicality thesis on purpose, and that is fine as
an option rather than a default.

What is *not* on the list, deliberately: racking, seating a magazine, pumping a
forend, opening a break action, working an ejector rod, throwing. All of those
have a part, and WM already does them better. Throwing in particular is already
solved from `AttackVel`/`OffhandVel` and needs nothing.

---

## 4. The mismatch to fix first

Three properties of the matcher are right for spellcasting and wrong for weapon
handling.

**Modality.** You cannot raise your hand above your head to enter gesture mode
before closing a cylinder. Weapon gestures have to be always live.

The fix is not to remove the mode — it is to **replace modality with context**.
Spellcasting needs a mode because its context is "anything, anytime." A weapon
gesture's context is razor-thin: *this hand, holding nothing, while the crane of
the weapon in the other hand is open.* A template gated that tightly cannot
false-fire, so it needs no mode at all. `ContextValid` is already the hook; what
is missing is a per-template or per-book flag saying "live outside mode."

**Main-hand only.** Reload work is done by whichever hand is not holding the
weapon, which is as often the off hand. The off ring is already captured; the
matcher just never reads it. Small fix.

**Body-relative space.** `BodyRelative` subtracts the head and rotates out head
yaw. Correct for a spell — the shape means the same wherever you face. Wrong for
a weapon gesture, which is relative to *the weapon*, not the body: flick a
cylinder closed while turning and body-relative space smears it. WM can supply
the right frame — `WM_Rig.FrameBasis()` already returns the weapon's drawn
origin and three axes — so a weapon-relative normaliser is a small addition with
the data already available.

There is also a **fourth thing worth checking in the headset**: `EntryPoseHeld`
is main hand above head height with grip held, and with WM loaded that is a pose
you can hit by accident — racking a weapon held high, or reaching toward a
shoulder holster with VRBody loaded. Gesture mode opening mid-reload is harmless
today but won't be once templates do things.

---

## 5. Two corrections to PASSING.md

**`MoveWeaponToHand(wpn, hand, exactInstance)` is a native**, and
`RSG_DemoActions` already calls it. My earlier suggestion to lift WM's
`EquipInstantly` is worse advice — use the native. Worth confirming it does the
`SisterWeapon.bOffhandWeapon` and `SetPsprite` work that `EquipInstantly` does by
hand, but if it does, that whole section collapses to one call.

**The palm-up problem is already solved by the capture ring.** I said nobody has
a signed palm direction and GESTURES would need to read IQM bones. Wrong — the
ring stores `MainHandRoll` and `OffhandRoll` per tic, and the capture file's own
comment explains it uses `MainHandRoll` rather than `AttackRoll` specifically
because the latter is force-zeroed every tic to stay deterministic. Roll about
the forward axis is exactly the palm-up-versus-palm-down axis. Both palms up is
readable from `HandAngles(age)` today, no bones, no new engine work.

That also means passing needs only the *capture* half of GESTURES, not the
matcher: it is a held pose, not a drawn path.

---

## 6. The idea worth having: the card names the gesture

If gestures are going to be part of this rather than beside it, they belong in
the card grammar from `UNIVERSAL.md`, not in a separate wiring file.

```
open crane
  part   = crane
  latch  = cylinderlatch
  openat = 0.85
  rest   = stay
  close  = flick          # a gesture closes it, not a drag
end
```

WM reads that at card load, registers a template with GESTURES scoped to the
context "the weapon this hand works has `crane` open", gets an index back, and
fires the verb's close on `rsg_matched` with that index. The card author says
*flick* and never touches ZScript, which is the whole thesis of the system
applied one layer out.

That also gives a clean answer to which gestures exist: exactly the ones cards
ask for, registered when a weapon that wants them is loaded, and gone otherwise.
No global gesture library to keep in sync.

---

## 7. How the two mods should talk

Both codebases have the same scar tissue about this — a hard class reference
across pk3s is a fatal *global* load error, and `RSG_DemoActions` has a
twenty-line comment about a name literal in a `class<T>` position causing exactly
that. So neither side can name the other's classes.

`EventHandler.Find("RSG_Matcher")` doesn't escape it either: the *cast* to
`RSG_Matcher` is compile-time. So WM cannot map a match index back to a name the
way `RSG_DemoActions` does.

The pattern both codebases already use is a `Service` found by string —
`ServiceIterator.Find("RS_GripArbiterService")` in WM, and WM's own
`WM_GrabBecomeService` answering WorldHands. GESTURES should grow the same:

Registration — WM asks a `RSG_RegistryService` to register a template by name
and gets an index back, so WM knows its own indices without ever casting to a
GESTURES class.

Context — the template holds a context string and asks a registered service
whether it currently holds, rather than WM subclassing `RSG_Template` (which
would be a compile-time reference again).

Matching — WM already has a `NetworkProcess`; it listens for `rsg_matched` and
compares `e.Args[0]` against the indices it was handed at registration. No cast
needed.

One operational note: `rsg_enabled` defaults false, so WM must treat gestures as
absent-by-default and degrade cleanly — a card asking for `close = flick` on a
build with gestures off should fall back to the drag, not become unclosable.

---

## 8. What I'd do

Nothing about gestures until `UNIVERSAL.md` step eight is done, because until
`open`/`close` and `return = stay` exist there is no verb for a flick to
complete.

Then, in order: off-hand matching in the matcher; the live-outside-mode flag with
context gating; the service pair so the two mods can talk without casting; then
one weapon-relative or velocity-based flick as the first real template, on the
break action, where a drag genuinely feels wrong.

Passing is independent of all of it and can proceed now off the capture ring
alone.
