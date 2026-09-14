# What "working" means

The finish line, in the owner's words, pinned here so it cannot drift.
This is a FULL LOOP, not a demo of one gesture. Every line below has to be true
at the same time, on the same gun, in one continuous session in the headset.

## The loop

1. **Drop the magazine** — two ways, both must work:
   - press the release button, or
   - physically grab the magazine with the off hand and pull it out
2. **The dropped magazine falls and lands on the floor**, as a real object.
3. **It is coloured by what is left in it:**
   - neutral/grey when empty
   - green → red gradient by how full it is
4. **A removed magazine can be dropped or thrown** — an open hand while moving
   throws it; standing still drops it.
5. **The off hand can reach into the ammo pouch and take a fresh magazine.**
6. **A carried magazine can be:** dropped, thrown, put back into the pouch, or
   seated into the gun.
7. **Once seated, racking the slide chambers a round.**
8. **The slide locks back when the gun is empty**, and stays locked until worked.
9. **15 rounds per magazine.**
10. **One in the chamber is real and separate from the magazine.**
    Consequence, and this is the "use logic" clause: if a round is still
    chambered, a fresh magazine does NOT need a rack — the gun is already ready.
    Racking anyway ejects the chambered round, because that is what racking does.

## What this is NOT

Not a spike, not a gesture demo, not "the slide moves." The gun must go from
loaded, through empty, through a complete hand-driven reload, back to firing,
without a hardcoded line of logic about *this* pistol anywhere in the system.

## The proof that it is generic

The same system, unmodified, drives a second gun from a second card.
`m4a3.md3` is the clean case. `pistolet.md3` is the adversarial one — its
magazine genuinely deforms (rigid-fit error 4.29 against m4a3's 0.013), so it
also tells us what a non-rigid part costs.
