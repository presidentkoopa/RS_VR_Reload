// ============================================================================
// THE SYSTEM. Reads every card, puts a gun in each hand, and lets each hand
// work the OTHER hand's gun.
//
// NOTHING IN THIS FILE NAMES A GUN. Which weapon goes in which hand is the
// card's `hand` line; what a part does is its `role`. If a third gun needed a
// line added here, the design would have failed.
//
// ------------------------------------------------------------ THE HANDS
//
// Hand h holds gun h and works gun 1-h. You cannot rack a slide with a hand
// that is holding a pistol, so while a hand is working the other gun -- on its
// slide, its magazine, under its grip, or carrying a magazine for it -- its own
// gun is put away, and comes back the moment the hand is free.
//
// ------------------------------------------------ THE HAND IS NOT OURS BY DEFAULT
//
// RS_WorldHands does the catching, the pulling and the passing, and it stands
// a hand down completely -- no near grab, no cone, no catch -- whenever that
// hand's grip subject says it is reloading. So this system publishes a subject
// ONLY while it actually has the hand: holding a part, carrying or seating a
// magazine, or bracing. Never for hovering near a part, never for being near
// the pouch. It used to, and with a gun in each hand held close together that
// was nearly always -- which is how a pulled barrel came to fly straight into
// you instead of into your hand.
//
// ------------------------------------------------------------ THE RELOAD
//
//   drop    the drop-mag button of the hand HOLDING the gun, or take hold of
//           the magazine and pull it out -- then it is in your hand
//   carry   drop it (open your hand), throw it (open it moving), or open your
//           hand inside the pouch and it goes back in, rounds and all
//   draw    squeeze inside the pouch: a fresh magazine for the gun that hand
//           works, drawn from your reserve
//   seat    bring it to the mouth of the well and push -- glued to your hand at
//           draw rate -- until the catch takes it
//   rack    take the slide, pull it back, let go. On a locked-back gun that
//           chambers; on a loaded one it throws the chambered round out
//   load    a gun with load points (a pump's tube, wm_verbs on): bring ONE round
//           -- off the floor, out of the air, or the one the pouch hands you --
//           into a load point's oval and open your hand
//
// One in the chamber survives a magazine change, so a gun reloaded before it
// ran dry needs no rack at all.
//
// ------------------------------------------------------ WHAT DECIDES A RACK
//
// wm_verbs, for this build. On: the card's verbs (verb.zs) -- HoldByVerbs,
// ReleaseByVerbs, and the swap's seat in Guide. Off: Hold, Release and
// rig.Racked, the old role code, exactly as they were, reached through
// HoldOldPath, which only adds a log line. A card that declares no verbs has
// the old behaviour synthesised as verbs, so the two paths must feel the same;
// the switch is there so that claim is tested in the headset rather than
// trusted. Every rack, release and seat logs which path ran it.
// ============================================================================

class WM_System : EventHandler
{
	private WM_CardSet set;

	// EVERY PLAYER'S HANDS, one container per player slot, made the first time
	// it is asked for (hand.zs). What each hand is doing, the gun in it, and
	// every per-hand scratch value live there -- nothing per hand is kept on
	// the system itself. Only the console player's is ever worked today;
	// making this multiplayer is a loop over these, not a rewrite.
	private WM_PlayerHands perPlayer[MAXPLAYERS];

	WM_PlayerHands ForPlayer(int pn)
	{
		if (pn < 0 || pn >= MAXPLAYERS) return null;
		if (!perPlayer[pn])
		{
			perPlayer[pn] = new("WM_PlayerHands");
			perPlayer[pn].Init(pn);
		}
		perPlayer[pn].Ensure();
		return perPlayer[pn];
	}

	private Array<WM_Marker> markers;
	private int markerUsed;

	// One breathing copy per part per gun, kept alive and drawn only while its
	// gate cvar is on -- see WM_Marker.MarkSelected and menu.zs.
	const SEL_PER_GUN = 8;
	private WM_Marker selMark[16];
	private String    selNamed[16];
	// THE GRAB TUNING A BAKE CARRIES (wm_bake_ofs / wm_bake_shape), until its wm_bake_go (BakePrint).
	private Vector3   bakeOfs, bakeShape;

	// ---- placement mode, for the ammo pouches ------------------------------
	//
	// RS_VRBody's placement mode and its two grab keys, borrowed rather than
	// duplicated: a netevent reaches every handler, so the same keys that used
	// to move body parts move the pouch here. The body no longer picks its own
	// parts up by default, so one mode moves one thing and holster symmetry is
	// left alone (rs_body_place_parts, RS_VRBody).
	//
	// The mode and which pouch each hand is dragging are the player's
	// (WM_PlayerHands.placeMode / placingSite).

	private Service arbiter;
	private int     arbWait;
	private bool    arbWarned;

	private Array<String> spoken;
	private bool toldOnce;

	// The live readout, composed in the playsim and drawn by RenderOverlay.
	const HUD_MAX = 24;
	private String hudLine[HUD_MAX];
	private int    hudColor[HUD_MAX];
	private int    hudCount;

	// ---- small things -------------------------------------------------------

	private double Cvf(String n, double d)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetFloat() : d;
	}
	private bool Cvb(String n, bool d)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetBool() : d;
	}

	private int Cvi(String n, int d)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetInt() : d;
	}
	private void CvSetS(String n, String v)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		if (c && c.GetString() != v) c.SetString(v);
	}

	// BRACING IS OFF until it is taken on. Not only its oval: the whole thing.
	// Hiding the oval alone left an open hand near the support point still
	// "bracing" -- pinned there, claiming the grip as a support hand, and marking
	// the hand busy so its own gun was put away -- all of it invisible. Two-handed
	// bracing has never been seen to work in this system, so nothing of it runs
	// unless this is turned on.
	private bool BraceOn() { return Cvb("wm_brace", false); }

	// The last palm-to-gun reading per hand, for the HUD: 1 is the palm square to
	// the gun's up or down, 0 is sideways. A take needs at least wm_palm_cos.
	// Kept per hand on the player's container (WM_PlayerHands.palmFacing).

	private Vector3 HandPos(PlayerPawn pmo, int h) { return h == 0 ? pmo.AttackPos : pmo.OffhandPos; }
	private bool    GripHeld(PlayerPawn pmo, int h) { return h == 0 ? pmo.GripHeldMain : pmo.GripHeldOff; }
	private int     GetClaim(PlayerPawn pmo, int h) { return h == 0 ? pmo.GripClaimMain : pmo.GripClaimOff; }
	private void    SetClaim(PlayerPawn pmo, int h, int v) { if (h == 0) pmo.GripClaimMain = v; else pmo.GripClaimOff = v; }
	private String  HandName(int h) { return h == 0 ? "main" : "off"; }

	static double DistToSegment(Vector3 p, Vector3 a, Vector3 b)
	{
		Vector3 ab = b - a;
		double l2 = ab dot ab;
		double t = (l2 > 1e-9) ? clamp(((p - a) dot ab) / l2, 0.0, 1.0) : 0.0;
		return (p - (a + ab * t)).Length();
	}

	// RS_WorldHands' own rule for what a fist is: a class with "fist" in its
	// name. Asked by name, because naming its class would tie this package to
	// that one at compile time.
	static bool IsFistWeapon(Weapon w)
	{
		if (!w) return false;
		String n = w.GetClassName();
		n = n.MakeLower();
		return n.IndexOf("fist") >= 0;
	}

	// The said-once ledger for WM_Log.Once. Cleared every map, so a fixed
	// problem stops being quiet about itself the moment you reload.
	bool AlreadySaid(String key)
	{
		if (spoken.Find(key) != spoken.Size()) return true;
		spoken.Push(key);
		return false;
	}

	// A card whose gun fires this ammunition, or null. Asked by
	// WM_GrabBecomeService, deciding whether a clip in a hand is a magazine for
	// one of our guns.
	WM_Card CardForAmmo(Class<Ammo> ammo)
	{
		if (!set || !ammo) return null;
		for (int i = 0; i < set.cards.Size(); i++)
		{
			// A GUN WITH NO MAGAZINE (no swap verb -- a pump's tube) has none for a clip to
			// become: a shell picked up stays a shell. Both pistols have a swap.
			if (!set.cards[i].HasVerbKind(WM_Verb.SWAP)) continue;
			Class<Weapon> wc = (Class<Weapon>)(Object.FindClass(set.cards[i].weaponClass, "Weapon"));
			if (!wc) continue;
			let def = GetDefaultByType(wc);
			if (def.AmmoType1 && def.AmmoType1 == ammo) return set.cards[i];
		}
		return null;
	}

	// THE CARD OF A WEAPON CLASS, or null -- by class, not through a rig, so it does
	// not depend on which player's hands are worked here. (The shot is no longer
	// on the card: WM_Gun reads its own ShotPellets / ShotSpread / ShotDamage.)
	WM_Card CardForWeapon(String weaponClass)
	{
		if (!set) return null;
		for (int i = 0; i < set.cards.Size(); i++)
			if (set.cards[i].weaponClass ~== weaponClass) return set.cards[i];
		return null;
	}

	// A GUN TAKES ITS WEAPON SHEET (sheet.zs): its shot fields set back to its class's Default, then the sheet
	// laid over them. Called at WorldLoaded for every gun in the level and from WM_Gun.PostBeginPlay for a gun
	// made after -- both playsim, alike on every machine. Never from a rebind, which is the console player's
	// only. Before the cards are loaded it does nothing, and WorldLoaded reaches that gun.
	void ApplySheet(WM_Gun g)
	{
		if (!g || !set) return;
		g.TakeSheet(set.SheetFor(g.GetClassName()));
	}

	private void ApplySheetsToAllGuns()
	{
		if (!set) return;
		let it = ThinkerIterator.Create("WM_Gun");
		Thinker t = it.Next();
		while (t)
		{
			let g = WM_Gun(t);
			if (g) ApplySheet(g);
			t = it.Next();
		}
	}

	// ---- what the weapons ask ------------------------------------------------

	// THE CHAMBER DECIDES, and a gun that is put away does not fire.
	//
	// ASKED FOR THE FIRING WEAPON'S OWNER (pn, from WM_Gun.WM_TryFire), never the
	// console player. The fire action runs on every machine in a netgame; answering
	// from the console player's chamber made player 2's trigger read player 1's gun.
	// In single player the owner IS the console player, so nothing changes there.
	//
	// ONLY THE CONSOLE PLAYER'S HANDS ARE WORKED TODAY (WorldTick), so on a machine
	// that is not the shooter's there is no container, or one with no bound gun, and
	// the answer is "cannot fire" -- said once, never a null. That is NOT netplay
	// safety yet: the shooter's own machine still fires. The fix is working every
	// player's hands on every machine; borrowing the wrong chamber was never it.
	// Never MADE here (ForPlayer makes one): a question must not create state.
	private WM_PlayerHands HandsIfAny(int pn)
	{
		if (pn < 0 || pn >= MAXPLAYERS) return null;
		return perPlayer[pn];
	}

	// chambers: the most chambers the firing class's pull may fire (WM_Gun.ChambersPerPull),
	// 1 for every class that says nothing -- which asks exactly what this always asked.
	// rounds: what one pull spends from a gun with no chamber (WM_Card.FIRES_MAGAZINE) -- 1
	// for every class that says nothing. A chamber gun fires chambers and never reads it.
	// asking: the gun whose trigger was pulled. Given, a hand whose rig is still bound to a DIFFERENT gun
	// refuses -- a gun put in the hand since the system last bound one is never answered by the gun that
	// was there before (P_PlayerThink fires before WorldTick binds; see PutGunInHand). null (unset) asks
	// exactly as it always did.
	bool CanFire(int pn, int h, int chambers = 1, int rounds = 1, Weapon asking = null)
	{
		let ph = HandsIfAny(pn);
		if (!ph)
		{
			WM_Log.Once(WM_Log.LV_WARN, String.Format("fire:nohands:%d", pn), String.Format(
				"player %d pulled a carded trigger, but this machine works no hands for that player -- the shot is refused here",
				pn));
			return false;
		}
		if (h < 0 || h > 1 || !ph.rigs[h]) return false;
		let rig = ph.rigs[h];
		if (asking && rig.gunItem && rig.gunItem != asking) return false;
		if (!rig.card || !rig.prop || !rig.ammo || rig.stowed) return false;
		// TWO-HANDED (card `hands = 2`): only while the other hand holds this gun's support grip.
		if (rig.card.NeedsTwoHands() && !SupportHeld(ph, h, rig)) return false;
		// A GUN WITH AN ENGINE (verb.zs START) fires only while it runs: its ripcord first.
		if (rig.card.HasVerbKind(WM_Verb.START) && !rig.ammo.engineRunning) return false;
		// A GUN WITH NO CHAMBER (WM_Card.firesFrom), on either wm_verbs path: one that fires
		// on nothing always may; one that fires from the reserve while the owner's reserve can
		// pay for the pull; one that fires from its magazine while the magazine can.
		// A PULL THAT FIRES SEVERAL CHAMBERS (wm_verbs on) fires while ANY of them is live:
		// a double with one barrel spent still fires the other. Every other pull asks the
		// selected chamber, as it always has.
		bool loaded;
		if (rig.card.firesFrom == WM_Card.FIRES_NOTHING) loaded = true;
		else if (rig.card.firesFrom == WM_Card.FIRES_RESERVE) loaded = ReserveHolds(pn, rig.card, rounds);
		else if (rig.card.FiresFromMagazine()) loaded = rig.ammo.MagazineHolds(rounds);
		else if (chambers > 1 && WM_Verb.Enabled()) loaded = (rig.ammo.LiveChambers() > 0 && !rig.ammo.actionLock);
		else loaded = rig.ammo.CanFire();
		// IN BATTERY (G16, wm_verbs on): not with an action open -- a forend part-way
		// back, a stroke ejected and not yet fed, an open verb open. A pistol's slide is
		// spring-returned and never asked (WM_Rig.OutOfBattery), so both fire as before.
		return loaded && (!WM_Verb.Enabled() || rig.InBattery());
	}

	// CAN THE OWNER'S RESERVE PAY FOR A PULL (WM_Card.FIRES_RESERVE): the gun class's
	// Weapon.AmmoType1 in that player's own inventory -- keyed by pn, never the console
	// player -- at least n of it, or infinite ammo (Weapon.DepleteAmmo's own test).
	private bool ReserveHolds(int pn, WM_Card card, int n)
	{
		if (pn < 0 || pn >= MAXPLAYERS || !playeringame[pn] || !players[pn].mo) return false;
		let owner = players[pn].mo;
		if (sv_infiniteammo || owner.FindInventory("PowerInfiniteAmmo", true) != null) return true;
		let inv = owner.FindInventory(WM_LooseMag.ReserveFor(card.weaponClass));
		return inv != null && inv.Amount >= max(n, 1);
	}

	// THE OTHER HAND IS ON THIS GUN'S SUPPORT GRIP (card `hands = 2`). Hand 1-h works gun h,
	// so the part it holds indexes this gun's card. This is local hand input -- see
	// FEEL_PLAN.md section 10 and Engine docs/NETWORK_HAND_INPUT_PLAN.md.
	private bool SupportHeld(WM_PlayerHands ph, int h, WM_Rig rig)
	{
		if (!ph || !rig || !rig.card || h < 0 || h > 1 || !ph.hstate[1 - h]) return false;
		int heldIdx = ph.hstate[1 - h].HeldPart();
		return heldIdx >= 0 && heldIdx < rig.card.parts.Size() && rig.card.parts[heldIdx].role == "support";
	}

	// WHAT A PULL OF THIS WEAPON CLASS SPENDS (WM_Card.firesFrom), by class. The card set is
	// read on every machine (WorldLoaded), so the fire action may ask it on any of them.
	// FIRES_CHAMBER for a class with no card.
	int FiresFrom(String weaponClass)
	{
		let c = CardForWeapon(weaponClass);
		return c ? c.firesFrom : WM_Card.FIRES_CHAMBER;
	}

	// ---- A SECOND BARREL (card `barrel <id>`, card.zs WM_Barrel) ----------------------------
	//
	// Asked by WM_Gun's AltFire state, on every machine, for the weapon's OWNER by player
	// number -- the same shape as CanFire, OnShot and OnDry are for the main barrel.

	// The barrel this weapon class's second button fires, or null. Card data.
	WM_Barrel AltBarrelFor(String weaponClass)
	{
		let c = CardForWeapon(weaponClass);
		return c ? c.AltBarrel() : null;
	}

	// CAN THE SECOND BARREL FIRE: the gun drawn in this hand, both hands on a two-handed gun, a
	// live round in the barrel's store, and (wm_verbs on) the open verb it waits on shut.
	// asking: as CanFire's -- a rig still bound to a different gun refuses; null asks as always.
	bool CanAltFire(int pn, int h, Weapon asking = null)
	{
		let ph = HandsIfAny(pn);
		if (!ph || h < 0 || h > 1 || !ph.rigs[h]) return false;
		let rig = ph.rigs[h];
		if (asking && rig.gunItem && rig.gunItem != asking) return false;
		if (!rig.card || !rig.prop || !rig.ammo || rig.stowed) return false;
		let b = rig.card.AltBarrel();
		if (!b) return false;
		if (rig.card.NeedsTwoHands() && !SupportHeld(ph, h, rig)) return false;
		return rig.ammo.BarrelLoaded(b.fromStore) && (!WM_Verb.Enabled() || rig.BarrelOutOfBattery(b) == "");
	}

	void OnAltShot(int pn, int h)
	{
		let ph = HandsIfAny(pn);
		if (h < 0 || h > 1 || !ph || !ph.rigs[h] || !ph.rigs[h].card) return;
		let b = ph.rigs[h].card.AltBarrel();
		if (!b) return;
		ph.lastShotTic  = level.maptime;
		ph.lastShotHand = h;
		let pmo = PlayerPawn(players[pn].mo);
		if (pmo) ph.rigs[h].OnBarrelShot(pmo, b);
	}

	void OnAltDry(int pn, int h)
	{
		let ph = HandsIfAny(pn);
		if (h < 0 || h > 1 || !ph || !ph.rigs[h] || !ph.rigs[h].card) return;
		let rig = ph.rigs[h];
		let b = rig.card.AltBarrel();
		if (!b) return;
		rig.OnBarrelDry(b, rig.card.NeedsTwoHands() && !SupportHeld(ph, h, rig));
	}

	// THE RIG DRAWING THIS GUN, or null: the weapon's owner's hands, the hand the gun is in, and
	// only if that rig is bound to this very weapon. For WM_Gun's effect helpers
	// (CardPointToWorld and friends), which are presentation only.
	WM_Rig RigForGun(Weapon w)
	{
		let g = WM_Gun(w);
		if (!g || !g.Owner || !g.Owner.player) return null;
		let ph = HandsIfAny(g.Owner.PlayerNumber());
		int gunHand = g.Hand();
		if (!ph || !ph.rigs[gunHand] || ph.rigs[gunHand].gunItem != w) return null;
		return ph.rigs[gunHand];
	}

	// HOW MANY CHAMBERS A PULL THAT MAY FIRE `most` WILL FIRE: the live ones, at least 1
	// (CanFire has already said yes), at most `most`. 1 whenever most is 1 or wm_verbs is
	// off -- the old path fires one round a pull whatever the class says.
	int ChambersToFire(int pn, int h, int most)
	{
		if (most <= 1 || !WM_Verb.Enabled()) return 1;
		let ph = HandsIfAny(pn);
		if (!ph || h < 0 || h > 1 || !ph.rigs[h] || !ph.rigs[h].ammo) return 1;
		return clamp(ph.rigs[h].ammo.LiveChambers(), 1, most);
	}

	// rounds: what the pull spends from a gun with no chamber (see CanFire).
	void OnShot(int pn, int h, int chambers = 1, int rounds = 1)
	{
		let ph = HandsIfAny(pn);
		if (h < 0 || h > 1 || !ph || !ph.rigs[h] || !ph.rigs[h].card) return;
		ph.lastShotTic  = level.maptime;
		ph.lastShotHand = h;
		let pmo = PlayerPawn(players[pn].mo);
		if (pmo) ph.rigs[h].OnShot(pmo, chambers, rounds);
	}

	void OnDry(int pn, int h, int rounds = 1)
	{
		let ph = HandsIfAny(pn);
		if (h < 0 || h > 1 || !ph || !ph.rigs[h] || !ph.rigs[h].card) return;
		// TWO-HANDED AND UNHELD (card `hands = 2`): the rig says that click's reason.
		let dryRig = ph.rigs[h];
		dryRig.OnDry(rounds, dryRig.card.NeedsTwoHands() && !SupportHeld(ph, h, dryRig));
	}

	// A CHARGE STARTING (WM_Gun.ChargeTics): the charge sound at the gun and one log line.
	// Presentation only, like the fire sound; the shot is still WM_TryFire's.
	void OnCharge(int pn, int h, String snd, int tics)
	{
		let ph = HandsIfAny(pn);
		if (h < 0 || h > 1 || !ph || !ph.rigs[h] || !ph.rigs[h].card) return;
		ph.rigs[h].OnCharge(snd, tics);
	}

	// ---- loading ---------------------------------------------------------------

	override void WorldLoaded(WorldEvent e)
	{
		spoken.Clear();
		toldOnce = false;
		LoadCards();
		ApplySheetsToAllGuns();

		let ph = ForPlayer(consoleplayer);   // makes both rigs if they are not there yet
		for (int h = 0; h < 2; h++)
		{
			// A NEW MAP. The old level's actors are gone; the guns and what is
			// in them are not -- they travel with you. So only the drawn prop is
			// forgotten, and it is spawned again on the first tic. A prop made on THIS map before now -- a
			// PutGunInHand in PlayerSpawned, which the engine fires before WorldLoaded -- is still standing, so it
			// is destroyed rather than only forgotten, or it would stay drawn in the hand beside the new one.
			let rig = ph.rigs[h];
			if (rig.prop) rig.prop.Destroy();
			rig.prop = null;
			rig.resolved = false;
			rig.heldPart = -1;
			rig.stowed = false;
			rig.lastFlash = null;
			if (rig.card)
				for (int i = 0; i < rig.card.parts.Size(); i++)
					rig.card.parts[i].driveSlot = -1;

			ph.hstate[h].Clear();
			ph.lastForeign[h] = null;
			ph.handActors[h] = null;
			ph.bonesAsked[h] = false;
			ph.pinned[h] = false;
			ph.lastReach[h] = -1;
		}
		markers.Clear();
	}

	// THE GUNS GO IN FIRST. For a second after you spawn, each carded gun is put
	// in its hand even if a fist got there first -- RS_WorldHands hands out its
	// fists at spawn, and a fist already in a hand used to mean that hand's gun
	// never appeared. After that the hands are yours.
	override void PlayerSpawned(PlayerEvent e)
	{
		if (e.PlayerNumber == consoleplayer)
		{
			let ph = ForPlayer(e.PlayerNumber);
			if (ph) ph.equipWindow = 35;
		}
	}

	// EVERY WMCARD LUMP IN THE LOAD ORDER, every weapon in each. A weapon pk3
	// opts in by shipping a card and nothing else.
	private void LoadCards()
	{
		// A SAVE WRITTEN BEFORE VERBS brings its cards back with none on them, and a
		// set once loaded was never read again -- with wm_verbs on, those guns would
		// have nothing to run them. So a set Finish never ran over is read afresh.
		// Each rig rebinds to its new card on the first tic, as on any weapon change;
		// the rounds live on the weapon and are untouched.
		// A SET FROM A SAVE WRITTEN BEFORE GUN TYPES (WM_CardSet.typed) is read afresh too:
		// its cards have no type, and every gun's hands would read the uncalibrated seats.
		// And one from before throwables (WM_CardSet.throwablesRead): its cards have no throw blocks.
		// And one from before weapon sheets (WM_CardSet.sheetsRead): no sheet was ever laid over its cards.
		// And one from before borrowed model cards (WM_CardSet.modelsRead): its cards never recorded their lumps.
		// And one from before card bases (WM_CardSet.basesRead): no card was ever built from its base.
		if (set && set.finished && set.typed && set.throwablesRead && set.sheetsRead && set.modelsRead && set.basesRead) return;
		if (set) WM_Log.Info("the cards came back from a save written before verbs, gun types, throwables, weapon sheets, borrowed models or card bases -- reading every WMCARD and WMSHEET lump again");
		set = new("WM_CardSet");
		int lump = -1;
		int lumps = 0;
		while ((lump = Wads.FindLump("WMCARD", lump + 1, Wads.GLOBALNAMESPACE)) >= 0)
		{
			int cardsBefore = set.cards.Size();
			WM_Parser.ParseAll(Wads.ReadLump(lump), "WMCARD", set);
			// EACH CARD KNOWS ITS LUMP, so a gun that borrows it reads its own copy from there (sheet.zs BorrowModels).
			for (int c = cardsBefore; c < set.cards.Size(); c++) set.cards[c].sourceLump = lump;
			lumps++;
		}
		if (lumps == 0)
		{
			set.finished = true;
			set.typed    = true;
			set.throwablesRead = true;
			set.sheetsRead = true;
			set.modelsRead = true;
			set.basesRead = true;
			WM_Log.Err("no WMCARD lump in the load order. The card IS the weapon -- with no card there is nothing to build.");
			return;
		}
		// A CARD THAT STARTS FROM ANOTHER (`base = <id>`, parser.zs INHERITANCE) is built whole now, in its own place in the
		// order, before any sheet borrows a card or lays keys over one.
		WM_Parser.ResolveBases(set);
		set.basesRead = true;

		// THE WEAPON SHEETS (sheet.zs): every WMSHEET lump in the load order, laid over the cards' own capacity,
		// firesfrom, firesound and barrel shots BEFORE Finish, so Finish checks each card as its sheet leaves it.
		// Their shot keys reach the guns themselves at WorldLoaded and as each gun is made (ApplySheet).
		int sheetLumps = 0;
		lump = -1;
		while ((lump = Wads.FindLump("WMSHEET", lump + 1, Wads.GLOBALNAMESPACE)) >= 0)
		{
			WM_SheetReader.ParseAll(Wads.ReadLump(lump), "WMSHEET", set);
			sheetLumps++;
		}
		// A GUN THAT NAMES A MODEL CARD gets its own copy of it first, so its sheet's card keys land on that copy.
		WM_SheetReader.BorrowModels(set);
		set.modelsRead = true;
		WM_SheetReader.ApplyToCards(set);
		set.sheetsRead = true;
		if (sheetLumps > 0)
			WM_Log.Info(String.Format("%d weapon sheet(s) from %d WMSHEET lump(s)", set.sheets.Size(), sheetLumps));

		// MECHANISMS, SYNTHESIS AND EVERY VERB CHECKED -- only now, with every lump
		// read, because an archetype may live in a later one.
		WM_Parser.Finish(set);
		WM_Log.Info(String.Format("%d card(s) and %d archetype(s) from %d WMCARD lump(s); wm_verbs %s",
			set.cards.Size(), set.archetypes.Size(), lumps,
			WM_Verb.Enabled() ? "ON -- the verbs run the guns" : "OFF -- the old role code runs the guns"));
		// THE RELOAD SYSTEM ALONE ships archetypes and no guns. Not an error: said once
		// a map, so an empty pair of hands is explained rather than a mystery.
		if (set.cards.Size() == 0)
			WM_Log.Info("no weapon cards -- nothing here to put in a hand. Guns come from a weapon package loaded after this one, whose WMCARD lump has `weapon` blocks.");
		for (int i = 0; i < set.cards.Size(); i++)
		{
			let c = set.cards[i];
			WM_Log.Info(String.Format("  %s -- %s hand, %d parts, drawn as %s; verbs %s; hands %s",
				c.weaponClass, HandName(c.hand), c.parts.Size(), c.propClass, c.VerbsSummary(), WM_HandProfile.Describe(c)));
		}
		for (int i = 0; i < set.archetypes.Size(); i++)
		{
			let a = set.archetypes[i];
			WM_Log.Info(String.Format("  archetype %s (%s line %d) -- %d verb(s)", a.id, a.sourceName, a.line, a.verbs.Size()));
		}
	}

	// ---- the last rail ---------------------------------------------------------------
	//
	// WHERE A RAIL REALLY WENT. The engine hands every event handler a rail's start and end point
	// (p_map.cpp P_RailAttack -> WorldRailgunFired) while A_RailAttack is still running, so a gun
	// that fires one reads them back straight after the call -- WM_Gun's rail branch, for its
	// TrailProfile. Playsim: it runs on every machine alike, off the rail's own trace. railsFired
	// counts every rail, so a gun can tell its rail went from one a handler cancelled.
	int     railsFired;
	Actor   lastRailShooter;
	Vector3 lastRailFrom;
	Vector3 lastRailTo;

	override void WorldRailgunFired(WorldEvent e)
	{
		railsFired++;
		lastRailShooter = e.Thing;
		lastRailFrom    = e.AttackPos;
		lastRailTo      = e.DamagePosition;
	}

	// ---- the tic------------------------------------------------------------------

	override void WorldTick()
	{
		let p = players[consoleplayer];
		if (!p || !p.mo || !set) return;
		let pmo = PlayerPawn(p.mo);
		if (!pmo || !pmo.player) return;

		// THE CONSOLE PLAYER'S HANDS, and only theirs, as it has always been.
		// Everything below reads and writes that player's container; running it
		// for every player is this body in a loop. ForPlayer makes the two hand
		// states and the two rigs if they are not there yet.
		let ph = ForPlayer(consoleplayer);
		if (!ph) return;

		Equip(ph, pmo);
		if (ph.equipWindow > 0) ph.equipWindow--;
		for (int h = 0; h < 2; h++) BindRig(ph, pmo, h);
		for (int r = 0; r < 2; r++) PublishHandProfile(ph, r);
		ArbiterFind();
		for (int h = 0; h < 2; h++) RecordHand(ph, pmo, h);

		for (int r = 0; r < 2; r++)
		{
			let rig = ph.rigs[r];
			if (!rig.card) continue;
			rig.EnsureProp(pmo);
			rig.Resolve();
			if (rig.resolved && !toldOnce) { toldOnce = true; SelfTest(); }
			rig.Automatic(pmo);
		}

		// WHERE IT STANDS IS FOR CULLING, AND IT MUST STAND WITH YOU. The gun is
		// drawn in the controller's frame, but the renderer only draws an actor
		// whose OWN position is in a part of the map it can see -- and the prop
		// was left wherever it was spawned. Walk far enough from that spot and
		// the gun vanished from your hand while it went on firing; holstering
		// and drawing it spawned it again at your feet, which is why that brought
		// it back. RS_WorldHands keeps its hands with the player the same way.
		// A magazine carried in the hand has the same problem.
		for (int r = 0; r < 2; r++)
			if (ph.rigs[r].prop) ph.rigs[r].prop.SetOrigin(pmo.Pos, false);
		for (int h = 0; h < 2; h++)
		{
			let cm = ph.hstate[h].Carried();
			if (cm && cm.FollowHandMode != 0) cm.SetOrigin(HandPos(pmo, h), false);
		}

		Buttons(ph, pmo);
		PreviewMags(ph, pmo);
		for (int h = 0; h < 2; h++) WorkHand(ph, pmo, h);
		for (int r = 0; r < 2; r++) PutAway(ph, r);
		for (int r = 0; r < 2; r++) ph.rigs[r].Pose();
		for (int r = 0; r < 2; r++) ph.rigs[r].BarrelSmoke();
		for (int r = 0; r < 2; r++) ph.rigs[r].ChargeLook();
		for (int r = 0; r < 2; r++) ph.rigs[r].RecoilLook();
		for (int h = 0; h < 2; h++) PinHand(ph, pmo, h);
		for (int h = 0; h < 2; h++) PoseHand(ph, pmo, h);
		DragPouches(ph, pmo);
		PublishNear(ph, pmo);
		DrawMarkers(ph, pmo);
		ReachBuzz(ph, pmo);
		BuildHud(ph, pmo);
	}

	// ---- a gun in each hand ---------------------------------------------------

	// AT SPAWN each carded gun goes in its own hand, over a fist if need be. AFTER
	// that nothing is taken back: switch a hand to its fist, pass a gun across
	// with RS_WorldHands -- a hand holding anything belongs to whoever put it
	// there, and this only ever fills a hand holding NOTHING.
	private void Equip(WM_PlayerHands ph, PlayerPawn pmo)
	{
		let pl = pmo.player;
		if (pl.PendingWeapon != WP_NOCHANGE) return;
		bool opening = ph.equipWindow > 0;
		for (int i = 0; i < set.cards.Size(); i++)
		{
			let c = set.cards[i];
			Class<Inventory> ic = (Class<Inventory>)(Object.FindClass(c.weaponClass, "Inventory"));
			if (!ic) continue;
			let w = Weapon(pmo.FindInventory(ic));
			if (!w) continue;
			Weapon inHand    = (c.hand == 0) ? pl.ReadyWeapon : pl.OffhandWeapon;
			Weapon otherHand = (c.hand == 0) ? pl.OffhandWeapon : pl.ReadyWeapon;
			if (inHand == w) continue;

			if (opening)
			{
				if (otherHand == w)
				{
					if (c.hand == 0) pl.OffhandWeapon = null;
					else             pl.ReadyWeapon   = null;
				}
				if (inHand == null || IsFistWeapon(inHand)) EquipInstantly(pmo, w, c.hand);
				continue;
			}
			if (inHand == null && otherHand != w) EquipInstantly(pmo, w, c.hand);
		}
	}

	// PUT A GUN IN A HAND FROM OUTSIDE, AND BIND IT NOW. The one entry point for another package that hands
	// a gun straight to a hand instead of through a weapon switch: a caught pickup (catch-to-equip), a console
	// give. The swap is EquipInstantly's. Both hands' rigs are bound, and their props made, on the spot:
	// P_PlayerThink (psprites and the fire check) runs BEFORE WorldTick (p_tick.cpp), so a bind left to the
	// next WorldTick came a tic late, and that tic's pull was answered by the gun that was there before.
	// BindRig lets go as for any change -- the other hand's grip or guide on the old gun ends, a carry stays.
	// Rigs are the console player's only, as WorldTick works them: another player's gun is swapped and not
	// bound here (NETPLAY_SPEC section 5, P1).
	void PutGunInHand(PlayerPawn pmo, Weapon weap, int hand)
	{
		if (!pmo || !pmo.player || !weap || hand < 0 || hand > 1) return;
		EquipInstantly(pmo, weap, hand);
		if (!set || pmo.PlayerNumber() != consoleplayer) return;
		let ph = ForPlayer(consoleplayer);
		if (!ph) return;
		for (int h = 0; h < 2; h++)
		{
			BindRig(ph, pmo, h);
			ph.rigs[h].EnsureProp(pmo);
		}
	}

	// IS HAND h'S RIG STILL BOUND TO ANOTHER GUN than w -- one put in the hand since the system last bound
	// it. WM_Gun's quiet refusal: no dry click, and no dry told to the gun that was there before. False when
	// this machine works no hands for pn, or the rig holds nothing, so those pulls go on exactly as before.
	bool RigBoundElsewhere(int pn, int h, Weapon w)
	{
		let ph = HandsIfAny(pn);
		if (!ph || h < 0 || h > 1 || !ph.rigs[h]) return false;
		let bound = ph.rigs[h].gunItem;
		return bound && bound != w;
	}

	// RS_TestPistol's equipInstantly, which copied the weapon wheel's. Setting
	// the pointer is not enough -- SetPsprite is what hands the layer to it.
	private void EquipInstantly(PlayerPawn pmo, Weapon weap, int hand)
	{
		let player = pmo.player;
		if (!player || !weap) return;
		bool wantOff = (hand == 1);
		let already = wantOff ? player.OffhandWeapon : player.ReadyWeapon;
		if (already == weap) return;
		if (weap.bNoHandSwitch && weap.bOffhandWeapon != wantOff) return;
		if (wantOff && player.ReadyWeapon == weap)    player.ReadyWeapon   = null;
		if (!wantOff && player.OffhandWeapon == weap) player.OffhandWeapon = null;
		weap.bOffhandWeapon = wantOff;
		if (weap.SisterWeapon) weap.SisterWeapon.bOffhandWeapon = wantOff;
		if (wantOff) player.OffhandWeapon = weap;
		else         player.ReadyWeapon   = weap;
		// A SWITCH PENDING FOR THIS HAND is what this replaces; one pending for the OTHER hand goes on.
		let pending = player.PendingWeapon;
		if (pending != WP_NOCHANGE && (!pending || pending == weap || pending.bOffhandWeapon == wantOff))
			player.PendingWeapon = WP_NOCHANGE;
		player.SetPsprite(wantOff ? PSP_OFFHANDWEAPON : PSP_WEAPON, weap.GetReadyState());
	}

	// The gun in hand h, bound to its card. Rebound when the weapon INSTANCE
	// changes, not just the class -- dying gives you new ones, and they come
	// loaded.
	private void BindRig(WM_PlayerHands ph, PlayerPawn pmo, int h)
	{
		let pl = pmo.player;
		Weapon w = (h == 0) ? pl.ReadyWeapon : pl.OffhandWeapon;
		WM_Card want = null;
		if (w)
		{
			String wn = w.GetClassName();
			for (int i = 0; i < set.cards.Size(); i++)
				if (set.cards[i].weaponClass ~== wn) { want = set.cards[i]; break; }
		}
		let rig = ph.rigs[h];
		if (rig.card == want && rig.gunItem == w) return;
		LetGoOf(ph, pmo, h);
		rig.Unbind();
		if (want) rig.Bind(want, w);
	}

	// Whatever the other hand was doing to gun r, it stops. Holding a part or
	// guiding a magazine in; a carry is not about the gun and survives.
	private void LetGoOf(WM_PlayerHands ph, PlayerPawn pmo, int r)
	{
		int w = 1 - r;
		let rig = ph.rigs[r];
		let st = ph.hstate[w];
		int held = st.HeldPart();
		if (held >= 0 && rig.card && held < rig.card.parts.Size())
			rig.StopDrive(rig.card.parts[held]);
		if (held >= 0)
		{
			ReleaseClaim(pmo, w);
			st.Clear();
		}
		if (st.mode == WM_HandState.GUIDE)
		{
			let m = st.mag;
			if (m) m.bINVISIBLE = false;
			if (st.ours && m) st.ReturnToCarry();
			else st.EndGuide();
		}
		rig.heldPart = -1;
	}

	// ---- buttons ----------------------------------------------------------------

	// THE MAGAZINE RELEASE IS ON THE GUN, under the thumb of the hand holding
	// it. Two buttons, one per gun: with a pistol in each hand, "whichever
	// needs it" guesses wrong exactly when both are low.
	private void Buttons(WM_PlayerHands ph, PlayerPawn pmo)
	{
		uint b = pmo.player.cmd.buttons;
		for (int r = 0; r < 2; r++)
		{
			int bit = (r == 0) ? BT_MAINHANDDROPMAG : BT_OFFHANDDROPMAG;
			if ((b & bit) && !(ph.lastButtons & bit)) ButtonDrop(ph, pmo, r);
		}
		ph.lastButtons = b;
	}

	private void ButtonDrop(WM_PlayerHands ph, PlayerPawn pmo, int r)
	{
		let rig = ph.rigs[r];
		if (!rig.card || !rig.ammo) return;
		// A GUN WHOSE BUTTON OPENS IT OR THROWS ITS CASES (an open or eject verb's `button = yes`,
		// wm_verbs on) -- a revolver. Every magazine gun, the pumps and the double have none, and
		// go on below exactly as always.
		if (WM_Verb.Enabled() && ButtonWorksVerbs(ph, pmo, r)) return;
		if (!rig.ammo.magIn) return;
		// A FEED STORE THAT DOES NOT DETACH -- a tube -- has nothing to drop. Both
		// pistols' magazines detach.
		if (!rig.ammo.MagDetaches())
		{
			WM_Log.Once(WM_Log.LV_INFO, "nodrop:" .. rig.card.weaponClass, String.Format(
				"%s gun: the drop-mag button does nothing -- its feed store does not detach", rig.HandName()));
			return;
		}
		int w = 1 - r;
		int fi = rig.card.FindRoleIndex("feed");
		// THE SWAP SAYS WHETHER THE BUTTON WORKS IT (wm_verbs on). A card written
		// before verbs has a synthesised swap that says yes -- what this always did.
		if (WM_Verb.Enabled() && fi >= 0)
		{
			let sv = rig.card.VerbForPart(fi);
			if (sv && sv.kind == WM_Verb.SWAP && !sv.button)
			{
				WM_Log.Once(WM_Log.LV_INFO, "nobutton:" .. rig.card.weaponClass, String.Format(
					"%s gun: the drop-mag button does nothing -- its swap %s says button = no", rig.HandName(), sv.id));
				return;
			}
			// A SWAP THAT NEEDS SOMETHING OPEN (swap `needs = open:<id>`) -- a BFG's cell under its
			// cover -- does not drop while that is shut.
			if (sv && sv.kind == WM_Verb.SWAP && !rig.LoadGateOpen(sv))
			{
				WM_Log.Once(WM_Log.LV_INFO, "gateshut:" .. rig.card.weaponClass, String.Format(
					"%s gun: the drop-mag button does nothing while its %s is shut -- swap %s needs it open", rig.HandName(), sv.needsOpen, sv.id));
				return;
			}
			// A LATCHED SWAP (swap `latch = <part>`, F3) -- a flamethrower's lever -- does not drop until
			// the latch is thrown.
			if (sv && sv.kind == WM_Verb.SWAP && !rig.LatchThrown(sv))
			{
				WM_Log.Once(WM_Log.LV_INFO, "latchshut:" .. rig.card.weaponClass, String.Format(
					"%s gun: the drop-mag button does nothing until its %s is thrown -- swap %s is latched", rig.HandName(), sv.latchId, sv.id));
				return;
			}
		}
		if (fi >= 0 && ph.hstate[w].HeldPart() == fi)
		{
			ph.hstate[w].Clear();
			rig.heldPart = -1;
			ReleaseClaim(pmo, w);
		}
		rig.DropMagazine(pmo);
	}

	// THE DROP-MAG BUTTON ON A GUN LOADED THROUGH AN OPEN VERB (FEEL_PLAN section 3b). Every open
	// verb with `button = yes` that is not open opens -- taken out of the other hand first if it
	// holds the part -- and runs its onopen; then every eject with `button = yes` whose gate is
	// now open throws out everything in its store, whichever way the gun is held. One press, one
	// line each (SetOpen, ThrowOutAll), never per tic. False, touching nothing, for a card with
	// neither, so the swap path is untouched.
	private bool ButtonWorksVerbs(WM_PlayerHands ph, PlayerPawn pmo, int r)
	{
		let rig = ph.rigs[r];
		let gunCard = rig.card;
		bool buttonVerbs = false;
		for (int k = 0; k < gunCard.verbs.Size(); k++)
		{
			let bv = gunCard.verbs[k];
			if (bv.button && (bv.kind == WM_Verb.OPEN || bv.kind == WM_Verb.EJECT)) buttonVerbs = true;
		}
		if (!buttonVerbs) return false;
		if (!rig.prop || !rig.resolved) return true;
		int w = 1 - r;
		for (int k = 0; k < gunCard.verbs.Size(); k++)
		{
			let ov = gunCard.verbs[k];
			if (ov.kind != WM_Verb.OPEN || !ov.button || rig.IsHeldOpen(k)) continue;
			if (ov.partIndex < 0 || ov.partIndex >= gunCard.parts.Size()) continue;
			let openPart = gunCard.parts[ov.partIndex];
			if (ph.hstate[w].HeldPart() == ov.partIndex)
			{
				rig.StopDrive(openPart);
				ph.hstate[w].Clear();
				rig.heldPart = -1;
				ReleaseClaim(pmo, w);
			}
			openPart.value = 1.0;
			rig.SetOpen(pmo, k, true, 1.0, "by the drop-mag button");
		}
		for (int k = 0; k < gunCard.verbs.Size(); k++)
		{
			let ev = gunCard.verbs[k];
			if (ev.kind != WM_Verb.EJECT || !ev.button || !rig.LoadGateOpen(ev)) continue;
			if (!rig.ammo.SlotHeld(ev.fromStore, -1))
			{
				WM_Log.Info(String.Format("%s gun: drop-mag button -- nothing in %s to throw out", rig.HandName(), ev.fromStore));
				continue;
			}
			rig.SetEjectThrown(k, true);
			rig.ThrowOutAll(pmo, k, ev.fromStore, rig.GateCarrier(ev), "by the drop-mag button");
		}
		return true;
	}

	// ---- the hand that works the other gun -----------------------------------

	private void RecordHand(WM_PlayerHands ph, PlayerPawn pmo, int h)
	{
		for (int k = 3; k > 0; k--) ph.trail[h * 4 + k] = ph.trail[h * 4 + k - 1];
		ph.trail[h * 4] = HandPos(pmo, h);
	}

	// HOW FAST THE HAND WAS MOVING AS IT LET GO. The controller's own velocity,
	// from OpenXR's sensor fusion, in map units per second -- not two 35Hz
	// samples differenced, which amplifies tracking jitter and throws away
	// everything the headset saw between tics. The difference is only the
	// fallback, for a frame the runtime reported nothing.
	private Vector3 HandVel(WM_PlayerHands ph, PlayerPawn pmo, int h)
	{
		Vector3 v = (h == 0) ? pmo.AttackVel : pmo.OffhandVel;
		if (v.Length() > 1e-6) return v / 35.0;
		return (ph.trail[h * 4] - ph.trail[h * 4 + 3]) / 3.0;
	}

	private void WorkHand(WM_PlayerHands ph, PlayerPawn pmo, int h)
	{
		let rig = ph.rigs[1 - h];
		let st  = ph.hstate[h];
		bool squeeze = GripHeld(pmo, h);
		bool press   = squeeze && !ph.gripArm[h];
		ph.gripArm[h] = squeeze;
		// BRACING IS DECIDED AFRESH EVERY TIC, at the bottom, for an open free hand.
		if (st.mode == WM_HandState.BRACE) st.Clear();

		// A MAGAZINE IN THIS HAND LOOKS LIKE THE GUN IT IS LOADING.
		//
		// Every gun's card has its own magazine mesh and size, each matched to that
		// gun. Once any pistol took any pistol magazine, a magazine kept the look of
		// the gun it came OUT of -- so the same reload showed a full-size magazine in
		// one hand and a tiny one in the other, depending only on which gun it had
		// last been in. It now takes on the look of the gun this hand works, the
		// moment it is in the hand, and keeps its rounds. Guiding hides the loose
		// magazine (the gun's own surface is drawn instead), so it is left alone.
		if (st.mode != WM_HandState.GUIDE && rig.card)
		{
			WM_LooseMag inHand = st.Carried();
			if (!inHand) inHand = ForeignInHand(ph, h);
			if (inHand && !inHand.IsRound()
				&& inHand.magFamily ~== rig.card.FamilyOfMags()
				&& !(inHand.cardId ~== rig.card.weaponClass))
			{
				inHand.Setup(inHand.Amount, rig.card);
			}
		}

		// ONE STATE, ONE BRANCH. A hand with something of ours in it does that
		// and nothing else this tic.
		switch (st.mode)
		{
			case WM_HandState.GUIDE:
				GuideLogged(ph, pmo, h, rig, squeeze);
				return;
			case WM_HandState.CARRY:
				// A carry whose magazine has gone (destroyed out of the hand)
				// is a free hand, as it always was.
				if (st.Carried()) { Carry(ph, pmo, h, rig, squeeze); return; }
				break;
			case WM_HandState.ONPART:
				// THE A/B SWITCH: the verbs, or the old role code exactly as it was.
				if (WM_Verb.Enabled()) HoldByVerbs(ph, pmo, h, rig, squeeze);
				else                   HoldOldPath(ph, pmo, h, rig, squeeze);
				return;
		}

		// ---- FREE. Everything from here down is a hand with nothing of ours in
		// it: FREE, FOREIGN as of last tic, or a carry whose magazine is gone.
		// THE ORDER OF THESE TESTS IS LOAD-BEARING -- see each comment.

		// A MAGAZINE SOMETHING ELSE IS HOLDING IN THIS HAND -- RS_WorldHands'
		// grab, off the floor or out of the air. Ours to seat, not to carry.
		let fm = ForeignInHand(ph, h);
		if (fm)
		{
			st.Foreigner(fm);
			ph.lastForeign[h] = fm;
			// A ROUND RS_WorldHands HOLDS, AT A LOAD POINT of a gun that has them: it goes
			// in when that hand lets go (below, the tic after). Held there, say once why
			// it would not. A pistol has no load points, so this is never taken for one.
			if (rig.LoadTakes(fm) && rig.LoadActive())
			{
				int flk = rig.LoadVerbAt(HandPos(pmo, h));
				if (flk >= 0) LoadHover(h, rig, flk, fm);
			}
			else if (NearWell(pmo, h, rig))
			{
				if (CanSeat(h, rig, fm)) BeginGuide(ph, pmo, h, rig, fm, false);
				else
				{
					String why = SeatRefusal(h, rig, fm);
					if (why != "")
						WM_Log.Once(WM_Log.LV_INFO, String.Format("noseat:%d:%s", h, why),
							String.Format("%s hand is at the %s gun's well but the magazine will not go in: %s",
								HandName(h), rig.HandName(), why));
				}
			}
			return;
		}
		// Nothing foreign in it any more. A preview carry whose magazine went is
		// left marked, as the old preview flag was, so it is not spawned again
		// until the preview is switched off.
		if (!st.preview) st.Clear();

		// Just let go of one. Inside the pouch, it goes back in.
		if (ph.lastForeign[h])
		{
			let m = ph.lastForeign[h];
			ph.lastForeign[h] = null;
			if (m && m.FollowHandMode == 0 && !m.bINVISIBLE)
			{
				// A ROUND LET GO OF AT A LOAD POINT goes in; refused, it falls where it was
				// let go. Anything else, inside the pouch, goes back in, as always.
				bool loaded = false;
				if (rig.LoadTakes(m) && rig.LoadActive())
				{
					int rlk = rig.LoadVerbAt(HandPos(pmo, h));
					if (rlk >= 0) loaded = rig.LoadFrom(rlk, m, h, "as RS_WorldHands let it go");
				}
				if (!loaded && HandInPouch(pmo, h) >= 0) PouchIt(pmo, h, m, rig);
			}
		}

		// A CLOSED FREE HAND CATCHES A FALLING MAGAZINE -- before a squeeze can
		// mean taking a part, since a magazine going past is gone in a moment.
		if (squeeze && CatchFalling(ph, pmo, h)) return;

		if (!rig.card || !rig.prop || !rig.resolved) return;

		// A SQUEEZE TAKES A PART; AN OPEN HAND NEAR THE GRIP BRACES -- tested in
		// that order. The brace used to be tested first and returned, and the
		// support point sits about 3 map units from the magazine's floorplate
		// with both reaches 3 wide: over most of the magazine's own sphere a
		// squeeze braced instead of taking it, while the HUD said "squeeze to
		// take it". A squeeze that only meant to tighten a two-handed hold does
		// no harm -- a magazine taken and not pulled the full stroke springs
		// back in.
		// A FRESH SQUEEZE STARTS NOTHING in a hand another mod holds full (HandHeldByOther): a caught gun, a world
		// object. A braced, merely closed or pouch-leased hand still draws and takes, exactly as before.
		if (press && !HandHeldByOther(pmo, h))
		{
			if (HandInPouch(pmo, h) >= 0) { DrawFromPouch(ph, pmo, h, rig); return; }
			int pick = NearestPart(ph, pmo, h, rig, true, false);
			if (pick >= 0 && TakeAllowed(ph, pmo, h, rig, pick)) { Take(ph, pmo, h, rig, pick); return; }
		}
		int near = NearestPart(ph, pmo, h, rig, true);
		if (near >= 0 && rig.card.parts[near].role == "support" && BraceOn()) st.Bracing();
	}

	// A FREE HAND CATCHES A FALLING MAGAZINE. Drop one with its button and close
	// the other hand under it: it is in that hand, rounds and all, to go back in
	// or into the pouch. It is how a half-empty magazine is kept, now that a hand
	// does not pull one out of the gun.
	//
	// A HAND ALREADY SHUT CATCHES, not only a fresh squeeze -- your fist is
	// usually closed before the magazine gets there. Only in the air: one on the
	// floor is RS_WorldHands' to pick up. The hand whose gun dropped it is left
	// out for half a second, or the magazine would land in the fist it just fell
	// out of. A hand something else holds is not free.
	private bool CatchFalling(WM_PlayerHands ph, PlayerPawn pmo, int h)
	{
		int claim = GetClaim(pmo, h);
		if (claim != GRIPSUBJ_None && !IsOurs(claim)) return false;
		// Nor a hand another mod holds full -- a caught gun, a world object (HandHeldByOther).
		if (HandHeldByOther(pmo, h)) return false;
		// A ROUND TOO, for a hand working a gun with load points (verb.zs LOAD): it is on
		// its way to one. For every other gun -- both pistols -- a round in the air is
		// left alone, exactly as it always was.
		let target = ph.rigs[1 - h];
		bool catchRounds = target && target.LoadActive();
		Vector3 hp = HandPos(pmo, h);
		WM_LooseMag best = null;
		double bestD = Cvf("wm_catch_radius", 6.0);
		let it = ThinkerIterator.Create("WM_LooseMag");
		WM_LooseMag m;
		while (m = WM_LooseMag(it.Next()))
		{
			if ((m.IsRound() && !catchRounds) || m.Owner || m.bINVISIBLE || m.FollowHandMode != 0) continue;
			if (m.Pos.Z <= m.floorz + 0.5) continue;
			if (m.droppedBy == h + 1 && level.maptime - m.dropTic < 18) continue;
			double d = (hp - (m.Pos + (0, 0, m.Height * 0.5))).Length();
			if (d < bestD) { bestD = d; best = m; }
		}
		if (!best) return false;

		InHand(best, h);
		best.graceTics = int(Cvf("wm_walk_grace", 175.0));
		ph.hstate[h].Carrying(best);
		ph.hstate[h].leftPouch = true;
		Claim(pmo, h, best.IsRound() ? RoundGrip(best) : GRIPSUBJ_Magazine);
		level.VRHaptic(h, 0.6, 12.0);
		if (best.IsRound())
			WM_Log.Info(String.Format("%s hand caught a %s -- for the %s gun's load points", HandName(h),
				(best.wmSubject == "") ? "round" : best.wmSubject, target.HandName()));
		else
			WM_Log.Info(String.Format("%s hand caught a %s -- %d rounds in it", HandName(h), best.IsLoader() ? "loader" : "magazine", best.Amount));
		return true;
	}

	private WM_LooseMag ForeignInHand(WM_PlayerHands ph, int h)
	{
		let it = ThinkerIterator.Create("WM_LooseMag");
		WM_LooseMag m;
		while (m = WM_LooseMag(it.Next()))
		{
			if (m.FollowHandMode != h + 1 || m.bINVISIBLE) continue;
			if (m == ph.hstate[0].Carried() || m == ph.hstate[1].Carried()
				|| m == ph.hstate[0].Guided() || m == ph.hstate[1].Guided()) continue;
			return m;
		}
		return null;
	}

	// NEAREST WINS, AND THE GUN'S STATE BREAKS TIES. Every part is measured and
	// then compared -- not tested in card order, which would make the answer
	// depend on how the card was written. Action locked back: you are going for
	// the slide. A magazine in the gun and none in your hand: probably not for
	// the magazine. A weight, not an override.
	//
	// A GUN THAT IS PUT AWAY CANNOT BE TOUCHED. It still rides its hand,
	// invisible, with its support point right at that controller -- so the
	// other hand, working the gun between them, braced a gun it could not see,
	// which put ITS own gun away too. Invisible actors are not drawn, a part is
	// only driven while drawn, and the slide froze short of racking.
	private int NearestPart(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig, bool weighted, bool withSupport = true)
	{
		if (!rig.card || !rig.prop || !rig.resolved || rig.stowed) return -1;
		Vector3 hp = HandPos(pmo, h);
		int best = -1;
		double bestD = 1e9;
		for (int i = 0; i < rig.card.parts.Size(); i++)
		{
			let part = rig.card.parts[i];
			// The old three roles, or a part a verb works (a pump's forend). The same set
			// for both pistols, whose verbs were synthesised from those roles.
			if (!rig.card.PartIsWorkable(i)) continue;
			// THE SUPPORT GRIP: bracing's (off by default), or a two-handed gun's (card `hands = 2`),
			// which is always offered -- the other hand must hold it for the trigger to fire.
			if (part.role == "support" && !rig.card.NeedsTwoHands() && (!withSupport || !BraceOn())) continue;
			if (part.role == "feed" && !part.present) continue;
			if (!part.handTake) continue;
			// LOCKED BY ITS LATCH (verb.zs latch, F3): not taken at home until the latch is thrown.
			if (rig.LatchLocks(i)) continue;
			if (part.role != "support" && part.surfaces.Size() == 0) continue;
			// INSIDE THE OVAL, not within a radius. The depth also ranks two
			// parts by which one the hand is further inside, which is what
			// "nearest" wants once they are not all the same shape.
			double d = HandPartDepth(pmo, h, rig, i, part, hp);
			if (d > 1.0) continue;
			double wgt = 1.0;
			if (weighted)
			{
				if (part.role == "action" && rig.ammo.actionLock) wgt = 0.5;
				if (part.role == "feed" && rig.ammo.magIn && !ph.hstate[h].Carried()) wgt = 1.4;
			}
			if (d * wgt < bestD) { bestD = d * wgt; best = i; }
		}
		return best;
	}

	private void Take(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig, int idx)
	{
		let part = rig.card.parts[idx];
		Claim(pmo, h, SubjectFor(part));
		ph.hstate[h].Holding(idx);
		rig.heldPart = idx;
		rig.pastBack = false;
		rig.StartDrive(part, h, part.value);
		level.VRHaptic(h, 0.4, 10.0);
		WM_Log.Info(String.Format("%s hand took the %s of the %s gun", HandName(h), part.id, rig.HandName()));
	}

	private void Hold(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig, bool squeeze)
	{
		let st = ph.hstate[h];
		if (!rig.card || st.HeldPart() >= rig.card.parts.Size()) { st.Clear(); return; }
		let part = rig.card.parts[st.HeldPart()];
		double v = rig.DrawnValue(part);

		if (part.role == "action" && v > 0.6 && !rig.pastBack)
		{
			rig.pastBack = true;
			level.VRHaptic(h, 0.35, 8.0);
		}

		// THE APEX: full travel, once per stroke. The sound belongs where the hand
		// feels the slide stop, not partway back.
		if (part.role == "action" && v >= 0.95 && !rig.atApex)
		{
			rig.atApex = true;
			rig.PlaySnd(rig.RackApexSound());
			level.VRHaptic(h, 0.5, 10.0);
		}

		// PULLED ALL THE WAY OUT, it is in your hand now -- the pull-out ends
		// with you holding the magazine, not with it falling.
		if (part.role == "feed" && v >= 0.97 && rig.ammo.magIn)
		{
			PullOut(ph, pmo, h, rig, part);
			return;
		}

		if (!squeeze) Release(ph, pmo, h, rig);
	}

	private void Release(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig)
	{
		int idx = ph.hstate[h].HeldPart();
		ph.hstate[h].Clear();
		rig.heldPart = -1;
		if (!rig.card || idx < 0 || idx >= rig.card.parts.Size()) { ReleaseClaim(pmo, h); return; }

		let part = rig.card.parts[idx];
		double v = rig.StopDrive(part);

		if (part.role == "action")
		{
			// PULLED FAR ENOUGH AT ANY POINT DURING THE HOLD, not only on the
			// tic you let go: a fast rack is already on its way home by then.
			// THE RESET: the slide slams home whenever it is let go, racked or
			// not. Racked plays it itself; a short pull still springs back.
			if (v > 0.6 || rig.pastBack) rig.Racked(pmo);
			else if (v > 0.05) rig.PlaySnd(rig.RackResetSound());
			part.value = rig.ammo.actionLock ? 1.0 : 0.0;
			rig.pastBack = false;
			rig.atApex   = false;
		}
		else if (part.role == "feed")
		{
			if (v >= part.dof.detach && rig.ammo.magIn)
			{
				let m = rig.DropMagazine(pmo);
				if (m) m.Vel = HandVel(ph, pmo, h) * Cvf("wm_throw_mult", 1.0) + pmo.Vel;
			}
			else part.value = 0.0;   // not far enough: the catch takes it back
		}

		ReleaseClaim(pmo, h);
		level.VRHaptic(h, 0.5, 12.0);
	}

	// ---- THE A/B SWITCH (wm_verbs) ----------------------------------------------
	//
	// OFF: Hold and Release above, and rig.Racked, run exactly as they were,
	// through HoldOldPath -- which reads the drawn value first and says one line
	// after, and changes nothing. ON: HoldByVerbs and ReleaseByVerbs below.

	// THE OLD PATH, run as it was, with one line said once the hand has left the
	// part, so the log shows which path decided. The value read here is the drawn
	// value the old Hold reads on this same tic; reading it moves nothing.
	private void HoldOldPath(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig, bool squeeze)
	{
		let st = ph.hstate[h];
		int idx = st.HeldPart();
		String partName = "";
		double drawn = 0.0;
		bool wasPast = rig.pastBack;
		if (rig.card && idx >= 0 && idx < rig.card.parts.Size())
		{
			partName = rig.card.parts[idx].id;
			drawn = rig.DrawnValue(rig.card.parts[idx]);
		}
		Hold(ph, pmo, h, rig, squeeze);
		if (partName == "" || st.mode == WM_HandState.ONPART) return;
		WM_Log.Info(String.Format("%s hand %s the %s gun's %s -- path OLD (wm_verbs off), drawn %.3f%s; the lines above are its decision",
			HandName(h), (st.mode == WM_HandState.CARRY) ? "pulled out" : "let go of", rig.HandName(), partName, drawn,
			wasPast ? ", pulled past 0.60 earlier in the hold" : ""));
	}

	// ---- the interpreter (wm_verbs on) ----------------------------------------------
	//
	// HOLD AND RELEASE, BY VERB. A held part is worked by at most one verb -- the
	// parser refuses two -- and what the hold measures and what letting go does are
	// that verb's: a cycle's outat, apex and return, a swap's pull-out and detach, an
	// open verb's openat. Every threshold is compared against the DRAWN value: in the
	// hold through DrawnValue, at the release through StopDrive.
	private void HoldByVerbs(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig, bool squeeze)
	{
		let st = ph.hstate[h];
		if (!rig.card || st.HeldPart() >= rig.card.parts.Size()) { st.Clear(); return; }
		int idx = st.HeldPart();
		let part = rig.card.parts[idx];
		double v = rig.DrawnValue(part);
		int k = rig.card.VerbIndexForPart(idx);
		WM_Verb verb = null;
		if (k >= 0) verb = rig.card.verbs[k];

		if (verb && verb.kind == WM_Verb.CYCLE)
		{
			// PULLED FAR ENOUGH, REMEMBERED: a fast rack is already on its way home by
			// the tic the hand opens, so the release reads this, not only its own value.
			if (v > verb.outAt)
			{
				if (!rig.pastBack)
				{
					rig.pastBack = true;
					level.VRHaptic(h, 0.35, 8.0);
				}
				// Returned by hand, the far end happens HERE, at the back of the stroke.
				if (verb.ret != WM_Verb.RET_SPRING) rig.StrokeOut(pmo, k, v);
			}

			// THE APEX: full travel, once per stroke. The sound belongs where the hand
			// feels it stop, not partway back.
			if (v >= verb.apex && !rig.atApex)
			{
				rig.atApex = true;
				// A SPRING-RETURNED ACTION'S STOP. One returned by hand sounds at its far
				// end and at home instead (cycleoutsound / cyclehomesound in rig.StrokeOut
				// and StrokeHome) -- never the pistol rack sound RackApexSound falls back to.
				if (verb.ret == WM_Verb.RET_SPRING) rig.PlaySnd(rig.RackApexSound());
				level.VRHaptic(h, 0.5, 10.0);
			}

			// Returned by hand, home again is the near end -- and opens the next stroke.
			if (verb.ret != WM_Verb.RET_SPRING && rig.StrokeAt(k) == WM_Rig.STROKE_OUT && v <= rig.HomeAt(verb))
			{
				rig.StrokeHome(pmo, k, v);
				rig.pastBack = false;
				rig.atApex   = false;
			}
		}
		else if (verb && verb.kind == WM_Verb.OPEN)
		{
			// OPEN PAST openat, SHUT AGAIN ONLY BACK AT closeat; in between it stays as it
			// was. Opening throws the cases out (rig.SetOpen) while the hand still has it.
			if (!rig.IsHeldOpen(k) && v >= verb.openAt)
			{
				level.VRHaptic(h, 0.35, 8.0);
				rig.SetOpen(pmo, k, true, v);
			}
			else if (rig.IsHeldOpen(k) && v <= rig.CloseAt(verb))
			{
				level.VRHaptic(h, 0.35, 8.0);
				rig.SetOpen(pmo, k, false, v);
			}
		}
		else if (verb && verb.kind == WM_Verb.EJECT)
		{
			// A PART WORKED PAST at (by = hand): every case out, once a stroke, gate open.
			if (v >= verb.at && !rig.EjectThrown(k) && rig.LoadGateOpen(verb))
			{
				rig.SetEjectThrown(k, true);
				level.VRHaptic(h, 0.5, 10.0);
				rig.ThrowOutAll(pmo, k, verb.fromStore, rig.GateCarrier(verb), String.Format("the %s worked to %.2f", part.id, v));
			}
		}
		else if (verb && verb.kind == WM_Verb.SWAP)
		{
			// PULLED ALL THE WAY OUT, it is in your hand now -- the pull-out ends with
			// you holding the container, not with it falling.
			if (v >= verb.pullOutAt && rig.SwapAttached(verb) && rig.LoadGateOpen(verb) && rig.LatchThrown(verb))
			{
				WM_Log.Info(String.Format("%s hand: [verbs] swap %s -- PULLED OUT at drawn %.3f (in the hand at %.2f)",
					HandName(h), verb.id, v, verb.pullOutAt));
				PullOut(ph, pmo, h, rig, part);
				return;
			}
		}
		else if (verb && verb.kind == WM_Verb.START)
		{
			// THE PULL BEGINS: its sound, once a hold. PAST outat THE ENGINE CATCHES, while the hand
			// still has the grip -- once a hold, and not at all on one already running.
			if (v > 0.15 && !rig.pastBack)
			{
				rig.pastBack = true;
				rig.PlaySnd(rig.SlotSound("pull", rig.card.pullSound));
				level.VRHaptic(h, 0.35, 8.0);
			}
			if (v >= verb.outAt && !rig.atApex)
			{
				rig.atApex = true;
				if (!rig.ammo.engineRunning) level.VRHaptic(h, 0.7, 16.0);
				rig.StartEngine(k, v);
			}
		}

		if (!squeeze) ReleaseByVerbs(ph, pmo, h, rig);
	}

	private void ReleaseByVerbs(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig)
	{
		int idx = ph.hstate[h].HeldPart();
		ph.hstate[h].Clear();
		rig.heldPart = -1;
		if (!rig.card || idx < 0 || idx >= rig.card.parts.Size()) { ReleaseClaim(pmo, h); return; }

		let part = rig.card.parts[idx];
		double v = rig.StopDrive(part);     // THE DRAWN VALUE. Everything below is decided on it.
		int k = rig.card.VerbIndexForPart(idx);
		WM_Verb verb = null;
		if (k >= 0) verb = rig.card.verbs[k];
		bool past = rig.pastBack;
		String decision = "left where the hand let go -- no verb works this part";

		if (verb && verb.kind == WM_Verb.CYCLE)
		{
			if (verb.ret == WM_Verb.RET_SPRING)
			{
				// PULLED FAR ENOUGH AT ANY POINT DURING THE HOLD, not only on the tic
				// you let go. THE RESET: it slams home whenever it is let go, racked or
				// not. RackByVerbs plays it itself; a short pull still springs back.
				if (v > verb.outAt || rig.pastBack)
				{
					rig.RackByVerbs(pmo, k, v);
					decision = "RACKED";
				}
				else if (v > 0.05)
				{
					rig.PlaySnd(rig.RackResetSound());
					decision = String.Format("sprang back, short of %.2f", verb.outAt);
				}
				else decision = "sprang back, barely moved";
				// The old Release's own line: home, or held back by the lock.
				part.value = rig.ammo.actionLock ? 1.0 : 0.0;
			}
			else
			{
				// RETURNED BY HAND: it stays where it was let go, and a stroke half done
				// is still half done for the next hand that takes it.
				if (rig.StrokeAt(k) == WM_Rig.STROKE_OUT && v <= rig.HomeAt(verb)) rig.StrokeHome(pmo, k, v);
				// LET GO INSIDE HOME (HomeAt, per kind of gun): it goes the rest of the way, so a pump left a
				// hair back is forward, not out of battery.
				if (v <= rig.HomeAt(verb)) part.value = 0.0;
				bool strokeOut = (rig.StrokeAt(k) == WM_Rig.STROKE_OUT);
				if (verb.ret == WM_Verb.RET_STAY)
				{
					rig.SetHeldOpen(k, strokeOut);
					decision = strokeOut ? "STAYED OPEN, stroke out" : "stayed, stroke home";
				}
				else decision = strokeOut ? "left where the hand let go, stroke out -- home again feeds"
				                          : "left where the hand let go, stroke home";
			}
			rig.pastBack = false;
			rig.atApex   = false;
		}
		else if (verb && verb.kind == WM_Verb.SWAP)
		{
			if (v >= verb.detachAt && rig.SwapAttached(verb))
			{
				let m = rig.DropMagazine(pmo);
				if (m) m.Vel = HandVel(ph, pmo, h) * Cvf("wm_throw_mult", 1.0) + pmo.Vel;
				decision = String.Format("DROPPED, past %.2f", verb.detachAt);
			}
			else
			{
				part.value = 0.0;   // not far enough: the catch takes it back
				decision = String.Format("sprang back in, short of %.2f", verb.detachAt);
			}
		}
		else if (verb && verb.kind == WM_Verb.OPEN)
		{
			if (verb.ret == WM_Verb.RET_SPRING || v <= rig.CloseAt(verb))
			{
				// Let go shut -- or a spring's, anywhere: home, and shut.
				part.value = 0.0;
				rig.SetOpen(pmo, k, false, v);
				if (verb.ret == WM_Verb.RET_SPRING) decision = "sprang SHUT";
				else decision = String.Format("SHUT -- let go at or inside %.2f", rig.CloseAt(verb));
			}
			else
			{
				// IT STAYS WHERE IT WAS LET GO. Past openat it is open; short of it and not
				// back to closeat, it is neither -- and it does not fire.
				if (!rig.IsHeldOpen(k) && v >= verb.openAt) rig.SetOpen(pmo, k, true, v);
				if (rig.IsHeldOpen(k)) decision = "STAYED OPEN";
				else decision = String.Format("stayed part-open -- not open (opens at %.2f), not shut (shuts at %.2f): it will not fire", verb.openAt, rig.CloseAt(verb));
			}
		}
		else if (verb && verb.kind == WM_Verb.EJECT)
		{
			part.value = 0.0;
			rig.SetEjectThrown(k, false);
			decision = "sprang back -- the next stroke throws again";
		}
		else if (verb && verb.kind == WM_Verb.START)
		{
			// IT SPRINGS HOME, whatever the pull did.
			part.value = 0.0;
			if (!rig.ammo.engineRunning) decision = String.Format("sprang home, short of %.2f -- the engine did not catch", verb.outAt);
			else decision = rig.atApex ? "sprang home -- the engine is running" : "sprang home -- the engine was already running";
			rig.pastBack = false;
			rig.atApex   = false;
		}
		else if (verb)
		{
			part.value = 0.0;
			decision = String.Format("sprang back -- a %s verb is read but not yet acted on", WM_Verb.KindName(verb.kind));
		}
		else if (rig.card.LatchSprings(idx))
		{
			// A SPRING LATCH (verb.zs latchreturn = spring) goes home the moment it is let go; the verb it
			// unlocks stays open to a hand for a second (WM_Rig.LatchThrown).
			part.value = 0.0;
			decision = "sprang home -- a spring latch; its part is free to take for a second";
		}

		ReleaseClaim(pmo, h);
		level.VRHaptic(h, 0.5, 12.0);

		String how = "no verb";
		if (verb) how = WM_Verb.KindName(verb.kind) .. " " .. verb.id;
		String pastText = "";
		if (past && verb && verb.kind == WM_Verb.CYCLE) pastText = String.Format(" (pulled past %.2f earlier in the hold)", verb.outAt);
		WM_Log.Info(String.Format("%s hand let go of the %s gun's %s -- path VERBS, %s: %s at drawn %.3f%s",
			HandName(h), rig.HandName(), part.id, how, decision, v, pastText));
	}

	// WHERE THE CATCH TAKES A MAGAZINE. With wm_verbs on, the swap's own seatat when
	// the card states one; otherwise wm_seat_at, read live -- exactly what the old
	// Guide read, so a card silent on it cannot tell the two paths apart.
	private double SeatAtFor(WM_Rig rig, int partIndex)
	{
		double live = Cvf("wm_seat_at", 0.25);
		if (!WM_Verb.Enabled() || !rig.card) return live;
		let verb = rig.card.VerbForPart(partIndex);
		if (verb && verb.kind == WM_Verb.SWAP && verb.seatAt >= 0) return verb.seatAt;
		return live;
	}

	private String SeatSource(WM_Rig rig, int partIndex)
	{
		if (!WM_Verb.Enabled() || !rig.card) return "wm_seat_at";
		let verb = rig.card.VerbForPart(partIndex);
		if (verb && verb.kind == WM_Verb.SWAP && verb.seatAt >= 0) return String.Format("swap %s's seatat", verb.id);
		return "wm_seat_at";
	}

	// A GUIDE, and once it has ended, which path ran it and what it decided. Guide
	// is shared by both paths; only SeatAtFor differs between them.
	private void GuideLogged(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig, bool squeeze)
	{
		let st = ph.hstate[h];
		bool wasIn = rig.ammo && rig.ammo.magIn;
		int fi = rig.card ? rig.card.FindRoleIndex("feed") : -1;
		double drawn = 0.0;
		if (fi >= 0) drawn = rig.DrawnValue(rig.card.parts[fi]);
		double seat = SeatAtFor(rig, fi);
		Guide(ph, pmo, h, rig, squeeze);
		if (st.mode == WM_HandState.GUIDE) return;
		bool seated = !wasIn && rig.ammo && rig.ammo.magIn;
		WM_Log.Info(String.Format("%s hand: guide ended -- path %s, %s at drawn %.3f (the catch takes it at %.2f, from %s)",
			HandName(h), WM_Verb.Enabled() ? "VERBS" : "OLD (wm_verbs off)",
			seated ? "SEATED" : "not seated", drawn, seat, SeatSource(rig, fi)));
	}

	// THE HUD'S "HOLDING" TEXT, from the verb. For both shipped cards this is the
	// old text word for word: their parts are called slide and magazine, and the
	// synthesised numbers are the ones the old text printed.
	private String VerbHoldText(WM_Rig rig, int idx, WM_Part part, double v)
	{
		int k = rig.card.VerbIndexForPart(idx);
		if (k < 0) return String.Format("HOLDING %s -- at %.2f, no verb works it", part.id, v);
		let verb = rig.card.verbs[k];
		if (verb.kind == WM_Verb.CYCLE)
		{
			if (verb.ret == WM_Verb.RET_SPRING)
				return String.Format("HOLDING %s -- back %.2f, racks past %.2f%s", part.id, v, verb.outAt, rig.pastBack ? " (will rack)" : "");
			if (rig.StrokeAt(k) == WM_Rig.STROKE_OUT)
				return String.Format("HOLDING %s -- at %.2f, stroke OUT: home at %.2f feeds", part.id, v, rig.HomeAt(verb));
			return String.Format("HOLDING %s -- at %.2f, stroke home: out past %.2f ejects", part.id, v, verb.outAt);
		}
		if (verb.kind == WM_Verb.SWAP)
			return String.Format("HOLDING %s -- out %.2f, drops past %.2f, in hand at %.2f", part.id, v, verb.detachAt, verb.pullOutAt);
		if (verb.kind == WM_Verb.OPEN)
			return String.Format("HOLDING %s -- at %.2f, opens at %.2f, shuts at %.2f%s%s", part.id, v, verb.openAt, rig.CloseAt(verb),
				rig.IsHeldOpen(k) ? " (OPEN -- bring it back to shut it)" : "",
				(verb.closeBy == "flick") ? (verb.flickAxisSide ? " -- or let go and flick it sideways" : " -- or let go and flick it shut") : "");
		if (verb.kind == WM_Verb.EJECT)
			return String.Format("HOLDING %s -- at %.2f, throws out at %.2f%s", part.id, v, verb.at, rig.EjectThrown(k) ? " (thrown)" : "");
		if (verb.kind == WM_Verb.START)
			return String.Format("HOLDING %s -- pulled %.2f, the engine catches past %.2f%s", part.id, v, verb.outAt,
				rig.ammo.engineRunning ? " (RUNNING)" : "");
		return String.Format("HOLDING %s -- at %.2f", part.id, v);
	}

	// THE RACK TEST CONTROLS, down whichever path is on.
	private void RackTest(WM_Rig rig, PlayerPawn pmo)
	{
		if (WM_Verb.Enabled())
		{
			rig.RackByEvent(pmo);
			return;
		}
		WM_Log.Info(String.Format("%s gun: rack test control -- path OLD (wm_verbs off)", rig.HandName()));
		rig.Racked(pmo);
	}

	private void PullOut(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig, WM_Part part)
	{
		rig.StopDrive(part);
		ph.hstate[h].Clear();
		rig.heldPart = -1;
		int had = rig.ammo.TakeMagazine();
		part.present = false;
		part.value = 0.0;

		let m = WM_LooseMag(Actor.Spawn("WM_LooseMag", HandPos(pmo, h), ALLOW_REPLACE));
		if (!m) return;
		m.Setup(had, rig.card, pmo);
		InHand(m, h);
		m.graceTics = int(Cvf("wm_walk_grace", 175.0));
		ph.hstate[h].Carrying(m);
		ph.hstate[h].leftPouch = true;
		rig.PlaySnd(rig.SlotSound("magout", rig.card.magOutSound));
		Claim(pmo, h, GRIPSUBJ_Magazine);
		WM_Log.Info(String.Format("%s hand pulled the %s gun's magazine -- %d rounds in your hand, %s",
			HandName(h), rig.HandName(), had, rig.LeftAfterMagOut()));
	}

	// LOCKED TO THE HAND BY THE RENDERER. Writing a position once a tic makes a
	// held thing lag the hand and swim -- and carries no orientation at all.
	private void InHand(WM_LooseMag m, int h)
	{
		m.FollowHandMode = h + 1;
		m.bNOGRAVITY = true;
		m.Vel = (0, 0, 0);
	}

	// THE LOAD GUIDE (the owner, 09-15): a round this hand carries buzzes the hand as it nears a load point that would
	// take it -- a faint pulse now and then within twice the point's oval, quick firm ones inside it -- so a rocket
	// finds the front of its tube by feel. PRESENTATION on this machine's own controllers: the console player's hands
	// only, and it decides nothing.
	private void LoadBuzz(PlayerPawn pmo, int h, WM_Rig rig, WM_LooseMag m)
	{
		if (!pmo || !pmo.player || pmo.PlayerNumber() != consoleplayer || !rig || !m) return;
		double depth = rig.LoadNearDepth(HandPos(pmo, h), m);
		if (depth <= 1.0)
		{
			if (level.maptime % 5 == 0) level.VRHaptic(h, 0.3, 18.0);
		}
		else if (depth <= 2.0)
		{
			if (level.maptime % 12 == 0) level.VRHaptic(h, 0.12, 10.0);
		}
	}

	private void Carry(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig, bool squeeze)
	{
		let st = ph.hstate[h];
		let m = st.Carried();
		int inPouch = HandInPouch(pmo, h);
		if (inPouch < 0) st.leftPouch = true;

		if (!st.preview && CanSeat(h, rig, m) && NearWell(pmo, h, rig))
		{
			BeginGuide(ph, pmo, h, rig, m, true);
			return;
		}

		// A ROUND AT A LOAD POINT (verb.zs LOAD, wm_verbs on). Held there, it says once
		// why it would not go in; let go of there, it goes in -- or, refused, it falls
		// where the hand opened, like any round let go of. A magazine never gets here,
		// and a magazine is every carry a pistol has.
		int lk = -1;
		if (!st.preview && rig.LoadTakes(m) && rig.LoadActive()) lk = rig.LoadVerbAt(HandPos(pmo, h));
		if (!st.preview) LoadBuzz(pmo, h, rig, m);
		if (squeeze || st.preview)
		{
			if (lk >= 0) LoadHover(h, rig, lk, m);
			return;
		}
		if (lk >= 0 && rig.LoadFrom(lk, m, h, "as the hand opened"))
		{
			// A LOADER STILL THERE -- rounds left in it, or empty and set to drop -- leaves
			// the opened hand like anything else let go of. A round that went in is gone.
			if (m && !m.bDestroyed) Throw(ph, pmo, h, m);
			st.Clear();
			ReleaseClaim(pmo, h);
			return;
		}

		// PUT IT BACK -- only once it has LEFT the pouch. Your hand is still in
		// there on the tic after you draw, so without this it goes straight back
		// on the same gesture and the pouch reads as giving you nothing.
		if (inPouch >= 0 && st.leftPouch)
		{
			PouchIt(pmo, h, m, rig);
			st.Clear();
			ReleaseClaim(pmo, h);
			return;
		}

		// OPEN YOUR HAND AND IT GOES. Still, it drops; moving, it is thrown --
		// the same act meaning both, the way it works with a real object.
		Throw(ph, pmo, h, m);
		st.Clear();
		ReleaseClaim(pmo, h);
	}

	private void Throw(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_LooseMag m)
	{
		m.FollowHandMode = 0;
		m.bNOGRAVITY = false;
		m.SetOrigin(HandPos(pmo, h), false);
		m.Vel = HandVel(ph, pmo, h) * Cvf("wm_throw_mult", 1.0) + pmo.Vel;
		m.graceTics = int(Cvf("wm_walk_grace", 175.0));
		m.Recolour();
	}

	private void PouchIt(PlayerPawn pmo, int h, WM_LooseMag m, WM_Rig rig)
	{
		// NEVER DESTROYS ROUNDS. The reserve starts at Clip's cap of 200, so
		// capping here meant pulling the gun's own magazine at the start and
		// pouching it simply deleted those rounds. The pouch holds what you put
		// in it; floor pickups still stop at the cap, as they always have.
		//
		// INTO THE RESERVE OF THE GUN IT CAME FROM (WM_LooseMag.ReserveClass): Clip for
		// every pistol magazine, as always; Shell for a shell; a second barrel's round to its
		// own named ammo -- a launcher's grenade back to the grenades.
		Class<Ammo> reserve = m.ReserveClass();
		let inv = pmo.FindInventory(reserve);
		if (inv) inv.Amount += m.Amount;
		else pmo.GiveInventory(reserve, m.Amount);
		int n = m.Amount;
		bool wasRound = m.IsRound();
		m.Destroy();
		// A magazine's click; a single round goes back in quietly rather than with a
		// magazine noise.
		if (!wasRound && rig && rig.card) pmo.A_StartSound(rig.SlotSound("magin", rig.card.magInSound), CHAN_AUTO, CHANF_OVERLAP, 0.45);
		level.VRHaptic(h, 0.4, 10.0);
		Class<Ammo> clipClass = "Clip";
		if (reserve == clipClass) WM_Log.Info(String.Format("back in the pouch -- %d rounds to your reserve", n));
		else WM_Log.Info(String.Format("back in the pouch -- %d to your %s reserve", n, GetDefaultByType(reserve).GetClassName()));
	}

	// REACHING IN AND SQUEEZING PUTS A MAGAZINE IN YOUR HAND, for the gun this
	// hand works. It does not load anything -- getting it into the gun is a
	// second act, which is the whole difference from pressing a button.
	// ---- THE POUCH FOR A SECOND BARREL (card.zs WM_Barrel) ----------------------------------

	// A SECOND BARREL WHOSE LOAD IS WAITING, and that load verb's index; null and -1 for none.
	// Waiting: a load into the barrel's store, its gate open, and room in the store. A load with
	// no gate waits only on a gun that keeps no rounds of its own -- on any other gun it would
	// take every pouch draw away from the main barrel's magazine.
	private WM_Barrel, int BarrelAwaitingRound(WM_Rig rig)
	{
		if (!rig || !rig.card || !rig.ammo) return null, -1;
		for (int k = 0; k < rig.card.verbs.Size(); k++)
		{
			let v = rig.card.verbs[k];
			if (v.kind != WM_Verb.LOAD) continue;
			let b = rig.card.BarrelForStore(v.intoStore);
			if (!b) continue;
			if (v.needsOpen == "" && !rig.card.KeepsNoRounds()) continue;
			if (!rig.LoadGateOpen(v)) continue;
			if (rig.ammo.LoadRefusal(v.intoStore, v.slot, v.slotNext) != "") continue;
			return b, k;
		}
		return null, -1;
	}

	// WHY NO SECOND BARREL IS WAITING, for the pouch's line: its gate shut, or its store full.
	private String BarrelShutText(WM_Rig rig)
	{
		for (int k = 0; k < rig.card.verbs.Size(); k++)
		{
			let v = rig.card.verbs[k];
			if (v.kind != WM_Verb.LOAD || !rig.card.IsBarrelStore(v.intoStore)) continue;
			if (!rig.LoadGateOpen(v)) return String.Format("open %s first: load %s takes a round only while it is open", v.needsOpen, v.id);
			String fullWhy = rig.ammo.LoadRefusal(v.intoStore, v.slot, v.slotNext);
			if (fullWhy != "") return fullWhy;
		}
		return String.Format("it fires %s", (rig.card.firesFrom == WM_Card.FIRES_RESERVE) ? "straight from your reserve" : "on no ammunition at all");
	}

	// ONE ROUND FOR A SECOND BARREL, from its own ammo (WM_Barrel `ammo`), into the hand: the
	// card's loose round, with its load verb's subject, marked to go back to that ammo if it is
	// dropped or pouched (WM_LooseMag.reserveName).
	// WHAT A SECOND BARREL'S ROUNDS ARE (WM_Barrel `ammo`): the named ammo class, or the weapon's
	// own reserve when none is named. Null when one is named and no loaded package declares it --
	// a soft dependency, by name.
	private Class<Ammo> BarrelAmmoClass(WM_Barrel b, String weaponClass)
	{
		if (!b || b.ammoClassName == "") return WM_LooseMag.ReserveFor(weaponClass);
		return (Class<Ammo>)(Object.FindClass(b.ammoClassName, "Ammo"));
	}

	private void DrawBarrelRound(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig, WM_Barrel b, int k)
	{
		Class<Ammo> barrelAmmo = BarrelAmmoClass(b, rig.card.weaponClass);
		if (!barrelAmmo)
		{
			pmo.A_StartSound(rig.SlotSound("dry", rig.card.drySound), CHAN_AUTO, CHANF_OVERLAP, 0.4);
			WM_Log.Once(WM_Log.LV_WARN, "barrelammo:" .. rig.card.weaponClass .. ":" .. b.id, String.Format(
				"the pouch has nothing for barrel %s of the %s -- its ammo %s is no loaded class (the package that declares it is not in the load order)",
				b.id, rig.card.weaponClass, b.ammoClassName));
			return;
		}
		let inv = pmo.FindInventory(barrelAmmo);
		if (!inv || inv.Amount <= 0)
		{
			pmo.A_StartSound(rig.SlotSound("dry", rig.card.drySound), CHAN_AUTO, CHANF_OVERLAP, 0.4);
			WM_Log.Info(String.Format("the pouch is empty for barrel %s -- no %s in reserve", b.id, GetDefaultByType(barrelAmmo).GetClassName()));
			return;
		}
		let r = WM_LooseRound(Actor.Spawn("WM_LooseRound", HandPos(pmo, h), ALLOW_REPLACE));
		if (!r) return;
		inv.Amount -= 1;
		r.SetupRound(rig.card, pmo);
		let lv = rig.card.verbs[k];
		if (lv.subject != "" && lv.subject != "loader") r.wmSubject = lv.subject;
		r.reserveName = inv.GetClassName();
		InHand(r, h);
		r.graceTics = 0;
		ph.hstate[h].Carrying(r);
		ph.hstate[h].leftPouch = false;
		Claim(pmo, h, RoundGrip(r));
		level.VRHaptic(h, 0.5, 12.0);
		WM_Log.Info(String.Format("%s hand drew one %s for barrel %s of the %s gun -- %d left in the %s reserve",
			HandName(h), r.wmSubject, b.id, rig.HandName(), inv.Amount, inv.GetClassName()));
	}

	private void DrawFromPouch(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig)
	{
		if (!rig.card) return;
		// A SECOND BARREL WAITING FOR A ROUND (card.zs WM_Barrel) -- a launcher's breech slid open,
		// room in its chamber -- gets one round of ITS ammo, before anything for the main barrel:
		// opening that gate is what says which barrel the hand is reloading.
		if (WM_Verb.Enabled() && rig.card.barrels.Size() > 0)
		{
			WM_Barrel waiting;
			int waitLoad;
			[waiting, waitLoad] = BarrelAwaitingRound(rig);
			if (waiting)
			{
				DrawBarrelRound(ph, pmo, h, rig, waiting, waitLoad);
				return;
			}
			// A gun that keeps no rounds of its own has only its second barrel to load: say why not.
			if (rig.card.KeepsNoRounds())
			{
				WM_Log.Info(String.Format("the pouch has nothing for the %s right now -- %s", rig.card.weaponClass, BarrelShutText(rig)));
				return;
			}
		}
		// A GUN THAT KEEPS NO ROUNDS OF ITS OWN (card `firesfrom = reserve | none`) has nothing
		// in the pouch for it: it fires straight from the reserve, or on nothing at all.
		if (rig.card.KeepsNoRounds())
		{
			WM_Log.Once(WM_Log.LV_INFO, "nopouch:" .. rig.card.weaponClass, String.Format(
				"the pouch has nothing for the %s -- it fires %s", rig.card.weaponClass,
				(rig.card.firesFrom == WM_Card.FIRES_RESERVE) ? "straight from your reserve" : "on no ammunition at all"));
			return;
		}
		// FROM THE RESERVE THE GUN FIRES: its own Weapon.AmmoType1 -- Clip for both pistols.
		Class<Ammo> reserve = WM_LooseMag.ReserveFor(rig.card.weaponClass);
		let inv = pmo.FindInventory(reserve);
		if (!inv || inv.Amount <= 0)
		{
			pmo.A_StartSound(rig.SlotSound("dry", rig.card.drySound), CHAN_AUTO, CHANF_OVERLAP, 0.4);
			WM_Log.Info("the pouch is empty -- no rounds in reserve");
			return;
		}

		// A LOADER for a gun loaded by one (WM_Card.PouchGivesLoader, wm_verbs on): a
		// speedloader of up to its card's capacity, drawn as its magmodel, held on the
		// held-magazine sets. Checked before one round: such a gun has load verbs too.
		if (WM_Verb.Enabled() && rig.card.PouchGivesLoader())
		{
			int fill = min(rig.card.capacity, inv.Amount);
			let lm = WM_LooseMag(Actor.Spawn("WM_LooseMag", HandPos(pmo, h), ALLOW_REPLACE));
			if (!lm) return;
			inv.Amount -= fill;
			lm.SetupLoader(fill, rig.card, pmo);
			InHand(lm, h);
			lm.graceTics = 0;
			ph.hstate[h].Carrying(lm);
			ph.hstate[h].leftPouch = false;
			Claim(pmo, h, GRIPSUBJ_Magazine);
			level.VRHaptic(h, 0.5, 12.0);
			WM_Log.Info(String.Format("%s hand drew a loader for the %s gun -- %d rounds, %d left in the %s reserve",
				HandName(h), rig.HandName(), fill, inv.Amount, inv.GetClassName()));
			return;
		}

		// ONE ROUND for a gun loaded a round at a time -- load verbs and no swap
		// (WM_Card.PouchGivesRounds), wm_verbs on. A gun with a swap -- both pistols --
		// gets a magazine below, as always.
		if (WM_Verb.Enabled() && rig.card.PouchGivesRounds())
		{
			let r = WM_LooseRound(Actor.Spawn("WM_LooseRound", HandPos(pmo, h), ALLOW_REPLACE));
			if (!r) return;
			inv.Amount -= 1;
			r.SetupRound(rig.card, pmo);
			InHand(r, h);
			r.graceTics = 0;
			ph.hstate[h].Carrying(r);
			ph.hstate[h].leftPouch = false;
			Claim(pmo, h, RoundGrip(r));
			level.VRHaptic(h, 0.5, 12.0);
			WM_Log.Info(String.Format("%s hand drew one %s for the %s gun -- %d left in the %s reserve",
				HandName(h), r.wmSubject, rig.HandName(), inv.Amount, inv.GetClassName()));
			return;
		}

		int take = min(rig.card.capacity, inv.Amount);
		inv.Amount -= take;

		let m = WM_LooseMag(Actor.Spawn("WM_LooseMag", HandPos(pmo, h), ALLOW_REPLACE));
		if (!m) return;
		m.Setup(take, rig.card, pmo);
		InHand(m, h);
		m.graceTics = 0;
		ph.hstate[h].Carrying(m);
		ph.hstate[h].leftPouch = false;
		Claim(pmo, h, GRIPSUBJ_Magazine);
		level.VRHaptic(h, 0.5, 12.0);
		WM_Log.Info(String.Format("%s hand drew a magazine for the %s gun -- %d rounds, %d left in reserve",
			HandName(h), rig.HandName(), take, inv.Amount));
	}

	private bool CanSeat(int h, WM_Rig rig, WM_LooseMag m)
	{
		if (!m || !rig.card || !rig.prop || !rig.resolved || !rig.ammo) return false;
		if (rig.ammo.magIn || m.IsRound()) return false;
		// A SWAP THAT NEEDS SOMETHING OPEN (swap `needs = open:<id>`) -- a BFG's cell under its
		// cover -- takes no magazine while that is shut.
		if (!SwapGateOpen(rig)) return false;
		// BY FAMILY, not by gun: any pistol magazine fits any pistol.
		return m.magFamily ~== rig.card.FamilyOfMags();
	}

	// THE FEED PART'S SWAP IS NOT WAITING ON A SHUT OPEN VERB (its `needs`), wm_verbs on. True
	// for every swap that needs nothing -- every card before the key existed.
	private bool SwapGateOpen(WM_Rig rig)
	{
		if (!WM_Verb.Enabled() || !rig.card) return true;
		int gateFeed = rig.card.FindRoleIndex("feed");
		if (gateFeed < 0) return true;
		let sv = rig.card.VerbForPart(gateFeed);
		return !sv || sv.kind != WM_Verb.SWAP || (rig.LoadGateOpen(sv) && rig.LatchThrown(sv));
	}

	// The open verb a feed part's swap waits on, for the refusal text; "" when none.
	private String SwapGateName(WM_Rig rig)
	{
		if (!rig.card) return "";
		int gateFeed = rig.card.FindRoleIndex("feed");
		if (gateFeed < 0) return "";
		let sv = rig.card.VerbForPart(gateFeed);
		if (sv && sv.kind == WM_Verb.SWAP) return sv.needsOpen;
		return "";
	}

	// The latch a feed part's swap waits on while it is not thrown, for the refusal text; "" otherwise.
	private String SwapLatchName(WM_Rig rig)
	{
		if (!rig.card) return "";
		int latchFeed = rig.card.FindRoleIndex("feed");
		if (latchFeed < 0) return "";
		let sv = rig.card.VerbForPart(latchFeed);
		if (sv && sv.kind == WM_Verb.SWAP && sv.latchIndex >= 0 && !rig.LatchThrown(sv)) return sv.latchId;
		return "";
	}

	// WHY A MAGAZINE AT THE WELL IS NOT GOING IN. Empty when it would be taken.
	//
	// The HUD used to say "no magazine in hand" whenever the magazine was not
	// one this system was carrying -- including a magazine the hands mod had put
	// in that very hand, sitting at the well. From a headset that reads as the
	// insert being broken, when the real answer was usually that the magazine
	// belongs to the other gun. So it says which.
	private String SeatRefusal(int h, WM_Rig rig, WM_LooseMag m)
	{
		if (!m) return "no magazine in this hand";
		if (!rig.card || !rig.prop || !rig.resolved || !rig.ammo) return "that gun is not ready";
		if (m.IsRound()) return "that is a loose round, not a magazine";
		if (rig.ammo.magIn) return "that gun already has a magazine in";
		if (!SwapGateOpen(rig))
		{
			String latchName = SwapLatchName(rig);
			if (latchName != "") return String.Format("throw its %s first -- the magazine goes in only while it is thrown", latchName);
			return String.Format("open its %s first -- the magazine goes in only while it is open", SwapGateName(rig));
		}
		if (!(m.magFamily ~== rig.card.FamilyOfMags()))
			return String.Format("that is a %s magazine -- the %s takes %s magazines",
				m.magFamily, rig.card.weaponClass, rig.card.FamilyOfMags());
		return "";
	}

	private bool NearWell(PlayerPawn pmo, int h, WM_Rig rig)
	{
		return (HandPos(pmo, h) - rig.WellPoint()).Length() <= Cvf("wm_well_radius", 3.0);
	}

	// CAPTURED AT THE MOUTH OF THE WELL. The loose magazine is hidden and the
	// gun's own magazine surface takes its place, driven by your hand at draw
	// rate from fully out -- one magazine before, one after, at the same point.
	private void BeginGuide(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig, WM_LooseMag m, bool ours)
	{
		int fi = rig.card.FindRoleIndex("feed");
		if (fi < 0) return;
		let feed = rig.card.parts[fi];
		ph.hstate[h].Guiding(m, ours);
		m.bINVISIBLE = true;
		feed.present = true;
		rig.heldPart = fi;
		rig.StartDrive(feed, h, 1.0);
		Claim(pmo, h, GRIPSUBJ_Inserting);
		level.VRHaptic(h, 0.3, 8.0);
		WM_Log.Info(String.Format("%s hand: magazine at the %s gun's well -- push it home", HandName(h), rig.HandName()));
	}

	// WHERE A GUIDE LEAVES THE HAND is WM_HandState's: EndGuide (a magazine
	// RS_WorldHands holds is still in its hand) and ReturnToCarry (ours, let go
	// of short of the catch). Guide below has four exits; each says which.
	private void Guide(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig, bool squeeze)
	{
		let st = ph.hstate[h];
		int fi = rig.card ? rig.card.FindRoleIndex("feed") : -1;
		let m = st.Guided();
		// EXIT 1: the gun has no magazine part to guide into.
		if (fi < 0) { st.EndGuide(); ReleaseClaim(pmo, h); return; }
		let feed = rig.card.parts[fi];

		// EXIT 2: taken from us -- destroyed, or RS_WorldHands let go of it.
		if (!m)
		{
			rig.StopDrive(feed);
			feed.present = false;
			feed.value = 0.0;
			rig.heldPart = -1;
			st.Clear();
			ReleaseClaim(pmo, h);
			return;
		}

		double v = rig.DrawnValue(feed);

		// EXIT 3: PAST THE CATCH, IT SEATS. Let go most of the way in and the
		// catch takes it the last bit; let go further out and it is still yours.
		if (v <= SeatAtFor(rig, fi) || (!squeeze && v <= 0.5))
		{
			rig.StopDrive(feed);
			rig.heldPart = -1;
			int n = m.Amount;
			m.Destroy();
			st.Clear();
			rig.Seat(n);
			ReleaseClaim(pmo, h);
			return;
		}

		// EXIT 4: LET GO, or pulled off the line of the well. Ours goes back to
		// being carried (and is thrown if the hand opened); one RS_WorldHands
		// holds is still in its hand.
		double off = DistToSegment(HandPos(pmo, h), rig.SeatedPoint(), rig.WellPoint());
		if (!squeeze || off > Cvf("wm_well_letgo", 5.0))
		{
			rig.StopDrive(feed);
			rig.heldPart = -1;
			feed.present = false;
			feed.value = 0.0;
			m.bINVISIBLE = false;
			if (st.ours)
			{
				st.ReturnToCarry();
				if (!squeeze) { Throw(ph, pmo, h, m); st.Clear(); ReleaseClaim(pmo, h); }
				else Claim(pmo, h, GRIPSUBJ_Magazine);
			}
			else
			{
				st.EndGuide();
				ReleaseClaim(pmo, h);
			}
		}
	}

	// ---- putting your own gun away while that hand works ----------------------
	//
	// BUSY IS "NOT FREE" FOR HAND r -- the hand that HOLDS gun r and is working
	// the other one. Not the rig's own state.
	private void PutAway(WM_PlayerHands ph, int r)
	{
		let rig = ph.rigs[r];
		if (!rig.prop) return;
		bool busy = ph.hstate[r].HasHand();
		// Never while the OTHER hand has hold of this gun. An invisible actor is
		// not drawn, a part is only driven while it is drawn, and the part would
		// freeze in that hand mid-stroke.
		rig.stowed = busy && rig.heldPart < 0 && Cvb("wm_stow_working_hand", true);
		if (rig.prop.bINVISIBLE != rig.stowed) rig.prop.bINVISIBLE = rig.stowed;
	}

	// ---- the drawn hand, on the part -------------------------------------------
	//
	// ONE WRITER EACH, AND NEITHER IS SCRIPT-TIMED. The SLIDERS say where on
	// the part the hand sits and how the wrist turns; they live under a
	// placement prefix the RENDERER reads every frame, which is why they move
	// the hand while the menu is open. HOW FAR THE PART HAS TRAVELLED is no
	// longer anyone's number to write: the hand is seated in the part's own
	// drawn frame (FollowActorSlot) and the renderer carries it.
	//
	// WHOSE SLIDERS: the gun's hand profile's -- wm_hs_<profile>_<main|off>_<seat>, per
	// kind of gun (handprofile.zs, which declares them to the lint). They were per hand
	// once, shared by every gun, and tuning the revolver's hand moved the pistol's.
	private Actor HandActor(WM_PlayerHands ph, int h)
	{
		if (ph.handActors[h]) return ph.handActors[h];
		// BY NAME, AT RUNTIME. A class literal from another pk3 is checked at
		// compile time and a miss refuses every pk3 after this one.
		Class<Actor> c = (Class<Actor>)(Object.FindClass(h == 0 ? "RS_HandWorldMain" : "RS_HandWorldOff", "Actor"));
		if (!c)
		{
			WM_Log.Once(WM_Log.LV_WARN, "nohands",
				"RS_WorldHands is not loaded -- parts still move, but no hand is drawn on them.");
			return null;
		}
		let it = ThinkerIterator.Create(c);
		ph.handActors[h] = Actor(it.Next());
		return ph.handActors[h];
	}

	private void PinHand(WM_PlayerHands ph, PlayerPawn pmo, int h)
	{
		let hand = HandActor(ph, h);
		if (!hand) return;

		// BONE INFO, ONCE. Every live bone getter is a silent no-op until this
		// is set, and nothing in the tree was setting it on any actor.
		if (!ph.bonesAsked[h])
		{
			ph.bonesAsked[h] = true;
			hand.SetModelFlag(0, IQM_GET_BONE_INFO | IQM_GET_BONE_INFO_RECALC);
		}

		let rig = ph.rigs[1 - h];
		let st  = ph.hstate[h];
		int held = st.HeldPart();
		String kind = "";
		int previewSlot = -1;
		WM_Part seatPart = null;   // the part the hand is seated on, when it is one
		if (Cvb("wm_hand_lock", true) && rig.card && rig.prop)
		{
			if (held >= 0 && held < rig.card.parts.Size())
			{
				// BY THE GRIP, not "magazine or else slide": a pump's forend has no role,
				// and reading it as a slide put the hand on the pistol's slide seat.
				seatPart = rig.card.parts[held];
				kind = WM_Rig.HandSeatKind(seatPart);
			}
			else if (st.mode == WM_HandState.GUIDE) kind = "mag";
			else if (st.mode == WM_HandState.BRACE) kind = "support";
			else
			{
				// SHOWN ON THE PART FOR TUNING, WITHOUT HOLDING IT. A menu freezes
				// the game, so nobody can be mid-rack while dragging a slider --
				// which made the hand's seat on a part impossible to tune. With a
				// preview chosen, the hand that works the selected gun is pinned to
				// that part at rest. Open the menu and the pin stays exactly where
				// it is (script is frozen, the seat sliders are renderer-read), so
				// every slider on the page moves the hand while you watch.
				int pv = int(Cvf("wm_hand_preview", 0));
				if (pv > 0 && rig.hand == int(Cvf("wm_tune_gun", 0)))
				{
					// The action part is the slide on a pistol and the forend on a pump
					// (WM_Card.ActionPartIndex), each on its own seat set.
					int pvAt = (pv == 2) ? rig.card.FindRoleIndex("feed") : rig.card.ActionPartIndex();
					if (pvAt >= 0 && rig.card.parts[pvAt].present)
					{
						seatPart    = rig.card.parts[pvAt];
						kind        = WM_Rig.HandSeatKind(seatPart);
						previewSlot = seatPart.poseSlot;
					}
				}
			}
		}

		if (kind == "")
		{
			// HAND IT BACK, and only what we took. Empty, not 'None' -- the
			// literal name "None" makes the renderer look up None_ofs_x and
			// kills the hand's own sliders.
			if (ph.pinned[h])
			{
				hand.FollowActor     = null;
				hand.FollowActorSlot = -1;
				hand.FollowHandMode  = 0;
				hand.FollowHandOfs   = (0, 0, 0);
				hand.PlacementPrefix = "";
				// A card seat set these; left on, the next thing to seat this hand
				// would read its offset as a mesh point.
				hand.FollowActorOfs        = (0, 0, 0);
				hand.FollowActorOfsInModel = false;
				ph.pinned[h] = false;
			}
			return;
		}

		// WHOSE NUMBERS: this gun's hand profile (handprofile.zs) -- its card's handprofile,
		// its type, or the uncalibrated seats -- never one set every gun shares.
		String pre, hsProfile, hsFell;
		[pre, hsProfile, hsFell] = WM_HandProfile.SeatPrefix(rig.card, rig.hand, kind);
		if (hsFell != "")
			WM_Log.Once(WM_Log.LV_WARN, String.Format("hsfell:%s:%d:%s", rig.card.weaponClass, rig.hand, kind), String.Format(
				"%s gun %s: no hand seat set where it asked -- %s; the %s hand reads %s",
				rig.HandName(), rig.card.weaponClass, hsFell, HandName(h), pre));

		// ON THE PART ITSELF (Actor.FollowActorSlot), not on the controller with
		// a guess at how far the part has travelled.
		//
		// The hand used to ride the controller and be pushed along by script:
		// three "travel" sliders per set said how far it should move per unit of
		// pull, script multiplied them by the part's value every tic, and the
		// result only kept up on playsim tics -- and stood perfectly still while
		// a menu was open, which is when someone is trying to tune it. Seated in
		// the part's own drawn frame, the renderer carries the hand with
		// WHATEVER the part does this frame, including a live hand drive, and
		// there is nothing left to approximate: the twelve travel sliders and
		// wm_pin_units are gone.
		//
		// FollowHandMode stays as the fallback: FollowActor outranks it while the
		// gun has a model to follow, and defers to it when it has none.
		int slot = previewSlot;
		if (held >= 0 && held < rig.card.parts.Size())
			slot = rig.card.parts[held].driveSlot;
		else if (st.mode == WM_HandState.GUIDE)
		{
			let feed = rig.card.FindRole("feed");
			if (feed) slot = feed.driveSlot;
		}

		hand.FollowActor     = rig.prop;
		hand.FollowActorSlot = slot;
		// ON THE CARD'S HAND SEAT, when the part states one (WM_Part.handSeat): a point
		// on the mesh, which the renderer carries into the part's drawn frame
		// (Actor.FollowActorOfsInModel) -- so with the drive slot above it rides the
		// pump, menu open or not. The seat sets below then trim it. A part with none --
		// every pistol part -- is seated exactly as before, at the frame origin.
		if (seatPart && seatPart.handSeatStated)
		{
			hand.FollowActorOfs        = WM_Space.Eng(seatPart.handSeat);
			hand.FollowActorOfsInModel = true;
		}
		else
		{
			hand.FollowActorOfs        = (0, 0, 0);
			hand.FollowActorOfsInModel = false;
		}
		hand.FollowHandMode  = rig.hand + 1;
		hand.FollowHandOfs   = (0, 0, 0);
		// Its seat, turn and size on that part -- every one of them renderer-read
		// and so live with the menu open.
		hand.PlacementPrefix = pre;
		ph.pinned[h] = true;
		// PROOF, once per hand per gun per seat: which seat set and whether the card's seat
		// was used -- the line that says a hand on a pump went to the pump.
		WM_Log.Once(WM_Log.LV_INFO, String.Format("seat:%d:%s:%s", h, rig.card.weaponClass, pre), String.Format(
			"%s hand seated on the %s gun's %s -- set %s, %s",
			HandName(h), rig.HandName(), seatPart ? seatPart.id : kind, pre,
			(seatPart && seatPart.handSeatStated) ? ("at the card's handseat " .. WM_Log.Vec(seatPart.handSeat) .. ", riding the part")
			                                      : "at the gun's frame origin (no handseat on the card)"));
	}

	// WHICH HAND PROFILE EACH GUN'S HANDS READ, for the hand-seat pages. A menu cannot
	// read a card, so the game writes it where a menu can, as wm_gp_name_* does for the
	// grab page: "<weapon class>|<profile its action part's seat reads>|<its type>", or
	// "" with no carded gun in that hand. Written only when it changes (CvSetS).
	private void PublishHandProfile(WM_PlayerHands ph, int r)
	{
		let hsRig = ph.rigs[r];
		String hsNow = "";
		if (hsRig.card)
		{
			int hsAction = hsRig.card.ActionPartIndex();
			String hsKind = (hsAction >= 0) ? WM_Rig.HandSeatKind(hsRig.card.parts[hsAction]) : "slide";
			String hsSet, hsProfile, hsFell;
			[hsSet, hsProfile, hsFell] = WM_HandProfile.SeatPrefix(hsRig.card, r, hsKind);
			hsNow = hsRig.card.weaponClass .. "|" .. hsProfile .. "|" .. WM_HandProfile.TypeOf(hsRig.card);
		}
		CvSetS((r == 0) ? "wm_hs_now_main" : "wm_hs_now_off", hsNow);
	}

	// ---- what shape the hand makes --------------------------------------------

	// THE PART'S SUBJECT, in the engine's own vocabulary. The card gets the
	// first word; the role is only a fallback.
	static int SubjectFor(WM_Part part)
	{
		if (part.subject == "slide")    return GRIPSUBJ_Slide;
		if (part.subject == "forend")   return GRIPSUBJ_Forend;
		if (part.subject == "foregrip") return GRIPSUBJ_Foregrip;
		if (part.subject == "magazine") return GRIPSUBJ_Magazine;
		if (part.subject == "shell")    return GRIPSUBJ_Shell;
		if (part.subject == "round")    return GRIPSUBJ_Round;
		if (part.subject == "support")  return GRIPSUBJ_Support;
		if (part.role == "action") return GRIPSUBJ_Slide;
		if (part.role == "feed")   return GRIPSUBJ_Magazine;
		return GRIPSUBJ_None;
	}

	static bool IsOurs(int s)
	{
		return s == GRIPSUBJ_Slide || s == GRIPSUBJ_Magazine || s == GRIPSUBJ_Inserting
			|| s == GRIPSUBJ_Support || s == GRIPSUBJ_Round || s == GRIPSUBJ_Pouch
			|| s == GRIPSUBJ_Forend || s == GRIPSUBJ_Foregrip || s == GRIPSUBJ_Shell;
	}

	// THE GRIP A LOOSE ROUND IS HELD WITH: a shell's, or a cartridge's.
	static int RoundGrip(WM_LooseMag m)
	{
		if (m && m.wmSubject == "shell") return GRIPSUBJ_Shell;
		return GRIPSUBJ_Round;
	}

	// A ROUND HELD INSIDE A LOAD POINT THAT WOULD NOT GO IN: why, said once per reason
	// per hand -- the load point's own SeatRefusal. The attempt itself (the hand
	// opening) is logged every time by rig.LoadFrom.
	private void LoadHover(int h, WM_Rig rig, int k, WM_LooseMag m)
	{
		if (!rig.card || k < 0 || k >= rig.card.verbs.Size()) return;
		let v = rig.card.verbs[k];
		String why = rig.LoadWhy(v, m);
		if (why == "") return;
		WM_Log.Once(WM_Log.LV_INFO, String.Format("noload:%d:%s", h, why),
			String.Format("%s hand is at the %s gun's load point %s but the round will not go in: %s",
				HandName(h), rig.HandName(), v.id, why));
	}

	// A SUBJECT ONLY WHILE WE HAVE THE HAND. Holding a part, carrying or
	// seating a magazine, or bracing -- and nothing for hovering. RS_WorldHands
	// stands a hand down entirely when its subject reads as a reload, so a
	// subject published for a hand that is merely NEAR a part is a hand that
	// can no longer catch, pull or pass anything.
	private void PoseHand(WM_PlayerHands ph, PlayerPawn pmo, int h)
	{
		let st = ph.hstate[h];
		// Whoever holds it poses it -- loose in the hand, or being pushed into
		// the well, which does not take it out of RS_WorldHands' hand.
		if (st.ForeignMag()) return;
		let rig = ph.rigs[1 - h];
		int subj = GRIPSUBJ_None;
		switch (st.mode)
		{
			case WM_HandState.GUIDE:
				subj = GRIPSUBJ_Inserting;
				break;
			case WM_HandState.CARRY:
				if (st.mag)
				{
					if (st.mag.IsRound()) subj = RoundGrip(st.mag);
					else                  subj = GRIPSUBJ_Magazine;
				}
				break;
			case WM_HandState.ONPART:
				if (rig.card) subj = SubjectFor(rig.card.parts[st.part]);
				break;
			case WM_HandState.BRACE:
				subj = GRIPSUBJ_Support;
				break;
		}

		int mine = GetClaim(pmo, h);
		bool ours = IsOurs(mine);
		if (subj != GRIPSUBJ_None) { if (mine == GRIPSUBJ_None || ours) SetClaim(pmo, h, subj); }
		else if (ours) SetClaim(pmo, h, GRIPSUBJ_None);
	}

	// ---- a hand another mod holds ------------------------------------------------
	//
	// IS HAND h HELD BY ANOTHER MOD, CLOSED ON SOMETHING THAT FILLS IT? Asked before a FRESH squeeze starts
	// anything here (a pouch draw, a part taken) and before a closed hand catches a falling magazine. Some
	// hands are not free: one closed on a caught gun (RS_VR_Weapons' catch-to-equip), on a world object
	// (RS_WorldHands' RS_Held: a weapon, a pickup, a barrel, a key) or on a shield's grip. One squeeze must
	// not start two things. Holds already under way here are never asked (see Claim).
	//
	// ONLY A SUBJECT THAT FILLS THE HAND COUNTS, never "someone holds a lease". RS_WorldHands ticks before
	// this system and can lease a hand on the very squeeze this reacts to; RS_ShieldSaw found that refusing
	// on grip.held alone refused every draw. Never the two-hand brace (RS_Stabilize: forend, foregrip,
	// support), the pouch (the arbiter hands a pouch lease to the reload) or a holster, so a braced off hand
	// still racks the pump and reaches the pouch exactly as before.
	//
	// WITHOUT THE ARBITER, the engine's GripClaim is read as CatchFalling reads it: a value that is not one of
	// ours. IsOurs cannot tell our magazine from another mod's, so there only Grip counts.
	private bool HandHeldByOther(PlayerPawn pmo, int h)
	{
		if (arbiter)
		{
			if (arbiter.GetInt("grip.mine", "", h, 0, pmo, 'RS_WeaponMech') == 1) return false;
			if (arbiter.GetInt("grip.held", "", h, 0, pmo, 'RS_WeaponMech') != 1) return false;
			return FillsHand(arbiter.GetInt("grip.subject", "", h, 0, pmo, 'RS_WeaponMech'));
		}
		int claim = GetClaim(pmo, h);
		return claim != GRIPSUBJ_None && !IsOurs(claim) && FillsHand(claim);
	}

	// A SUBJECT THAT MEANS THE HAND IS FULL: a round, a shell, one being pushed home, a magazine (or any pickup
	// RS_WorldHands holds as one), a gun's grip, a slide. Not None, the brace subjects, a holster or the pouch.
	static bool FillsHand(int s)
	{
		return s == GRIPSUBJ_Round || s == GRIPSUBJ_Shell || s == GRIPSUBJ_Inserting
			|| s == GRIPSUBJ_Magazine || s == GRIPSUBJ_Grip || s == GRIPSUBJ_Slide;
	}

	// ---- the grip arbiter, reached by string ------------------------------------
	//
	// WITHOUT IT, TWO MODS ACT ON ONE SQUEEZE: RS_WorldHands closes on world
	// objects with the same grip. The arbiter is the ledger -- one squeeze, one
	// owner. BY STRING, because a hard reference to another pk3's class is a
	// fatal and global load error when that pk3 is absent.
	const ARB_RETRY = 350;
	const ARB_IDENT = 1;

	private void ArbiterFind()
	{
		if (arbiter) return;
		if (arbWait > 0) { arbWait--; return; }
		ServiceIterator it = ServiceIterator.Find("RS_GripArbiterService");
		Service sv;
		while (sv = it.Next())
		{
			if (sv.GetInt("grip.hello", "", 0, 0, null, 'None') != ARB_IDENT) continue;
			arbiter = sv;
			break;
		}
		if (!arbiter) arbWait = ARB_RETRY;
	}

	// A DENIAL IS ADVICE, NOT A VETO, for a gun's own parts: nothing else
	// drives them, and making the gun unusable is not the answer to someone
	// else holding the hand. Said once, then ignored.
	//
	// DELIBERATE, AND KEPT (2026-09-14). The fresh-squeeze starts (a pouch draw, a
	// part taken) and CatchFalling ask HandHeldByOther first, so a denial here meets
	// a hold already under way -- a part mid-stroke, a magazine mid-guide -- or a
	// lease that does not fill the hand, such as a brace. Letting go there would drop
	// what the hand is doing, so the hand is kept.
	private void Claim(PlayerPawn pmo, int h, int subject)
	{
		if (arbiter)
		{
			bool granted = arbiter.GetInt("grip.claim", "", h, subject, pmo, 'RS_WeaponMech') == 1;
			if (!granted && arbiter.GetInt("grip.mine", "", h, 0, pmo, 'RS_WeaponMech') == 1)
			{
				arbiter.GetInt("grip.release", "", h, 0, pmo, 'RS_WeaponMech');
				granted = arbiter.GetInt("grip.claim", "", h, subject, pmo, 'RS_WeaponMech') == 1;
			}
			if (!granted && !arbWarned)
			{
				arbWarned = true;
				WM_Log.Info("the arbiter says a hand is spoken for -- taking it anyway; a gun's own parts are not shared with anything.");
			}
		}
		if (subject != GRIPSUBJ_None) SetClaim(pmo, h, subject);
	}

	private void ReleaseClaim(PlayerPawn pmo, int h)
	{
		if (IsOurs(GetClaim(pmo, h))) SetClaim(pmo, h, GRIPSUBJ_None);
		if (arbiter) arbiter.GetInt("grip.release", "", h, 0, pmo, 'RS_WeaponMech');
	}

	// ---- the pouch ------------------------------------------------------------
	//
	// ON YOUR BELT, RELATIVE TO YOUR HEAD, IN YOUR BODY'S FRAME -- so it stays
	// put when you turn and does not swing across you when you glance aside.
	// Off the chest on purpose: the chest is where you catch things, and a
	// pouch there turned a catch into a magazine draw.
	private Vector3 PouchPoint(PlayerPawn pmo, int site)
	{
		double fwd  = Cvf("wm_belt_fwd",   5.0);
		double side = Cvf("wm_belt_side",  0.0);
		double up   = Cvf("wm_belt_up",  -20.0);
		if (site == 1) { side = -Cvf("wm_hip_side", 9.0); up = Cvf("wm_hip_up", -22.0); fwd = Cvf("wm_hip_fwd", 1.0); }
		if (site == 2) { side =  Cvf("wm_hip_side", 9.0); up = Cvf("wm_hip_up", -22.0); fwd = Cvf("wm_hip_fwd", 1.0); }
		double ang = pmo.Angle;
		Vector3 rel = (fwd * cos(ang) - side * sin(ang), fwd * sin(ang) + side * cos(ang), up);
		return pmo.HmdPos + rel;
	}

	private int PouchSites() { return Cvb("wm_hip_pouches", false) ? 3 : 1; }

	private double PouchRadius() { return Cvf("wm_belt_radius", 4.0); }

	// ---- the part being edited ---------------------------------------------
	//
	// A COPY, NOT A COLOUR SWAP. Which part is being edited changes in the menu,
	// and the menu freezes the game -- so nothing script does can follow it. One
	// copy per part exists all along, each naming its own gate cvar, and the
	// renderer shows whichever the page has turned on. The same trick RS_VRBody
	// uses to light the holster whose page is open.
	//
	// Its name goes out on a cvar at the same time, because the page cannot read
	// the card: a menu is UI, a card is playsim.
	private void MarkEdited(WM_Rig rig, int i, String both, Vector3 raw, Vector3 at, Vector3 axes)
	{
		if (i < 0 || i >= SEL_PER_GUN) return;
		int slot = rig.hand * SEL_PER_GUN + i;
		String tag = String.Format("%s%d", rig.hand == 0 ? "m" : "o", i);

		// ROLE AND NAME IN ONE STRING, "role|name", from the caller -- a grab slot is
		// a part ("action|slide", "|forend") or a load point ("load|gate"). The page
		// leaves the brace out, so it needs the role; and it says "slide" rather than
		// "part 0", so it needs the name. They are always read together.
		if (selNamed[slot] != both)
		{
			selNamed[slot] = both;
			CvSetS("wm_gp_name_" .. tag, both);
		}

		if (!selMark[slot])
		{
			selMark[slot] = WM_Marker(Actor.Spawn("WM_Marker", (0, 0, 0), ALLOW_REPLACE));
			if (!selMark[slot]) return;
		}
		let mk = selMark[slot];
		// A hair larger, so it reads as a skin over the oval rather than fighting
		// it for the same pixels. The whole-gun offset rides its first seat set,
		// as on the plain marker, so dragging that moves this too.
		mk.PlaceInFrame(rig.prop, rig.SeatFor(raw), rig.FrameUnits(), 'wm_grab_all',
			at, axes * 1.04, false, WM_Marker.KIND_PART, rig.RadiusCVar(i),
			rig.OwnSeatCVar(i), rig.OwnShapePrefix(i));
		mk.MarkSelected(Name("wm_gp_sel_" .. tag),
			Cvf("wm_gp_pulse_hz", 1.0), Cvf("wm_gp_pulse_depth", 0.35),
			Color(Cvi("wm_gp_sel_color", 0xFF40FF)));
	}

	// A GRAB SLOT NOTHING DREW THIS PASS loses its name, so the page stops listing it.
	// Names were only ever written, so a shotgun bound where a pistol had been kept the
	// pistol's "feed|magazine" in a slot the shotgun never fills, and the page offered
	// a magazine that gun does not have.
	private void ForgetEdited(int gunHand, int i)
	{
		int slot = gunHand * SEL_PER_GUN + i;
		if (selNamed[slot] == "") return;
		selNamed[slot] = "";
		CvSetS(String.Format("wm_gp_name_%s%d", gunHand == 0 ? "m" : "o", i), "");
	}

	// ---- BAKING GRAB TUNING INTO THE CARD (BUILD.md step 5) ----------------------------------------
	//
	// The card lines to paste, for the gun in hand `gun`: mode 0 the tuned slot alone, 1 every slot with
	// the tuned one's scratch folded in, 2 every slot from its OLD per-slot set (wm_gp_<m|o><n>_*, the
	// tuning from before step 5, declared until it is baked). The whole-gun offset is folded into each.
	// Printed to the console, so it lands in log-debug.txt -- and, when `record`, kept in the bake ledger
	// (WM_BakeLedger, menu.zs) with the ini saved at once. The engine opens its log fresh on every launch, so
	// a printed bake nobody copied out was lost at the next one. `record` is this machine's own bake.
	private void BakePrint(WM_PlayerHands ph, int gun, int tunedSlot, int mode, double reach, bool record)
	{
		if (!ph || gun < 0 || gun > 1 || !ph.rigs[gun] || !ph.rigs[gun].card || !ph.rigs[gun].prop)
		{
			Console.Printf("\c[Gold]WM BAKE: no carded gun is drawn in that hand -- nothing to bake.");
			return;
		}
		let rig = ph.rigs[gun];
		String what = "the tuned part";
		if (mode == 1) what = "every part";
		else if (mode == 2) what = "every part, from its OLD per-slot tuning";
		Console.Printf("\c[Gold]WM BAKE -- %s, %s gun, %s. Paste into its card, then clear the tuning (the whole-gun offset is folded in):",
			rig.card.weaponClass, rig.HandName(), what);
		int slots = rig.GrabSlotCount();
		int printed = 0;
		for (int s = 0; s < slots; s++)
		{
			if (mode == 0 && s != tunedSlot) continue;
			Vector3 nudge = (0, 0, 0);
			Vector3 shape = (1, 1, 1);
			double ball = 0;
			if (mode == 2)
			{
				[nudge, shape, ball] = rig.OldSlotTuning(s);
			}
			else if (s == tunedSlot)
			{
				nudge = bakeOfs;
				shape = bakeShape;
				ball  = reach;
			}
			String lines = rig.BakeSlot(s, nudge, shape, ball);
			if (lines == "") continue;
			Console.Printf("%s", lines);
			if (record) WM_BakeLedger.Keep(rig.card.weaponClass, lines);
			printed++;
		}
		if (printed == 0) Console.Printf("  (nothing in that slot to bake)");
		else if (record)
		{
			CVar.SaveConfig();
			Console.Printf("\c[Gold]WM BAKE: kept in the bake ledger (%d of %d parts) and saved to the ini.",
				WM_BakeLedger.Count(), WM_BakeLedger.SIZE);
		}
	}

	// ---- moving a pouch by hand -------------------------------------------
	//
	// POSITION ONLY, and the hips stay MIRRORED: both hip pouches share one
	// sideways number, so dragging either moves both and the pair cannot go
	// crooked. The belt pouch is on its own. Written straight to the sliders,
	// so what you place is what the menu shows and what is saved.
	private void SetCv(String n, double v)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		if (c) c.SetFloat(float(v));
	}

	private String PouchName(int site)
	{
		if (site == 0) return "the belt pouch";
		return "the hip pouches";
	}

	private int NearestPouch(PlayerPawn pmo, int h)
	{
		Vector3 hp = HandPos(pmo, h);
		int best = -1;
		double bd = PouchRadius() * 3.0;
		for (int i = 0; i < PouchSites(); i++)
		{
			double d = (hp - PouchPoint(pmo, i)).Length();
			if (d < bd) { bd = d; best = i; }
		}
		return best;
	}

	private void PouchGrab(WM_PlayerHands ph, PlayerPawn pmo, int h)
	{
		if (ph.placingSite[h] >= 0)
		{
			int s = ph.placingSite[h];
			ph.placingSite[h] = -1;
			Console.Printf("\c[Gold]WM: dropped %s at fwd %.1f side %.1f up %.1f", PouchName(s),
				Cvf(s == 0 ? "wm_belt_fwd" : "wm_hip_fwd", 0),
				Cvf(s == 0 ? "wm_belt_side" : "wm_hip_side", 0),
				Cvf(s == 0 ? "wm_belt_up" : "wm_hip_up", 0));
			level.VRHaptic(h, 0.6, 15.0);
			return;
		}
		int site = NearestPouch(pmo, h);
		if (site < 0)
		{
			Console.Printf("WM: no ammo pouch within reach of that hand");
			return;
		}
		ph.placingSite[h] = site;
		Console.Printf("\c[Gold]WM: holding %s", PouchName(site));
		level.VRHaptic(h, 0.4, 10.0);
	}

	// THE HAND'S PLACE IN YOUR BODY'S FRAME -- the inverse of PouchPoint, so a
	// pouch dropped where your hand is comes back to exactly there.
	private void DragPouches(WM_PlayerHands ph, PlayerPawn pmo)
	{
		for (int h = 0; h < 2; h++)
		{
			int s = ph.placingSite[h];
			if (s < 0) continue;
			Vector3 d = HandPos(pmo, h) - pmo.HmdPos;
			double ang = pmo.Angle;
			double fwd  =  d.X * cos(ang) + d.Y * sin(ang);
			double side = -d.X * sin(ang) + d.Y * cos(ang);
			if (s == 0)
			{
				SetCv("wm_belt_fwd", fwd);
				SetCv("wm_belt_side", side);
				SetCv("wm_belt_up", d.Z);
			}
			else
			{
				SetCv("wm_hip_fwd", fwd);
				SetCv("wm_hip_side", abs(side));   // both hips, mirrored
				SetCv("wm_hip_up", d.Z);
			}
		}
	}

	// ---- 4. THE HAND'S OVAL MEETS THE PART'S --------------------------------
	//
	// A hand is at a part when its reach oval -- the one drawn on the hand -- and
	// the part's oval MEET, not when one point of the hand is inside the part's.
	// The hand's oval belongs to the hands package, so it is asked for rather
	// than recomputed (reach.centre, reach.score on the grip arbiter).
	//
	// ALONG THE LINE BETWEEN THE TWO CENTRES each oval has a radius, and they meet
	// when the centres are no further apart than the two radii together. In
	// normalised terms that is 1/hand + 1/part >= 1, where each is how many of
	// its own radii away the other centre sits. Returned in the same sense as
	// GrabDepth -- 1.0 is just touching, less is overlapping -- so the ranking
	// and every "> 1 means no" test above keep working unchanged.
	//
	// Without the hands package it falls back to the hand's point in the part.
	private double HandPartDepth(PlayerPawn pmo, int h, WM_Rig rig, int i, WM_Part part, Vector3 hp)
	{
		if (!arbiter) return rig.GrabDepth(i, part, hp);
		String cs = arbiter.GetString("reach.centre", "", h, 0, pmo, 'RS_WeaponMech');
		if (cs == "") return rig.GrabDepth(i, part, hp);
		Array<String> c;
		cs.Split(c, " ", TOK_SKIPEMPTY);
		if (c.Size() < 3) return rig.GrabDepth(i, part, hp);
		Vector3 handC = (c[0].ToDouble(), c[1].ToDouble(), c[2].ToDouble());

		Vector3 at = rig.PartPoint(i);
		double hs = arbiter.GetDouble("reach.score", String.Format("%.4f %.4f %.4f", at.x, at.y, at.z), h, 0, pmo, 'RS_WeaponMech');
		if (hs < 0) return rig.GrabDepth(i, part, hp);

		double handR = sqrt(max(0.0, hs));          // hand radii from the hand centre to the part
		double partR = rig.GrabDepth(i, part, handC); // part radii from the part centre to the hand
		if (handR < 1e-4 || partR < 1e-4) return 0.0;  // centres coincide: deepest overlap
		return 1.0 / (1.0 / handR + 1.0 / partR);
	}

	// ---- 5. A GRAB NEEDS THE HAND TURNED FOR IT, AND NO TRIGGER ---------------
	//
	// Two guns fired close together must not start working each other. A hand
	// gripping a gun holds its palm SIDEWAYS; a hand racking a slide turns its
	// palm onto it (down) and a hand under a magazine or a pump turns it up. So
	// a take needs the working hand's palm facing along the target gun's up or
	// down -- either sign, which is what keeps this free of any per-hand mirror
	// question -- within wm_palm_cos. The palm's direction is the working hand's
	// sideways axis, taken from its own gun's frame (the gun rides that hand).
	//
	// And never while that hand's trigger is held: a hand that is firing is not
	// reaching for anything.
	private bool TakeAllowed(WM_PlayerHands ph, PlayerPawn pmo, int h, WM_Rig rig, int pick)
	{
		uint b = pmo.player.cmd.buttons;
		if (b & ((h == 0) ? BT_ATTACK : BT_OFFHANDATTACK)) return false;

		if (!Cvb("wm_palm_gate", true)) return true;
		// A SUPPORT GRIP (a two-handed gun's, card `hands = 2`) is held with the palm however the
		// grip is shaped -- a vertical foregrip sideways, a handguard up -- so the palm gate,
		// which is about racking and loading, does not ask.
		if (pick >= 0 && pick < rig.card.parts.Size() && rig.card.parts[pick].role == "support") return true;
		let own = ph.rigs[h];
		if (!own || !own.prop || !rig.prop) return true;   // nothing to measure against

		Vector3 o1, fwd1, side, up1;
		[o1, fwd1, side, up1] = own.FrameBasis();
		Vector3 o2, fwd2, left2, gunUp;
		[o2, fwd2, left2, gunUp] = rig.FrameBasis();
		if (side.Length() < 1e-6 || gunUp.Length() < 1e-6) return true;

		double facing = abs(side.Unit() dot gunUp.Unit());
		ph.palmFacing[h] = facing;
		return facing >= Cvf("wm_palm_cos", 0.5);
	}

	// ---- 6. TELL THE HANDS PACKAGE WHICH HANDS ARE AT A PART ------------------
	//
	// Every tic, so the distance-grab laser stands down while a hand hovers inside
	// a part's volume -- before anything is grabbed -- and comes back the tic it
	// leaves. Proximity only: palm and trigger decide a TAKE, not whether the
	// laser should keep out of the way.
	private void PublishNear(WM_PlayerHands ph, PlayerPawn pmo)
	{
		if (!arbiter) return;
		for (int h = 0; h < 2; h++)
		{
			let rig = ph.rigs[1 - h];
			bool near = ph.hstate[h].HeldPart() >= 0 || ph.hstate[h].mode == WM_HandState.GUIDE
				|| (rig && rig.card && NearestPart(ph, pmo, h, rig, false, false) >= 0);
			arbiter.GetInt("grip.near", "", h, near ? 1 : 0, pmo, 'RS_WeaponMech');
		}
	}

	private int HandInPouch(PlayerPawn pmo, int h)
	{
		double r = PouchRadius();
		Vector3 hp = HandPos(pmo, h);
		for (int i = 0; i < PouchSites(); i++)
			if ((hp - PouchPoint(pmo, i)).Length() <= r) return i;
		return -1;
	}

	private double PouchDistance(PlayerPawn pmo, int h)
	{
		double best = 1e9;
		Vector3 hp = HandPos(pmo, h);
		for (int i = 0; i < PouchSites(); i++)
			best = min(best, (hp - PouchPoint(pmo, i)).Length());
		return best;
	}

	// ---- an empty magazine in each hand, for tuning where it sits ----------------
	private void PreviewMags(WM_PlayerHands ph, PlayerPawn pmo)
	{
		bool want = Cvb("wm_heldmag_preview", false);
		for (int h = 0; h < 2; h++)
		{
			let rig = ph.rigs[1 - h];
			let st  = ph.hstate[h];
			// NEVER INTO A HAND RS_WorldHands HOLDS A MAGAZINE IN. Carrying() would wipe
			// FOREIGN, and PoseHand would then publish a Magazine subject for that hand
			// and stand RS_WorldHands down -- where the old foreign pointer stayed set
			// and published nothing.
			if (want && !st.preview && !st.Carried() && st.mode != WM_HandState.GUIDE && st.HeldPart() < 0 && rig.card
				&& st.mode != WM_HandState.FOREIGN && !ForeignInHand(ph, h))
			{
				let m = WM_LooseMag(Actor.Spawn("WM_LooseMag", HandPos(pmo, h), ALLOW_REPLACE));
				if (!m) continue;
				m.Setup(0, rig.card);
				InHand(m, h);
				st.Carrying(m);
				st.preview = true;
			}
			else if (!want && st.preview)
			{
				let pm = st.Carried();
				if (pm) pm.Destroy();
				st.Clear();
			}
		}
	}

	// ---- markers ---------------------------------------------------------------
	private WM_Marker NextMarker()
	{
		if (markerUsed >= markers.Size()) markers.Push(null);
		if (!markers[markerUsed])
			markers[markerUsed] = WM_Marker(Actor.Spawn("WM_Marker", (0, 0, 0), ALLOW_REPLACE));
		return markers[markerUsed++];
	}

	private void DrawMarkers(WM_PlayerHands ph, PlayerPawn pmo)
	{
		markerUsed = 0;
		if (Cvb("wm_show_grabs", true))
		{
			for (int r = 0; r < 2; r++)
			{
				let rig = ph.rigs[r];
				if (!rig.card || !rig.prop || !rig.resolved || rig.stowed) continue;
				int w = 1 - r;
				int usedSlots = 0;   // the grab slots drawn for this gun this pass, one bit each
				Vector3 hp = HandPos(pmo, w);
				for (int i = 0; i < rig.card.parts.Size(); i++)
				{
					let part = rig.card.parts[i];
					if (!rig.card.PartIsWorkable(i)) continue;
					// THE BRACE'S OVAL IS HIDDEN until bracing is taken on. Two-handed
					// bracing has never been seen to work here -- only the engine's
					// stock two-hand mechanic has -- so this hides a grab point, not
					// a working feature. A TWO-HANDED gun's support oval (card `hands = 2`) is
					// always drawn: the other hand must find it for the trigger to fire.
					if (part.role == "support" && !BraceOn() && !rig.card.NeedsTwoHands()) continue;
					Vector3 at, raw;
					Vector3 axes;
					bool hot;
					if (part.role == "feed" && !part.present)
					{
						// The magazine is out: show where one goes back IN.
						at   = rig.WellPoint();
						raw  = rig.WellPointRaw();
						double wr = Cvf("wm_well_radius", 3.0);
						axes = (wr, wr, wr);
						hot  = (hp - at).Length() <= wr || ph.hstate[w].HeldPart() == i;
					}
					else
					{
						at   = rig.PartPoint(i);
						raw  = rig.PartPointRaw(i);
						axes = rig.DrawAxes(i, part);
						hot  = part.handTake && (rig.HandInGrab(i, part, hp) || ph.hstate[w].HeldPart() == i);
					}
					let mk = NextMarker();
					// Seated in the gun's frame, so it stays on the gun with the
					// menu open -- and carries the live tuning set only for the
					// gun the tuner has selected.
					Name tune = (int(Cvf("wm_tune_gun", 0)) == rig.hand) ? 'wm_grab_all' : 'None';
					// The well is its own slider; a part answers to whichever
					// radius slider outranks the card for it.
					Name rcv = (part.role == "feed" && !part.present) ? 'wm_well_radius' : rig.RadiusCVar(i);
					// ITS OWN CHANNELS only while it is the part being tuned (WM_Rig.IsTuned); otherwise the card's.
					if (mk) mk.PlaceInFrame(rig.prop, rig.SeatFor(raw), rig.FrameUnits(), tune,
						at, axes, hot, WM_Marker.KIND_PART, rcv,
						rig.OwnSeatCVar(i), rig.OwnShapePrefix(i));
					// A TWO-HANDED gun's support grip (card `hands = 2`) goes to the grab page as
					// "grip", which the page lists; a brace stays "support", which it does not.
					String markRole = part.role;
					if (markRole == "support" && rig.card.NeedsTwoHands()) markRole = "grip";
					MarkEdited(rig, i, markRole .. "|" .. part.id, raw, at, axes);
					if (i < SEL_PER_GUN) usedSlots |= 1 << i;
				}

				// THE LOAD POINTS (verb.zs LOAD), drawn exactly as a part is: seated in the
				// gun's frame, carrying the whole-gun tuning set for the selected gun, and
				// this load point's own three channels from its grab slot (rig.LoadTagIndex)
				// -- nudge, shape, reach -- all renderer-read, sized by the very oval
				// rig.LoadDepth tests. Listed on the grab-point page as "load zone: <id>".
				if (rig.LoadActive())
				{
					for (int k = 0; k < rig.card.verbs.Size(); k++)
					{
						let lv = rig.card.verbs[k];
						if (lv.kind != WM_Verb.LOAD) continue;
						Vector3 lat   = rig.LoadPoint(k);
						Vector3 lraw  = rig.LoadPointRaw(k);
						Vector3 laxes = rig.LoadDrawAxes(k);
						bool    lhot  = rig.LoadDepth(k, hp) <= 1.0;
						let lmk = NextMarker();
						Name ltune = (int(Cvf("wm_tune_gun", 0)) == rig.hand) ? 'wm_grab_all' : 'None';
						int lt = rig.LoadTagIndex(k);
						if (lt < 0)
						{
							if (lmk) lmk.PlaceInFrame(rig.prop, rig.SeatFor(lraw), rig.FrameUnits(), ltune,
								lat, laxes, lhot, WM_Marker.KIND_PART);
							continue;
						}
						if (lmk) lmk.PlaceInFrame(rig.prop, rig.SeatFor(lraw), rig.FrameUnits(), ltune,
							lat, laxes, lhot, WM_Marker.KIND_PART, rig.RadiusCVar(lt),
							rig.OwnSeatCVar(lt), rig.OwnShapePrefix(lt));
						MarkEdited(rig, lt, "load|" .. lv.id, lraw, lat, laxes);
						usedSlots |= 1 << lt;
					}
				}
				for (int s = 0; s < SEL_PER_GUN; s++)
					if (!(usedSlots & (1 << s))) ForgetEdited(rig.hand, s);
			}
			double pr = PouchRadius();
			for (int i = 0; i < PouchSites(); i++)
			{
				Vector3 at = PouchPoint(pmo, i);
				bool hot = (HandPos(pmo, 0) - at).Length() <= pr || (HandPos(pmo, 1) - at).Length() <= pr;
				let mk = NextMarker();
				if (mk) mk.PlaceAt(at, (pr, pr, pr), hot, WM_Marker.KIND_POUCH, 'wm_belt_radius');
			}
		}
		for (int i = markerUsed; i < markers.Size(); i++)
			if (markers[i]) markers[i].Conceal();
	}

	// A SMALL BUZZ ON THE WAY INTO REACH -- a part, the pouch, or the mouth of
	// the well with a magazine in hand -- so where a grab will land can be FELT,
	// not only found. Once per entry, never while you stay inside.
	private void ReachBuzz(WM_PlayerHands ph, PlayerPawn pmo)
	{
		bool on = Cvb("wm_reach_buzz", true);
		for (int h = 0; h < 2; h++)
		{
			let rig = ph.rigs[1 - h];
			let st  = ph.hstate[h];
			int code = -1;
			if (st.HeldPart() < 0 && st.mode != WM_HandState.GUIDE)
			{
				let cm = st.Carried();
				if (cm)
				{
					if (CanSeat(h, rig, cm) && NearWell(pmo, h, rig)) code = 200;
					else if (rig.LoadTakes(cm) && rig.LoadActive())
					{
						int blk = rig.LoadVerbAt(HandPos(pmo, h));
						if (blk >= 0) code = 300 + blk;
					}
				}
				else
				{
					int near = NearestPart(ph, pmo, h, rig, true);
					if (near >= 0) code = near;
					else if (rig.card && HandInPouch(pmo, h) >= 0) code = 100;
				}
			}
			if (on && code >= 0 && code != ph.lastReach[h]) level.VRHaptic(h, 0.25, 8.0);
			ph.lastReach[h] = code;
		}
	}

	// ---- the live readout --------------------------------------------------------
	//
	// "HOW IS IT DETECTING" -- answered on the HUD, every tic, in the numbers the
	// decisions are actually made from. For each hand: what it holds, which gun
	// it works, what the grip is doing, and how far it is from every part next to
	// the reach that part needs. Composed here in the playsim, because that is
	// where the numbers live; drawn by RenderOverlay below.
	private void Hud(String s, int col)
	{
		if (hudCount >= HUD_MAX) return;
		hudLine[hudCount] = s;
		hudColor[hudCount] = col;
		hudCount++;
	}

	private void BuildHud(WM_PlayerHands ph, PlayerPawn pmo)
	{
		hudCount = 0;
		// Composed whenever EITHER the HUD or the log wants it -- switching the
		// on-screen readout off must not also blind the log.
		if (!Cvb("wm_overlay", true) && !Cvb("wm_log_hud", true)) return;
		let pl = pmo.player;

		for (int h = 0; h < 2; h++)
		{
			let rig = ph.rigs[1 - h];
			let st  = ph.hstate[h];
			let carriedMag = st.Carried();
			int held = st.HeldPart();
			Weapon inHand = (h == 0) ? pl.ReadyWeapon : pl.OffhandWeapon;
			String holds = "nothing";
			if (inHand) holds = inHand.GetClassName();

			String doing = "free";
			if (st.mode == WM_HandState.GUIDE && rig.card)
			{
				let feed = rig.card.FindRole("feed");
				double v = feed ? rig.DrawnValue(feed) : 0.0;
				doing = String.Format("SEATING -- in to %.2f, seats at %.2f", v, SeatAtFor(rig, rig.card.FindRoleIndex("feed")));
			}
			else if (carriedMag)
			{
				if (carriedMag.IsRound())
					doing = String.Format("CARRYING a %s", (carriedMag.wmSubject == "") ? "round" : carriedMag.wmSubject);
				else if (carriedMag.IsLoader())
					doing = String.Format("CARRYING a loader (%d)", carriedMag.Amount);
				else
					doing = String.Format("CARRYING a magazine (%d)", carriedMag.Amount);
			}
			else if (held >= 0 && rig.card && held < rig.card.parts.Size())
			{
				let part = rig.card.parts[held];
				double v = rig.DrawnValue(part);
				if (WM_Verb.Enabled())
					doing = VerbHoldText(rig, held, part, v);
				else if (part.role == "action")
					doing = String.Format("HOLDING slide -- back %.2f, racks past 0.60%s", v, rig.pastBack ? " (will rack)" : "");
				else
					doing = String.Format("HOLDING magazine -- out %.2f, drops past %.2f, in hand at 0.97", v, part.dof.detach);
			}
			else if (st.mode == WM_HandState.BRACE) doing = "BRACING the other gun";
			else if (st.ForeignMag()) doing = "RS_WorldHands put a magazine in this hand";

			Hud(String.Format("%s HAND   holds %s   grip %s   %s",
				h == 0 ? "MAIN" : "OFF", holds, GripHeld(pmo, h) ? "SQUEEZED" : "open", doing), Font.CR_GOLD);

			if (!rig.card)
			{
				Hud("   works: no carded gun in the other hand", Font.CR_DARKGRAY);
			}
			else if (!rig.prop || !rig.resolved)
			{
				Hud(String.Format("   works the %s -- NOT READY: gun drawn %s, parts found %s",
					rig.card.weaponClass, rig.prop ? "yes" : "NO", rig.resolved ? "yes" : "NO"), Font.CR_RED);
			}
			else
			{
				Hud(String.Format("   works the %s%s", rig.card.weaponClass, rig.stowed ? "  (put away: its own hand is busy)" : ""), Font.CR_GRAY);
				Vector3 hp = HandPos(pmo, h);
				for (int i = 0; i < rig.card.parts.Size(); i++)
				{
					let part = rig.card.parts[i];
					if (!rig.card.PartIsWorkable(i)) continue;
					String label = part.id;
					Vector3 at;
					double rad;
					bool inReach;
					if (part.role == "feed" && !part.present)
					{
						label = "the well";
						at  = rig.WellPoint();
						rad = Cvf("wm_well_radius", 3.0);
						inReach = (hp - at).Length() <= rad;
					}
					else
					{
						at  = rig.PartPoint(i);
						rad = rig.GrabRadius(i, part);
						inReach = rig.HandInGrab(i, part, hp);
					}
					double d = (hp - at).Length();
					String what = "";
					if (inReach)
					{
						if (part.role == "support")
						{
							if (rig.card.NeedsTwoHands()) what = "  IN REACH -- squeeze to hold it: it fires only while you do";
							else what = BraceOn() ? "  IN REACH -- you are bracing" : "  (bracing is off)";
						}
						else if (label == "the well")
						{
							WM_LooseMag inHand = carriedMag;
							if (!inHand) inHand = st.ForeignMag();
							String why = SeatRefusal(h, rig, inHand);
							what = (why == "") ? "  IN REACH -- it will catch the magazine" : ("  in reach, but " .. why);
						}
						else what = part.handTake ? "  IN REACH -- squeeze to take it" : "  (not taken by hand -- its button drops it)";
					}
					Hud(String.Format("     %-9s %5.1f away, reach %.1f%s", label, d, rad, what),
						inReach ? Font.CR_GREEN : Font.CR_WHITE);
				}

				// EACH LOAD POINT: how far, its oval, what its store holds, and -- with a
				// round in this hand inside it -- whether it will go in, and if not, why.
				if (rig.LoadActive())
				{
					WM_LooseMag heldRound = carriedMag;
					if (!heldRound) heldRound = st.ForeignMag();
					for (int k = 0; k < rig.card.verbs.Size(); k++)
					{
						let lv = rig.card.verbs[k];
						if (lv.kind != WM_Verb.LOAD) continue;
						Vector3 lat = rig.LoadPoint(k);
						Vector3 lax = rig.LoadAxes(k);
						bool lin = rig.LoadDepth(k, hp) <= 1.0;
						let lstore = rig.ammo.FindStore(lv.intoStore);
						String lholds = lstore ? lstore.Contents() : ("no store " .. lv.intoStore);
						String lwhat = "";
						if (lin)
						{
							if (heldRound && rig.LoadTakes(heldRound))
							{
								String lwhy = rig.LoadWhy(lv, heldRound);
								lwhat = (lwhy == "") ? "  IN REACH -- open your hand and it goes in" : ("  in reach, but " .. lwhy);
							}
							else lwhat = "  IN REACH -- bring a round to it";
						}
						Hud(String.Format("     load %-4s %5.1f away, oval %.1f x %.1f x %.1f, %s%s", lv.id, (hp - lat).Length(),
							lax.X, lax.Y, lax.Z, lholds, lwhat),
							lin ? Font.CR_GREEN : Font.CR_WHITE);
					}
				}
			}

			double pd = PouchDistance(pmo, h);
			double pr = PouchRadius();
			String pouchIn = carriedMag ? "  IN -- open your hand to put it back" : "  IN -- squeeze for a magazine";
			// A SECOND BARREL WAITING (card.zs WM_Barrel) is what a squeeze draws for, first.
			WM_Barrel hudWaiting;
			int hudLoad;
			if (!carriedMag && rig.card && WM_Verb.Enabled() && rig.card.barrels.Size() > 0)
			{
				[hudWaiting, hudLoad] = BarrelAwaitingRound(rig);
			}
			if (hudWaiting)
				pouchIn = String.Format("  IN -- squeeze for a %s for barrel %s", rig.card.verbs[hudLoad].subject == "" ? "round" : rig.card.verbs[hudLoad].subject, hudWaiting.id);
			else if (!carriedMag && rig.card && WM_Verb.Enabled() && rig.card.barrels.Size() > 0 && rig.card.KeepsNoRounds())
				pouchIn = "  IN -- nothing to draw: " .. BarrelShutText(rig);
			else if (!carriedMag && rig.card && WM_Verb.Enabled() && rig.card.PouchGivesRounds())
				pouchIn = String.Format("  IN -- squeeze for a %s", rig.card.RoundSubject());
			else if (!carriedMag && rig.card && WM_Verb.Enabled() && rig.card.PouchGivesLoader())
				pouchIn = "  IN -- squeeze for a loader";
			Hud(String.Format("     %-9s %5.1f away, reach %.1f%s", "pouch", pd, pr,
				pd <= pr ? pouchIn : ""),
				pd <= pr ? Font.CR_GREEN : Font.CR_WHITE);
		}

		for (int r = 0; r < 2; r++)
		{
			let rig = ph.rigs[r];
			if (!rig.card || !rig.ammo) continue;
			// THE SANITY LINE. The gun's own origin, through the same transform
			// every grab point uses, measured against the hand holding it. A
			// number in the tens or hundreds means that transform is wrong, and
			// with it every grab point on that gun.
			double gd = rig.prop ? (rig.World((0, 0, 0)) - HandPos(pmo, r)).Length() : -1.0;
			if (rig.card.HasVerbKind(WM_Verb.SWAP))
			{
				Hud(String.Format("%s: %d + %s, magazine %s, slide %s   drawn %.1f from its hand%s",
					rig.card.weaponClass, rig.ammo.rounds, rig.card.FiresFromMagazine() ? "no chamber" : (rig.ammo.chambered ? "1" : "0"),
					rig.ammo.magIn ? "in" : "OUT", rig.ammo.actionLock ? "LOCKED BACK" : "closed",
					gd, gd > 30.0 ? "  <- TOO FAR, grab points are wrong" : ""),
					gd > 30.0 ? Font.CR_RED : Font.CR_CYAN);
			}
			else
			{
				// A GUN WITH NO MAGAZINE: its stores by name, and whether its action is in
				// battery -- a tube and a chamber say more than "magazine in".
				String act = "closed";
				if (WM_Verb.Enabled() && !rig.InBattery()) act = "OPEN";
				Hud(String.Format("%s: %s, action %s   drawn %.1f from its hand%s",
					rig.card.weaponClass, rig.ammo.StoreCounts(), act,
					gd, gd > 30.0 ? "  <- TOO FAR, grab points are wrong" : ""),
					gd > 30.0 ? Font.CR_RED : Font.CR_CYAN);
			}
		}
		Hud(String.Format("reserve %s   spheres: gold = pouch, blue = a part, green = in reach   path %s", ReserveText(ph, pmo),
			WM_Verb.Enabled() ? "VERBS" : "OLD"), Font.CR_DARKGRAY);
		LogHud(ph, pmo);
	}

	// THE RESERVE, AS THE HUD AND wm_dump SAY IT: one number while both hands' guns fire
	// the same ammunition -- the pistols' Clip, exactly as before -- and each by name
	// when they differ.
	private String ReserveText(WM_PlayerHands ph, PlayerPawn pmo)
	{
		Class<Ammo> first = null;
		Class<Ammo> second = null;
		for (int r = 0; r < 2; r++)
		{
			let rig = ph.rigs[r];
			if (!rig || !rig.card) continue;
			Class<Ammo> c = WM_LooseMag.ReserveFor(rig.card.weaponClass);
			if (!first) first = c;
			else if (c != first && !second) second = c;
		}
		Class<Ammo> clipClass = "Clip";
		if (!first) first = clipClass;
		if (!second) return String.Format("%d", pmo.CountInv(first));
		return String.Format("%s %d, %s %d", GetDefaultByType(first).GetClassName(), pmo.CountInv(first),
			GetDefaultByType(second).GetClassName(), pmo.CountInv(second));
	}

	// THE READOUT, INTO THE LOG AS WELL.
	//
	// So a test can be read back afterwards line for line, without anyone
	// reading numbers aloud from inside a headset. PRINT_NONOTIFY: it goes to
	// the console and the log file and never flashes across your view.
	//
	// A snapshot on a steady interval, and -- the one that matters -- one on the
	// exact tic either grip closes or opens. That snapshot holds the distance to
	// every part against the reach it needed at the instant of the squeeze,
	// which is the whole answer to "why didn't it grab".
	//
	// The log is build-dxr/RelWithDebInfo/log-debug.txt, and each launch
	// overwrites it. The grip each hand had at the last snapshot is the
	// player's (WM_PlayerHands.lastGripHud).
	private void LogHud(WM_PlayerHands ph, PlayerPawn pmo)
	{
		String reason = "";
		for (int h = 0; h < 2; h++)
		{
			bool g = GripHeld(pmo, h);
			if (g != ph.lastGripHud[h])
				reason = reason .. (reason == "" ? "" : ", ") .. HandName(h) .. (g ? " grip SQUEEZED" : " grip opened");
			ph.lastGripHud[h] = g;
		}
		if (!Cvb("wm_log_hud", true) || hudCount <= 0) return;

		int every = int(max(1.0, Cvf("wm_log_hud_every", 70.0)));
		if (reason == "")
		{
			if ((level.maptime % every) != 0) return;
			reason = String.Format("every %d tics", every);
		}
		Console.PrintfEx(PRINT_LOW | PRINT_NONOTIFY, "---- WM HUD  tic %d  %s ----", level.maptime, reason);
		for (int i = 0; i < hudCount; i++)
			Console.PrintfEx(PRINT_LOW | PRINT_NONOTIFY, "%s", hudLine[i]);
	}

	override void RenderOverlay(RenderEvent e)
	{
		if (hudCount <= 0) return;
		let c = CVar.GetCVar("wm_overlay", players[consoleplayer]);
		if (c && !c.GetBool()) return;
		Font f = SmallFont;
		int lh = f.GetHeight() + 1;
		int y = 8;
		for (int i = 0; i < hudCount; i++)
		{
			Screen.DrawText(f, hudColor[i], 8, y, hudLine[i],
				DTA_VirtualWidth, 640, DTA_VirtualHeight, 400, DTA_KeepRatio, true);
			y += lh;
		}
	}

	// ---- diagnostics -------------------------------------------------------------

	void Dump()
	{
		WM_Log.Rule("DUMP");
		let pmo = PlayerPawn(players[consoleplayer].mo);
		if (!set) { WM_Log.Err("no cards loaded."); return; }
		if (!pmo) { WM_Log.Err("no player."); return; }
		let ph = ForPlayer(consoleplayer);
		if (!ph) { WM_Log.Err("no hands for the console player."); return; }
		WM_Log.Info(String.Format("reserve %s rounds   arbiter %s   hands main %s  off %s",
			ReserveText(ph, pmo), arbiter ? "found" : "ABSENT",
			WM_Log.Vec(pmo.AttackPos), WM_Log.Vec(pmo.OffhandPos)));
		WM_Log.Info(String.Format("wm_verbs %s", WM_Verb.Enabled()
			? "ON -- the card verbs run every rack, drop and seat"
			: "OFF -- the old role code runs every rack, drop and seat"));
		for (int h = 0; h < 2; h++)
		{
			let st = ph.hstate[h];
			let cm = st.Carried();
			String c = cm ? String.Format("carrying %d", cm.Amount) : "empty";
			WM_Log.Info(String.Format("%s hand: holding part %d, %s, %s%s%s", HandName(h), st.HeldPart(), c,
				st.mode == WM_HandState.GUIDE ? "GUIDING a magazine, " : "", st.mode == WM_HandState.BRACE ? "BRACING, " : "",
				st.ForeignMag() ? "RS_WorldHands has a magazine in it" : ""));
			DumpHandState(ph, h);
		}
		for (int r = 0; r < 2; r++)
			ph.rigs[r].Dump(pmo, 1 - r, HandPos(pmo, 1 - r));
		WM_Log.Rule("end");
	}

	// THE STATE MACHINE, BY NAME. One line per hand: its mode, the part it is
	// on (with the part's name from the gun it works), the magazine it has, and
	// the flags that ride on a carry or a guide. So one headset test shows
	// whether the hand is in the state it should be.
	private void DumpHandState(WM_PlayerHands ph, int h)
	{
		let st  = ph.hstate[h];
		let rig = ph.rigs[1 - h];

		String partName = "";
		if (st.mode == WM_HandState.ONPART)
		{
			if (rig && rig.card && st.part >= 0 && st.part < rig.card.parts.Size())
				partName = " (" .. rig.card.parts[st.part].id .. ")";
			else
				partName = " (NOT A PART of the gun it works)";
		}

		String magText = "none";
		if (st.mag)
			magText = String.Format("%s, %d rounds, dressed as %s", st.mag.IsRound() ? "a round" : "a magazine", st.mag.Amount, st.mag.cardId);
		else if (st.mode == WM_HandState.CARRY || st.mode == WM_HandState.GUIDE || st.mode == WM_HandState.FOREIGN)
			magText = "GONE (destroyed out of the hand)";

		String flags = "";
		if (st.mode == WM_HandState.GUIDE) flags = flags .. (st.ours ? ", was our carry" : ", RS_WorldHands holds it");
		if (st.preview)   flags = flags .. ", PREVIEW";
		if (st.leftPouch) flags = flags .. ", has left the pouch";

		WM_Log.Info(String.Format("  player %d %s hand STATE %s -- part %d%s, magazine %s%s",
			ph.playerNum, HandName(h), st.ModeName(), st.part, partName, magText, flags));
	}

	void SelfTest()
	{
		WM_Log.Rule("self test");
		WM_Log.Info(String.Format("lumps  WMCARD %s  MODELDEF %s  SNDINFO %s  CVARINFO %s",
			Wads.CheckNumForFullName("WMCARD.txt")   >= 0 ? "found" : "MISSING",
			Wads.CheckNumForFullName("MODELDEF.txt") >= 0 ? "found" : "MISSING",
			Wads.CheckNumForFullName("SNDINFO.txt")  >= 0 ? "found" : "MISSING",
			Wads.CheckNumForFullName("CVARINFO.txt") >= 0 ? "found" : "MISSING"));
		Dump();
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		let pmo = PlayerPawn(players[e.Player].mo);
		// THIS MACHINE'S OWN UI (NETPLAY_SPEC section 8, P0): moving a pouch, baking a grab oval, the dump and
		// the self test read and write this machine's cvars and print to its console, so they act only on the
		// machine of the player who sent them. Another player's copy of the event, arriving here, does nothing.
		if (e.Name ~== "rs_body_edit" || e.Name ~== "rs_body_grab_main" || e.Name ~== "rs_body_grab_off"
			|| e.Name ~== "wm_bake_ofs" || e.Name ~== "wm_bake_shape" || e.Name ~== "wm_bake_go"
			|| e.Name ~== "wm_dump" || e.Name ~== "wm_selftest" || e.Name.Left(8) ~== "wm_card:")
		{
			if (e.Player == consoleplayer) LocalUiEvent(e, pmo);
			return;
		}
		// THE SENDER'S GUNS (NETPLAY_SPEC section 8, P0): the drop-mag buttons and the test controls act on the
		// hands of the player who SENT them, never on this machine's console player -- another player's drop
		// must not drop your magazine. A machine makes hands only for the player it works (ForPlayer), so on any
		// other machine the event finds no hands and does nothing; P2's commands close that gap.
		let ph = HandsIfAny(e.Player);
		if (!ph || !pmo) return;
		if (e.Name ~== "wm_drop_main") { if (ph.rigs[0]) ButtonDrop(ph, pmo, 0); return; }
		if (e.Name ~== "wm_drop_off")  { if (ph.rigs[1]) ButtonDrop(ph, pmo, 1); return; }
		// TEST CONTROLS change a gun's state with no hand on it, so a netgame takes them only with sv_cheats
		// on. Both are the same on every machine (multiplayer, and sv_cheats as server info).
		if (!(e.Name ~== "wm_rack_main" || e.Name ~== "wm_rack_off" || e.Name ~== "wm_reset")) return;
		if (multiplayer && !CheatsOn())
		{
			if (e.Player == consoleplayer)
				Console.Printf("\c[Gold]WM: %s is a test control -- in a netgame it needs sv_cheats 1.", e.Name);
			return;
		}
		if (e.Name ~== "wm_rack_main" && ph.rigs[0] && ph.rigs[0].card) { RackTest(ph.rigs[0], pmo); return; }
		if (e.Name ~== "wm_rack_off"  && ph.rigs[1] && ph.rigs[1].card) { RackTest(ph.rigs[1], pmo); return; }
		if (e.Name ~== "wm_reset")
		{
			for (int r = 0; r < 2; r++) if (ph.rigs[r]) ph.rigs[r].Reset();
			return;
		}
	}

	private static bool CheatsOn()
	{
		let c = CVar.FindCVar("sv_cheats");
		return c && c.GetBool();
	}

	// THIS MACHINE'S UI EVENTS, from its own console player only (NetworkProcess): the console player's hands.
	private void LocalUiEvent(ConsoleEvent e, PlayerPawn pmo)
	{
		let ph = ForPlayer(consoleplayer);
		if (!ph) return;
		if (e.Name ~== "rs_body_edit")
		{
			ph.placeMode = !ph.placeMode;
			ph.placingSite[0] = -1; ph.placingSite[1] = -1;
			Console.Printf(ph.placeMode
				? "\c[Gold]WM: placement mode ON -- reach at a gold pouch and press grab to pick it up, again to drop it."
				: "\c[Gold]WM: placement mode off.");
			return;
		}
		if (e.Name ~== "rs_body_grab_main") { if (ph.placeMode && pmo) PouchGrab(ph, pmo, 0); return; }
		if (e.Name ~== "rs_body_grab_off")  { if (ph.placeMode && pmo) PouchGrab(ph, pmo, 1); return; }
		// BAKING GRAB TUNING INTO THE CARD (BUILD.md step 5): the grab-point page sends the scratch IN
		// three events (WM_BakeRow.SendBake), because a menu freezes the game and they run once it closes.
		if (e.Name ~== "wm_bake_ofs")   { bakeOfs   = (e.Args[0], e.Args[1], e.Args[2]) / 1000.0; return; }
		if (e.Name ~== "wm_bake_shape") { bakeShape = (e.Args[0], e.Args[1], e.Args[2]) / 1000.0; return; }
		if (e.Name ~== "wm_bake_go")    { BakePrint(ph, e.Args[0], e.Args[1] % 100, e.Args[1] / 100, e.Args[2] / 1000.0, true); return; }
		if (e.Name ~== "wm_dump")     { Dump(); return; }
		if (e.Name ~== "wm_selftest") { SelfTest(); return; }
		// THE CARD AND SHEET PRINTOUT (sheet.zs): `wm_card <weapon class> | all | check`, KEYCONF's alias for
		// `netevent wm_card:<arg>`. Prints only.
		if (e.Name.Left(8) ~== "wm_card:") { WM_SheetReader.Print(set, e.Name.Mid(8)); return; }
	}
}
