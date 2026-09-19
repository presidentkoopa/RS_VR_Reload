// ============================================================================
// WHAT A GUN DOES WITH ITS PARTS: EIGHT VERBS.
//
// A part says what it IS and how it can move (card.zs). A verb says what the
// gun DOES with it, and these cover every mechanism this system is for:
//
//   CYCLE   a part travels out and back; at the far end something ejects, at
//           the near end something is fed. A pistol slide, a pump forend, a
//           lever, a bolt.
//   OPEN    a part moves to a held state and stays there, and while it is open
//           the stores behind it can be reached. A break action, a crane.
//   SWAP    a container leaves the gun and another goes in. The magazine.
//   LOAD    one round into a named store. A tube gate, a pair of barrels.
//   EJECT   one slot, or every slot, of a store thrown into the world. A rod.
//   START   a part pulled past a threshold starts the gun's engine, and springs home. A
//           chainsaw's ripcord: the gun fires only while it runs.
//   PULLOFF a part pulled along its dof until it comes away. A grenade's pin.
//   RELEASE a part the holding hand's grip keeps shut, which springs off when that hand
//           lets go. A grenade's lever. Both belong to a weapon that leaves the hand
//           (throw.zs, THROWABLE_PLAN.md §2.3).
//
// Before verbs, `role` did this job twice over: `action` meant both "the part
// that reciprocates" and "the thing Cycle animates, Hold measures against 0.60,
// Release springs home and Racked acts on". That is why a pump cost an edit to
// system.zs rather than a text block.
//
// ------------------------------------------------------- WHERE A VERB COMES FROM
//
//   DECLARED     the card's own `cycle rack` ... `end` block
//   ARCHETYPE    the card says `mechanism = <name>`, and an `archetype <name>`
//                block -- in any WMCARD lump, before or after the card -- has it
//   OVERRIDE     the card declares a block under an archetype verb's id: it
//                starts as that verb and changes only the keys the card states
//   SYNTHESISED  the card declares no verbs and no mechanism: the old role
//                code's behaviour, built from its `role = action` and
//                `role = feed` parts with the exact numbers that code used
//
// ------------------------------------------------------ CARD DATA, NOT LIVE STATE
//
// A verb belongs to a card, and a card is one shared object read by whichever
// hand binds it. Nothing on a verb changes once the cards are loaded. The
// stroke a hand is part-way through, the clock running after a shot, and
// whether something is held open all live on the WM_Rig, in arrays indexed
// like card.verbs.
//
// ------------------------------------------------------------------ THE A/B SWITCH
//
// wm_verbs. On, the verbs decide every rack, drop and seat. Off, the old role
// code runs exactly as it did, so the two can be compared in the headset for
// this build rather than bisected.
//
// ---------------------------------------------------------- NAMES THAT CANNOT MEET
//
// Identifiers are case-insensitive, and one constant per `const` line. No field
// here shares a name with a method: `kind` is read directly and its word is
// KindName(); `ret` is read directly and its word is ReturnName(). `auto` and
// `none` are keywords of this compiler, which is why the fields are autoOnShot
// and every "none" lives only inside a string.
// ============================================================================

class WM_Verb
{
	const CYCLE = 0;
	const OPEN  = 1;
	const SWAP  = 2;
	const LOAD  = 3;
	const EJECT = 4;
	const START = 5;   // a chainsaw's ripcord (CS-G1): the engine runs, and only then does it fire
	const PULLOFF = 6; // a grenade's pin, pulled off along its dof
	const RELEASE = 7; // a grenade's lever, held shut by the grip and off when that hand lets go

	// WHAT LETTING GO DOES. The fix for the constant in the old Release().
	const RET_SPRING = 0;   // it goes home by itself -- a pistol slide
	const RET_HAND   = 1;   // it stays where the hand left it; the hand brings it home
	const RET_STAY   = 2;   // it stays, and past its threshold it is held open

	const FROM_DECLARED  = 0;
	const FROM_ARCHETYPE = 1;
	const FROM_OVERRIDE  = 2;
	const FROM_SYNTH     = 3;

	// ---- WHAT IT IS -----------------------------------------------------------
	int     kind;
	String  id;
	int     origin;        // FROM_*
	String  originName;    // the archetype that supplied it, when one did
	String  sourceName;    // the lump its block was read from
	int     line;          // the line its block opened on

	// ---- WHAT IT WORKS ----------------------------------------------------------
	String  partId;        // CYCLE, OPEN, SWAP, EJECT: the part a hand moves
	int     partIndex;     // into card.parts, resolved once the card is whole; -1
	String  latchId;       // OPEN, SWAP: a part that must be thrown first (F3; BUILD.md step 8)
	int     latchIndex;
	// OPEN, SWAP: HOW FAR THE LATCH MUST BE THROWN (`latchat`, of its own travel; default 0.8). Until
	// it is, a hand cannot take this verb's part while that part is home -- a break action's barrels,
	// a flamethrower's can -- and a swap neither drops by its button nor seats (WM_Rig.LatchThrown,
	// LatchLocks). The latch part is itself a part a hand can take (WM_Card.PartIsWorkable), and stays
	// where the hand leaves it.
	double  latchAt;
	// OPEN, SWAP: THE LATCH SPRINGS HOME WHEN LET GO (`latchreturn = spring`; unset `stay`, a lever
	// thrown and left). A sprung latch keeps its verb unlocked for LATCH_GRACE_TICS after it was last
	// thrown, so the hand that pressed it can move on to the part -- an M203's latch, then its tube.
	bool    latchReturnSpring;
	const LATCH_GRACE_TICS = 35;

	// ---- THRESHOLDS: every one compared against the DRAWN value -----------------
	double  outAt;         // CYCLE: past here the stroke counts as worked
	double  apex;          // CYCLE: where the hand feels it stop -- the apex sound
	double  homeAt;        // CYCLE, returned by hand: back to here is home again
	double  openAt;        // OPEN: past here it is open
	// OPEN: back to here it is SHUT again, and only shut does the gun fire. Apart from
	// openat on purpose: a break-top let go of half way is neither open (its cases are
	// still in) nor shut (it will not fire), and one number for both would flicker
	// between the two on a hand resting near it.
	double  closeAt;
	double  seatAt;      // SWAP: in to here the catch takes it; < 0 = wm_seat_at, live
	double  detachAt;      // SWAP: let go past here and it drops
	double  pullOutAt;     // SWAP: pulled to here it is in the hand
	double  at;            // EJECT: past here it throws

	int     ret;           // RET_*
	bool    autoOnShot;          // CYCLE: the shot works it
	// CYCLE: with autoOnShot, the shot does the stroke's bookkeeping (eject, feed,
	// hold-open) but DRAWS NO MOTION -- a non-reciprocating handle (a Vector-style
	// SMG) sits still while firing. Card: `auto = onshotstill`.
	bool    autoOnShotStill;
	bool    holdOpenWhenEmpty;   // CYCLE: held at full travel when there was nothing to feed
	bool    onOutEject;          // CYCLE: the far end empties fromStore's selected slot
	bool    onHomeFeed;          // CYCLE: the near end moves a round feedStore -> intoStore
	bool    onOpenEjectAll;      // OPEN: opening empties every slot of fromStore (step 8)
	String  closeBy;             // OPEN: flick | hand (step 11)
	// OPEN, close = flick (WM_Rig.FlickByVerbs): the way a flick shuts it, in the gun's model
	// axes -- `flickaxis = up` (0, 0, 1, also the unstated default), `side` (across the gun,
	// signed by the part's own shutting motion: FlickSideSign) or a vector -- and how hard, as a
	// multiple of wm_flick_speed (`flickscale`, default 1).
	Vector3 flickAxis;
	bool    flickAxisSide;
	double  flickScale;
	bool    flickStated;         // flickaxis or flickscale was said, for the refusal without close = flick
	bool    all;                 // EJECT: every slot, not the selected one
	// EJECT: WHAT THROWS IT. False, `by = hand`: a hand works `part` past `at`, as a rod
	// is pushed. True, `by = tilt`: the gun itself, one of its axes pointed up past `at` (the
	// sine of that axis's elevation, 0..1) while `needs` holds open. `tiltaxis = down` is a
	// break-top turned past its side or over, its cases falling out; `by = muzzleup` is
	// shorthand for a tilt along the bore -- a swing-out's rounds falling out backward. No part
	// is named: the gun is what moves.
	bool    ejectByTilt;
	bool    tiltAlongBarrel;   // the tilt is the bore's (by = muzzleup, tiltaxis = barrel)
	Vector3 tiltAxis;          // otherwise this gun model-space axis, unit
	bool    tiltAxisStated;

	// ---- STORES, by name --------------------------------------------------------
	String  fromStore;     // CYCLE onout, OPEN onopen, EJECT: what is emptied
	String  feedStore;     // CYCLE onhome: where the fed round comes from
	String  intoStore;     // CYCLE onhome, LOAD: where a round goes
	String  storeId;       // SWAP: the container that leaves

	// ---- LOAD (step 7) ----------------------------------------------------------
	int     slot;          // a slotted target's index, -1 when unstated
	bool    slotNext;      // `slot = next`: the first empty one
	String  subject;       // what shape the hand holds the round in
	Vector3 loadAt;        // the load point, model space
	Vector3 loadSize;      // its oval's half-sizes
	// THE WAY A ROUND TRAVELS GOING IN, model space, unit; zero when unstated. A
	// bottom port loads upward and a side port inward, and a load that drives the
	// mesh's own shell along its line needs to know which. Nothing moves by it yet:
	// it is on the card, in the bind log and in wm_dump, so every zone says its way.
	Vector3 loadDir;
	// LOAD: A PART WHOSE MOTION CARRIES THE ZONE. `rides = barrel`: `at` is where the zone
	// is with that part at rest, and it goes wherever the part goes -- a break-top's
	// cylinder face tips down with the barrel, a crane's swings out. Unstated, the zone is
	// fixed to the gun, as a tube's gate is.
	String  ridesId;
	int     ridesIndex;

	String  needsOpen;    // LOAD, EJECT: an OPEN verb's id that must be open
	// THE GUN'S DROP-MAG BUTTON WORKS IT. SWAP (default yes): it drops the magazine. OPEN
	// (default no): it opens the gun if shut. EJECT (default no): once its gate is open it
	// throws out everything in its store, whichever way the gun is held (WM_System.ButtonWorksVerbs).
	bool    button;
	bool    handTake;      // SWAP: a hand may take the part and pull it

	// ---- PULLOFF AND RELEASE (THROWABLE_PLAN.md §2.3) ------------------------------
	double  offAt;         // PULLOFF: pulled past here along its dof, the part comes away
	bool    pullByHead;    // PULLOFF: `by = head`, brought to the mouth; unset `hand`, the other hand
	bool    needsTrigger;  // PULLOFF: `needs = trigger`, only while the holding hand's trigger is held
	bool    arms;          // PULLOFF: a throw after it is live; unset yes
	bool    heldByGrip;    // RELEASE: `heldby = grip`, the holding hand's grip keeps it shut -- the one way

	// ---- WHAT THE CARD SAID, for an override and for refusals ---------------------
	bool    handTakeStated;
	bool    homeAtStated;
	bool    closeAtStated;
	Array<String> keys;   // every key the block stated, in order
	Array<String> vals;

	// EVERY DEFAULT, in one place. The CYCLE and SWAP numbers are the old role
	// code's own: Hold's `v > 0.6` and `v >= 0.95`, the magazine's `v >= 0.97`.
	void Init(int verbKind, String verbId)
	{
		kind       = verbKind;
		id         = verbId;
		origin     = FROM_DECLARED;
		originName = "";
		sourceName = "";
		line       = 0;

		partId     = "";
		partIndex  = -1;
		latchId    = "";
		latchIndex = -1;
		latchAt    = 0.8;
		latchReturnSpring = false;

		outAt     = 0.6;
		apex      = 0.95;
		homeAt    = 0.1;
		openAt    = 0.9;
		closeAt   = 0.05;
		seatAt    = -1.0;
		detachAt  = -1.0;    // unstated: the part's own dof.detach, settled once the card is whole
		pullOutAt = 0.97;
		at        = -1.0;

		ret = (verbKind == OPEN) ? RET_STAY : RET_SPRING;
		if (verbKind == START) outAt = 0.85;   // most of the pull: a cord is yanked, not nudged
		autoOnShot        = false;
		autoOnShotStill   = false;
		holdOpenWhenEmpty = false;
		onOutEject        = false;
		onHomeFeed        = false;
		onOpenEjectAll    = false;
		closeBy           = "";
		flickAxis         = (0, 0, 0);
		flickAxisSide     = false;
		flickScale        = 1.0;
		flickStated       = false;
		all               = false;
		ejectByTilt       = false;
		tiltAlongBarrel   = false;
		tiltAxis          = (0, 0, 0);
		tiltAxisStated    = false;

		fromStore = "";
		feedStore = "";
		intoStore = "";
		storeId   = "";

		slot      = -1;
		slotNext  = false;
		subject   = "";
		loadAt    = (0, 0, 0);
		loadSize  = (0, 0, 0);
		loadDir   = (0, 0, 0);
		ridesId    = "";
		ridesIndex = -1;
		needsOpen = "";
		button    = (verbKind == SWAP);
		handTake  = true;
		offAt        = 0.9;
		pullByHead   = false;
		needsTrigger = false;
		arms         = true;
		heldByGrip   = true;

		handTakeStated = false;
		homeAtStated   = false;
		closeAtStated  = false;
		keys.Clear();
		vals.Clear();
	}

	// A WHOLE, SEPARATE VERB. An archetype's verbs are copied into every card that
	// follows it, so a card resolving its part index can never touch another's.
	WM_Verb Copy()
	{
		let c = new("WM_Verb");
		c.kind = kind;  c.id = id;  c.origin = origin;  c.originName = originName;
		c.sourceName = sourceName;  c.line = line;
		c.partId = partId;  c.partIndex = partIndex;  c.latchId = latchId;  c.latchIndex = latchIndex;  c.latchAt = latchAt;  c.latchReturnSpring = latchReturnSpring;
		c.outAt = outAt;  c.apex = apex;  c.homeAt = homeAt;  c.openAt = openAt;  c.closeAt = closeAt;
		c.seatAt = seatAt;  c.detachAt = detachAt;  c.pullOutAt = pullOutAt;  c.at = at;
		c.ret = ret;  c.autoOnShot = autoOnShot;  c.autoOnShotStill = autoOnShotStill;  c.holdOpenWhenEmpty = holdOpenWhenEmpty;
		c.onOutEject = onOutEject;  c.onHomeFeed = onHomeFeed;  c.onOpenEjectAll = onOpenEjectAll;
		c.closeBy = closeBy;  c.all = all;
		c.flickAxis = flickAxis;  c.flickAxisSide = flickAxisSide;  c.flickScale = flickScale;  c.flickStated = flickStated;
		c.ejectByTilt = ejectByTilt;  c.tiltAlongBarrel = tiltAlongBarrel;  c.tiltAxis = tiltAxis;  c.tiltAxisStated = tiltAxisStated;
		c.fromStore = fromStore;  c.feedStore = feedStore;  c.intoStore = intoStore;  c.storeId = storeId;
		c.slot = slot;  c.slotNext = slotNext;  c.subject = subject;
		c.loadAt = loadAt;  c.loadSize = loadSize;  c.loadDir = loadDir;
		c.ridesId = ridesId;  c.ridesIndex = ridesIndex;
		c.needsOpen = needsOpen;  c.button = button;  c.handTake = handTake;
		c.offAt = offAt;  c.pullByHead = pullByHead;  c.needsTrigger = needsTrigger;  c.arms = arms;  c.heldByGrip = heldByGrip;
		c.handTakeStated = handTakeStated;  c.homeAtStated = homeAtStated;  c.closeAtStated = closeAtStated;
		for (int i = 0; i < keys.Size(); i++) { c.keys.Push(keys[i]); c.vals.Push(vals[i]); }
		return c;
	}

	// WHICH WAY ACROSS THE GUN A PART SHUTS, for `flickaxis = side`: the sign of its grab point's
	// y shut minus fully open, +1 or -1; 0 when it does not move across. A hinge turns the grab
	// point about its pivot; a slide carries it along the axis.
	static int FlickSideSign(WM_Part part)
	{
		if (!part || !part.dof) return 0;
		let d = part.dof;
		Vector3 openGrab;
		if (d.moveKind == WM_Dof.MOVE_HINGE) openGrab = d.pivot + WM_Space.Rotate(part.grabAt - d.pivot, d.axis, d.degrees);
		else                                 openGrab = part.grabAt + d.axis * d.distance;
		double across = part.grabAt.Y - openGrab.Y;
		if (abs(across) < 0.001) return 0;
		return (across > 0) ? 1 : -1;
	}

	// ---- THE SYNTHESIS RULE, in one place ------------------------------------
	//
	// What the old role code did, as verbs, for a card that declares none. Every
	// number is copied from that code, not from the spec: where the two disagreed
	// the code is what the headset was tuned against.

	// THE `role = action` PART. OnShot started the clock whenever an action part
	// existed (auto); WM_Ammo.Fire and Cycle set the lock when nothing fed
	// (holdopen); Release wrote `value = actionLock ? 1 : 0` (spring); Hold and
	// Release compared against 0.6 and 0.95; Racked threw the chambered round and
	// fed the next from the magazine.
	static WM_Verb SynthCycle(String partName, int partAt, String feedId, String chamberId)
	{
		let v = new("WM_Verb");
		v.Init(CYCLE, "rack");
		v.origin            = FROM_SYNTH;
		v.partId            = partName;
		v.partIndex         = partAt;
		v.outAt             = 0.6;
		v.apex              = 0.95;
		v.onOutEject        = true;
		v.fromStore         = chamberId;
		v.onHomeFeed        = true;
		v.feedStore         = feedId;
		v.intoStore         = chamberId;
		v.ret               = RET_SPRING;
		v.holdOpenWhenEmpty = true;
		v.autoOnShot        = true;
		return v;
	}

	// THE `role = feed` PART. Guide read wm_seat_at live every tic (seatAt left
	// unstated says exactly that); Release dropped it past the part's own
	// dof.detach; Hold put it in the hand at 0.97; the drop-mag button always
	// worked it; NearestPart honoured the part's `take`.
	static WM_Verb SynthSwap(WM_Part part, int partAt, String magId)
	{
		let v = new("WM_Verb");
		v.Init(SWAP, "magwell");
		v.origin    = FROM_SYNTH;
		v.partId    = part.id;
		v.partIndex = partAt;
		v.storeId   = magId;
		v.seatAt    = -1.0;
		v.detachAt  = part.dof.detach;
		v.pullOutAt = 0.97;
		v.button    = true;
		v.handTake  = part.handTake;
		return v;
	}

	// ---- THE SWITCH -------------------------------------------------------------
	//
	// wm_verbs, read as the tic reads it. Unset -- a load with no CVARINFO from this
	// package -- means the interpreter, which is the build's default.
	// PRESENTATION AND THE LOCAL TIC ONLY. This reads the CONSOLE player, so it
	// answers "what is this machine's own player set to" -- right for a log line,
	// for what this machine draws, and for the hand loop, which works only the
	// console player's hands anyway.
	//
	// NEVER ON A PATH THAT DECIDES WHETHER A SHOT HAPPENS. wm_verbs is a `user`
	// cvar, so two players can hold different values; a fire path that asked this
	// one had every machine answer for its own player, and two machines then
	// disagreed about whether a trigger pull fired at all. Use EnabledFor(pn).
	static bool Enabled()
	{
		let c = CVar.GetCVar("wm_verbs", players[consoleplayer]);
		return c ? c.GetBool() : true;
	}

	// PER PLAYER, FOR GAMEPLAY. The same question asked about the player whose
	// trigger was pulled, so every machine reaches the same answer about the same
	// shot -- exactly the shape WM_System.ReloadMode(pn) already uses, and for the
	// same reason. A `user` cvar's value travels with its player, so players[pn]
	// is correct on every machine, not just that player's own.
	//
	// In single player the owner IS the console player and nothing changes.
	static bool EnabledFor(int pn)
	{
		if (pn < 0 || pn >= MAXPLAYERS || !playeringame[pn]) return true;
		let c = CVar.GetCVar("wm_verbs", players[pn]);
		return c ? c.GetBool() : true;
	}

	// ---- WORDS, for the parser and the log ----------------------------------------

	static int KindFromWord(String word)
	{
		if (word == "cycle") return CYCLE;
		if (word == "open")  return OPEN;
		if (word == "swap")  return SWAP;
		if (word == "load")  return LOAD;
		if (word == "eject") return EJECT;
		if (word == "start") return START;
		if (word == "pulloff") return PULLOFF;
		if (word == "release") return RELEASE;
		return -1;
	}

	static String KindName(int verbKind)
	{
		switch (verbKind)
		{
			case CYCLE: return "cycle";
			case OPEN:  return "open";
			case SWAP:  return "swap";
			case LOAD:  return "load";
			case EJECT: return "eject";
			case START: return "start";
			case PULLOFF: return "pulloff";
			case RELEASE: return "release";
		}
		return String.Format("verb%d", verbKind);
	}

	static String ReturnName(int r)
	{
		if (r == RET_HAND) return "hand";
		if (r == RET_STAY) return "stay";
		return "spring";
	}

	// Where it came from, as the bind log says it.
	String OriginText()
	{
		if (origin == FROM_SYNTH)     return "synthesised from the old role code";
		if (origin == FROM_ARCHETYPE) return "from archetype " .. originName;
		if (origin == FROM_OVERRIDE)  return String.Format("from archetype %s, the card changing: %s", originName, StatedKeys());
		return "declared by the card";
	}

	String StatedKeys()
	{
		String s = "";
		for (int i = 0; i < keys.Size(); i++) s = s .. (i > 0 ? ", " : "") .. keys[i];
		return (s == "") ? "nothing" : s;
	}

	// ONE VERB, ONE LINE, WITH ITS NUMBERS. liveSeatAt is wm_seat_at as it reads
	// now, for a swap that leaves its seat to that slider.
	String Describe(double liveSeatAt)
	{
		String s = KindName(kind) .. " " .. id;
		if (partId != "") s = s .. " on " .. partId;

		if (kind == CYCLE)
		{
			s = s .. String.Format(": out at %.2f, apex %.2f", outAt, apex);
			s = s .. (onOutEject ? (", out ejects from " .. fromStore) : ", out does nothing");
			s = s .. (onHomeFeed ? String.Format(", home feeds %s -> %s", feedStore, intoStore) : ", home does nothing");
			s = s .. ", return " .. ReturnName(ret);
			if (ret != RET_SPRING) s = s .. String.Format(" (home at %.2f)", homeAt);
			s = s .. (holdOpenWhenEmpty ? ", holds open when empty" : ", never holds open");
			s = s .. (autoOnShot ? (autoOnShotStill ? ", cycles on the shot, handle drawn still" : ", cycles on the shot") : ", manual");
		}
		else if (kind == OPEN)
		{
			s = s .. String.Format(": open at %.2f, shut at %.2f, rest %s -- will not fire unless shut", openAt, closeAt, ReturnName(ret));
			if (latchId != "")    s = s .. String.Format(", its latch %s thrown past %.2f before a hand takes it%s", latchId, latchAt,
				latchReturnSpring ? " (it springs back: a second to take it)" : "");
			if (onOpenEjectAll)   s = s .. ", opening throws out every case in " .. fromStore;
			if (closeBy == "flick")
			{
				String flickWay = "up";
				if (flickAxisSide) flickWay = "sideways";
				else if (flickAxis.Length() > 0.5 && flickAxis.Z < 0.9999) flickWay = String.Format("along (%.2f, %.2f, %.2f)", flickAxis.X, flickAxis.Y, flickAxis.Z);
				s = s .. String.Format(", shuts by a flick %s at %.2f x wm_flick_speed, or by hand", flickWay, flickScale);
			}
			else if (closeBy == "hand") s = s .. ", shuts by hand";
			if (button)           s = s .. ", the drop-mag button opens it";
		}
		else if (kind == SWAP)
		{
			s = s .. ": store " .. storeId;
			if (seatAt >= 0) s = s .. String.Format(", seats at %.2f", seatAt);
			else             s = s .. String.Format(", seats at wm_seat_at (%.2f now)", liveSeatAt);
			s = s .. String.Format(", drops past %.2f, in hand at %.2f", detachAt, pullOutAt);
			s = s .. (button ? ", button yes" : ", button NO");
			s = s .. (handTake ? ", hand take yes" : ", hand take no");
			if (latchId != "") s = s .. String.Format(", its latch %s thrown past %.2f before it drops, seats or comes out%s", latchId, latchAt,
				latchReturnSpring ? " (it springs back: a second to work it)" : "");
		}
		else if (kind == LOAD)
		{
			s = s .. ": into " .. intoStore;
			if (slotNext)       s = s .. ", slot next";
			else if (slot >= 0) s = s .. String.Format(", slot %d", slot);
			s = s .. String.Format(", at (%.2f, %.2f, %.2f) size (%.2f, %.2f, %.2f)",
				loadAt.X, loadAt.Y, loadAt.Z, loadSize.X, loadSize.Y, loadSize.Z);
			if (loadDir.Length() > 0.5) s = s .. String.Format(", goes in along (%.2f, %.2f, %.2f)", loadDir.X, loadDir.Y, loadDir.Z);
			else                        s = s .. ", no dir stated";
			if (subject != "") s = s .. ", subject " .. subject;
			if (ridesId != "") s = s .. ", rides " .. ridesId;
			if (subject == "loader")
				s = s .. " -- a loader let go of inside this oval fills every empty slot it can, one round fills one (wm_verbs on)";
			else
				s = s .. " -- a round let go of inside this oval goes in (wm_verbs on)";
		}
		else if (kind == EJECT)
		{
			if (ejectByTilt && tiltAlongBarrel)
				s = s .. String.Format(": the muzzle pointed up past %.2f throws out every case in %s", at, fromStore);
			else if (ejectByTilt)
				s = s .. String.Format(": the gun's (%.2f, %.2f, %.2f) axis pointed up past %.2f throws out every case in %s",
					tiltAxis.X, tiltAxis.Y, tiltAxis.Z, at, fromStore);
			else
				s = s .. String.Format(": worked past %.2f, throws out every case in %s", at, fromStore);
			if (button) s = s .. ", and the drop-mag button throws them out too";
		}
		else if (kind == START)
			s = s .. String.Format(": pulled past %.2f the engine starts, and it springs home -- the gun fires only while its engine runs", outAt);
		else if (kind == PULLOFF)
			s = s .. String.Format(": pulled past %.2f by %s it comes away%s%s", offAt, pullByHead ? "the mouth" : "the other hand",
				needsTrigger ? ", only while the holding hand's trigger is held" : "", arms ? ", arming it" : ", arming nothing");
		else if (kind == RELEASE)
			s = s .. ": held shut by the holding hand's grip, it springs off when that hand lets go";
		if (needsOpen != "") s = s .. ", needs open:" .. needsOpen;
		return s;
	}
}

// ============================================================================
// AN ARCHETYPE: DEFAULT VERBS FOR A KIND OF GUN.
//
// Eighty curated guns in a handful of mechanisms are mostly measurements. The
// card for each says where its parts are and how far they move; `mechanism =
// pistol` says what the gun does with them. A card's own verb block under an
// archetype verb's id changes only the keys it states; a verb id the archetype
// lacks is added; a card may state no verbs at all and inherit every one.
//
// An archetype holds verb blocks and one `type` line. Parts and stores are
// measured on each gun's own card.
//
// ITS `type` IS THE KIND OF GUN IT MAKES -- `type = shotgun` on the pump -- which a
// card taking this mechanism with no `type` of its own inherits (WM_Parser.FinishCard),
// and with it the hand seats that kind of gun reads (handprofile.zs).
// ============================================================================

class WM_Archetype
{
	String id;
	String sourceName;
	int    line;
	String gunType;      // `type = <word>`; "" when it states none
	Array<WM_Verb> verbs;

	WM_Verb FindVerb(String verbId)
	{
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].id ~== verbId) return verbs[i];
		return null;
	}
}
