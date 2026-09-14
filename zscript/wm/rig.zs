// ============================================================================
// ONE GUN IN ONE HAND.
//
// Everything that belongs to a single gun: its card, the prop drawn on the
// controller, its magazine and chamber, where each part is, and what a shot
// does. Two of these run at once -- one per hand -- and neither knows the other
// exists. The system decides which hand works which gun.
//
// NOTHING IN HERE NAMES A GUN. It knows parts, degrees of freedom, roles and
// verbs. If a second gun needed a line added here, the design would have failed.
//
// ------------------------------------------------------ TWO PATHS, ONE BUILD
//
// wm_verbs on: the card's verbs (verb.zs) run the action -- CycleByVerbs,
// ShotByVerbs, RackByVerbs, StrokeOut / StrokeHome. Off: Cycle, the ammo lines
// in OnShot, and Racked, exactly as they were. Both paths read and write the
// same WM_Ammo, so flipping the switch mid-game leaves a gun as it was.
//
// ---------------------------------------------------------------- SLOTS
//
// Surface overrides live in sixteen slots and THE LOWEST SLOT WINS for a given
// surface; values never add. So the hand drive takes slots 0-3 and every parked
// pose starts at 4. While a hand holds a part, the drive at 0 is what is drawn
// and the parked slot underneath is kept at the DRAWN value -- so on the tic the
// hand lets go, the parked pose already agrees with the screen and nothing jumps.
// ============================================================================

class WM_Rig play
{
	int     hand;        // the hand that HOLDS this gun: 0 main, 1 off
	WM_Card card;
	Weapon  gunItem;      // the inventory instance it was bound for
	Actor   prop;
	WM_Ammo ammo;
	bool    resolved;
	bool    stowed;      // its hand is busy working the other gun

	int     heldPart;    // a part the OTHER hand has hold of, -1
	int     cycleTics;
	int     hammerDownTics;
	bool    hammerCocked;
	bool    pastBack;    // pulled far enough during this hold to feed
	bool    atApex;      // reached full travel during this hold -- its sound played
	// A DOUBLE-ACTION HAMMER HAS FALLEN (WM_Part.cockByTrigger): set by the shot and by an
	// in-battery click, cleared once the finger is off the trigger. Read by no other hammer.
	bool    hammerFell;
	RSB_Flash lastFlash;  // this hand's last muzzle flash, retired by the next (FlashAt)
	int     brassSeq;     // casings this gun has thrown, for their jitter -- never the playsim RNG
	int     firedTic;     // the tic it last fired, for a part that spins while it fires (WM_Part.SPIN_FIRE)
	bool    spinLoopOn;   // the card's spin loop is playing on the prop (Spin)
	bool    idleLoopOn;   // the card's engine idle is playing on the prop (EngineIdle)
	// THE METER STEP EACH PART'S GAUGE SHOWS NOW (Meter), -1 unknown; and the prop it was set on,
	// since a fresh prop wears its MODELDEF skin again.
	Array<int> meterShown;
	// THE LAST TIC EACH VERB'S LATCH WAS THROWN (LatchesTick), for a spring latch's grace.
	Array<int> verbLatchTic;
	Actor      meterProp;
	// The prop's sound channel for that loop, so stopping it stops nothing else: the shot is on
	// CHAN_WEAPON and every other gun sound on CHAN_AUTO.
	const SPIN_CHANNEL = 7;
	// The engine idle's own channel (EngineIdle), for the same reason.
	const IDLE_CHANNEL = 6;

	// ---- THE VERBS' LIVE STATE, one entry per card verb (verb.zs) ------------
	//
	// A verb is card data and a card is shared; what a verb is doing right now is
	// this gun's. Indexed like card.verbs, sized fresh at every Bind.
	Array<int>  verbTics;     // CYCLE on the shot: tics left in the shot's stroke
	Array<int>  verbStroke;   // CYCLE returned by hand: STROKE_HOME or STROKE_OUT
	Array<bool> verbOpen;     // OPEN, and a CYCLE that stays: held open
	Array<bool> verbThrown;   // EJECT: has thrown this stroke or this tilt; re-armed by the way back
	// OPEN, close = flick (FlickByVerbs): grace tics left after a hand lets go or the part leaves
	// shut, the last tic's speed along the flick, and whether the hand has settled since the grace.
	Array<int>    verbFlickQuiet;
	Array<double> verbFlickLast;
	Array<bool>   verbFlickCalm;
	// About a sixth of a second: the jerk that yanked it open, or the thumb on the drop-mag button,
	// never shuts it again. A constant rather than a slider -- it is a guard, not a feel.
	const FLICK_GRACE_TICS = 6;

	const STROKE_HOME = 0;    // the next pull past outat does the far end
	const STROKE_OUT  = 1;    // the far end is done; back to homeat does the near end

	// Surface-override slots: each (part, surface) gets ONE for life, and the
	// pose and the hand drive share it. See Bind for why they must.
	const SLOT_BASE   = 0;
	const SLOTS       = 16;

	// GRAB SLOTS PER GUN: the eight the grab-point page lists and picks from (wm_tune_part), and the
	// same eight WM_System.SEL_PER_GUN counts. A card's parts take slots 0 up by index; its load points
	// number on after them (LoadTagIndex). Only the picked slot reads the scratch set (IsTuned).
	const GRAB_SLOTS  = 8;

	// WHICH SEAT A HAND ON THIS PART TAKES -- the <seat> of its hand seat set,
	// wm_hs_<profile>_<main|off>_<seat> (handprofile.zs: the profile is the GUN's type,
	// so a pistol's slide and a revolver's hammer never share numbers again). Named by
	// the grip: a magazine, a forend (a pump's, held under the gun), a foregrip (what a
	// hand takes to open a gun -- a break-top's barrel, a crane's cylinder -- its own
	// seat, since that wrist is not a pump's), or a slide -- which is also what any
	// other part falls back to, as it always did.
	static String HandSeatKind(WM_Part part)
	{
		if (!part) return "slide";
		if (part.role == "feed") return "mag";
		if (part.subject == "forend") return "forend";
		if (part.subject == "foregrip") return "foregrip";
		return "slide";
	}

	static double Cvf(String n, double d)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetFloat() : d;
	}
	static bool Cvb(String n, bool d)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetBool() : d;
	}

	String HandName() { return hand == 0 ? "main" : "off"; }

	void Init(int h)
	{
		hand = h;
		heldPart = -1;
		hammerCocked = true;
	}

	// FIFTEEN IN THE MAGAZINE, ONE UP THE SPOUT, HAMMER COCKED. How a loaded
	// pistol is carried, and how each gun starts.
	void Bind(WM_Card c, Weapon w)
	{
		card   = c;
		gunItem = w;

		// THE GUN'S ROUNDS LIVE ON THE GUN. First time in a hand it comes
		// loaded, 15 + 1; every time after, exactly as it was left -- empty,
		// locked back, magazine out. A fresh WM_Ammo per bind was a free reload
		// for anyone who switched to the fist and back.
		let g = WM_Gun(w);
		bool fresh = !g || !g.wmAmmo;
		if (fresh)
		{
			ammo = new("WM_Ammo");
			ammo.Init(c.capacity, c);
			if (g) g.wmAmmo = ammo;
		}
		else ammo = g.wmAmmo;

		resolved = false;
		heldPart = -1;
		cycleTics = 0;
		hammerDownTics = 0;
		hammerCocked = true;
		hammerFell = false;
		pastBack = false;
		atApex   = false;
		spinLoopOn = false;
		idleLoopOn = false;

		// ONE OVERRIDE SLOT PER (PART, SURFACE), FOR LIFE, SHARED BY THE POSE AND
		// THE HAND DRIVE. They used to be separate -- drive in 0-3, pose from 4 --
		// and ClearModelSurfaceDrive only switches a drive OFF: the slot still
		// names its surface, the lowest slot wins, and a slot with nothing else
		// in it draws the part at rest. So after the first grab the slide could
		// never show locked back and the magazine could never be hidden again.
		// Sharing one slot, letting go hands the part straight back to the pose
		// script has been writing all along. Reserved per NAMED surface, so the
		// numbering never depends on what the mesh turned out to contain.
		int slot = SLOT_BASE;
		for (int i = 0; i < c.parts.Size(); i++)
		{
			let p = c.parts[i];
			p.present   = (p.role == "feed") ? ammo.magIn : true;
			p.driveSlot = -1;
			if (p.role == "hammer")      p.value = p.cockByTrigger ? 0.0 : 1.0;
			else if (p.role == "action") p.value = ammo.actionLock ? 1.0 : 0.0;
			else                         p.value = 0.0;
			if (p.dof2) p.pastSplit = (p.value > p.dof2.split);   // where it starts is not a crossing
			p.spinSpeed = 0.0;   // a spinning part comes into the hand still

			int n = p.surfaceNames.Size();
			p.poseSlot = -1;
			if (n == 0) continue;
			if (slot + n > SLOTS)
			{
				WM_Log.Err(String.Format("part '%s': more moving surfaces than the %d override slots -- it will not move", p.id, SLOTS));
				continue;
			}
			p.poseSlot = slot;
			slot += n;
		}
		WM_Log.Info(String.Format("%s hand: %s -- %d parts, %s", HandName(), c.weaponClass, c.parts.Size(),
			fresh ? (c.FiresFromMagazine() ? String.Format("loaded, %d in the magazine -- no chamber, it fires straight from it", ammo.rounds)
			                               : String.Format("loaded, %d + 1 chambered", ammo.rounds))
			      : String.Format("as it was left: magazine %s, %d in it, chamber %s%s",
			            ammo.magIn ? "in" : "OUT", ammo.rounds, ammo.chambered ? "loaded" : "empty",
			            ammo.actionLock ? ", slide locked back" : "")));
		// WHERE ITS ROUNDS LIVE, once per bind: every store, and whether the card
		// declared it or it was synthesised (store.zs).
		WM_Log.Info(String.Format("%s hand: %s stores -- %s", HandName(), c.weaponClass, ammo.DescribeStores()));
		BindVerbs();
		LogHandProfile();
	}

	// THE HAND PROFILE, ONCE PER BIND (handprofile.zs): what kind of gun this is, the
	// hand seat set a hand on each part it has reads, and every fallback past a set
	// nobody declared. "Why is my hand in the wrong place on this gun" starts here.
	private void LogHandProfile()
	{
		Array<String> hsKinds;
		for (int i = 0; i < card.parts.Size(); i++)
		{
			if (!card.PartIsWorkable(i)) continue;
			let hp = card.parts[i];
			String hsKind = (hp.role == "support") ? "support" : HandSeatKind(hp);
			bool hsListed = false;
			for (int k = 0; k < hsKinds.Size(); k++)
				if (hsKinds[k] == hsKind) hsListed = true;
			if (!hsListed) hsKinds.Push(hsKind);
		}
		String hsSets = "";
		String hsMissed = "";
		for (int k = 0; k < hsKinds.Size(); k++)
		{
			String hsSet, hsProfile, hsFell;
			[hsSet, hsProfile, hsFell] = WM_HandProfile.SeatPrefix(card, hand, hsKinds[k]);
			hsSets = hsSets .. ((k > 0) ? ", " : "") .. hsSet .. "_*";
			if (hsFell != "") hsMissed = hsMissed .. ((hsMissed != "") ? "; " : "") .. hsFell;
		}
		WM_Log.Info(String.Format("%s hand: %s hand profile: %s -> prefix %s, fallback %s",
			HandName(), card.weaponClass, WM_HandProfile.Describe(card),
			(hsSets == "") ? "none -- no part a hand works" : hsSets,
			(hsMissed == "") ? "none" : hsMissed));
	}

	// THE VERBS, ONCE PER BIND: their live state made fresh, every part they name
	// checked against this card, and each said with its numbers and where it came
	// from -- declared, from an archetype, or synthesised from the old role code.
	private void BindVerbs()
	{
		int n = card.verbs.Size();
		verbTics.Resize(n);
		verbStroke.Resize(n);
		verbOpen.Resize(n);
		verbThrown.Resize(n);
		verbFlickQuiet.Resize(n);
		verbFlickLast.Resize(n);
		verbFlickCalm.Resize(n);
		for (int k = 0; k < n; k++)
		{
			verbTics[k]   = 0;
			verbStroke[k] = STROKE_HOME;
			verbOpen[k]   = false;
			verbThrown[k] = false;
			verbFlickQuiet[k] = FLICK_GRACE_TICS;
			verbFlickLast[k]  = 0.0;
			verbFlickCalm[k]  = false;
		}

		WM_Log.Info(String.Format("%s hand: %s verbs -- %d, path %s", HandName(), card.weaponClass, n,
			WM_Verb.Enabled() ? "VERBS (wm_verbs on): these run this gun"
			                  : "OLD (wm_verbs off): the role code runs this gun, these are read and idle"));
		double liveSeat = Cvf("wm_seat_at", 0.25);
		for (int k = 0; k < n; k++)
		{
			let v = card.verbs[k];
			if (v.partId != "")
			{
				int partAt = card.FindPartIndex(v.partId);
				if (partAt < 0)
					WM_Log.Err(String.Format("%s hand: %s verb %s names part '%s', which this card lacks -- it works nothing",
						HandName(), card.weaponClass, v.id, v.partId));
				v.partIndex = partAt;
			}
			if (v.latchId != "")
			{
				int latchAt = card.FindPartIndex(v.latchId);
				if (latchAt < 0)
					WM_Log.Err(String.Format("%s hand: %s verb %s names latch '%s', which this card lacks",
						HandName(), card.weaponClass, v.id, v.latchId));
				v.latchIndex = latchAt;
			}
			if (v.ridesId != "")
			{
				int rideAt = card.FindPartIndex(v.ridesId);
				if (rideAt < 0)
					WM_Log.Err(String.Format("%s hand: %s verb %s rides part '%s', which this card lacks -- its zone stays fixed to the gun",
						HandName(), card.weaponClass, v.id, v.ridesId));
				v.ridesIndex = rideAt;
			}
			WM_Log.Info(String.Format("  [%d] %s -- %s", k, v.Describe(liveSeat), v.OriginText()));
		}
		if (n == 0) WM_Log.Info("  none: nothing on this gun is worked by a verb");
		LogShotAndLoads();
	}

	// THE SHOT OF THE GUN BOUND HERE, for the logs -- read off the weapon class
	// (WM_Gun.ShotPellets / ShotSpread / ShotDamage), not the card, which no longer
	// says what a gun fires.
	private String GunShotText()
	{
		let g = WM_Gun(gunItem);
		if (!g) return "no WM_Gun bound -- it fires nothing of this system's";
		return g.ShotText();
	}

	// THE SHOT AND THE LOAD POINTS, ONCE PER BIND: what a trigger pull fires, where a
	// round goes in and into what, and -- for a gun loaded a round at a time or worked
	// by hand -- the sounds it makes and what the pouch hands it.
	private void LogShotAndLoads()
	{
		// WHAT A PULL SPENDS AND WHETHER A CASE LEAVES (WM_Card.firesFrom, noCasing), once per bind.
		String firesText = "its chamber";
		if (card.firesFrom == WM_Card.FIRES_MAGAZINE)     firesText = "its magazine -- no chamber, nothing to rack";
		else if (card.firesFrom == WM_Card.FIRES_RESERVE)
			firesText = (card.barrels.Size() > 0) ? "the owner's reserve -- no stores but its second barrel's" : "the owner's reserve -- no stores";
		else if (card.firesFrom == WM_Card.FIRES_NOTHING) firesText = "nothing -- no ammunition";
		WM_Log.Info(String.Format("%s hand: %s shot -- %s; fires from %s%s%s", HandName(), card.weaponClass, GunShotText(),
			firesText, card.noCasing ? "; no casing" : "",
			card.NeedsTwoHands() ? "; hands 2 -- fires only while the other hand holds its support grip" : ""));
		// A WEAPON THAT LEAVES THE HAND (throw.zs), once per bind: its throw, route, fuse and mount.
		if (card.throwSpec)
		{
			WM_Log.Info(String.Format("%s hand: %s throw -- %s%s", HandName(), card.weaponClass, card.throwSpec.Describe(),
				card.pouchWhole ? "; the pouch hands a whole one" : ""));
			if (card.routeSpec) WM_Log.Info(String.Format("%s hand: %s route -- %s", HandName(), card.weaponClass, card.routeSpec.Describe()));
			if (card.fuseSpec)  WM_Log.Info(String.Format("%s hand: %s fuse -- %s", HandName(), card.weaponClass, card.fuseSpec.Describe()));
			if (card.mountSpec) WM_Log.Info(String.Format("%s hand: %s %s", HandName(), card.weaponClass, card.mountSpec.Describe()));
		}
		// EVERY SECOND BARREL (card.zs WM_Barrel), once per bind: its input, store, shot, ammo and gate.
		for (int bi = 0; bi < card.barrels.Size(); bi++)
		{
			let br = card.barrels[bi];
			WM_Log.Info(String.Format("%s hand: %s barrel %s -- on %s, fires %s from %s (the pouch hands its rounds from %s), trigger part %s, %s, %d tics a shot, muzzle %s along %s%s",
				HandName(), card.weaponClass, br.id, WM_Barrel.InputWord(br.input),
				(br.shotClassName != "") ? br.shotClassName : "RSB_Bullet", br.fromStore,
				(br.ammoClassName != "") ? br.ammoClassName : "the weapon's own reserve",
				(br.triggerId != "") ? br.triggerId : "none",
				(br.needsShut != "") ? ("fires only while open " .. br.needsShut .. " is shut, which stops only this barrel") : "no gate",
				br.CycleTics(), WM_Log.Vec(br.muzzle), WM_Log.Vec(br.dir), br.noCasing ? ", no cases" : ""));
		}
		// A BELT LINK WITH EVERY CASE (card `linkmodel`, G16), once per bind.
		if (card.linkModelFile != "")
			WM_Log.Info(String.Format("%s hand: %s throws a belt link with every case -- %s/%s at scale %.2f%s", HandName(), card.weaponClass,
				card.linkModelPath, card.linkModelFile, (card.linkScale > 0) ? card.linkScale : 0.34,
				card.noCasing ? " -- but casing = none, so no case leaves and no link with it" : ""));
		// EVERY CARD HAND SEAT, once per bind: where a hand gripping that part is put,
		// and which live set trims it. A part with none (every pistol part) says nothing.
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let sp = card.parts[i];
			if (!sp.handSeatStated) continue;
			String hsSet, hsProfile, hsFell;
			[hsSet, hsProfile, hsFell] = WM_HandProfile.SeatPrefix(card, hand, HandSeatKind(sp));
			WM_Log.Info(String.Format("%s hand: %s hand seat on %s -- %s model (card handseat), rides the part, trimmed live by %s_*",
				HandName(), card.weaponClass, sp.id, WM_Log.Vec(sp.handSeat), hsSet));
		}
		// EVERY TWO-STAGE PART, once per bind: both stages and the split (WM_Part.dof2).
		// A part with one stage -- every part shipped before dof2 -- says nothing here.
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let tp = card.parts[i];
			if (!tp.dof2) continue;
			WM_Log.Info(String.Format("%s hand: %s two-stage part %s -- dof %s, then dof2 %s, split %.3f",
				HandName(), card.weaponClass, tp.id, DofStageText(tp.dof), DofStageText(tp.dof2), tp.dof2.split));
		}
		// EVERY ROUND SURFACE AND DOUBLE-ACTION HAMMER, once per bind. A pistol and a pump
		// have neither, and say nothing here.
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let rp = card.parts[i];
			for (int r = 0; r < rp.roundSurfName.Size(); r++)
			{
				String which;
				if (card.StoreKindFor(rp.roundSurfStore[r]) == WM_Store.COUNTED)
					which = (rp.roundSurfSlot[r] < 0) ? (rp.roundSurfStore[r] .. " holds any round")
					                                  : String.Format("%s holds more than %d", rp.roundSurfStore[r], rp.roundSurfSlot[r]);
				else
					which = ((rp.roundSurfSlot[r] < 0) ? ("any slot of " .. rp.roundSurfStore[r])
					                                   : String.Format("slot %d of %s", rp.roundSurfSlot[r], rp.roundSurfStore[r])) .. " holds a case";
				WM_Log.Info(String.Format("%s hand: %s round surface %s rides %s -- drawn while %s",
					HandName(), card.weaponClass, rp.roundSurfName[r], rp.id, which));
			}
			if (rp.role == "hammer" && rp.cockByTrigger)
				WM_Log.Info(String.Format("%s hand: %s hammer %s is double action -- it follows the trigger back and falls on the shot or the click",
					HandName(), card.weaponClass, rp.id));
			if (rp.spinBy != WM_Part.SPIN_NONE)
				WM_Log.Info(String.Format("%s hand: %s part %s SPINS while %s -- %.2f deg a tic at full speed, up in %d tics, down in %d, wrapping every %.2f deg; sounds up %s, loop %s, down %s",
					HandName(), card.weaponClass, rp.id, (rp.spinBy == WM_Part.SPIN_TRIGGER) ? "the trigger is held" : "it fires",
					rp.spinRate, rp.spinUpTics, rp.spinDownTics, rp.dof.degrees,
					SoundText(card.spinUpSound), SoundText(card.spinSound), SoundText(card.spinDownSound)));
			if (rp.indexDof)
				WM_Log.Info(String.Format("%s hand: %s part %s INDEXES with its magazine -- a %s of %.3f a step along %s; steps = clamp(%d - rounds, 0, %d), %d now",
					HandName(), card.weaponClass, rp.id, (rp.indexDof.moveKind == WM_Dof.MOVE_HINGE) ? "turn" : "slide",
					(rp.indexDof.moveKind == WM_Dof.MOVE_HINGE) ? rp.indexDof.degrees : rp.indexDof.distance, WM_Log.Vec(rp.indexDof.axis),
					(rp.indexFrom > 0) ? rp.indexFrom : ammo.capacity, (rp.indexSteps > 0) ? rp.indexSteps : ammo.capacity, IndexSteps(rp)));
			if (rp.flipBy != WM_Part.FLIP_NONE)
				WM_Log.Info(String.Format("%s hand: %s part %s FLIPS while %s -- phase %d, %d tics a pose, %s at rest",
					HandName(), card.weaponClass, rp.id, (rp.flipBy == WM_Part.FLIP_TRIGGER) ? "the trigger is held" : "it fires",
					rp.flipPhase, (rp.flipTics > 0) ? rp.flipTics : 2, (rp.flipPhase == 0) ? "shown" : "hidden"));
			if (rp.meterSteps > 0 && rp.meterSkinFile != "")
				WM_Log.Info(String.Format("%s hand: %s part %s METERS the magazine on its surface %s -- %d steps of %s/%s",
					HandName(), card.weaponClass, rp.id, rp.meterSurface, rp.meterSteps, rp.meterSkinPath, rp.meterSkinFile));
		}
		int loads = 0;
		for (int k = 0; k < card.verbs.Size(); k++)
		{
			let v = card.verbs[k];
			if (v.kind != WM_Verb.LOAD) continue;
			loads++;
			int lt = LoadTagIndex(k);
			WM_Log.Info(String.Format("%s hand: %s load point [%d] %s -- into %s%s, at %s model, oval %s map units, goes in along %s, subject %s, %s; sliders %s",
				HandName(), card.weaponClass, k, v.id, v.intoStore, SlotText(v), WM_Log.Vec(v.loadAt), WM_Log.Vec(v.loadSize),
				(v.loadDir.Length() > 0.5) ? WM_Log.Vec(v.loadDir) : "(unstated)",
				(v.subject == "") ? "any" : v.subject, (v.needsOpen == "") ? "no gate" : ("gated on open:" .. v.needsOpen),
				(lt >= 0) ? String.Format("wm_tune_* while grab slot %d is picked", lt) : "none -- past the eight grab slots, only the whole-gun offset moves it"));
		}
		if (loads == 0) WM_Log.Info(String.Format("%s hand: %s load points -- none", HandName(), card.weaponClass));
		if (loads > 0 || ManualAction())
		{
			// WHAT A SQUEEZE IN THE POUCH DRAWS for the main barrel. A second barrel's rounds come
			// from its own ammo (card.zs WM_Barrel), said on its own line above.
			String pouchHands = "a magazine";
			if (card.PouchGivesLoader()) pouchHands = String.Format("a loader of up to %d", card.capacity);
			else if (card.PouchGivesRounds()) pouchHands = "one " .. card.RoundSubject();
			else if (card.KeepsNoRounds()) pouchHands = "nothing for the main barrel";
			if (card.barrels.Size() > 0) pouchHands = pouchHands .. " (a second barrel's rounds come from its own ammo, while its load waits)";
			WM_Log.Info(String.Format("%s hand: %s sounds -- cycle out %s, cycle home %s, load %s, eject %s; the pouch hands %s from the %s reserve",
				HandName(), card.weaponClass, SoundText(card.cycleOutSound), SoundText(card.cycleHomeSound), SoundText(card.loadSound),
				SoundText(card.ejectSound),
				pouchHands, GetDefaultByType(WM_LooseMag.ReserveFor(card.weaponClass)).GetClassName()));
		}
	}

	static String SlotText(WM_Verb v)
	{
		if (v.slotNext) return ", slot next";
		if (v.slot >= 0) return String.Format(", slot %d", v.slot);
		return "";
	}

	static String SoundText(String snd)
	{
		if (snd == "") return "silent";
		return "\"" .. snd .. "\"";
	}

	void Unbind()
	{
		if (prop && spinLoopOn) prop.A_StopSound(SPIN_CHANNEL);
		spinLoopOn = false;
		if (prop && idleLoopOn) prop.A_StopSound(IDLE_CHANNEL);
		idleLoopOn = false;
		// THE ENGINE STOPS WHEN THE GUN LEAVES THE HAND (verb.zs START): every draw is a pull.
		if (card && ammo && ammo.engineRunning)
		{
			ammo.engineRunning = false;
			String stopSound = SlotSound("stop", card.stopSound);
			if (prop && stopSound != "") prop.A_StartSound(stopSound, CHAN_AUTO, CHANF_OVERLAP);
			WM_Log.Info(String.Format("%s gun: the engine stopped -- the gun left the hand", HandName()));
		}
		if (prop) prop.Destroy();
		if (lastFlash) lastFlash.Destroy();
		prop = null;
		card = null;
		gunItem = null;
		resolved = false;
		heldPart = -1;
		stowed = false;
		verbTics.Clear();
		verbStroke.Clear();
		verbOpen.Clear();
		verbThrown.Clear();
		verbFlickQuiet.Clear();
		verbFlickLast.Clear();
		verbFlickCalm.Clear();
	}

	void Reset()
	{
		if (!card) return;
		ammo.Init(card.capacity, card);
		hammerCocked = true;
		cycleTics = 0;
		for (int k = 0; k < verbTics.Size(); k++)   verbTics[k]   = 0;
		for (int k = 0; k < verbStroke.Size(); k++) verbStroke[k] = STROKE_HOME;
		for (int k = 0; k < verbOpen.Size(); k++)   verbOpen[k]   = false;
		for (int k = 0; k < verbThrown.Size(); k++) verbThrown[k] = false;
		for (int k = 0; k < verbFlickQuiet.Size(); k++) { verbFlickQuiet[k] = FLICK_GRACE_TICS; verbFlickLast[k] = 0.0; verbFlickCalm[k] = false; }
		hammerFell = false;
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let p = card.parts[i];
			p.present = true;
			if (p.driveSlot < 0) p.value = (p.role == "hammer" && !p.cockByTrigger) ? 1.0 : 0.0;
		}
		WM_Log.Info(String.Format("%s gun reset -- %d + 1", HandName(), ammo.rounds));
	}

	// THE GUN, AS A THING IN THE ROOM. An actor drawn in the controller's own
	// frame at DRAW rate -- script never positions it, because a script-placed
	// held object lags the hand and swims around it.
	bool EnsureProp(PlayerPawn pmo)
	{
		if (!card) return false;
		if (prop) return true;

		// BY NAME AT RUNTIME. A class literal is checked at compile time and a
		// miss refuses every pk3 loaded after this one.
		Class<Actor> pc = (Class<Actor>)(Object.FindClass(card.propClass, "Actor"));
		if (!pc)
		{
			WM_Log.Once(WM_Log.LV_ERR, "noprop:" .. card.propClass, String.Format(
				"card %s names prop class '%s', which does not exist -- no gun can be drawn.",
				card.weaponClass, card.propClass));
			return false;
		}
		prop = Actor.Spawn(pc, pmo.Pos, ALLOW_REPLACE);
		if (!prop) return false;

		// A_ChangeModel ALSO CREATES THE PER-ACTOR MODEL DATA that every
		// surface override lives in. Without it SetModelSurfaceOffset and the
		// drive quietly return false and nothing on the gun ever moves -- even
		// though MODELDEF already draws the right mesh.
		prop.A_ChangeModel(card.propClass, 0, card.modelPath, card.modelFile,
			0, card.skinPath, card.skinFile);
		prop.FollowHandMode  = hand + 1;
		// NO PlacementPrefix HERE. The prop's own MODELDEF names its placement set (the pistols' say
		// wm_main / wm_off; a test weapon names its own). Forcing the prefix here overrode every
		// weapon's MODELDEF, so a shotgun silently sat on the pistol's seat and its sliders did nothing.
		resolved = false;
		return true;
	}

	// NAMES, NOT INDICES, AND IT RETRIES. A_ChangeModel binds as a side effect
	// that is not always visible on the same tic; resolving once reads as "this
	// mesh has no such surface" for a mesh that has them all.
	void Resolve()
	{
		if (resolved || !prop || !card) return;
		int found = 0;
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let part = card.parts[i];
			part.surfaces.Clear();
			part.surfaceRound.Clear();
			for (int s = 0; s < part.surfaceNames.Size(); s++)
			{
				int idx = prop.FindModelSurfaceIndex(part.modelIndex, part.surfaceNames[s]);
				if (idx < 0) continue;
				part.surfaces.Push(idx);
				// Kept in step with surfaces: a name the mesh lacks is skipped in both.
				part.surfaceRound.Push(part.RoundBindFor(part.surfaceNames[s]));
				found++;
			}
		}
		if (found == 0) return;
		resolved = true;

		int total = prop.GetModelSurfaceCount(0);
		WM_Log.Rule(String.Format("%s gun: %s", HandName(), card.modelFile));
		WM_Log.Info(String.Format("%d surfaces, %d frames", total, prop.GetModelFrameCount(0)));
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let part = card.parts[i];
			if (part.surfaceNames.Size() > 0 && part.surfaces.Size() < part.surfaceNames.Size())
			{
				String have = "";
				for (int k = 0; k < total; k++)
					have = have .. (k > 0 ? ", " : "") .. prop.GetModelSurfaceName(0, k);
				WM_Log.Err(String.Format("part '%s' names a surface this mesh does not have -- IT HAS: %s", part.id, have));
				continue;
			}
			WM_Log.Info(String.Format("  %-9s %-8s %d surface(s), %s",
				part.id, part.role, part.surfaces.Size(),
				part.dof.moveKind == WM_Dof.MOVE_HINGE
					? String.Format("turns %.2f deg", part.dof.degrees)
					: String.Format("travels %.3f", part.dof.distance)));
		}
	}

	// ---- WHERE THINGS ARE ------------------------------------------------
	//
	// THROUGH THE RENDERER'S OWN MATRIX. ModelPointToWorld runs the same
	// object-to-world transform the gun is drawn with -- controller pose,
	// MODELDEF scale and offset, your placement sliders, all of it. So a grab
	// point is ON the drawn part, however the gun is seated, and moving a
	// placement slider moves the grab point with the gun.
	//
	// It replaced a hand-rolled basis that ignored the prop's scale and its
	// 28-unit MODELDEF offset: every grab sphere sat at your controller rather
	// than on the gun, which is why nothing could be grabbed.
	Vector3 World(Vector3 m)
	{
		if (!prop) return (0, 0, 0);
		Vector3 e = WM_Space.Eng(m);
		Vector3 p, f, u;
		[p, f, u] = prop.ModelPointToWorld(e.x, e.y, e.z);
		return p;   // map order, from the engine (fixed 2026-09-11; it was GL order)
	}

	Vector3 WorldDir(Vector3 at, Vector3 dir)
	{
		Vector3 d = World(at + dir) - World(at);
		return d.Length() > 1e-6 ? d.Unit() : (0, 0, 1);
	}

	// ---- THE PART BEING TUNED, AND BAKING IT INTO THE CARD (BUILD.md step 5) -------------------------
	//
	// ONE SCRATCH SET, wm_tune_*. The grab slot the grab-point page picked reads it -- wm_tune_gun this
	// gun's hand, wm_tune_part the slot, and wm_tune_for saying the scratch was set for that very slot --
	// and every other part draws and tests its card numbers alone. Its channels are the renderer's (a seat
	// set, a placement set, a size cvar), so the tuned oval moves with the menu open, and script adds the
	// same numbers to what it tests. Baked into card lines from the page (WM_System.BakePrint).
	bool IsTuned(int index)
	{
		if (index < 0 || int(Cvf("wm_tune_gun", 0)) != hand || int(Cvf("wm_tune_part", 0)) != index) return false;
		int owner = int(Cvf("wm_tune_for", 0));
		return owner == 0 || owner == hand * 16 + index + 1;
	}

	// A scratch number of the tuned part, or `unset` for every other part.
	double TuneF(int index, String suffix, double unset)
	{
		if (!IsTuned(index)) return unset;
		// A NAME BUILT FIRST: wm_tune on its own is a seat set's prefix, not a cvar to read.
		String tuneName = "wm_tune" .. suffix;
		return Cvf(tuneName, unset);
	}

	// ITS RENDERER CHANNELS: the scratch seat set and shape set for the tuned part; none for the rest.
	Name OwnSeatCVar(int index)    { return IsTuned(index) ? 'wm_tune' : 'None'; }
	Name OwnShapePrefix(int index) { return IsTuned(index) ? 'wm_tune_sh' : 'None'; }

	// THE GRAB SLOTS THIS GUN FILLS: its parts, then its load points, at most GRAB_SLOTS.
	int GrabSlotCount()
	{
		if (!card) return 0;
		int n = card.parts.Size();
		for (int k = 0; k < card.verbs.Size(); k++)
			if (card.verbs[k].kind == WM_Verb.LOAD) n++;
		return min(n, GRAB_SLOTS);
	}

	// A SLOT'S TUNING FROM BEFORE STEP 5 (wm_gp_<m|o><n>_*), still declared so it can be baked.
	Vector3, Vector3, double OldSlotTuning(int slot)
	{
		String t = PartTag(slot);
		Vector3 nudge = (Cvf(t .. "_ofs_x", 0), Cvf(t .. "_ofs_y", 0), Cvf(t .. "_ofs_z", 0));
		Vector3 shape = (Cvf(t .. "_sh_scale_x", 1.0), Cvf(t .. "_sh_scale_y", 1.0), Cvf(t .. "_sh_scale_z", 1.0));
		return nudge, shape, Cvf(t .. "_r", 0);
	}

	// A WORLD DISPLACEMENT AS MODEL UNITS in the gun's own axes: World's linear part inverted by
	// Cramer's rule over the drawn model basis, scale and mirror included.
	Vector3 ModelDelta(Vector3 worldDelta)
	{
		Vector3 o  = World((0, 0, 0));
		Vector3 bx = World((1, 0, 0)) - o;
		Vector3 by = World((0, 1, 0)) - o;
		Vector3 bz = World((0, 0, 1)) - o;
		double det = bx dot (by cross bz);
		if (abs(det) < 0.000000000001) return (0, 0, 0);
		return ((worldDelta dot (by cross bz)) / det, (bx dot (worldDelta cross bz)) / det, (bx dot (by cross worldDelta)) / det);
	}

	// ONE SLOT'S CARD LINES with a tuning folded in: nudge in frame units, shape as multipliers, reach a
	// ball's radius (0: none) -- and the whole-gun offset, when this is the gun being tuned. Tune a part
	// at rest: a nudge is measured where the part is drawn. "" for a slot this gun does not fill.
	String BakeSlot(int slot, Vector3 nudgeFrame, Vector3 shapeMult, double reachBall)
	{
		if (!card || !prop || slot < 0) return "";
		Vector3 allFrame = (0, 0, 0);
		if (int(Cvf("wm_tune_gun", 0)) == hand)
			allFrame = (Cvf("wm_grab_all_ofs_x", 0), Cvf("wm_grab_all_ofs_y", 0), Cvf("wm_grab_all_ofs_z", 0));
		Vector3 delta = ModelDelta(FrameToWorld(nudgeFrame + allFrame));
		if (slot < card.parts.Size())
		{
			if (!card.PartIsWorkable(slot)) return "";
			let p = card.parts[slot];
			Vector3 a = p.grabSize;
			if (a.X <= 0.01 || a.Y <= 0.01 || a.Z <= 0.01) a = (p.grabRadius, p.grabRadius, p.grabRadius);
			double over = Cvf("wm_reach_override", 0);
			if (reachBall > 0.01) a = (reachBall, reachBall, reachBall);
			else if (over > 0.01) a = (over, over, over);
			a = (a.X * max(0.01, shapeMult.X), a.Y * max(0.01, shapeMult.Y), a.Z * max(0.01, shapeMult.Z));
			Vector3 g = p.grabAt + delta;
			String sizeLine;
			if (abs(a.X - a.Y) < 0.001 && abs(a.X - a.Z) < 0.001) sizeLine = String.Format("    grabradius = %.3f", a.X);
			else sizeLine = String.Format("    grabsize   = %.3f, %.3f, %.3f", a.X, a.Y, a.Z);
			return String.Format("  part %s\n    grab       = %.3f, %.3f, %.3f\n%s", p.id, g.X, g.Y, g.Z, sizeLine);
		}
		for (int k = 0; k < card.verbs.Size(); k++)
		{
			if (LoadTagIndex(k) != slot) continue;
			let v = card.verbs[k];
			Vector3 zoneAt = v.loadAt + delta;
			Vector3 zoneSize = v.loadSize;
			if (reachBall > 0.01) zoneSize = (reachBall, reachBall, reachBall);
			zoneSize = (zoneSize.X * max(0.01, shapeMult.X), zoneSize.Y * max(0.01, shapeMult.Y), zoneSize.Z * max(0.01, shapeMult.Z));
			return String.Format("  load %s\n    at   = %.3f, %.3f, %.3f\n    size = %.3f, %.3f, %.3f",
				v.id, zoneAt.X, zoneAt.Y, zoneAt.Z, zoneSize.X, zoneSize.Y, zoneSize.Z);
		}
		return "";
	}

	// EVERY PART'S OWN NAME FOR ITS OWN NUMBERS: wm_gp_m3 is the main gun's
	// fourth part. The renderer reads these same names -- as a seat set, a
	// placement set and a size -- so the oval moves while the page is open, and
	// script reads them here for what is TESTED. One set of numbers, two
	// readers, which is the only way the drawn oval can be trusted.
	String PartTag(int index)
	{
		return String.Format("wm_gp_%s%d", hand == 0 ? "m" : "o", index);
	}

	// ONE PART'S OWN NUDGE. The whole-gun offset is NOT here: it lives in the
	// gun's drawn frame instead (TuneWorld below), so the renderer can apply it
	// to the spheres while a menu has the playsim frozen.
	Vector3 GrabModel(int index, WM_Part part)
	{
		Vector3 g = part.grabAt;
		return g;
	}

	// ---- THE GUN'S DRAWN FRAME -------------------------------------------
	//
	// A wire oval is SEATED IN THIS FRAME (Actor.FollowActor), so the renderer
	// keeps it on the gun every frame it draws, menu open or not.
	//
	// ASKED OF THE ENGINE, NOT REBUILT HERE. The frame a child is drawn in
	// leaves out the parent's scale; the gun's full matrix keeps it. This used
	// to derive the frame from ModelPointToWorld -- the full matrix -- and on a
	// gun drawn with a mirrored Scale (the M4A3 is -0.82) that flipped the
	// frame, so every seat landed on the far side of the gun: grab spheres "a
	// few inches to the side", correctly spaced, on the wrong side.
	// ModelFollowFrameToWorld answers from the very frame the renderer uses.
	//
	// The axes come back UNNORMALISED -- one frame unit each, in map units -- so
	// the frame's units come with them and nothing has to guess the ratio.
	Vector3, Vector3, Vector3, Vector3 FrameBasis()
	{
		if (!prop) return (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0);
		Vector3 o, ax, ay, az;
		[o, ax, ay, az] = prop.ModelFollowFrameToWorld(0, 0, 0);
		if (ax.Length() < 1e-6) return (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0);
		return o, ax, ay, az;
	}

	// Map units in one frame unit. The frame is uniform, so any axis says it.
	double FrameUnits()
	{
		Vector3 o, ax, ay, az;
		[o, ax, ay, az] = FrameBasis();
		double u = ax.Length();
		return u > 1e-6 ? u : max(0.01, Cvf("wm_world_factor", 0.34));
	}

	// A displacement written in frame units, as a world vector.
	Vector3 FrameToWorld(Vector3 seat)
	{
		Vector3 o, ax, ay, az;
		[o, ax, ay, az] = FrameBasis();
		return ax * seat.X + ay * seat.Y + az * seat.Z;
	}

	// THE TWO OFFSETS THE RENDERER ADDS, as world vectors, so script can add the
	// very same shift to the point it TESTS. The whole-gun one applies only to
	// the gun the tuner has selected; a part's own nudge always applies.
	Vector3 TuneWorld()
	{
		if (int(Cvf("wm_tune_gun", 0)) != hand) return (0, 0, 0);
		return FrameToWorld((Cvf("wm_grab_all_ofs_x", 0), Cvf("wm_grab_all_ofs_y", 0), Cvf("wm_grab_all_ofs_z", 0)));
	}

	Vector3 NudgeWorld(int index)
	{
		if (!IsTuned(index)) return (0, 0, 0);
		return FrameToWorld((Cvf("wm_tune_ofs_x", 0), Cvf("wm_tune_ofs_y", 0), Cvf("wm_tune_ofs_z", 0)));
	}

	// A RAW world point -- no nudge, no whole-gun offset -- as a seat in the
	// frame. Raw on purpose: the renderer adds both offsets itself, and seating
	// a point that already had them in would move the oval twice the moment the
	// menu closed and script ran again.
	Vector3 SeatFor(Vector3 rawWorld)
	{
		Vector3 o, ax, ay, az;
		[o, ax, ay, az] = FrameBasis();
		if (ax.Length() < 1e-6) return (0, 0, 0);
		Vector3 d = rawWorld - o;
		return (d dot ax / (ax dot ax), d dot ay / (ay dot ay), d dot az / (az dot az));
	}

	// WHICH SLIDER GOVERNS THIS SPHERE'S SIZE (Actor.ScaleCVar). The part being
	// tuned answers to its own radius slider; every other sphere answers to the
	// global override. Both are map units of radius and both read as "off" at
	// zero, which hands the size back to the card's own number -- the same
	// order GrabRadius below tests in, so the drawn sphere and the tested reach
	// cannot disagree about which slider won.
	Name RadiusCVar(int index) { return IsTuned(index) ? 'wm_tune_r' : 'None'; }

	// THE OVAL A GRAB REALLY IS: three half-sizes in the gun's own axes -- along
	// the barrel, across it, and up. The card states them; a part that states
	// only a radius gets a ball of that radius, which is what every card meant
	// before this existed.
	//
	// The same order of precedence as GrabRadius below, so the drawn oval and
	// the tested volume cannot disagree about which slider won: the part being
	// tuned answers to the tuner's three sliders, everything else to the global
	// override, and a slider at zero hands the number back to the card.
	Vector3 GrabAxes(int index, WM_Part part)
	{
		Vector3 a = part.grabSize;
		if (a.X <= 0.01 || a.Y <= 0.01 || a.Z <= 0.01)
			a = (part.grabRadius, part.grabRadius, part.grabRadius);

		// ITS OWN REACH first -- the scratch set's, while it is the part being tuned -- then the one that
		// covers every part, then the card's. Same order the renderer resolves the size in.
		double own = TuneF(index, "_r", 0);
		double over = Cvf("wm_reach_override", 0);
		if (own > 0.01)       a = (own, own, own);
		else if (over > 0.01) a = (over, over, over);

		// MULTIPLIERS, the tuned part's shape set -- the ones the renderer scales its drawn oval by, so the
		// shape you drag is the shape that grabs.
		a.X *= max(0.01, TuneF(index, "_sh_scale_x", 1.0));
		a.Y *= max(0.01, TuneF(index, "_sh_scale_y", 1.0));
		a.Z *= max(0.01, TuneF(index, "_sh_scale_z", 1.0));
		return a;
	}

	// THE OVAL AS HANDED TO THE RENDERER: the tested one WITHOUT this part's
	// shape multipliers, because the renderer applies those itself from the
	// part's placement set. Hand it the tested one and the shape is applied
	// twice the moment the menu closes and script runs again.
	Vector3 DrawAxes(int index, WM_Part part)
	{
		Vector3 a = GrabAxes(index, part);
		a.X /= max(0.01, TuneF(index, "_sh_scale_x", 1.0));
		a.Y /= max(0.01, TuneF(index, "_sh_scale_y", 1.0));
		a.Z /= max(0.01, TuneF(index, "_sh_scale_z", 1.0));
		return a;
	}

	// IS THIS A BALL? Only then is the drawn sphere honest without stretching,
	// and only then does the live size slider tell the whole truth.
	bool GrabIsBall(int index, WM_Part part)
	{
		Vector3 a = GrabAxes(index, part);
		return abs(a.X - a.Y) < 0.01 && abs(a.X - a.Z) < 0.01;
	}

	// HOW FAR A HAND IS INTO THAT OVAL: 1.0 is exactly on its surface, less is
	// inside, and the number orders two parts by which one the hand is deeper
	// in -- which is what picking the nearest part really wants, now that they
	// are not all the same shape. Measured in the gun's own axes, so the oval
	// turns with the gun. With no frame this tic it falls back to a ball.
	double GrabDepth(int index, WM_Part part, Vector3 hand)
	{
		Vector3 a = GrabAxes(index, part);
		Vector3 d = hand - PartPoint(index);
		Vector3 org, ax, ay, az;
		[org, ax, ay, az] = FrameBasis();
		if (ax.Length() < 1e-6) return d.Length() / max(0.01, a.X);
		double x = (d dot ax.Unit()) / max(0.01, a.X);
		double y = (d dot ay.Unit()) / max(0.01, a.Y);
		double z = (d dot az.Unit()) / max(0.01, a.Z);
		return sqrt(x * x + y * y + z * z);
	}

	bool HandInGrab(int index, WM_Part part, Vector3 hand)
	{
		return GrabDepth(index, part, hand) <= 1.0;
	}

	// THE BIGGEST HALF-SIZE. For the things that still want one number: the
	// marker's light, and the buzz as a hand comes into range.
	double GrabRadius(int index, WM_Part part)
	{
		Vector3 a = GrabAxes(index, part);
		return max(0.5, max(a.X, max(a.Y, a.Z)));
	}

	// The grab point where the part IS now, not where it rests: a slide held
	// back carries its grab point back with it.
	Vector3 PartPointRaw(int index)
	{
		let part = card.parts[index];
		if (part.dof2) return World(TwoStagePoint(part, GrabModel(index, part), part.value));
		Vector3 g = GrabModel(index, part);
		let d = part.dof;
		if (d.moveKind == WM_Dof.MOVE_HINGE)
			g = d.pivot + WM_Space.Rotate(g - d.pivot, d.axis, part.value * d.degrees);
		else
			g += d.axis * (part.value * d.distance);
		return World(g);
	}

	// WHERE IT IS TESTED: the raw point plus the two offsets the renderer draws
	// the oval by, applied in the same frame and units it applies them in.
	Vector3 PartPoint(int index)
	{
		return PartPointRaw(index) + NudgeWorld(index) + TuneWorld();
	}

	// Where a hand holding a magazine by its floorplate is when the top of
	// that magazine reaches the mouth of the well: the floorplate point, one
	// full stroke out along the well.
	Vector3 WellPointRaw()
	{
		int i = card.FindRoleIndex("feed");
		if (i < 0) return prop ? prop.Pos : (0, 0, 0);
		let f = card.parts[i];
		// A TWO-STAGE MAGAZINE (WM_Part.dof2) is fully out only past both stages -- the BFG's
		// cell slides back and then lifts. Stage one alone left the mouth of the well inside
		// the cradle.
		if (f.dof2) return World(TwoStagePoint(f, GrabModel(i, f), 1.0));
		return World(GrabModel(i, f) + f.dof.axis * f.dof.distance);
	}

	Vector3 WellPoint()
	{
		int i = card.FindRoleIndex("feed");
		if (i < 0) return prop ? prop.Pos : (0, 0, 0);
		return WellPointRaw() + NudgeWorld(i) + TuneWorld();
	}

	Vector3 SeatedPoint()
	{
		int i = card.FindRoleIndex("feed");
		if (i < 0) return prop ? prop.Pos : (0, 0, 0);
		return World(GrabModel(i, card.parts[i])) + NudgeWorld(i) + TuneWorld();
	}

	// ---- POSING THE PARTS ------------------------------------------------

	// A hinge turns about its pin: v' = R v + (p - R p). The renderer applies
	// translate-then-rotate about the model origin, so the pivot is folded into
	// the offset here, in MD3 space, and only then converted.
	// ---- A MAGAZINE THAT INDEXES ON THE SHOT (card.zs WM_Part.indexDof, G13) -----------------

	// HOW MANY STEPS IT HAS TAKEN: clamp(from - rounds, 0, steps), off the seated magazine's count
	// as it is now -- so a partial magazine seats already stepped. from and steps unset are the
	// magazine's capacity. 0 for a part with no index.
	int IndexSteps(WM_Part part)
	{
		if (!part || !part.indexDof || !ammo) return 0;
		int magCap = max(ammo.capacity, 1);
		int fromCount = (part.indexFrom > 0) ? part.indexFrom : magCap;
		int mostSteps = (part.indexSteps > 0) ? part.indexSteps : magCap;
		return clamp(fromCount - ammo.rounds, 0, mostSteps);
	}

	// A POINT ON THE PART, STEPPED BY ITS INDEX: turned about the index's pivot, or slid along its
	// axis, once per step taken -- model space, before the part's dof moves it.
	Vector3 IndexPoint(WM_Part part, Vector3 m)
	{
		int n = IndexSteps(part);
		if (n <= 0) return m;
		let ix = part.indexDof;
		if (ix.moveKind == WM_Dof.MOVE_HINGE) return ix.pivot + WM_Space.Rotate(m - ix.pivot, ix.axis, n * ix.degrees);
		return m + ix.axis * (n * ix.distance);
	}

	// The index's turn, as the engine needs it; none for a slide index.
	Quat IndexRotation(WM_Part part)
	{
		int n = IndexSteps(part);
		if (n <= 0 || part.indexDof.moveKind != WM_Dof.MOVE_HINGE) return Quat(0, 0, 0, 1);
		return WM_Space.EngRot(part.indexDof.axis, n * part.indexDof.degrees);
	}

	Vector3 PartOffset(WM_Part part)
	{
		if (part.dof2) return WM_Space.Eng(TwoStagePoint(part, (0, 0, 0), part.value));
		let d = part.dof;
		Vector3 ofs = (0, 0, 0);
		double deg = 0;
		Vector3 ax = (0, 0, 1);
		if (d.moveKind == WM_Dof.MOVE_HINGE)
		{
			deg = part.value * d.degrees;
			ax  = d.axis;
		}
		else
		{
			ofs = d.axis * (part.value * d.distance);
			if (d.twist != 0) { deg = part.value * d.twist; ax = d.twistAxis; }
		}
		if (deg != 0) ofs += d.pivot - WM_Space.Rotate(d.pivot, ax, deg);
		// THE INDEX UNDER THE DOF (G13): x' = Rdof (Rindex x + oindex) + odof, so the offset gains
		// the dof's turn of where the index put the origin.
		if (part.indexDof)
		{
			Vector3 indexOrigin = IndexPoint(part, (0, 0, 0));
			ofs += (deg != 0) ? WM_Space.Rotate(indexOrigin, ax, deg) : indexOrigin;
		}
		return WM_Space.Eng(ofs);
	}

	Quat PartRotation(WM_Part part)
	{
		if (part.dof2) return TwoStageRotation(part, part.value);
		let d = part.dof;
		Quat q = Quat(0, 0, 0, 1);
		if (d.moveKind == WM_Dof.MOVE_HINGE) q = WM_Space.EngRot(d.axis, part.value * d.degrees);
		else if (d.twist != 0)               q = WM_Space.EngRot(d.twistAxis, part.value * d.twist);
		// THE INDEX UNDER THE DOF (G13): its turn first, the dof's after -- the product q_dof q_index,
		// as TwoStageRotation composes its stages.
		if (part.indexDof) q = q * IndexRotation(part);
		return q;
	}

	// ---- A PART IN TWO STAGES (WM_Part.dof2) -----------------------------------
	//
	// THE ENGINE'S OWN RULE, IN SCRIPT. In the hand a two-stage part is drawn by
	// SurfaceStagedDrivePose (models.cpp); the rest of the time it is posed from here,
	// and the instant the hand lets go the slot shows what was posed here. So the two
	// agree at every value or the part snaps on release. At value v and split S:
	//   stage one at min(v / S, 1), stage two at clamp((v - S) / (1 - S), 0, 1),
	//   stage two applied ON TOP of stage one in the gun's model space:
	//   x' = R2 (R1 x + o1) + o2, turn q2 q1.
	// At v = S stage two is the identity, so both sides of the split meet. Stage one
	// moves a point exactly as PartOffset / PartRotation / CarriedBy move a
	// single-stage part, twist included.
	private double FirstStageTravel(WM_Part part, double v)
	{
		double s = part.dof2.split;
		return clamp((v >= s) ? 1.0 : v / s, 0.0, 1.0);
	}

	private double SecondStageTravel(WM_Part part, double v)
	{
		double s = part.dof2.split;
		return clamp((v - s) / (1.0 - s), 0.0, 1.0);
	}

	// Model point m, carried by a two-stage part at value v, MD3 space. dof2's axis and
	// pivot are where they stand once stage one is complete: the gun's frame, not the
	// part's, as SetModelSurfaceDriveStage reads them. PartOffset is this at the origin
	// (the renderer draws x' = R x + o), so one function places the drawn part, its grab
	// oval and anything it carries.
	Vector3 TwoStagePoint(WM_Part part, Vector3 m, double v)
	{
		let d = part.dof;
		double u = FirstStageTravel(part, v);
		Vector3 moved = m;
		if (d.moveKind == WM_Dof.MOVE_HINGE)
			moved = d.pivot + WM_Space.Rotate(m - d.pivot, d.axis, u * d.degrees);
		else if (d.twist != 0)
			moved = d.pivot + WM_Space.Rotate(m - d.pivot, d.twistAxis, u * d.twist) + d.axis * (u * d.distance);
		else
			moved = m + d.axis * (u * d.distance);

		let d2 = part.dof2;
		double w = SecondStageTravel(part, v);
		if (w <= 0) return moved;
		if (d2.moveKind == WM_Dof.MOVE_HINGE)
			return d2.pivot + WM_Space.Rotate(moved - d2.pivot, d2.axis, w * d2.degrees);
		return moved + d2.axis * (w * d2.distance);
	}

	// The turn a two-stage part is drawn with at value v, as the engine needs it: stage
	// two's turn after stage one's, the product q2 q1 the engine composes. ZScript's
	// Quat * Quat is the same Hamilton product (vectors.h, OP_MULQQ).
	Quat TwoStageRotation(WM_Part part, double v)
	{
		let d = part.dof;
		double u = FirstStageTravel(part, v);
		Quat q = Quat(0, 0, 0, 1);
		if (d.moveKind == WM_Dof.MOVE_HINGE) q = WM_Space.EngRot(d.axis, u * d.degrees);
		else if (d.twist != 0)               q = WM_Space.EngRot(d.twistAxis, u * d.twist);

		let d2 = part.dof2;
		double w = SecondStageTravel(part, v);
		if (w > 0 && d2.moveKind == WM_Dof.MOVE_HINGE) q = WM_Space.EngRot(d2.axis, w * d2.degrees) * q;
		return q;
	}

	// ONE LINE WHEN A TWO-STAGE PART CROSSES ITS SPLIT, either way, in the hand or going
	// home on its own -- never per tic. Exactly at S is stage one's end, as the engine
	// reads it, so "past" is strictly past.
	private void NoteSplitCrossing(WM_Part part)
	{
		bool beyond = part.value > part.dof2.split;
		if (beyond == part.pastSplit) return;
		part.pastSplit = beyond;
		WM_Log.Info(String.Format("%s gun: %s crossed its split %.3f %s -- value %.3f, %s",
			HandName(), part.id, part.dof2.split, beyond ? "into its dof2" : "back into its dof", part.value,
			(part.driveSlot >= 0) ? "in the hand" : "not held"));
	}

	// One stage of a part, for the bind log.
	private String DofStageText(WM_Dof d)
	{
		if (d.moveKind == WM_Dof.MOVE_HINGE)
			return String.Format("hinge %.2f deg about %s through %s", d.degrees, WM_Log.Vec(d.axis), WM_Log.Vec(d.pivot));
		return String.Format("slide %.3f along %s%s", d.distance, WM_Log.Vec(d.axis),
			(d.twist != 0) ? String.Format(", turning %.2f deg", d.twist) : "");
	}

	double DrawnValue(WM_Part part)
	{
		if (part.driveSlot >= 0 && prop) return prop.GetModelSurfaceDrawnValue(part.driveSlot);
		return part.value;
	}

	void Pose()
	{
		if (!prop || !resolved) return;
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let part = card.parts[i];
			int n = part.surfaces.Size();
			if (n == 0 || part.poseSlot < 0) continue;
			int slot = part.poseSlot;

			// Not drawn at all: animation-only pieces, and a magazine that has
			// left the gun. "Hidden" and "away" are different things, and an
			// empty gun must not still show a magazine in its well.
			if (part.role == "hidden" || !part.present)
			{
				for (int s = 0; s < n; s++)
					prop.SetModelSurfaceHidden(slot + s, part.modelIndex, part.surfaces[s], true);
				continue;
			}

			// Written every tic, driven or not. While a hand drives this slot the
			// renderer ignores what is written here; the instant the hand lets
			// go, this is what the slot shows -- so the part carries on from
			// exactly where it was drawn.
			if (part.driveSlot >= 0) part.value = prop.GetModelSurfaceDrawnValue(part.driveSlot);
			if (part.dof2) NoteSplitCrossing(part);

			Vector3 ofs = PartOffset(part);
			Quat rot = PartRotation(part);
			// A PART THAT FLIPS is hidden off its beat (FlipShown), every surface of it.
			bool flipHidden = (part.flipBy != WM_Part.FLIP_NONE) && !FlipShown(part);
			for (int s = 0; s < n; s++)
			{
				// A ROUND SURFACE shows only while its slot holds a case -- or, on a counted store,
				// while the store holds more than its count (WM_Part.roundSurfName, WM_Ammo.RoundShows).
				// The hidden flag is its own field in the engine, so it holds under a live drive
				// too: a cylinder emptied while the hand still has the barrel open shows empty.
				bool noCase = false;
				int rb = (s < part.surfaceRound.Size()) ? part.surfaceRound[s] : -1;
				if (rb >= 0 && ammo) noCase = !ammo.RoundShows(part.roundSurfStore[rb], part.roundSurfSlot[rb]);
				if (flipHidden) noCase = true;
				prop.SetModelSurfaceHidden(slot + s, part.modelIndex, part.surfaces[s], noCase);
				prop.SetModelSurfaceOffset(slot + s, part.modelIndex, part.surfaces[s], ofs, rot);
			}
		}
	}

	// HAND THE PART TO THE RENDERER. From here until release it is placed from
	// the working hand's live controller pose on the frame being drawn --
	// glued, one to one, because `distance` is both how far the part goes and
	// how far your hand goes. Your fingers stay on the serrations. Driven in
	// the part's OWN pose slots (Bind says why).
	void StartDrive(WM_Part part, int workHand, double startValue)
	{
		if (!prop || part.poseSlot < 0) return;
		int n = part.surfaces.Size();

		// A PART THAT ONLY TURNS -- a break-top's barrel, a crane -- is driven as a hinge
		// (Actor.SetModelSurfaceDriveHinge): the renderer reads the hand by its angle round
		// the pin, so the part turns exactly as far as the hand swings round it. The same
		// axis, sign and pivot as PartOffset/PartRotation (WM_Space.EngRot's negated angle),
		// so held and let go agree at every value. No pistol or pump part a hand takes is a
		// hinge, so none of them reaches this.
		if (part.dof.moveKind == WM_Dof.MOVE_HINGE)
		{
			for (int s = 0; s < n; s++)
				prop.SetModelSurfaceDriveHinge(part.poseSlot + s, part.modelIndex, part.surfaces[s], workHand,
					WM_Space.Eng(part.dof.axis), -part.dof.degrees, WM_Space.Eng(part.dof.pivot), startValue);
			DriveSecondStage(part);
			part.driveSlot = part.poseSlot;
			part.value = startValue;
			return;
		}

		Vector3 ax = WM_Space.Eng(part.dof.axis);

		// A part that turns as it slides (a card `twist`) turns in the hand
		// too, not only once it is let go. Same axis, sign and pivot as
		// PartOffset/PartRotation, so the posed part and the driven part agree
		// at every value and nothing snaps on release.
		let d = part.dof;
		bool turns = (d.moveKind != WM_Dof.MOVE_HINGE && d.twist != 0);
		for (int s = 0; s < n; s++)
		{
			prop.SetModelSurfaceDrive(part.poseSlot + s, part.modelIndex, part.surfaces[s],
				workHand, ax, d.distance, startValue);
			if (turns)
				prop.SetModelSurfaceDriveRotation(part.poseSlot + s,
					WM_Space.Eng(d.twistAxis), -d.twist, WM_Space.Eng(d.pivot));
		}
		DriveSecondStage(part);
		part.driveSlot = part.poseSlot;
		part.value = startValue;
	}

	// THE SECOND STAGE, ON THE SAME SLOTS (Actor.SetModelSurfaceDriveStage), for a part
	// with a dof2; nothing at all for any other. Called straight after StartDrive has
	// driven the slots, which is the native's rule: the drive's startValue is read as the
	// COMBINED value, so a bolt taken hold of open resumes open, and both stages anchor
	// on the next drawn frame.
	//
	// THE HAND IS THE ENGINE'S. It works each stage along that stage's own path -- the
	// hand's angle round a hinge's pin, its projection on a slide's axis -- on an L-shaped
	// track: stage two cannot move until stage one is complete, stage one cannot move
	// while stage two is under way, and a pull crossing the corner inside one frame is
	// cut at the corner (SurfaceStagedSolve, models.cpp). A card handseat rides both
	// stages, because the follower reads the same staged pose (SurfaceSlotPoseForFollower).
	// Axis, sign and pivot are converted exactly as StartDrive converts stage one, so
	// TwoStagePoint / TwoStageRotation pose the part the hand drew.
	private void DriveSecondStage(WM_Part part)
	{
		let d2 = part.dof2;
		if (!d2 || !prop) return;
		bool isHinge = (d2.moveKind == WM_Dof.MOVE_HINGE);
		int stageKind = isHinge ? Actor.DRIVESTAGE_Hinge : Actor.DRIVESTAGE_Slide;
		double stageAmount = isHinge ? -d2.degrees : d2.distance;
		for (int s = 0; s < part.surfaces.Size(); s++)
		{
			if (!prop.SetModelSurfaceDriveStage(part.poseSlot + s, stageKind, WM_Space.Eng(d2.axis), stageAmount, WM_Space.Eng(d2.pivot), d2.split))
				WM_Log.Err(String.Format("%s gun: the engine refused %s's dof2 on slot %d -- in the hand it is a single-stage drive",
					HandName(), part.id, part.poseSlot + s));
		}
	}

	// Take back the value that was DRAWN, not script's estimate -- deciding
	// anything on the one that was not on screen is how a magazine seats while
	// visibly still out.
	double StopDrive(WM_Part part)
	{
		if (part.driveSlot < 0 || !prop) return part.value;
		double v = prop.GetModelSurfaceDrawnValue(part.driveSlot);
		for (int s = 0; s < part.surfaces.Size(); s++) prop.ClearModelSurfaceDrive(part.driveSlot + s);
		part.driveSlot = -1;
		part.value = v;
		return v;
	}

	// ---- THE PARTS THAT MOVE THEMSELVES ------------------------------------
	void Automatic(PlayerPawn pmo)
	{
		if (!card) return;
		if (hammerDownTics > 0) hammerDownTics--;

		// THE TRIGGER FOLLOWS YOUR FINGER. The analog travel of the hand
		// holding this gun, not a button -- so the trigger is as far back as
		// your finger is, and you can see the take-up.
		double trig = (hand == 0) ? pmo.TriggerValueMain : pmo.TriggerValueOff;
		// A fallen double-action hammer comes back to the finger once the finger lets go.
		if (hammerFell && trig < 0.15) hammerFell = false;

		for (int i = 0; i < card.parts.Size(); i++)
		{
			let part = card.parts[i];
			if (part.role == "trigger")
				part.value = stowed ? 0.0 : clamp(trig, 0.0, 1.0);
			else if (part.role == "hammer")
			{
				// DOUBLE ACTION (`cock = trigger`): back with the finger, down once it fell.
				if (part.cockByTrigger)
					part.value = (stowed || hammerFell) ? 0.0 : clamp(trig, 0.0, 1.0);
				else
					part.value = (hammerCocked && hammerDownTics <= 0) ? 1.0 : 0.0;
			}
		}
		// A SECOND BARREL'S TRIGGER (card.zs WM_Barrel `trigger`) follows its button: pulled while
		// the holding hand's second button is down. A button has no travel, so all or nothing.
		if (card.barrels.Size() > 0 && pmo.player)
		{
			int altBit = (hand == 0) ? BT_ALTATTACK : BT_OFFHANDALTATTACK;
			bool altHeld = !stowed && (pmo.player.cmd.buttons & altBit) != 0;
			for (int bi = 0; bi < card.barrels.Size(); bi++)
			{
				int ti = card.barrels[bi].triggerIndex;
				if (ti >= 0 && ti < card.parts.Size()) card.parts[ti].value = altHeld ? 1.0 : 0.0;
			}
		}
		Spin(pmo);
		EngineIdle(pmo);
		Meter();
		LatchesTick();
		// THE A/B SWITCH. Each path zeroes only the other's clock, which the path
		// running never reads -- so a flip mid-stroke cannot resume a stale one.
		if (WM_Verb.Enabled())
		{
			cycleTics = 0;
			CycleByVerbs();
			EjectByTilt(pmo);
			FlickByVerbs(pmo);
		}
		else
		{
			for (int k = 0; k < verbTics.Size(); k++) verbTics[k] = 0;
			Cycle();
		}
	}

	// ---- A SURFACE THAT SHOWS THE MAGAZINE'S FILL (card.zs WM_Part.meterSurface) ----------------------
	//
	// A BFG's charge gauge. Each tic its step is ceil(fill x metersteps), 1 to metersteps -- 1 with the
	// magazine out or empty -- and only a CHANGED step reaches the prop, as that surface's own skin
	// (A_ChangeModel, CMDL_USESURFACESKIN). A new prop wears its MODELDEF skin again, so it is re-set.
	// Presentation only.
	private void Meter()
	{
		if (!prop || !resolved || !ammo) return;
		int partCount = card.parts.Size();
		if (meterProp != prop || meterShown.Size() != partCount)
		{
			meterShown.Resize(partCount);
			for (int i = 0; i < partCount; i++) meterShown[i] = -1;
			meterProp = prop;
		}
		for (int i = 0; i < partCount; i++)
		{
			let p = card.parts[i];
			if (p.meterSteps <= 0 || p.meterSkinFile == "") continue;
			int surf = MeterSurfaceIndex(p);
			if (surf < 0) continue;
			double share = ammo.magIn ? clamp(double(ammo.rounds) / max(ammo.capacity, 1), 0.0, 1.0) : 0.0;
			int step = clamp(int(ceil(share * p.meterSteps)), 1, p.meterSteps);
			if (meterShown[i] == step) continue;
			meterShown[i] = step;
			String skinFile = String.Format(p.meterSkinFile, step);
			prop.A_ChangeModel(prop.GetClassName(), p.modelIndex, "", "", surf, p.meterSkinPath, skinFile, CMDL_USESURFACESKIN);
		}
	}

	// The model's own index of a part's meter surface, or -1 before the part's surfaces resolve.
	private int MeterSurfaceIndex(WM_Part p)
	{
		for (int j = 0; j < p.surfaceNames.Size() && j < p.surfaces.Size(); j++)
			if (p.surfaceNames[j] ~== p.meterSurface) return p.surfaces[j];
		return -1;
	}

	// ---- A PART THAT FLIPS (card.zs WM_Part.flipBy, CS-G4) -----------------------------------------
	//
	// A heavy saw's running chain is two poses of it, `chain` and `chain2`, shown in turn. Each flipping
	// part is drawn on its own phase of every 2 x fliptics tics while it is wanted -- the trigger of the
	// hand holding this gun down (flip = trigger), or a shot within the last cycle (flip = fire) -- and at
	// rest only phase 0 is. Presentation only: the tic and the owner's usercmd.
	private bool FlipShown(WM_Part part)
	{
		bool want = false;
		if (!stowed && gunItem && gunItem.Owner && gunItem.Owner.player)
		{
			if (part.flipBy == WM_Part.FLIP_TRIGGER)
				want = (gunItem.Owner.player.cmd.buttons & ((hand == 0) ? BT_ATTACK : BT_OFFHANDATTACK)) != 0;
			else
			{
				let flipGun = WM_Gun(gunItem);
				int window = flipGun ? flipGun.CycleTics() + 1 : 20;
				want = firedTic > 0 && level.maptime - firedTic <= window;
			}
		}
		if (!want) return part.flipPhase == 0;
		int each = (part.flipTics > 0) ? part.flipTics : 2;
		return ((level.maptime / each) % 2) == part.flipPhase;
	}

	// ---- A GUN WITH AN ENGINE (verb.zs START -- a chainsaw's ripcord, CS-G1) ---------------------

	// THE ENGINE CATCHES: the start verb's part pulled past its outat. One already running is left
	// alone. LOCAL HAND INPUT, as a rack is (FEEL_PLAN section 10); the flag lives on the weapon.
	void StartEngine(int k, double drawn)
	{
		if (!card || !ammo || ammo.engineRunning) return;
		ammo.engineRunning = true;
		PlaySnd(SlotSound("start", card.startSound));
		String startId = (k >= 0 && k < card.verbs.Size()) ? card.verbs[k].id : "its start verb";
		WM_Log.Info(String.Format("%s gun: [verbs] start %s -- the engine CAUGHT at drawn %.3f; it fires now", HandName(), startId, drawn));
	}

	// THE PART A START VERB PULLS, for the click's line.
	String StartPartName()
	{
		if (!card) return "ripcord";
		for (int k = 0; k < card.verbs.Size(); k++)
			if (card.verbs[k].kind == WM_Verb.START && card.verbs[k].partId != "") return card.verbs[k].partId;
		return "ripcord";
	}

	// ITS IDLE, LOOPED on the prop while it runs with the trigger up -- while the trigger is down the
	// cut is the weapon's own sound. Presentation only, off the owner's usercmd.
	private void EngineIdle(PlayerPawn pmo)
	{
		bool want = !stowed && prop != null && ammo != null && ammo.engineRunning;
		if (want && pmo && pmo.player && (pmo.player.cmd.buttons & ((hand == 0) ? BT_ATTACK : BT_OFFHANDATTACK)) != 0) want = false;
		// The sound is resolved as the loop starts (a pick is heard on its next start). With no pick and no
		// card idle sound it stays silent, asked again each tic, so a pick made while it runs starts it.
		if (want && !idleLoopOn)
		{
			String idleSound = SlotSound("idle", card.idleSound);
			if (idleSound != "")
			{
				prop.A_StartSound(idleSound, IDLE_CHANNEL, CHANF_LOOPING);
				idleLoopOn = true;
			}
		}
		else if (!want && idleLoopOn)
		{
			if (prop) prop.A_StopSound(IDLE_CHANNEL);
			idleLoopOn = false;
		}
	}

	// ---- A PART THAT SPINS (card.zs WM_Part.spinBy, G11) -----------------------------------
	//
	// A chaingun's barrels. Each tic its speed eases toward full while it is wanted -- the trigger
	// of the hand holding this gun down (spin = trigger), or a shot within the last cycle (spin =
	// fire) -- and toward still otherwise, over spinup / spindown tics. It turns by speed x
	// spinrate degrees, wrapped into one period of its hinge (`degrees`): exactly where its
	// pattern repeats, so the wrap never shows. PRESENTATION ONLY -- read off the owner's usercmd
	// and this gun's own shots, it moves nothing the game compares.
	private void Spin(PlayerPawn pmo)
	{
		bool full = false;
		bool rising = false;
		bool falling = false;
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let p = card.parts[i];
			if (p.spinBy == WM_Part.SPIN_NONE || p.dof.degrees <= 0) continue;
			bool want = false;
			if (!stowed && pmo && pmo.player)
			{
				if (p.spinBy == WM_Part.SPIN_TRIGGER)
					want = (pmo.player.cmd.buttons & ((hand == 0) ? BT_ATTACK : BT_OFFHANDATTACK)) != 0;
				else
				{
					let spinGun = WM_Gun(gunItem);
					int window = spinGun ? spinGun.CycleTics() + 1 : 20;
					want = firedTic > 0 && level.maptime - firedTic <= window;
				}
			}
			double was = p.spinSpeed;
			if (want) p.spinSpeed = (p.spinUpTics > 0) ? min(1.0, was + 1.0 / p.spinUpTics) : 1.0;
			else      p.spinSpeed = (p.spinDownTics > 0) ? max(0.0, was - 1.0 / p.spinDownTics) : 0.0;
			if (want && was <= 0.0) rising = true;
			if (was >= 1.0 && p.spinSpeed < 1.0) falling = true;
			if (p.spinSpeed >= 1.0) full = true;
			double period = p.dof.degrees;
			double turned = p.spinAngle + p.spinSpeed * p.spinRate;
			p.spinAngle = turned - floor(turned / period) * period;
			p.value = p.spinAngle / period;
		}
		// ITS SOUNDS (card spinupsound / spinsound / spindownsound): the wind-up as it starts from
		// still, the loop while at full speed, the run-down as it leaves full speed.
		if (rising) PlaySnd(SlotSound("spinup", card.spinUpSound));
		String spinLoop = (full && !spinLoopOn && prop) ? SlotSound("spin", card.spinSound) : "";
		if (spinLoop != "")
		{
			prop.A_StartSound(spinLoop, SPIN_CHANNEL, CHANF_LOOPING);
			spinLoopOn = true;
		}
		else if (!full && spinLoopOn)
		{
			if (prop) prop.A_StopSound(SPIN_CHANNEL);
			spinLoopOn = false;
		}
		if (falling) PlaySnd(SlotSound("spindown", card.spinDownSound));
	}

	// THE SHOT'S STROKE, BY VERB (wm_verbs on). Every CYCLE that cycles on the
	// shot runs its own clock, with Cycle's curve, cvars and end rule below; one
	// that holds open shows it. A hand on the part beats the clock.
	private void CycleByVerbs()
	{
		for (int k = 0; k < card.verbs.Size() && k < verbTics.Size(); k++)
		{
			let v = card.verbs[k];
			if (v.kind != WM_Verb.CYCLE || v.partIndex < 0 || v.partIndex >= card.parts.Size()) continue;
			let part = card.parts[v.partIndex];
			if (heldPart == v.partIndex) { verbTics[k] = 0; continue; }

			if (verbTics[k] > 0)
			{
				verbTics[k]--;
				double total = max(1.0, Cvf("wm_cycle_tics", 6.0));
				double t = 1.0 - (double(verbTics[k]) / total);
				double peak = clamp(Cvf("wm_recoil_travel", 1.0), 0.1, 1.0);
				double curve = (t < 0.35) ? (t / 0.35) : (1.0 - (t - 0.35) / 0.65);
				part.value = clamp(curve, 0.0, 1.0) * peak;
				// EMPTY MEANS IT STAYS BACK -- Cycle's own end rule.
				if (verbTics[k] <= 0) part.value = ammo.actionLock ? 1.0 : 0.0;
				continue;
			}
			// THE LOCK IS A STATE, re-asserted -- by the verb that holds open.
			if (ammo.actionLock && v.holdOpenWhenEmpty) part.value = 1.0;
		}
	}

	// THE ACTION CYCLING ON A SHOT -- out fast, back slower: the shot throws
	// it, the spring returns it. A hand on the slide beats the clock.
	private void Cycle()
	{
		int ai = card.FindRoleIndex("action");
		if (ai < 0) return;
		let part = card.parts[ai];
		if (heldPart == ai) { cycleTics = 0; return; }

		if (cycleTics > 0)
		{
			cycleTics--;
			double total = max(1.0, Cvf("wm_cycle_tics", 6.0));
			double t = 1.0 - (double(cycleTics) / total);
			double peak = clamp(Cvf("wm_recoil_travel", 1.0), 0.1, 1.0);
			double v = (t < 0.35) ? (t / 0.35) : (1.0 - (t - 0.35) / 0.65);
			part.value = clamp(v, 0.0, 1.0) * peak;
			// EMPTY MEANS IT STAYS BACK. The held-open slide IS the gun telling
			// you it is out.
			if (cycleTics <= 0) part.value = ammo.actionLock ? 1.0 : 0.0;
			return;
		}
		// The lock is a STATE, re-asserted rather than set once.
		if (ammo.actionLock) part.value = 1.0;
	}

	// The rack's two sounds, falling back to the magazine's until a card names
	// its own -- see WM_Card.rackApexSound.
	// A pick for the slot (SlotSound) outranks both. The magazine fallback is the card's own magazine sound,
	// used only with no pick and no card rack sound -- exactly as before picks existed.
	String RackApexSound()
	{
		String rack = SlotSound("rackapex", card.rackApexSound);
		return (rack != "") ? rack : card.magOutSound;
	}
	String RackResetSound()
	{
		String rack = SlotSound("rackreset", card.rackResetSound);
		return (rack != "") ? rack : card.magInSound;
	}

	void PlaySnd(String snd, double vol = 1.0)
	{
		if (prop && snd != "") prop.A_StartSound(snd, CHAN_AUTO, CHANF_OVERLAP, vol);
	}

	// THE SOUND A SLOT PLAYS: the owner's pick for this gun and slot (VR Weapon Sound Selection's
	// wm_snd_<gun>_<slot>, WM_SoundPick) when one is set, else the card's own. Resolved on every play, so a
	// pick is heard the next time the slot sounds. It only names a sound, and reads the gun's OWNER.
	String SlotSound(String slot, String cardSound)
	{
		if (!card) return cardSound;
		return WM_SoundPick.ForActor(gunItem ? gunItem.Owner : null, card.weaponClass, slot, cardSound);
	}

	// ---- A SHOT ------------------------------------------------------------
	// chambers: how many chambers this pull fires (WM_System.ChambersToFire) -- 1 for every
	// class that does not say WM_Gun.ChambersPerPull, which is the shot exactly as it was.
	// rounds: what this pull spends from a gun with no chamber (WM_Card.FIRES_MAGAZINE) -- 1
	// for every class that says nothing; a chamber gun never reads it.
	void OnShot(PlayerPawn pmo, int chambers = 1, int rounds = 1)
	{
		// NO CHAMBER (WM_Card.firesFrom), on either wm_verbs path, and no case waits in a
		// chamber -- so nothing below keeps one. From the MAGAZINE the pull is paid here; from
		// the RESERVE the weapon's own fire action already paid it (on every machine); on
		// NOTHING there is nothing to pay.
		bool fromMag = card.FiresFromMagazine();
		bool noChamber = !card.FiresFromChamber();
		// A MANUAL ACTION (wm_verbs on) keeps the fired case in its chamber for the
		// stroke to throw, so no brass leaves on the shot. Both pistols cycle on the
		// shot, so for them this is false and the shot is exactly as it was.
		bool manual = !noChamber && WM_Verb.Enabled() && ManualAction();
		// THE CASE STAYS IN ITS CHAMBER until something throws it out (WM_Card.KeepsCaseOnShot):
		// a revolver's, until the gun opens. False for both pistols, true for both pumps --
		// which `manual` already said -- so for them nothing here changes.
		bool keeps  = !noChamber && WM_Verb.Enabled() && card.KeepsCaseOnShot();
		hammerFell = true;
		firedTic = level.maptime;
		int fired = 1;
		int spent = 0;
		if (noChamber)
		{
			if (fromMag) spent = ammo.SpendFromMagazine(rounds);
			hammerCocked = true;
			hammerDownTics = 2;
		}
		else if (WM_Verb.Enabled()) fired = ShotByVerbs(pmo, manual || keeps, chambers);
		else
		{
			ammo.Fire();
			hammerCocked = true;       // it falls, and the slide cocks it again
			hammerDownTics = 2;
			if (card.FindRoleIndex("action") >= 0)
				cycleTics = int(max(1.0, Cvf("wm_cycle_tics", 6.0)));
		}

		// A SAW (WM_Gun.ShotSaw) has no muzzle: no flash, no sparks, and a lighter buzz, since it
		// "fires" every few tics for as long as the trigger is held.
		let shotGunClass = WM_Gun(gunItem);
		bool sawing = shotGunClass && shotGunClass.sawShotOn;
		if (prop) prop.A_StartSound(SlotSound("fire", card.fireSound), CHAN_WEAPON, CHANF_OVERLAP);
		level.VRHaptic(hand, sawing ? 0.35 : 0.8, sawing ? 6.0 : 18.0);
		if (!sawing) Flash(pmo);
		if (!manual && !keeps) Brass(pmo);

		if (fromMag)
		{
			WM_Log.Info(String.Format("%s gun: SHOT -- %d round%s straight from the magazine, %d left", HandName(),
				spent, (spent == 1) ? "" : "s", ammo.rounds));
		}
		else if (noChamber)
		{
			// FROM THE RESERVE the fire action paid for it; ON NOTHING there was nothing to pay.
			if (card.firesFrom == WM_Card.FIRES_RESERVE)
			{
				// `let`, not Class<Ammo>: inside WM_Rig the field `ammo` hides the type name Ammo
				// (ZScript names are case-insensitive), and the compiler refuses the declaration.
				let reserveClass = WM_LooseMag.ReserveFor(card.weaponClass);
				let reserveInv = pmo.FindInventory(reserveClass);
				WM_Log.Info(String.Format("%s gun: SHOT -- %d round%s from the %s reserve, %d left", HandName(),
					rounds, (rounds == 1) ? "" : "s", GetDefaultByType(reserveClass).GetClassName(), reserveInv ? reserveInv.Amount : 0));
			}
			else WM_Log.Info(String.Format("%s gun: SHOT -- it fires on no ammunition", HandName()));
		}
		else if (card.HasVerbKind(WM_Verb.SWAP))
		{
			WM_Log.Info(String.Format("%s gun: SHOT -- %d in the magazine, %s%s",
				HandName(), ammo.rounds,
				ammo.chambered ? "next one chambered" : "chamber EMPTY",
				ammo.actionLock ? ", SLIDE LOCKED BACK" : ""));
		}
		else
		{
			let shotGun = WM_Gun(gunItem);
			int np = shotGun ? shotGun.PelletsPerShot() : 1;
			// A PULL OF SEVERAL CHAMBERS says how many fired; every other class's line is as it was.
			String chamberText = "";
			if (shotGun && shotGun.ChambersEachPull() > 1)
			{
				np *= max(fired, 1);
				chamberText = String.Format(" from %d chamber%s at once", fired, (fired == 1) ? "" : "s");
			}
			WM_Log.Info(String.Format("%s gun: SHOT -- %d pellet%s%s; stores now %s%s", HandName(), np, (np == 1) ? "" : "s", chamberText,
				ammo.StoreCounts(), manual ? " -- the case stays in until the action is worked"
				                           : (keeps ? String.Format(" -- the case stays in its chamber until the gun opens; under the hammer now %s", ammo.UnderHammer()) : "")));
		}
	}

	// A DEAD TRIGGER. A click and nothing else. If the hammer was cocked on an
	// empty chamber it falls, and stays down until the slide is worked.
	//
	// OUT OF BATTERY (wm_verbs on) it is a click too, with the reason -- and the
	// hammer stays where it is, since nothing reached it. Never true of a pistol.
	// rounds: what the pull would have spent from a gun with no chamber, for its line.
	// A CHARGE STARTING (WM_Gun.ChargeTics): its sound at the gun, and the log line.
	void OnCharge(String snd, int tics)
	{
		if (!card) return;
		PlaySnd(SlotSound("charge", snd));
		WM_Log.Info(String.Format("%s gun: CHARGING -- %d tics, then the shot", HandName(), tics));
	}

	// ---- A SECOND BARREL (card.zs WM_Barrel) ------------------------------------------------

	// ITS MUZZLE, model space: the barrel's own point with this hand's muzzle trim sliders -- the
	// same trim the card's muzzle takes, since both are measured on the one mesh.
	private Vector3 BarrelMuzzleModel(WM_Barrel b)
	{
		return b.muzzle + (MuzzleModel() - card.muzzle);
	}

	// ITS SHOT, announced by WM_System.OnAltShot on the tic the weapon fired it: one round out of
	// its store, left SPENT in a slotted one until something empties it. Its sound, a kick, its
	// flash and sparks at its own muzzle, and no brass -- nothing cycles a barrel.
	void OnBarrelShot(PlayerPawn pmo, WM_Barrel b)
	{
		if (!card || !ammo || !b) return;
		bool spent = ammo.DischargeBarrel(b.fromStore);
		if (prop) prop.A_StartSound(SlotSound("altfire", (b.fireSound != "") ? b.fireSound : card.fireSound), CHAN_WEAPON, CHANF_OVERLAP);
		level.VRHaptic(hand, 1.0, 22.0);
		Vector3 mz = BarrelMuzzleModel(b);
		let g = WM_Gun(gunItem);
		FlashAt(pmo, mz, b.dir, g ? g.AltFlashProfileOrDefault() : "default");
		WM_Log.Info(String.Format("%s gun: barrel %s SHOT -- %s from %s%s; stores now %s", HandName(), b.id,
			(b.shotClassName != "") ? b.shotClassName : "RSB_Bullet", b.fromStore,
			spent ? "" : " -- but nothing live was left in it to spend, which CanAltFire had just denied",
			ammo.StoreCounts()));
	}

	// A DEAD SECOND BUTTON: a click, and why -- the other hand off the support grip, the open verb
	// the barrel waits on not shut, or nothing live in its store. needsGrip: WM_System.OnAltDry
	// works that out, because the hands are the system's.
	void OnBarrelDry(WM_Barrel b, bool needsGrip)
	{
		if (stowed || !card || !b) return;
		PlaySnd(SlotSound("dry", card.drySound), 0.8);
		String why;
		if (needsGrip) why = "it needs both hands: take its support grip with your other hand";
		else
		{
			String shutWhy = WM_Verb.Enabled() ? BarrelOutOfBattery(b) : "";
			if (shutWhy != "") why = "out of battery: " .. shutWhy;
			else why = String.Format("nothing live in %s -- stores %s", b.fromStore, ammo ? ammo.StoreCounts() : "unknown");
		}
		WM_Log.Info(String.Format("%s gun: barrel %s click -- %s", HandName(), b.id, why));
	}

	// needsGrip: a two-handed gun (card `hands = 2`) whose support grip the other hand is not
	// holding. WM_System.OnDry works that out, because the hands are the system's.
	void OnDry(int rounds = 1, bool needsGrip = false)
	{
		if (stowed || !card) return;
		// TWO-HANDED, AND THE OTHER HAND IS NOT ON IT: a click with its reason, and the hammer
		// left where it is -- the pull never reached it.
		if (needsGrip)
		{
			PlaySnd(SlotSound("dry", card.drySound), 0.8);
			WM_Log.Info(String.Format("%s gun: click -- it needs both hands: take its support grip with your other hand", HandName()));
			return;
		}
		// AN ENGINE NOT RUNNING (verb.zs START): a click, and what to pull.
		if (card.HasVerbKind(WM_Verb.START) && ammo && !ammo.engineRunning)
		{
			PlaySnd(SlotSound("dry", card.drySound), 0.8);
			WM_Log.Info(String.Format("%s gun: click -- the engine is not running: pull its %s", HandName(), StartPartName()));
			return;
		}
		String openWhy = WM_Verb.Enabled() ? OutOfBattery() : "";
		if (openWhy == "" && hammerCocked && !ammo.actionLock) hammerCocked = false;
		PlaySnd(SlotSound("dry", card.drySound), 0.8);
		if (openWhy != "")
		{
			WM_Log.Info(String.Format("%s gun: click -- out of battery: %s", HandName(), openWhy));
			return;
		}
		hammerFell = true;
		// NO CHAMBER (WM_Card.FIRES_MAGAZINE): the magazine is what could not pay for the pull.
		if (card.FiresFromMagazine())
		{
			if (!ammo.magIn)
				WM_Log.Info(String.Format("%s gun: click -- no magazine in, and it fires straight from one", HandName()));
			else
				WM_Log.Info(String.Format("%s gun: click -- the magazine has %d, a pull takes %d", HandName(), ammo.rounds, max(rounds, 1)));
			return;
		}
		// NO STORES (WM_Card.FIRES_RESERVE): the owner's reserve is what could not pay. A gun that
		// fires on nothing only clicks out of battery, which returned above.
		if (card.KeepsNoRounds())
		{
			let dryReserve = WM_LooseMag.ReserveFor(card.weaponClass);   // `let`: the field `ammo` hides the type Ammo here
			WM_Log.Info(String.Format("%s gun: click -- %s", HandName(), (card.firesFrom == WM_Card.FIRES_RESERVE)
				? String.Format("the %s reserve cannot pay for a pull of %d", GetDefaultByType(dryReserve).GetClassName(), max(rounds, 1))
				: "it fires on no ammunition, and still did not fire"));
			return;
		}
		// A DOUBLE-ACTION PULL TURNS THE CYLINDER ON A CLICK TOO: the hammer fell on an empty
		// or spent chamber, and the next one comes round. Only a gun whose chamber store is
		// indexed and turns on the shot -- never a pistol or a pump.
		if (WM_Verb.Enabled() && ammo.TurnsOnShot())
		{
			String wasUnder = ammo.UnderHammer();
			ammo.TurnChamber();
			WM_Log.Info(String.Format("%s gun: DRY FIRE -- click on chamber %s, the cylinder turned to %s. Stores %s",
				HandName(), wasUnder, ammo.UnderHammer(), ammo.StoreCounts()));
			return;
		}
		// A GUN LOADED THROUGH AN OPEN VERB -- a break action -- is emptied and filled by
		// opening it, not by working an action. (A revolver turned and returned above.)
		if (WM_Verb.Enabled() && card.HasVerbKind(WM_Verb.OPEN) && !card.HasVerbKind(WM_Verb.CYCLE))
		{
			WM_Log.Info(String.Format("%s gun: DRY FIRE -- click, nothing live to fire: open it, load, shut it. Stores %s", HandName(), ammo.StoreCounts()));
			return;
		}
		if (!card.HasVerbKind(WM_Verb.SWAP))
		{
			WM_Log.Info(String.Format("%s gun: click -- nothing live in the chamber: work the action. Stores %s", HandName(), ammo.StoreCounts()));
			return;
		}
		WM_Log.Info(String.Format("%s gun: click -- %s", HandName(),
			!ammo.magIn ? "no magazine, nothing chambered"
			: (ammo.actionLock ? "slide locked back: rack it" : "nothing chambered: rack it")));
	}

	private Vector3 MuzzleModel()
	{
		Vector3 trim = (hand == 0)
			? (Cvf("wm_main_muzzle_x", 0), Cvf("wm_main_muzzle_y", 0), Cvf("wm_main_muzzle_z", 0))
			: (Cvf("wm_off_muzzle_x", 0),  Cvf("wm_off_muzzle_y", 0),  Cvf("wm_off_muzzle_z", 0));
		return card.muzzle + trim;
	}

	// THE GUN'S SIDEWAYS AXIS ON THE DRAWN GUN, at the muzzle -- for WM_Gun's effect helpers
	// (the across axis of a flamethrower's jets). Presentation only. MuzzleWorld is below.
	Vector3 AcrossWorld() { return WorldDir(MuzzleModel(), (0, 1, 0)); }

	Vector3 BarrelWorld()
	{
		return WorldDir(MuzzleModel(), card.barrel);
	}

	// Where the muzzle is in the world, for anything that measures from it --
	// the impact effects match a bullet's puff to the shot by it.
	Vector3 MuzzleWorld()
	{
		return World(MuzzleModel());
	}

	// THE MUZZLE, AN RS_BALLISTICS FLASH (RSB_CALL_SITES_HANDOFF.md): light, lit-air cone, bore sparks,
	// flame and smoke, all from the class's FlashProfile and the player's RS Ballistics settings.
	// Presentation on this machine only: RSB_Flash is +NOINTERACTION and draws no playsim RNG.
	private void Flash(PlayerPawn pmo)
	{
		let g = WM_Gun(gunItem);
		FlashAt(pmo, MuzzleModel(), card.barrel, g ? g.FlashProfileOrDefault() : "default");
	}

	// mz, boreModel: a muzzle and the way its bore points, model space -- the card's, or a second
	// barrel's (WM_Barrel, OnBarrelShot, with the class's AltFlashProfile).
	private void FlashAt(PlayerPawn pmo, Vector3 mz, Vector3 boreModel, String profile)
	{
		if (!prop) return;
		Vector3 at  = World(mz);
		Vector3 fwd = WorldDir(mz, boreModel);
		// One flash per hand at a time: a new shot retires the old flash first, so the old one clearing
		// its beam slot cannot blank the new. Which beam slot a hand uses is the rig's (wm_flash_slot).
		if (lastFlash) lastFlash.Destroy();
		lastFlash = RSB_Flash.Fire(profile, at, fwd, int(Cvf("wm_flash_slot", 4.0)) + hand, pmo.Vel);
	}

	private Vector3 EjectDirModel()
	{
		Vector3 d = card.ejectDir;
		if (hand == 1 && Cvb("wm_eject_mirror_off", false)) d.y = -d.y;
		return d;
	}

	private void Brass(PlayerPawn pmo)
	{
		// A GUN WITH NO CASES (card `casing = none`) throws none, ever.
		if (card.noCasing || !prop) return;
		Vector3 at = World(card.ejectPort);
		Vector3 wd = WorldDir(card.ejectPort, EjectDirModel());
		let g = WM_Gun(gunItem);
		// AN RS_BALLISTICS CASING, LOCAL (shared: false; RSB_CALL_SITES_HANDOFF.md). A rig works only the
		// console player's hands, so this runs on one machine and must not spawn a missile: RSB_LocalEjecta
		// is +NOINTERACTION and hashes its own jitter. Its profile is the class's EjectaProfile; its sound the
		// owner's pick or the card's casingsound, and "" (neither) is the profile's own. RS Ballistics'
		// Casings switch and look settings apply inside Throw. When rigs run per player on every machine:
		// shared: true, and a constant speed instead of wm_eject_speed.
		RSB_Ejecta.Throw(g ? g.EjectaProfileOrDefault() : "default", at, wd, pmo.Vel,
			Cvf("wm_eject_speed", 4.0), hand * 65536 + (++brassSeq), false, SlotSound("casing", card.casingSound));

		// A BELT LINK WITH THE CASE (card `linkmodel`, G16): out of the same port, a little slower, on its own
		// jitter -- a hash, never the playsim RNG, as the brass. It follows RS Ballistics' Casings switch, and
		// bounces on the casing pick or card sound when one is named, else its own wm/casing. Wear may destroy
		// it, so nothing touches it after.
		if (card.linkModelFile == "" || !RSB_Settings.Casings()) return;
		let lk = WM_BeltLink(Actor.Spawn("WM_BeltLink", at, ALLOW_REPLACE));
		if (!lk) return;
		double linkKick = WM_Jitter.Between(0.55, 0.85, level.maptime, hand * 65536 + (++brassSeq), int(at.y * 16) ^ int(at.z * 16));
		lk.Vel = wd * (Cvf("wm_eject_speed", 4.0) * linkKick) + pmo.Vel;
		lk.angle = VectorAngle(wd.x, wd.y) + 90.0;
		String linkSound = SlotSound("casing", card.casingSound);
		if (linkSound != "") lk.BounceSound = linkSound;
		lk.Wear(card);
	}

	// A GOOD ROUND, RACKED OUT. It goes out of the port like the brass, slower,
	// and it stays on the floor -- it is ammunition, and it can be picked back up.
	private void EjectRound(PlayerPawn pmo)
	{
		if (!prop) return;
		Vector3 at = World(card.ejectPort);
		Vector3 wd = WorldDir(card.ejectPort, EjectDirModel());
		let r = WM_LooseRound(Actor.Spawn("WM_LooseRound", at, ALLOW_REPLACE));
		if (!r) return;
		r.SetupRound(card, pmo);
		r.Vel = wd * (Cvf("wm_eject_speed", 4.0) * 0.6) + pmo.Vel;
		r.angle = VectorAngle(wd.x, wd.y);
		r.graceTics = int(Cvf("wm_walk_grace", 175.0));
		// The gun's own hand does not catch it out of the port. Read only by a catch
		// for a gun with load points; a pistol's racked round is not caught at all.
		r.droppedBy = hand + 1;
		r.dropTic   = level.maptime;
		WM_Log.Info(String.Format("%s gun: a live round went out of the port", HandName()));
	}

	// ---- THE MAGAZINE ------------------------------------------------------

	// Out of the gun and into the room. THE CHAMBERED ROUND STAYS: dropping a
	// magazine does not empty the chamber, so you still have one shot.
	WM_LooseMag DropMagazine(PlayerPawn pmo)
	{
		// A store that does not detach -- a tube -- never leaves, and never spawns an
		// empty magazine pretending it did. Both pistols' magazines detach.
		if (!card || !ammo.magIn || !ammo.MagDetaches()) return null;
		int fi = card.FindRoleIndex("feed");
		WM_Part feed = (fi >= 0) ? card.parts[fi] : null;
		if (feed && feed.driveSlot >= 0) StopDrive(feed);

		double v = feed ? feed.value : 0.0;
		Vector3 c = card.magCenter;
		// THE WAY IT LEAVES: along the feed part's travel. A TWO-STAGE magazine (dof2) cannot
		// leave from inside the gun -- it has to clear both stages -- so it appears fully out
		// and leaves along its last stage (a slide's axis; a hinge last stage keeps stage one's).
		Vector3 leaveAxis = (0, 0, -1);
		if (feed)
		{
			leaveAxis = feed.dof.axis;
			if (feed.dof2)
			{
				c = TwoStagePoint(feed, card.magCenter, 1.0);
				if (feed.dof2.moveKind != WM_Dof.MOVE_HINGE) leaveAxis = feed.dof2.axis;
			}
			else c += feed.dof.axis * (v * feed.dof.distance);
		}
		Vector3 at = prop ? World(c) : pmo.Pos;

		// WHERE THE DRAWN MAGAZINE'S AXES POINT (G14), asked before it leaves the gun, so an indexed
		// part's steps still read the rounds in it. A two-stage magazine leaves fully out.
		double turnAt = (feed && feed.dof2) ? 1.0 : v;
		Vector3 turnX, turnY, turnZ;
		bool turnMirrored = false;
		bool turnKnown = false;
		if (prop && feed)
		{
			[turnX, turnY, turnZ, turnMirrored, turnKnown] = DrawnMagBasis(feed, c, turnAt);
		}

		int had = ammo.TakeMagazine();
		let m = WM_LooseMag(Actor.Spawn("WM_LooseMag", at, ALLOW_REPLACE));
		if (m)
		{
			m.Setup(had, card, pmo);
			Vector3 down = (0, 0, -1);
			if (prop && feed) down = WorldDir(c, leaveAxis);
			m.Vel = down * Cvf("wm_drop_speed", 2.0) + pmo.Vel;
			Vector3 fwd = prop ? BarrelWorld() : (cos(pmo.angle), sin(pmo.angle), 0);
			m.angle = VectorAngle(fwd.x, fwd.y);
			// IT LEAVES TURNED AS IT WAS DRAWN: the gun's whole attitude and the part's own turn, not
			// level with only the barrel's yaw -- a plasma cell twisted 18 degrees at detach, or a
			// magazine dropped from a gun held on its side, does not snap upright as it falls.
			if (turnKnown) TurnLikeDrawn(m, turnX, turnY, turnZ, turnMirrored, turnAt);
			m.graceTics = int(Cvf("wm_walk_grace", 175.0));
			m.droppedBy  = hand + 1;
			m.dropTic    = level.maptime;
		}
		if (feed) { feed.present = false; feed.value = 0.0; }
		PlaySnd(SlotSound("magout", card.magOutSound));
		level.VRHaptic(hand, 0.6, 14.0);
		WM_Log.Info(String.Format("%s gun: magazine out -- %d rounds went with it, %s",
			HandName(), had, LeftAfterMagOut()));
		return m;
	}

	// ---- A DROPPED MAGAZINE KEEPS ITS TURN (G14) ------------------------------------------------
	//
	// THE LOOSE MESH WAS CUT FROM THE GUN by tools/md3_write.py extract(): loose = R (gun - magcenter),
	// R the shortest turn carrying the feed part's dof axis onto -z (_rotation_onto; stage one's axis on
	// a two-stage part). So a loose-mesh direction w is the gun direction R^T w; the drawn part turns
	// that (its index, its hinge or twist, a second stage) and the drawn gun carries it into the world
	// (WorldDir). The props are drawn MIRRORED (a MODELDEF Scale x below 0) where the loose mesh is not,
	// and no turn matches a mirror, so the loose mesh's x is mirrored the same way first: the out axis
	// and y land exactly, and the loose mesh shows as its own x-mirror, as it always has. The rule, and
	// its measurement on 16 cards to 0.03 degrees, are the weapons lane's (2026-09-13).
	//
	// SOLVED AGAINST THE RENDERER, NOT A GUESSED EULER ORDER. The loose magazine's own
	// ModelPointToWorld at zero angles says what its MODELDEF and floor sliders do; the turn left over
	// is the actor's, Rz(angle) Ry(pitch) Rx(roll) in map axes -- models.cpp ObjectToWorldMatrix rotates
	// by -yaw about GL y, -pitch about GL z and -roll about GL x (USEACTORPITCH, USEACTORROLL), which the
	// GL-to-map swap turns into exactly those. Then checked the same way, and if the drawn and the loose
	// disagree by more than DROP_TURN_TOLERANCE the magazine falls level as it did before, with a warning.

	// The largest difference, per unit axis, the check lets through.
	const DROP_TURN_TOLERANCE = 0.05;

	// R^T w, for R the shortest turn carrying unit u onto -z: the gun direction a loose-mesh direction
	// came from. The opposite case is md3_write's half turn about a perpendicular, its own inverse.
	static Vector3 StandInverse(Vector3 u, Vector3 w)
	{
		Vector3 down = (0, 0, -1);
		Vector3 k = u cross down;
		double s = k.Length();
		double c = u dot down;
		if (s < 0.000000001)
		{
			if (c > 0) return w;
			Vector3 p;
			if (abs(u.x) < 0.9) p = (1, 0, 0);
			else                p = (0, 1, 0);
			Vector3 hk = (u cross p).Unit();
			return hk * (2.0 * (hk dot w)) - w;
		}
		return WM_Space.Rotate(w, k / s, -atan2(s, c));
	}

	// A GUN DIRECTION ON THE FEED PART, TURNED AS THE PART IS DRAWN at value v: its index's steps, then
	// its hinge or twist, then a second stage's turn. A slide moves no direction.
	private Vector3 DrawnFeedTurn(WM_Part feed, Vector3 g, double v)
	{
		if (feed.indexDof && feed.indexDof.moveKind == WM_Dof.MOVE_HINGE)
		{
			int n = IndexSteps(feed);
			if (n > 0) g = WM_Space.Rotate(g, feed.indexDof.axis, n * feed.indexDof.degrees);
		}
		if (feed.dof2) return TwoStagePoint(feed, g, v) - TwoStagePoint(feed, (0, 0, 0), v);
		let d = feed.dof;
		if (d.moveKind == WM_Dof.MOVE_HINGE) return WM_Space.Rotate(g, d.axis, v * d.degrees);
		if (d.twist != 0) return WM_Space.Rotate(g, d.twistAxis, v * d.twist);
		return g;
	}

	// WHERE THE LOOSE MAGAZINE'S THREE AXES SHOULD POINT, in the world, for the drawn magazine at
	// model point c and value v -- and whether the gun is drawn mirrored. ok false when the drawn gun
	// gives no basis to ask.
	private Vector3, Vector3, Vector3, bool, bool DrawnMagBasis(WM_Part feed, Vector3 c, double v)
	{
		Vector3 gx = WorldDir(c, (1, 0, 0));
		Vector3 gy = WorldDir(c, (0, 1, 0));
		Vector3 gz = WorldDir(c, (0, 0, 1));
		double handed = (gx cross gy) dot gz;
		if (abs(handed) < 0.5) return (0, 0, 0), (0, 0, 0), (0, 0, 0), false, false;
		double mirror = (handed < 0) ? -1.0 : 1.0;
		Vector3 u = feed.dof.axis;
		Vector3 fx = WorldDir(c, DrawnFeedTurn(feed, StandInverse(u, (mirror, 0, 0)), v));
		Vector3 fy = WorldDir(c, DrawnFeedTurn(feed, StandInverse(u, (0, 1, 0)), v));
		Vector3 fz = WorldDir(c, DrawnFeedTurn(feed, StandInverse(u, (0, 0, 1)), v));
		return fx, fy, fz, mirror < 0, true;
	}

	// A LOOSE MAGAZINE'S THREE MODEL AXES IN THE WORLD, as the renderer would draw it now; ok false with
	// no model frame to ask (no MODELDEF block for it is loaded).
	private Vector3, Vector3, Vector3, bool LooseBasis(WM_LooseMag m)
	{
		Vector3 p0, f0, u0;
		[p0, f0, u0] = m.ModelPointToWorld(0, 0, 0);
		Vector3 ex = WM_Space.Eng((1, 0, 0));
		Vector3 ey = WM_Space.Eng((0, 1, 0));
		Vector3 ez = WM_Space.Eng((0, 0, 1));
		Vector3 px, py, pz, fu, uu;
		[px, fu, uu] = m.ModelPointToWorld(ex.x, ex.y, ex.z);
		[py, fu, uu] = m.ModelPointToWorld(ey.x, ey.y, ey.z);
		[pz, fu, uu] = m.ModelPointToWorld(ez.x, ez.y, ez.z);
		Vector3 ax = px - p0;
		Vector3 ay = py - p0;
		Vector3 az = pz - p0;
		if (ax.Length() < 0.000001 || ay.Length() < 0.000001 || az.Length() < 0.000001)
			return (0, 0, 0), (0, 0, 0), (0, 0, 0), false;
		return ax.Unit(), ay.Unit(), az.Unit(), true;
	}

	// TURN THE LOOSE MAGAZINE so its axes point along fx, fy, fz: Q = F B0^T against its own basis at
	// zero angles, split into angle, pitch and roll, set, and checked. Falls back to level with the
	// barrel's yaw -- what it always did -- when there is nothing to ask or the check misses.
	private void TurnLikeDrawn(WM_LooseMag m, Vector3 fx, Vector3 fy, Vector3 fz, bool mirrored, double v)
	{
		double levelYaw = m.angle;
		m.angle = 0;
		m.pitch = 0;
		m.roll  = 0;
		m.ClearInterpolation();
		Vector3 bx, by, bz;
		bool baseOk;
		[bx, by, bz, baseOk] = LooseBasis(m);
		if (!baseOk)
		{
			m.angle = levelYaw;
			m.ClearInterpolation();
			WM_Log.Once(WM_Log.LV_WARN, "dropturn:nomodel", String.Format(
				"%s gun: a dropped magazine falls level -- the loose magazine has no model frame to measure (no MODELDEF block for WM_LooseMag loaded)", HandName()));
			return;
		}
		double q00 = fx.x * bx.x + fy.x * by.x + fz.x * bz.x;
		double q01 = fx.x * bx.y + fy.x * by.y + fz.x * bz.y;
		double q10 = fx.y * bx.x + fy.y * by.x + fz.y * bz.x;
		double q11 = fx.y * bx.y + fy.y * by.y + fz.y * bz.y;
		double q20 = fx.z * bx.x + fy.z * by.x + fz.z * bz.x;
		double q21 = fx.z * bx.y + fy.z * by.y + fz.z * bz.y;
		double q22 = fx.z * bx.z + fy.z * by.z + fz.z * bz.z;
		double pitchDeg = asin(clamp(-q20, -1.0, 1.0));
		double yawDeg = 0;
		double rollDeg = 0;
		if (abs(q20) < 0.9999)
		{
			yawDeg  = atan2(q10, q00);
			rollDeg = atan2(q21, q22);
		}
		else yawDeg = atan2(-q01, q11);   // straight up or down: roll folds into yaw
		m.angle = yawDeg;
		m.pitch = pitchDeg;
		m.roll  = rollDeg;
		m.ClearInterpolation();

		Vector3 cx, cy, cz;
		bool checkOk;
		[cx, cy, cz, checkOk] = LooseBasis(m);
		double miss = checkOk ? max((cx - fx).Length(), max((cy - fy).Length(), (cz - fz).Length())) : 9.0;
		if (miss > DROP_TURN_TOLERANCE)
		{
			m.angle = levelYaw;
			m.pitch = 0;
			m.roll  = 0;
			m.ClearInterpolation();
			WM_Log.Warn(String.Format("%s gun: a dropped magazine falls level -- turned to angle %.1f, pitch %.1f, roll %.1f it still missed the drawn one by %.3f (allowed %.2f)",
				HandName(), yawDeg, pitchDeg, rollDeg, miss, DROP_TURN_TOLERANCE));
			return;
		}
		WM_Log.Info(String.Format("%s gun: the dropped magazine keeps its turn -- angle %.1f, pitch %.1f, roll %.1f (part at %.2f%s), matching the drawn one to %.3f",
			HandName(), yawDeg, pitchDeg, rollDeg, v, mirrored ? ", the gun drawn mirrored" : "", miss));
	}

	// WHAT IS LEFT TO FIRE WITH THE MAGAZINE OUT, for the logs: a chambered round, or --
	// for a gun with no chamber (WM_Card.FIRES_MAGAZINE) -- nothing at all.
	String LeftAfterMagOut()
	{
		if (card && card.FiresFromMagazine()) return "nothing left to fire -- it fires straight from the magazine";
		return ammo.chambered ? "one still chambered" : "chamber empty";
	}

	void Seat(int rounds)
	{
		ammo.SeatMagazine(rounds);
		let feed = card.FindRole("feed");
		if (feed) { feed.present = true; feed.value = 0.0; }
		PlaySnd(SlotSound("magin", card.magInSound));
		level.VRHaptic(hand, 0.7, 16.0);
		// A GUN WITH NO CHAMBER is ready the moment a loaded magazine is in: nothing to rack.
		String readyText = ammo.chambered ? "One already chambered: ready." : "Rack the slide.";
		if (card.FiresFromMagazine()) readyText = "Ready -- it fires straight from the magazine.";
		WM_Log.Info(String.Format("%s gun: seated -- %d rounds. %s", HandName(), ammo.rounds, readyText));
	}

	// WORKING THE ACTION BY HAND. On a locked-back gun it chambers from the
	// magazine and closes. On a loaded one it throws the chambered round out of
	// the port -- that is what an extractor does -- and feeds the next.
	void Racked(PlayerPawn pmo)
	{
		if (ammo.actionLock)
		{
			if (ammo.ReleaseLock())
				WM_Log.Info(String.Format("%s gun: racked -- chambered, %d in the magazine", HandName(), ammo.rounds));
			else
				WM_Log.Info(String.Format("%s gun: racked an empty gun -- the slide stays back until a loaded magazine is in", HandName()));
		}
		else
		{
			bool threw = ammo.Cycle();
			if (threw) EjectRound(pmo);
			WM_Log.Info(String.Format("%s gun: racked -- %s, %d in the magazine%s", HandName(),
				threw ? "a live round ejected" : "nothing was chambered",
				ammo.rounds, ammo.actionLock ? ", SLIDE LOCKED BACK" : ""));
		}
		hammerCocked = true;
		PlaySnd(RackResetSound());
		level.VRHaptic(hand, 0.5, 12.0);
	}

	// ---- THE ACTION, BY VERB (wm_verbs on) --------------------------------------

	// THE SHOT. The trigger spends the chambered round; every CYCLE that cycles on
	// the shot then works both its ends at once -- what was in the chamber out,
	// the next round in -- and one that holds open does so when there was nothing
	// to feed. WM_Ammo.Fire's transfers over named stores, plus the clock OnShot
	// always started.
	//
	// RETURNS HOW MANY CHAMBERS FIRED. chambers > 1 (WM_Gun.ChambersPerPull) spends up to
	// that many live chambers at once -- both barrels of a double; 1 is Discharge, as it
	// always was.
	private int ShotByVerbs(PlayerPawn pmo, bool manual, int chambers = 1)
	{
		// A manual action's case stays in the chamber, spent, until a stroke throws it.
		int fired = 0;
		if (chambers > 1) fired = ammo.DischargeChambers(chambers, manual);
		else fired = ammo.Discharge(manual) ? 1 : 0;
		bool shot = (fired > 0);
		// A CYLINDER TURNS ON THE SHOT: the next chamber comes under the hammer.
		if (shot && ammo.TurnsOnShot()) ammo.TurnChamber();
		hammerCocked = true;       // it falls, and the action cocks it again
		hammerDownTics = 2;
		for (int k = 0; k < card.verbs.Size() && k < verbTics.Size(); k++)
		{
			let v = card.verbs[k];
			if (v.kind != WM_Verb.CYCLE || !v.autoOnShot) continue;
			if (shot)
			{
				// The round just fired left its chamber EMPTY (the case is Brass's to
				// throw), so for a pistol this far end finds nothing and throws nothing.
				if (v.onOutEject && ammo.EjectFrom(v.fromStore)) EjectRound(pmo);
				if (v.onHomeFeed)
				{
					bool wasEmpty = ammo.FeedEmpty(v.feedStore);
					bool fed = ammo.FeedFrom(v.feedStore, v.intoStore);
					if (!fed && wasEmpty && v.holdOpenWhenEmpty) ammo.SetActionLock(true);
				}
			}
			// onshotstill: no drawn stroke. One tic only when the action just locked
			// open, so the part settles at the lock rather than staying home.
			if (v.autoOnShotStill) verbTics[k] = ammo.actionLock ? 1 : 0;
			else verbTics[k] = int(max(1.0, Cvf("wm_cycle_tics", 6.0)));
		}
		return fired;
	}

	// A STROKE RETURNED BY A SPRING, WHOLE. Worked past outat (at any point in the
	// hold) and let go, both ends happen together as the spring slams it home:
	// Racked above, over the verb's named stores. `drawn` is the value it was let
	// go at, or below zero for the test control.
	void RackByVerbs(PlayerPawn pmo, int k, double drawn)
	{
		if (!card || k < 0 || k >= card.verbs.Size()) return;
		let v = card.verbs[k];
		bool wasLocked = ammo.actionLock;

		bool threw = false;
		if (v.onOutEject)
		{
			threw = ammo.EjectFrom(v.fromStore);
			if (threw) EjectRound(pmo);
		}
		bool fed = false;
		bool wasEmpty = false;
		if (v.onHomeFeed)
		{
			wasEmpty = ammo.FeedEmpty(v.feedStore);
			fed = ammo.FeedFrom(v.feedStore, v.intoStore);
		}
		// HELD OPEN exactly when there was nothing to feed: Cycle's `!Feed` and
		// ReleaseLock's "stays back until a loaded magazine is in", as one rule.
		ammo.SetActionLock(v.holdOpenWhenEmpty && !fed && wasEmpty);
		if (k < verbStroke.Size()) verbStroke[k] = STROKE_HOME;

		hammerCocked = true;
		PlaySnd(RackResetSound());
		level.VRHaptic(hand, 0.5, 12.0);

		String outText = "nothing ejects";
		if (v.onOutEject) outText = threw ? "a live round ejected" : "nothing live to eject";
		String homeText = "nothing feeds";
		if (v.onHomeFeed)
			homeText = String.Format("%s, %d left in %s", fed ? ("fed into " .. v.intoStore) : "nothing to feed", ammo.LiveIn(v.feedStore), v.feedStore);
		String lockText = "";
		if (ammo.actionLock) lockText = ", HELD OPEN";
		else if (wasLocked)  lockText = ", let go from held open";
		WM_Log.Info(String.Format("%s gun: [verbs] cycle %s RACKED at %s -- %s, %s%s", HandName(), v.id,
			(drawn >= 0) ? String.Format("drawn %.3f", drawn) : "the test control", outText, homeText, lockText));
	}

	// A STROKE RETURNED BY HAND, IN TWO HALVES. Out past outat, the far end
	// happens there and then -- the case leaves at the back of a pump's stroke.
	// Back to homeat, the near end -- the next round goes in as it closes. Half a
	// stroke does half, and neither half repeats until the other has happened.
	//
	// ONLY EVER A CYCLE NOT RETURNED BY A SPRING (HoldByVerbs, ReleaseByVerbs,
	// RackByEvent), so nothing here reaches a pistol. Its sounds are the card's
	// cycleoutsound and cyclehomesound, silent when unstated -- never the pistol
	// rack sounds RackApexSound / RackResetSound fall back to.
	void StrokeOut(PlayerPawn pmo, int k, double drawn)
	{
		if (!card || k < 0 || k >= card.verbs.Size() || k >= verbStroke.Size()) return;
		if (verbStroke[k] == STROKE_OUT) return;
		let v = card.verbs[k];
		verbStroke[k] = STROKE_OUT;
		// WHAT WAS IN THE CHAMBER COMES OUT AS WHAT IT IS: a live round to pick back
		// up, or the spent case the shot left there (ShotByVerbs, manual).
		String outText = "nothing ejects";
		if (v.onOutEject)
		{
			int was = ammo.EjectCase(v.fromStore);
			if (was == WM_Store.SLOT_LIVE)       { EjectRound(pmo); outText = "a LIVE round ejected"; }
			else if (was == WM_Store.SLOT_SPENT) { Brass(pmo);      outText = "a spent case ejected"; }
			else                                  outText = "nothing in " .. v.fromStore .. " to eject";
		}
		hammerCocked = true;
		if (v.ret == WM_Verb.RET_STAY && k < verbOpen.Size()) verbOpen[k] = true;
		PlaySnd(SlotSound("cycleout", card.cycleOutSound));
		WM_Log.Info(String.Format("%s gun: [verbs] cycle %s OUT %s -- %s; stores now %s", HandName(), v.id, DrawnText(drawn),
			outText, ammo.StoreCounts()));
	}

	void StrokeHome(PlayerPawn pmo, int k, double drawn)
	{
		if (!card || k < 0 || k >= card.verbs.Size() || k >= verbStroke.Size()) return;
		if (verbStroke[k] == STROKE_HOME) return;
		let v = card.verbs[k];
		verbStroke[k] = STROKE_HOME;
		String homeText = "nothing feeds";
		if (v.onHomeFeed)
		{
			bool wasEmpty = ammo.FeedEmpty(v.feedStore);
			if (ammo.FeedFrom(v.feedStore, v.intoStore)) homeText = String.Format("fed %s -> %s", v.feedStore, v.intoStore);
			else if (wasEmpty) homeText = String.Format("nothing to feed: %s is empty", v.feedStore);
			else homeText = String.Format("did not feed: %s is not empty", v.intoStore);
		}
		// An action returned by hand has no lock of its own: coming home clears one
		// the old path may have left on this gun.
		if (ammo.actionLock) ammo.SetActionLock(false);
		if (k < verbOpen.Size()) verbOpen[k] = false;
		PlaySnd(SlotSound("cyclehome", card.cycleHomeSound));
		level.VRHaptic(hand, 0.5, 12.0);
		WM_Log.Info(String.Format("%s gun: [verbs] cycle %s HOME %s -- %s; stores now %s", HandName(), v.id, DrawnText(drawn),
			homeText, ammo.StoreCounts()));
	}

	static String DrawnText(double drawn)
	{
		if (drawn < 0) return "by the test control";
		return String.Format("at drawn %.3f", drawn);
	}

	// THE TEST CONTROL (netevent wm_rack_main / wm_rack_off), by verb: the first
	// cycle, both ends at once. A spring's through RackByVerbs; one returned by hand
	// through its own two halves, so a pump's spent case comes out as it would.
	void RackByEvent(PlayerPawn pmo)
	{
		if (!card) return;
		for (int k = 0; k < card.verbs.Size(); k++)
		{
			if (card.verbs[k].kind != WM_Verb.CYCLE) continue;
			WM_Log.Info(String.Format("%s gun: rack test control -- path VERBS", HandName()));
			if (card.verbs[k].ret != WM_Verb.RET_SPRING)
			{
				StrokeOut(pmo, k, -1.0);
				StrokeHome(pmo, k, -1.0);
				return;
			}
			RackByVerbs(pmo, k, -1.0);
			return;
		}
		WM_Log.Info(String.Format("%s gun: rack test control -- path VERBS, and no cycle verb to rack", HandName()));
	}

	int StrokeAt(int k)
	{
		if (k < 0 || k >= verbStroke.Size()) return STROKE_HOME;
		return verbStroke[k];
	}

	bool IsHeldOpen(int k)
	{
		if (k < 0 || k >= verbOpen.Size()) return false;
		return verbOpen[k];
	}

	void SetHeldOpen(int k, bool held)
	{
		if (k >= 0 && k < verbOpen.Size()) verbOpen[k] = held;
	}

	// ---- OPEN AND SHUT, AND EVERY CASE OUT (verb.zs OPEN, EJECT) ---------------------

	// AN OPEN VERB GOING OPEN OR SHUT. The one place it happens, so every way there -- a
	// hand past openat, a hand back to closeat, letting go shut -- does it alike: one log
	// line, its sound, and for `onopen = ejectall` every case in the store thrown out.
	// how: what did it, for the log line -- "by the drop-mag button", a flick. "" for a hand.
	void SetOpen(PlayerPawn pmo, int k, bool nowOpen, double drawn, String how = "")
	{
		if (!card || !ammo || k < 0 || k >= card.verbs.Size() || k >= verbOpen.Size()) return;
		if (verbOpen[k] == nowOpen) return;
		verbOpen[k] = nowOpen;
		let v = card.verbs[k];
		level.VRHaptic(hand, 0.5, 12.0);
		if (nowOpen)
		{
			PlaySnd(SlotSound("open", card.openSound));
			WM_Log.Info(String.Format("%s gun: [verbs] open %s OPENED %s%s -- stores %s", HandName(), v.id, DrawnText(drawn),
				(how != "") ? " -- " .. how : "", ammo.StoreCounts()));
			if (v.onOpenEjectAll) ThrowOutAll(pmo, k, v.fromStore, v.partIndex, (how != "") ? "as it opened " .. how : "as it opened");
		}
		else
		{
			PlaySnd(SlotSound("close", card.closeSound));
			WM_Log.Info(String.Format("%s gun: [verbs] open %s CLOSED %s%s -- under the hammer %s; stores %s",
				HandName(), v.id, DrawnText(drawn), (how != "") ? " -- " .. how : "", ammo.UnderHammer(), ammo.StoreCounts()));
		}
	}

	// A POINT ON THE GUN, CARRIED BY A PART: where model point m is with that part where it
	// is drawn now -- turned about its hinge, or slid along its axis. m itself for no part.
	Vector3 CarriedBy(int partIndex, Vector3 m)
	{
		if (!card || partIndex < 0 || partIndex >= card.parts.Size()) return m;
		let part = card.parts[partIndex];
		if (part.dof2) return TwoStagePoint(part, m, DrawnValue(part));
		if (part.indexDof) m = IndexPoint(part, m);   // G13: the index moves it before the dof does
		let d = part.dof;
		double val = DrawnValue(part);
		if (d.moveKind == WM_Dof.MOVE_HINGE)
			return d.pivot + WM_Space.Rotate(m - d.pivot, d.axis, val * d.degrees);
		Vector3 slid = m + d.axis * (val * d.distance);
		if (d.twist != 0) slid = d.pivot + WM_Space.Rotate(m - d.pivot, d.twistAxis, val * d.twist) + d.axis * (val * d.distance);
		return slid;
	}

	// THE PART THAT CARRIES WHAT A GATED VERB WORKS ON: its `needs = open:<id>` verb's part
	// (a crane, for a rod or a tilt), or -1.
	int GateCarrier(WM_Verb v)
	{
		if (!card || v.needsOpen == "") return -1;
		int gk = card.FindVerbIndex(v.needsOpen);
		if (gk < 0) return -1;
		return card.verbs[gk].partIndex;
	}

	bool EjectThrown(int k) { return k >= 0 && k < verbThrown.Size() && verbThrown[k]; }
	void SetEjectThrown(int k, bool thrown) { if (k >= 0 && k < verbThrown.Size()) verbThrown[k] = thrown; }

	// EVERY CASE IN A SLOTTED STORE, OUT OF THE GUN: live rounds as loose rounds a hand can
	// pick back up, spent ones as brass. From the card's ejectport along its ejectdir, both
	// CARRIED BY `carrier` -- a break-top's cylinder face has tipped with its barrel, a
	// crane's has swung out -- each case a little apart from the next. The scatter is a
	// hash of the tic and a counter (jitter.zs), never the playsim RNG.
	void ThrowOutAll(PlayerPawn pmo, int k, String storeId, int carrier, String how)
	{
		if (!card || !ammo) return;
		String vid = "";
		if (k >= 0 && k < card.verbs.Size()) vid = WM_Verb.KindName(card.verbs[k].kind) .. " " .. card.verbs[k].id;
		// AN EJECT VERB'S OWN SOUND (card `ejectsound`, slot eject): the rod pushed, the extractor kicking. Once a
		// stroke, as the verb throws -- a rod worked by hand even with nothing inside; a tilt or the button throws
		// only a held store. An open verb's ejectall keeps its open sound.
		if (k >= 0 && k < card.verbs.Size() && card.verbs[k].kind == WM_Verb.EJECT) PlaySnd(SlotSound("eject", card.ejectSound));
		int live, spent;
		[live, spent] = ammo.EjectAll(storeId);
		int n = live + spent;
		if (n <= 0)
		{
			WM_Log.Info(String.Format("%s gun: [verbs] %s -- nothing in %s to throw out, %s", HandName(), vid, storeId, how));
			return;
		}
		// A SECOND BARREL'S STORE (card.zs WM_Barrel): its live rounds go back to that barrel's own
		// ammo, and its `casing = none` throws no brass.
		let throwBarrel = card.BarrelForStore(storeId);
		bool throwNoCasing = card.noCasing || (throwBarrel && throwBarrel.noCasing);
		if (prop && pmo)
		{
			Vector3 portM  = CarriedBy(carrier, card.ejectPort);
			Vector3 aheadM = CarriedBy(carrier, card.ejectPort + EjectDirModel());
			Vector3 at = World(portM);
			Vector3 wd = World(aheadM) - at;
			if (wd.Length() > 1e-6) wd = wd.Unit();
			else wd = (0, 0, 1);
			double speed = Cvf("wm_eject_speed", 4.0);
			let g = WM_Gun(gunItem);
			for (int i = 0; i < n; i++)
			{
				int seq = ++brassSeq;
				double jx = WM_Jitter.Between(-1.0, 1.0, level.maptime, seq, hand * 5 + 1);
				double jy = WM_Jitter.Between(-1.0, 1.0, level.maptime, seq, hand * 5 + 2);
				double jz = WM_Jitter.Between(-1.0, 1.0, level.maptime, seq, hand * 5 + 3);
				Vector3 jit = (jx, jy, jz);
				Vector3 dir = wd + jit * 0.35;
				if (dir.Length() > 1e-6) dir = dir.Unit();
				else dir = wd;
				double kick = WM_Jitter.Between(0.5, 1.0, level.maptime, seq, hand * 5 + 4);
				Vector3 spawnAt = at + jit * 0.3;
				if (i < live)
				{
					let r = WM_LooseRound(Actor.Spawn("WM_LooseRound", spawnAt, ALLOW_REPLACE));
					if (!r) continue;
					r.SetupRound(card, pmo);
					if (throwBarrel) r.reserveName = throwBarrel.ammoClassName;
					r.Vel = dir * (speed * 0.6 * kick) + pmo.Vel;
					r.angle = VectorAngle(dir.x, dir.y);
					r.graceTics = int(Cvf("wm_walk_grace", 175.0));
					r.droppedBy = hand + 1;
					r.dropTic   = level.maptime;
				}
				else if (!throwNoCasing)
				{
					// A LOCAL RS_BALLISTICS CASING: see Brass().
					RSB_Ejecta.Throw(g ? g.EjectaProfileOrDefault() : "default", spawnAt, dir, pmo.Vel,
						speed * kick, seq, false, SlotSound("casing", card.casingSound));
				}
			}
		}
		level.VRHaptic(hand, 0.6, 14.0);
		WM_Log.Info(String.Format("%s gun: [verbs] %s EJECTED %d -- %d live, %d spent, %s; stores now %s",
			HandName(), vid, n, live, spent, how, ammo.StoreCounts()));
	}

	// ---- A FLICK SHUTS AN OPEN GUN (verb.zs OPEN close = flick, FEEL_PLAN section 1) ------------
	//
	// An open part rests against its open stop, so a jerk of the gun the way it shuts carries the
	// frame and leaves the part behind: when the hand stops, the part goes on and shuts. Measured
	// at the part's grab point -- the hand's own velocity plus its wrist's turn, because a sideways
	// roll barely moves the grip but swings a crane several centimetres above it -- along the flick
	// axis as drawn, over a two-tic mean that halves a one-sample tracking spike. A grace after the
	// part leaves shut or a hand lets go, then one settle below half the threshold, so the jerk that
	// opened it never shuts it again. No velocity is no flick: an honest zero, never a guess.
	// LOCAL INPUT: the controller's velocity is the owner's and reads zero in a netgame, so there a
	// flick never shuts anything and a hand still does (FEEL_PLAN section 10).
	private void FlickByVerbs(PlayerPawn pmo)
	{
		if (!prop || !resolved || stowed || !ammo || !pmo || !Cvb("wm_flick_close", true)) return;
		for (int k = 0; k < card.verbs.Size() && k < verbFlickQuiet.Size(); k++)
		{
			let v = card.verbs[k];
			if (v.kind != WM_Verb.OPEN || v.closeBy != "flick") continue;
			if (v.partIndex < 0 || v.partIndex >= card.parts.Size()) continue;
			let part = card.parts[v.partIndex];
			if (heldPart == v.partIndex || DrawnValue(part) <= CloseAt(v))
			{
				verbFlickQuiet[k] = FLICK_GRACE_TICS;
				verbFlickCalm[k]  = false;
				verbFlickLast[k]  = 0.0;
				continue;
			}
			Vector3 flickWorld = WorldDir(part.dof.pivot, FlickAxisModel(v, part));
			if (flickWorld.Length() < 0.000001) continue;
			flickWorld = flickWorld.Unit();
			// Assigned by if/else: `?:` does not take vectors in this compiler.
			Vector3 lin;
			Vector3 ang;
			Vector3 handAt;
			if (hand == 0) { lin = pmo.AttackVel;  ang = pmo.AttackAngularVel;  handAt = pmo.AttackPos; }
			else           { lin = pmo.OffhandVel; ang = pmo.OffhandAngularVel; handAt = pmo.OffhandPos; }
			Vector3 partAt = World(CarriedBy(v.partIndex, part.grabAt));
			double linAlong  = lin dot flickWorld;
			double spinAlong = (ang cross (partAt - handAt)) dot flickWorld;
			double along = linAlong + spinAlong;
			double need = Cvf("wm_flick_speed", 1.5) * Cvf("vr_vunits_per_meter", 34.0) * v.flickScale;
			double mean = (along + verbFlickLast[k]) * 0.5;
			verbFlickLast[k] = along;
			if (verbFlickQuiet[k] > 0) { verbFlickQuiet[k]--; continue; }
			if (!verbFlickCalm[k])
			{
				if (along < need * 0.5) verbFlickCalm[k] = true;
				continue;
			}
			if (mean >= need) FlickShut(pmo, k, mean, linAlong, spinAlong, need);
		}
	}

	// THE WAY A FLICK SHUTS IT, in the gun's model axes: `side` across the gun, signed the way this
	// part shuts (WM_Verb.FlickSideSign); a stated vector; otherwise up.
	private Vector3 FlickAxisModel(WM_Verb v, WM_Part part)
	{
		if (v.flickAxisSide) return (0, WM_Verb.FlickSideSign(part), 0);
		if (v.flickAxis.Length() > 0.5) return v.flickAxis;
		return (0, 0, 1);
	}

	// A FLICK LANDED: the part shuts, with one line saying how hard, and how much was hand and how
	// much wrist, in metres a second.
	private void FlickShut(PlayerPawn pmo, int k, double mean, double linAlong, double spinAlong, double need)
	{
		let v = card.verbs[k];
		let part = card.parts[v.partIndex];
		double drawn = DrawnValue(part);
		double perMetre = max(Cvf("vr_vunits_per_meter", 34.0), 1.0);
		String flickWay = "up";
		if (v.flickAxisSide) flickWay = "sideways";
		else if (v.flickAxis.Length() > 0.5 && v.flickAxis.Z < 0.9999) flickWay = "along its flickaxis";
		String how = String.Format("FLICKED %s at %.1f m/s (needs %.1f: hand %.1f, wrist %.1f)",
			flickWay, mean / perMetre, need / perMetre, linAlong / perMetre, spinAlong / perMetre);
		part.value = 0.0;
		if (IsHeldOpen(k)) SetOpen(pmo, k, false, drawn, how);
		else
		{
			PlaySnd(SlotSound("close", card.closeSound));
			WM_Log.Info(String.Format("%s gun: [verbs] open %s CLOSED %s -- %s -- under the hammer %s; stores %s",
				HandName(), v.id, DrawnText(drawn), how, ammo.UnderHammer(), ammo.StoreCounts()));
		}
		level.VRHaptic(hand, 0.6, 14.0);
		verbFlickQuiet[k] = FLICK_GRACE_TICS;
		verbFlickCalm[k]  = false;
		verbFlickLast[k]  = 0.0;
	}

	// AN EJECT BY TILT (verb.zs, by = tilt | muzzleup): once its gate is open and the gun's named
	// axis points up past `at`, every case falls out -- once a tilt. It re-arms when that axis
	// comes back down past at - 0.15, or the gate shuts. Read off the drawn gun (BarrelWorld,
	// WorldDir), so it is where the gun is, not a guess: a break-top's `tiltaxis = down` rises as
	// the gun turns past its side or over, a swing-out's bore as its muzzle points up.
	// PRESENTATION OF LOCAL INPUT: the drawn gun is the owner's own controller (FEEL_PLAN section 10).
	private void EjectByTilt(PlayerPawn pmo)
	{
		if (!prop || !resolved || stowed || !ammo) return;
		for (int k = 0; k < card.verbs.Size() && k < verbThrown.Size(); k++)
		{
			let v = card.verbs[k];
			if (v.kind != WM_Verb.EJECT || !v.ejectByTilt) continue;
			// `up` is a word this compiler keeps for itself, and a member cannot be read off a
			// call's returned vector -- so the axis first, then its rise.
			Vector3 tilted;
			if (v.tiltAlongBarrel) tilted = BarrelWorld();
			else                   tilted = WorldDir(card.muzzle, v.tiltAxis);
			double rise = tilted.Z;
			if (!LoadGateOpen(v) || rise < v.at - 0.15) { verbThrown[k] = false; continue; }
			if (verbThrown[k] || rise < v.at) continue;
			if (!ammo.SlotHeld(v.fromStore, -1)) continue;
			verbThrown[k] = true;
			String tiltHow;
			if (v.tiltAlongBarrel) tiltHow = String.Format("the muzzle pointed up (%.2f, throws at %.2f)", rise, v.at);
			else                   tiltHow = String.Format("tilted -- its (%.2f, %.2f, %.2f) axis %.2f up, throws at %.2f", v.tiltAxis.X, v.tiltAxis.Y, v.tiltAxis.Z, rise, v.at);
			ThrowOutAll(pmo, k, v.fromStore, GateCarrier(v), tiltHow);
		}
	}

	// IS A SWAP'S CONTAINER IN THE GUN: its named store; the mirror's answer for a
	// gun that has no store by that name.
	bool SwapAttached(WM_Verb v)
	{
		let s = ammo.FindStore(v.storeId);
		if (!s) return ammo.magIn;
		return !s.Detached();
	}

	// ---- IN BATTERY (G16) -----------------------------------------------------------
	//
	// A GUN WITH ITS ACTION OPEN DOES NOT FIRE. "" when every action is closed;
	// otherwise which one is open and where, for the click's log line. Open is: a
	// cycle returned by hand whose part is out past its homeat by the DRAWN value, or
	// whose stroke is still out (ejected, not yet fed); or an open verb that is open.
	//
	// A CYCLE RETURNED BY A SPRING IS NOT ASKED. It is home whenever no hand holds it,
	// and a pistol has always fired with its slide held part-way by the other hand --
	// asking it would change the pistols, which this must not.
	String OutOfBattery()
	{
		if (!card) return "";
		for (int k = 0; k < card.verbs.Size(); k++)
		{
			let v = card.verbs[k];
			if (v.kind == WM_Verb.OPEN)
			{
				// AN OPEN VERB A SECOND BARREL WAITS ON (card.zs WM_Barrel `needs = shut:<id>`)
				// stops only that barrel: a launcher's breech open does not stop the machine gun
				// above it. Asked of that barrel by BarrelOutOfBattery below.
				if (card.OpenStopsOnlyABarrel(k)) continue;
				String openWhy = OpenVerbNotShut(k);
				if (openWhy != "") return openWhy;
				continue;
			}
			if (v.kind != WM_Verb.CYCLE || v.ret == WM_Verb.RET_SPRING) continue;
			if (v.partIndex < 0 || v.partIndex >= card.parts.Size()) continue;
			double drawnAt = DrawnValue(card.parts[v.partIndex]);
			if (drawnAt > HomeAt(v))
				return String.Format("cycle %s's %s is at %.2f, home is %.2f or less", v.id, v.partId, drawnAt, HomeAt(v));
			if (StrokeAt(k) == STROKE_OUT)
				return String.Format("cycle %s's stroke is still out -- bring the %s home to feed", v.id, v.partId);
		}
		return "";
	}

	bool InBattery() { return OutOfBattery() == ""; }

	// ---- HOW FAR BACK STILL COUNTS AS CLOSED, per kind of gun --------------------------------------
	//
	// The owner, 2026-09-13: a pump moved a hair would not fire. wm_feel_<type>_home is how far back a
	// cycle returned by hand (a pump) still counts as HOME; _shut how far open an open verb still counts
	// as SHUT. The larger of it and the card's own homeat / closeat wins, and a part let go inside it goes
	// fully home (WM_System.ReleaseByVerbs). The type is the card's, as its hand seats read it
	// (WM_HandProfile.TypeOf); a type with no set of its own reads the default one.
	// SCRIPT-READ, like every feel threshold (FEEL_PLAN section 10's cvar note).
	// LINT-CVARS: wm_feel_pistol_home wm_feel_pistol_shut wm_feel_shotgun_home wm_feel_shotgun_shut wm_feel_breakaction_home wm_feel_breakaction_shut wm_feel_revolver_home wm_feel_revolver_shut wm_feel_rifle_home wm_feel_rifle_shut wm_feel_smg_home wm_feel_smg_shut wm_feel_chaingun_home wm_feel_chaingun_shut wm_feel_plasma_home wm_feel_plasma_shut wm_feel_launcher_home wm_feel_launcher_shut wm_feel_bfg_home wm_feel_bfg_shut wm_feel_railgun_home wm_feel_railgun_shut wm_feel_flamethrower_home wm_feel_flamethrower_shut wm_feel_chainsaw_home wm_feel_chainsaw_shut wm_feel_default_home wm_feel_default_shut
	double HomeAt(WM_Verb v)  { return max(v.homeAt, FeelThreshold("home")); }
	double CloseAt(WM_Verb v) { return max(v.closeAt, FeelThreshold("shut")); }

	private double FeelThreshold(String which)
	{
		if (!card) return 0.0;
		String kind = WM_HandProfile.TypeOf(card);
		if (kind == "default") kind = WM_HandProfile.UncalibratedReads();
		String feelName = "wm_feel_" .. kind .. "_" .. which;
		if (!CVar.GetCVar(feelName, players[consoleplayer])) feelName = "wm_feel_default_" .. which;
		return clamp(Cvf(feelName, 0.0), 0.0, 0.95);
	}

	// AN OPEN VERB THAT IS NOT SHUT, and where it is, or "" when it is shut. NOT OPEN IS NOT
	// SHUT: a barrel let go of half way, past its closeat, does not fire either.
	private String OpenVerbNotShut(int k)
	{
		if (!card || k < 0 || k >= card.verbs.Size()) return "";
		let v = card.verbs[k];
		if (IsHeldOpen(k)) return String.Format("open %s is open", v.id);
		if (v.partIndex >= 0 && v.partIndex < card.parts.Size())
		{
			double openedTo = DrawnValue(card.parts[v.partIndex]);
			if (openedTo > CloseAt(v))
				return String.Format("open %s's %s is at %.2f, shut is %.2f or less", v.id, v.partId, openedTo, CloseAt(v));
		}
		return "";
	}

	// A SECOND BARREL'S OWN BATTERY (card.zs WM_Barrel `needs = shut:<id>`): "" when the open
	// verb it waits on is shut, or it waits on none.
	String BarrelOutOfBattery(WM_Barrel b)
	{
		if (!card || !b || b.needsShut == "") return "";
		return OpenVerbNotShut(card.FindVerbIndex(b.needsShut));
	}

	// AN ACTION NOTHING WORKS ON THE SHOT: the card has a cycle and none cycles on the
	// shot. Its fired case stays in the chamber until a hand strokes it out. Both
	// pistols' synthesised cycles cycle on the shot, so this is false for them.
	bool ManualAction()
	{
		if (!card) return false;
		bool sawCycle = false;
		for (int k = 0; k < card.verbs.Size(); k++)
		{
			let v = card.verbs[k];
			if (v.kind != WM_Verb.CYCLE) continue;
			if (v.autoOnShot) return false;
			sawCycle = true;
		}
		return sawCycle;
	}

	// ---- LOAD POINTS (verb.zs LOAD) ---------------------------------------------------
	//
	// A point on the gun and an oval about it, in the gun's own axes: `at` in model
	// space, `size` three half-sizes in map units, like a part's grabsize. A round let
	// go of inside the oval goes into the verb's store when there is room, its gate is
	// open and it is the right round. No driven surface: proximity and release.
	//
	// THE DRAWN VOLUME IS THE TESTED VOLUME. LoadPoint and the oval LoadDepth measures
	// are what WM_System.DrawMarkers places and sizes the marker by, and what a release
	// is tested against.
	//
	// ITS OWN SLIDERS, ALL RENDERER-READ, exactly a part's: a load point takes the grab
	// slot after the card's parts (LoadTagIndex), so wm_gp_<m|o><n> is its nudge (a
	// seat set on the marker), _sh_scale_x/y/z its shape and _r its reach as a ball.
	// The grab-point page lists it as "load zone: <id>". Script adds the same numbers
	// to what it tests, as it does for a part. A load point past the eighth slot keeps
	// only the whole-gun offset.

	// wm_verbs on, a drawn gun whose hand is not busy elsewhere, and a card with any.
	// Every pistol answers no: neither card has a load verb.
	bool LoadActive()
	{
		return card && prop && resolved && !stowed && ammo && WM_Verb.Enabled() && card.HasVerbKind(WM_Verb.LOAD);
	}

	// LOAD POINT k's GRAB SLOT: the card's parts take 0 up, and its load points number
	// on after them in verb order. -1 for a verb that is not a load, or past the slots.
	int LoadTagIndex(int k)
	{
		if (!card || k < 0 || k >= card.verbs.Size() || card.verbs[k].kind != WM_Verb.LOAD) return -1;
		int n = card.parts.Size();
		for (int j = 0; j < k; j++)
			if (card.verbs[j].kind == WM_Verb.LOAD) n++;
		return (n < GRAB_SLOTS) ? n : -1;
	}

	// Raw on purpose, as SeatFor wants it: the renderer adds both offsets itself. A zone
	// that `rides` a part is carried by it (CarriedBy) -- a cylinder face tipping down.
	Vector3 LoadPointRaw(int k) { return World(CarriedBy(card.verbs[k].ridesIndex, card.verbs[k].loadAt)); }

	// WHAT A LOAD POINT CAN TAKE AT ALL: one round, or a loader (WM_LooseMag.IsLoader).
	// Which point takes which is LoadWhy's question.
	bool LoadTakes(WM_LooseMag m) { return m && (m.IsRound() || m.IsLoader()); }

	// WHERE IT IS TESTED: the raw point plus the offsets the renderer draws its oval by
	// -- the whole-gun set, and this load point's own nudge.
	Vector3 LoadPoint(int k)
	{
		Vector3 p = LoadPointRaw(k) + TuneWorld();
		int t = LoadTagIndex(k);
		if (t >= 0) p += NudgeWorld(t);
		return p;
	}

	// THE OVAL TESTED: the card's size, or its own reach as a ball, times its own shape
	// multipliers -- GrabAxes' order, without the gun-wide reach override, which is a
	// part's.
	Vector3 LoadAxes(int k)
	{
		Vector3 a = card.verbs[k].loadSize;
		int t = LoadTagIndex(k);
		if (t < 0) return a;
		double own = TuneF(t, "_r", 0);
		if (own > 0.01) a = (own, own, own);
		a.X *= max(0.01, TuneF(t, "_sh_scale_x", 1.0));
		a.Y *= max(0.01, TuneF(t, "_sh_scale_y", 1.0));
		a.Z *= max(0.01, TuneF(t, "_sh_scale_z", 1.0));
		return a;
	}

	// THE OVAL AS HANDED TO THE RENDERER: without the shape multipliers, which the
	// renderer applies itself from the placement set -- DrawAxes' reason.
	Vector3 LoadDrawAxes(int k)
	{
		Vector3 a = LoadAxes(k);
		int t = LoadTagIndex(k);
		if (t < 0) return a;
		a.X /= max(0.01, TuneF(t, "_sh_scale_x", 1.0));
		a.Y /= max(0.01, TuneF(t, "_sh_scale_y", 1.0));
		a.Z /= max(0.01, TuneF(t, "_sh_scale_z", 1.0));
		return a;
	}

	// GrabDepth's own measure, over the load oval: 1.0 on its surface, less inside.
	double LoadDepth(int k, Vector3 at)
	{
		Vector3 a = LoadAxes(k);
		Vector3 d = at - LoadPoint(k);
		Vector3 org, ax, ay, az;
		[org, ax, ay, az] = FrameBasis();
		if (ax.Length() < 1e-6) return d.Length() / max(0.01, a.X);
		double x = (d dot ax.Unit()) / max(0.01, a.X);
		double y = (d dot ay.Unit()) / max(0.01, a.Y);
		double z = (d dot az.Unit()) / max(0.01, a.Z);
		return sqrt(x * x + y * y + z * z);
	}

	// The load point a hand at `at` is deepest inside, as an index into card.verbs; -1.
	int LoadVerbAt(Vector3 at)
	{
		if (!card) return -1;
		int best = -1;
		double bestDepth = 1.0;
		for (int k = 0; k < card.verbs.Size(); k++)
		{
			let v = card.verbs[k];
			if (v.kind != WM_Verb.LOAD) continue;
			double depth = LoadDepth(k, at);
			if (depth <= bestDepth) { bestDepth = depth; best = k; }
		}
		return best;
	}

	bool LoadGateOpen(WM_Verb v)
	{
		if (v.needsOpen == "") return true;
		return IsHeldOpen(card.FindVerbIndex(v.needsOpen));
	}

	// THE LATCH A VERB WAITS ON IS THROWN (verb.zs latch / latchat, F3): its part drawn at or past
	// latchat of its own travel. True for a verb with no latch -- every verb before F3.
	bool LatchThrown(WM_Verb v)
	{
		if (!card || !v || v.latchIndex < 0 || v.latchIndex >= card.parts.Size()) return true;
		if (DrawnValue(card.parts[v.latchIndex]) >= v.latchAt) return true;
		// A SPRING LATCH (latchreturn = spring) counts as thrown for a grace after it last was.
		if (!v.latchReturnSpring) return false;
		int k = card.FindVerbIndex(v.id);
		return k >= 0 && k < verbLatchTic.Size() && level.maptime - verbLatchTic[k] <= WM_Verb.LATCH_GRACE_TICS;
	}

	// THE LAST TIC EACH VERB'S LATCH WAS THROWN, for a spring latch's grace (LatchThrown). Once a tic.
	private void LatchesTick()
	{
		if (!card) return;
		int n = card.verbs.Size();
		if (verbLatchTic.Size() != n)
		{
			verbLatchTic.Resize(n);
			for (int k = 0; k < n; k++) verbLatchTic[k] = -1000;
		}
		for (int k = 0; k < n; k++)
		{
			let v = card.verbs[k];
			if (v.latchIndex < 0 || v.latchIndex >= card.parts.Size()) continue;
			if (DrawnValue(card.parts[v.latchIndex]) >= v.latchAt) verbLatchTic[k] = level.maptime;
		}
	}

	// A PART LOCKED BY ITS VERB'S LATCH: the latch not thrown and the part at home. Once off home -- a
	// break action swung open, a can half out -- it stays free until it comes home again.
	bool LatchLocks(int partIndex)
	{
		if (!card || partIndex < 0 || partIndex >= card.parts.Size()) return false;
		int k = card.VerbIndexForPart(partIndex);
		if (k < 0) return false;
		let v = card.verbs[k];
		if (v.latchIndex < 0 || LatchThrown(v)) return false;
		return DrawnValue(card.parts[partIndex]) <= 0.02;
	}

	// WHY THIS ROUND WILL NOT GO IN AT THIS LOAD POINT, or "" when it will. As specific
	// as WM_System.SeatRefusal, for the same reason: it is all someone in a headset
	// learns about why nothing happened.
	String LoadWhy(WM_Verb v, WM_LooseMag m)
	{
		if (!m) return "nothing in this hand";
		if (!card || !ammo) return "that gun is not ready";
		// A LOADER ZONE (subject = loader) takes a loader, or one round at a time; any other
		// zone takes only its one round, exactly as before.
		bool loaderZone = (v.subject == "loader");
		String subj = (m.wmSubject == "") ? "round" : m.wmSubject;
		if (m.IsLoader())
		{
			if (!loaderZone)
				return String.Format("that is a loader -- load %s takes one %s at a time", v.id, (v.subject == "") ? "round" : v.subject);
			if (m.Amount <= 0) return "that loader is empty";
		}
		else
		{
			if (!m.IsRound()) return "that is a magazine -- a load point takes one round at a time";
			if (loaderZone)
			{
				if (!(subj ~== "round")) return String.Format("that is a %s -- load %s takes a loader or a round", subj, v.id);
			}
			else if (v.subject != "" && !(subj ~== v.subject))
				return String.Format("that is a %s -- load %s takes a %s", subj, v.id, v.subject);
		}
		if (!(m.magFamily ~== card.FamilyOfMags()))
			return String.Format("that %s is %s -- the %s takes %s", subj, (m.magFamily == "") ? "of no family" : m.magFamily,
				card.weaponClass, card.FamilyOfMags());
		if (!LoadGateOpen(v)) return String.Format("the gate is shut -- open %s first", v.needsOpen);
		return ammo.LoadRefusal(v.intoStore, v.slot, v.slotNext);
	}

	// ONE ROUND, LET GO OF AT LOAD POINT k. True when it went in, and then the round is
	// gone. Every attempt says which, why, and what the stores hold after.
	bool LoadFrom(int k, WM_LooseMag m, int workHand, String how)
	{
		if (!card || !ammo || !m || k < 0 || k >= card.verbs.Size()) return false;
		let v = card.verbs[k];
		String why = LoadWhy(v, m);
		if (why == "" && m.IsLoader()) return LoadFromLoader(k, m, workHand, how);
		if (why == "" && !ammo.LoadRound(v.intoStore, v.slot, v.slotNext))
			why = String.Format("%s would not take it", v.intoStore);
		if (why != "")
		{
			WM_Log.Info(String.Format("%s gun: [verbs] load %s REFUSED %s -- %s; stores %s", HandName(), v.id, how, why, ammo.StoreCounts()));
			return false;
		}
		String subj = (m.wmSubject == "") ? "round" : m.wmSubject;
		m.Destroy();
		PlaySnd(SlotSound("load", card.loadSound));
		level.VRHaptic(workHand, 0.5, 12.0);
		WM_Log.Info(String.Format("%s gun: [verbs] load %s ACCEPTED %s -- one %s into %s; stores now %s",
			HandName(), v.id, how, subj, v.intoStore, ammo.StoreCounts()));
		return true;
	}

	// A LOADER, LET GO OF AT LOAD POINT k: every round it holds that the store has an empty
	// slot for goes in at once, in slot order. True when any went. The loader is left for
	// the caller to drop -- rounds still in it, or empty and wm_loader_spent_drops on --
	// or destroyed here when it is empty and that cvar is off.
	private bool LoadFromLoader(int k, WM_LooseMag m, int workHand, String how)
	{
		let v = card.verbs[k];
		int had = m.Amount;
		int went = 0;
		while (m.Amount > 0 && ammo.LoadRound(v.intoStore, v.slot, v.slotNext))
		{
			m.Amount--;
			went++;
		}
		if (went <= 0)
		{
			WM_Log.Info(String.Format("%s gun: [verbs] load %s REFUSED %s -- %s would not take a round from the loader; stores %s",
				HandName(), v.id, how, v.intoStore, ammo.StoreCounts()));
			return false;
		}
		m.Recolour();
		PlaySnd(SlotSound("load", card.loadSound));
		level.VRHaptic(workHand, 0.6, 14.0);
		String after;
		if (m.Amount > 0) after = String.Format("%d left in the loader", m.Amount);
		else if (Cvb("wm_loader_spent_drops", true)) after = "the loader is empty and drops";
		else
		{
			after = "the loader is empty and gone";
			m.Destroy();
		}
		WM_Log.Info(String.Format("%s gun: [verbs] load %s ACCEPTED %s -- LOADED %d of %d from a loader into %s, %s; stores now %s",
			HandName(), v.id, how, went, had, v.intoStore, after, ammo.StoreCounts()));
		return true;
	}

	// EVERY LOAD POINT, WHERE IT IS AND WHAT IT WOULD SAY, for netevent wm_dump.
	private void DumpLoads(int workHand, Vector3 workPos)
	{
		for (int k = 0; k < card.verbs.Size(); k++)
		{
			let v = card.verbs[k];
			if (v.kind != WM_Verb.LOAD) continue;
			String room = ammo.LoadRefusal(v.intoStore, v.slot, v.slotNext);
			if (room == "") room = "room for one";
			if (!prop)
			{
				WM_Log.Info(String.Format("  load [%d] %s -- into %s%s: %s, gate %s (no gun drawn)", k, v.id, v.intoStore, SlotText(v),
					room, LoadGateOpen(v) ? "open" : "SHUT"));
				continue;
			}
			Vector3 at = LoadPoint(k);
			double depth = LoadDepth(k, workPos);
			WM_Log.Info(String.Format("  load [%d] %s -- into %s%s: %s, gate %s, point %s, oval %s, %s hand %.1f away, depth %.2f%s",
				k, v.id, v.intoStore, SlotText(v), room, LoadGateOpen(v) ? "open" : "SHUT", WM_Log.Vec(at), WM_Log.Vec(LoadAxes(k)),
				(workHand == 0) ? "main" : "off", (workPos - at).Length(), depth, (depth <= 1.0) ? "  <- IN THE OVAL" : ""));
		}
	}

	// EVERY VERB AND WHAT IT IS DOING NOW, for netevent wm_dump.
	private void DumpVerbs()
	{
		int n = card.verbs.Size();
		WM_Log.Info(String.Format("  verbs %d, path %s", n, WM_Verb.Enabled() ? "VERBS (wm_verbs on)" : "OLD (wm_verbs off)"));
		double liveSeat = Cvf("wm_seat_at", 0.25);
		for (int k = 0; k < n; k++)
		{
			let v = card.verbs[k];
			String live = "no live state";
			if (v.kind == WM_Verb.CYCLE)
			{
				live = String.Format("clock %d, stroke %s", (k < verbTics.Size()) ? verbTics[k] : 0,
					(StrokeAt(k) == STROKE_OUT) ? "OUT" : "home");
				if (v.holdOpenWhenEmpty) live = live .. (ammo.actionLock ? ", HELD OPEN" : ", not held open");
				if (v.ret == WM_Verb.RET_STAY) live = live .. (IsHeldOpen(k) ? ", STAYED OPEN" : ", closed");
			}
			else if (v.kind == WM_Verb.OPEN)
			{
				double openedTo = 0.0;
				if (v.partIndex >= 0 && v.partIndex < card.parts.Size()) openedTo = DrawnValue(card.parts[v.partIndex]);
				String openWord = "shut";
				if (IsHeldOpen(k)) openWord = "OPEN";
				else if (openedTo > CloseAt(v)) openWord = "part-open, NOT shut";
				live = String.Format("%s, part at %.2f", openWord, openedTo);
			}
			else if (v.kind == WM_Verb.EJECT)
				live = String.Format("%s, gate %s", EjectThrown(k) ? "has thrown (re-arms on the way back)" : "armed",
					LoadGateOpen(v) ? "open" : "SHUT");
			else if (v.kind == WM_Verb.SWAP) live = SwapAttached(v) ? "container in" : "container OUT";
			else if (v.kind == WM_Verb.LOAD)
				live = String.Format("%s, gate %s", (ammo.LoadRefusal(v.intoStore, v.slot, v.slotNext) == "") ? "room for one" : "no room",
					LoadGateOpen(v) ? "open" : "SHUT");
			WM_Log.Info(String.Format("  verb [%d] %s -- NOW %s  (%s)", k, v.Describe(liveSeat), live, v.OriginText()));
		}
		WM_Log.Info(String.Format("  this hold: pulled past outat %s, apex reached %s", WM_Log.YesNo(pastBack), WM_Log.YesNo(atApex)));
	}

	void Dump(PlayerPawn pmo, int workHand, Vector3 workPos)
	{
		if (!card) { WM_Log.Info(String.Format("%s hand: no carded gun", HandName())); return; }
		WM_Log.Info(String.Format("%s gun %s  prop %s  resolved %s  %s",
			HandName(), card.weaponClass, prop ? "yes" : "NO",
			WM_Log.YesNo(resolved), stowed ? "PUT AWAY (hand busy)" : "in hand"));
		if (prop && prop.GetModelSurfaceCount(0) == 0)
			WM_Log.Err("its mesh bound NOTHING -- the MODELDEF block or the .md3 is missing.");
		WM_Log.Info(String.Format("  ammo %d in mag, %s, magazine %s, action %s (total %d)",
			ammo.rounds, card.FiresFromMagazine() ? "no chamber (fires from the magazine)" : (ammo.chambered ? "ONE CHAMBERED" : "chamber empty"),
			ammo.magIn ? "seated" : "OUT", ammo.actionLock ? "LOCKED BACK" : "closed", ammo.Total()));
		WM_Log.Info(String.Format("  stores: %s", ammo.StoreCounts()));
		WM_Log.Info(String.Format("  shot: %s", GunShotText()));
		String battery = OutOfBattery();
		if (battery != "") WM_Log.Info("  OUT OF BATTERY -- " .. battery);
		WM_Log.Info(String.Format("  hammer %s, held part %d", hammerCocked ? "cocked" : "down", heldPart));
		DumpVerbs();
		DumpLoads(workHand, workPos);
		if (!prop) return;
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let part = card.parts[i];
			bool reach = card.PartIsWorkable(i);
			if (reach)
			{
				Vector3 at = PartPoint(i);
				double d = (workPos - at).Length();
				Vector3 a = GrabAxes(i, part);
				bool inside = HandInGrab(i, part, workPos);
				WM_Log.Info(String.Format("  [%d] %-9s %-8s value %.3f  %s  %s hand %.1f away (oval %.1f x %.1f x %.1f)%s",
					i, part.id, part.role, part.value, part.present ? "in" : "OUT",
					workHand == 0 ? "main" : "off", d, a.X, a.Y, a.Z, inside ? "  <- IN REACH" : ""));
			}
			else
			{
				WM_Log.Info(String.Format("  [%d] %-9s %-8s value %.3f", i, part.id, part.role, part.value));
			}
		}
	}
}
