// ============================================================================
// A MAGAZINE THAT HAS LEFT THE GUN, AND A ROUND RACKED OUT OF ONE.
//
// THEY ARE AMMUNITION, LITERALLY. Both derive from Clip, so Doom treats them as
// the same pool everything else uses: walked over, a magazine's rounds go into
// your reserve; a racked-out round is one round. And RS_WorldHands' grab policy
// already carries a rule for Ammo -- grabbable, laser-grabbable, held with the
// magazine pose -- so catching one out of the air is not written here. It
// already exists, and these qualify.
//
// ------------------------------------------------ WALK-OVER, AND WHY IT WAITS
//
// A magazine leaves the gun inside your own reach, so without a wait it is
// collected by standing there before it has fallen an inch. The wait is on
// WALKING, not on hands: reaching out for one works from the first tic.
//
// It is enforced in TryPickup rather than by clearing bSPECIAL, and that is not
// a style choice. RS_WorldHands owns bSPECIAL on anything grabbable and resets
// it to the class default the moment a thing spawns -- so a timer written on
// that flag loses on the very first tic, and a magazine could be picked up by
// your own feet as it left the gun. Refusing the pickup itself has one writer.
//
// ------------------------------------------------------------ WHERE IT IS
//
// ONE WRITER FOR ITS PLACEMENT: THIS ACTOR. In a hand (ours or RS_WorldHands')
// it is drawn in that controller's frame; on the floor it is an ordinary world
// object. The sliders and the scale differ between the two, so it reads
// FollowHandMode every tic and picks its own prefix and size. That is how
// RS_WorldHands can pick one up and have it sit right without knowing this
// class exists.
// ============================================================================

class WM_LooseMag : Clip
{
	Default
	{
		Inventory.Amount 0;
		Inventory.PickupMessage "Magazine";
		-COUNTITEM
		+NOTELEPORT
		+DONTSPLASH
		+NOTONAUTOMAP
		Radius 3;
		Height 3;
		Gravity 0.9;
		RenderStyle "Normal";
	}

	int    capacity;
	int    graceTics;
	String cardId;         // the weapon this magazine came out of
	String magFamily;      // the guns it fits -- see WM_Card.magFamily
	double worldScale;     // on the floor
	int    lastHeldTic;
	int    lastHand;
	int    heldBy;         // -1 on the floor, 0 main hand, 1 off hand
	int    droppedBy;      // the hand whose gun dropped it, plus one; 0 none
	int    dropTic;
	// WHERE ITS ROUNDS GO BACK TO, when that is not its gun's own reserve: a second barrel's
	// named ammo (card.zs WM_Barrel `ammo`) -- a grenade drawn for an underbarrel launcher goes
	// back to the grenades, not to the machine gun's bullets. Empty for everything else.
	String reserveName;
	// A ROUND'S SHAPE IN THE HAND: "shell" or "round", from its gun's load verb
	// (WM_Card.RoundSubject). A load point that states a subject takes only that.
	// Empty on a magazine, and on a round from a save before this -- read as "round".
	String wmSubject;
	// ITS LANDING SOUND (card `magdropsound` / `casingsound`, or the owner's pick in VR Weapon Sound Selection,
	// WM_SoundPick): the card's sound when it was made, and the player whose picks apply, plus one (0 none).
	// Its gun is cardId. Resolved at each landing. It landed on a fixed wm/magdrop or wm/casing before.
	String wmLandSound;
	int    wmSoundOwner;

	private int    bounces;
	private bool   landed;
	private double spinP, spinR;
	protected int  still;  // tics lying at rest

	virtual bool   IsRound() { return false; }

	// A LOADER, not a magazine: a speedloader or a clip, holding several rounds that all
	// go into a gun's slots at once (verb.zs LOAD, subject = loader). The same object as a
	// magazine -- its gun's magmodel, its rounds in Amount, held on the held-magazine
	// sets -- but it seats in nothing; a load point takes it.
	bool IsLoader() { return wmSubject == "loader"; }

	void SetupLoader(int rounds, WM_Card card, Actor from = null)
	{
		Setup(rounds, card, from);
		wmSubject = "loader";
	}
	// ITS PLACEMENT SETS, per kind of gun (FEEL_PLAN row 3, WM_HandProfile.AmmoPrefix), resolved from
	// its gun's card when it is made (SetAmmoPrefixes) -- so tuning a revolver's speedloader never
	// moves a pistol's magazine. Unset, on one from a save before them, the uncalibrated sets.
	Name heldMainSet, heldOffSet, floorSet;
	virtual Name   FloorPrefix() { return (floorSet != 'None') ? floorSet : 'wm_ha_default_floor_mag'; }
	virtual Name   HeldPrefix(int hand)
	{
		Name held = (hand == 0) ? heldMainSet : heldOffSet;
		if (held != 'None') return held;
		return (hand == 0) ? 'wm_ha_default_main_mag' : 'wm_ha_default_off_mag';
	}

	// what: "mag" or "round" -- a loader is drawn on its magazine's sets.
	protected void SetAmmoPrefixes(WM_Card card, String what)
	{
		String setName, setProfile;
		[setName, setProfile] = WM_HandProfile.AmmoPrefix(card, "main_" .. what);
		heldMainSet = Name(setName);
		[setName, setProfile] = WM_HandProfile.AmmoPrefix(card, "off_" .. what);
		heldOffSet = Name(setName);
		[setName, setProfile] = WM_HandProfile.AmmoPrefix(card, "floor_" .. what);
		floorSet = Name(setName);
		// ON THE FLOOR FROM ITS FIRST TIC, before Tick picks: a dropped magazine's turn is measured
		// against this set the tic it is made (WM_Rig.TurnLikeDrawn).
		PlacementPrefix = floorSet;
	}
	virtual String DropSound() { return WMLandingSound("magdrop", "wm/magdrop"); }
	protected String WMLandingSound(String slot, String unset)
	{
		String own = (wmLandSound != "") ? wmLandSound : unset;
		return WM_SoundPick.ForPlayer(wmSoundOwner - 1, cardId, slot, own);
	}

	static double Cvf(String n, double d)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetFloat() : d;
	}

	// from: the player who made it, whose sound picks its landing takes. Left as it was when not given.
	void Setup(int rounds, WM_Card card, Actor from = null)
	{
		Amount     = rounds;
		capacity   = max(1, card.capacity);
		cardId     = card.weaponClass;
		wmLandSound = card.magDropSound;
		if (from && from.player) wmSoundOwner = from.PlayerNumber() + 1;
		magFamily  = card.FamilyOfMags();
		worldScale = card.magScale > 0 ? card.magScale : 0.3;
		// A SPENT MAGAZINE WEARS ITS SPENT SKIN (card magskinempty) when the card has one -- a BFG's dead cell.
		if (rounds <= 0 && card.magSkinEmptyFile != "")
			WearMesh(card.magModelPath, card.magModelFile, card.magSkinEmptyPath, card.magSkinEmptyFile);
		else
			WearMesh(card.magModelPath, card.magModelFile, card.magSkinPath, card.magSkinFile);
		SetAmmoPrefixes(card, "mag");
		A_SetScale(worldScale);
		Recolour();
	}

	protected void WearMesh(String path, String file, String skinPath, String skin)
	{
		if (file == "") return;
		A_ChangeModel(GetClassName(), 0, path, file, 0, skinPath, skin);
	}

	// WHERE ITS ROUNDS GO IN YOUR RESERVE: the ammunition of the gun it came from
	// (Weapon.AmmoType1, off that class's defaults), so a shell goes to Shell and a
	// pistol magazine to Clip. Clip when the gun is unknown -- what every magazine
	// was before a gun could fire anything else.
	static Class<Ammo> ReserveFor(String weaponClass)
	{
		Class<Ammo> fallback = "Clip";
		if (weaponClass == "") return fallback;
		Class<Weapon> wc = (Class<Weapon>)(Object.FindClass(weaponClass, "Weapon"));
		if (!wc) return fallback;
		let def = GetDefaultByType(wc);
		if (def && def.AmmoType1) return def.AmmoType1;
		return fallback;
	}

	// WHERE THIS ONE'S ROUNDS GO IN YOUR RESERVE: its named ammo when it has one and a loaded
	// package declares it (reserveName, a second barrel's round), else its gun's (ReserveFor).
	Class<Ammo> ReserveClass()
	{
		if (reserveName != "")
		{
			Class<Ammo> named = (Class<Ammo>)(Object.FindClass(reserveName, "Ammo"));
			if (named) return named;
		}
		return ReserveFor(cardId);
	}

	// NEUTRAL IF EMPTY, OTHERWISE RED THROUGH GREEN BY WHAT IS LEFT.
	//
	// An empty magazine carries no colour and no light -- it reads as litter,
	// which is what it is. One round left is red; full is green.
	//
	// THE LIGHT SITS ABOVE IT, not at its centre. A point light inside a mesh
	// lights none of its faces -- every one of them faces away from it -- so a
	// glow at the centre lit the floor and left the magazine itself dark.
	virtual void Recolour()
	{
		if (Amount <= 0)
		{
			A_RemoveLight("wm_magglow");
			TintColor = 0;
			return;
		}
		// HOW FULL, BY COLOUR: green full, yellow half, red nearly empty. Scaled so
		// the brighter of red and green is always full strength -- a plain
		// crossfade is a muddy olive at half, and a tint that dark reads as dirt,
		// not as a colour. The model is TINTED (Actor.TintColor, texture kept) and
		// the light beside it is the same colour.
		double f = clamp(double(Amount) / double(max(1, capacity)), 0.0, 1.0);
		double k = 255.0 / max(1e-3, max(1.0 - f, f));
		int r = clamp(int((1.0 - f) * k), 0, 255);
		int g = clamp(int(f * k), 0, 255);
		TintColor = Color(255, r, g, 40);
		A_AttachLight("wm_magglow", DynamicLight.PointLight, Color(255, r, g, 40),
			int(Cvf("wm_mag_glow", 14.0)), 0, DynamicLight.LF_ATTENUATE, (0, 0, 5));
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		if (capacity <= 0) capacity = 15;
		// NOT frandom. A loose magazine or round is spawned by the hands, which a netgame works on
		// one machine only, and a playsim draw there advances that RNG on that machine alone --
		// the next roll anywhere desyncs (jitter.zs). Hashed instead off when and where it
		// appeared, over the same ranges.
		int seedPos = int(pos.x * 16) ^ int(pos.y * 16) ^ int(pos.z * 16);
		spinP = WM_Jitter.Between(-14.0, 14.0, level.maptime, seedPos, 1);
		spinR = WM_Jitter.Between(-22.0, 22.0, level.maptime, seedPos, 2);
		heldBy = -1;
		lastHand = -1;
	}

	// Walked over. Refused in a hand, while a magazine well has it, and for the
	// grace period. After that it is ordinary ammunition.
	override bool TryPickup(in out Actor toucher)
	{
		if (graceTics > 0 || FollowHandMode != 0 || bINVISIBLE) return false;
		// A GUN THAT FIRES SOMETHING ELSE. This class IS a Clip, so walked over it
		// would feed the Clip reserve whatever gun it came out of. Its rounds go to
		// that gun's own ammunition instead -- or a second barrel's named ammo (ReserveClass);
		// a Clip gun's go the ordinary way.
		Class<Ammo> reserve = ReserveClass();
		Class<Ammo> clipClass = "Clip";
		if (reserve != clipClass)
		{
			let have = toucher.FindInventory(reserve);
			if (have && have.Amount >= have.MaxAmount) return false;
			toucher.GiveInventory(reserve, Amount);
			GoAwayAndDie();
			return true;
		}
		return Super.TryPickup(toucher);
	}

	override void Tick()
	{
		// THE FALL, READ BEFORE THE MOVE. The engine zeroes Vel.Z on the tic
		// it lands, so a bounce decided after Super.Tick() never sees how hard
		// it hit.
		double vz = Vel.Z;
		Super.Tick();
		if (Owner) return;

		if (graceTics > 0) graceTics--;

		int hand = (FollowHandMode == 1) ? 0 : ((FollowHandMode == 2) ? 1 : -1);
		heldBy = hand;
		if (hand >= 0) { lastHeldTic = level.maptime; lastHand = hand; }

		Name want = (hand >= 0) ? HeldPrefix(hand) : FloorPrefix();
		if (PlacementPrefix != want) PlacementPrefix = want;

		// In a hand it is drawn in the controller's frame, which is not in map
		// units: the renderer scales that frame by 0.01 and vr_vunits_per_meter
		// (34) on top, so one model unit there is 0.34 map units. One card
		// number serves both places because of this one ratio.
		double sc = worldScale;
		if (hand >= 0) sc = worldScale / max(0.01, Cvf("wm_world_factor", 0.34));
		if (abs(Scale.X - sc) > 1e-4) A_SetScale(sc);

		// IT GLOWS IN ITS OWN COLOUR once it is out of the hand -- falling or
		// lying, which is when you are looking for it. Fullbright with its tint;
		// an empty one has no tint and no glow. In the hand it is lit like the
		// hand holding it.
		bool glow = (hand < 0) && Amount > 0;
		if (bBRIGHT != glow) bBRIGHT = glow;

		if (hand >= 0) { landed = false; bounces = 0; still = 0; return; }
		if (bINVISIBLE) return;      // a magazine well has it

		if (landed)
		{
			still++;
			Lying();
			return;
		}

		// Airborne: it tumbles, the way a dropped magazine does.
		if (pos.Z > floorz + 0.5)
		{
			pitch += spinP;
			roll  += spinR;
			return;
		}

		// On the floor. Bounce while it still has something to give.
		double bf = Cvf("wm_bounce", 0.3);
		if (vz < -1.5 && bounces < 3 && bf > 0.01)
		{
			bounces++;
			Vel.Z = -vz * bf;
			Vel.XY *= 0.55;
			// NOT frandom (PostBeginPlay says why): off the tic, this bounce, and where it hit.
			int bounceSeed = int(pos.x * 16) ^ int(pos.y * 16);
			angle += WM_Jitter.Between(-35.0, 35.0, level.maptime, bounces, bounceSeed ^ 3);
			spinP  = WM_Jitter.Between(-16.0, 16.0, level.maptime, bounces, bounceSeed ^ 4);
			spinR  = WM_Jitter.Between(-26.0, 26.0, level.maptime, bounces, bounceSeed ^ 5);
			A_StartSound(DropSound(), CHAN_BODY, CHANF_OVERLAP, clamp(-vz / 8.0, 0.2, 1.0));
			return;
		}

		// AND IT LIES DOWN, on its side, the way RS Force Unleashed's magazine
		// settles. One standing upright reads as placed; one on its side reads
		// as dropped.
		landed = true;
		Vel = (0, 0, 0);
		pitch = 0;
		roll  = 90;
		angle += WM_Jitter.Between(-30.0, 30.0, level.maptime, bounces + 16, int(pos.x * 16) ^ int(pos.y * 16) ^ 6);   // NOT frandom (PostBeginPlay)
		if (vz < -0.5) A_StartSound(DropSound(), CHAN_BODY, CHANF_OVERLAP, 0.35);
	}

	// A magazine stays until it is taken -- a loaded one is worth crossing the
	// room for. AN EMPTY LOADER IS LITTER: it lies as long as a racked-out round does
	// (wm_round_life), then fades. One with rounds in it stays, like a magazine.
	virtual void Lying()
	{
		if (!IsLoader() || Amount > 0) return;
		if (still < int(Cvf("wm_round_life", 3150.0))) return;
		A_SetRenderStyle(Alpha, STYLE_Translucent);
		Alpha -= 0.03;
		if (Alpha <= 0) Destroy();
	}

	States
	{
	Spawn:
		WMMG A -1;
		Stop;
	}
}

// A LIVE ROUND, RACKED OUT OF A LOADED GUN.
//
// One round of ammunition, and it stays on the floor a long while -- racking a
// loaded pistol throws a good cartridge away, and the point of letting it lie
// there is that you can go and get it back.
class WM_LooseRound : WM_LooseMag
{
	Default
	{
		Inventory.PickupMessage "Round";
		Radius 2;
		Height 2;
		Gravity 0.8;
	}

	override bool   IsRound() { return true; }
	override Name   FloorPrefix() { return (floorSet != 'None') ? floorSet : 'wm_ha_default_floor_round'; }
	override Name   HeldPrefix(int hand)
	{
		Name held = (hand == 0) ? heldMainSet : heldOffSet;
		if (held != 'None') return held;
		return (hand == 0) ? 'wm_ha_default_main_round' : 'wm_ha_default_off_round';
	}
	override String DropSound() { return WMLandingSound("casing", "wm/casing"); }

	// A round has no "how full": its glint stays, and a throw does not tint it the way
	// it re-colours a magazine.
	override void Recolour() {}

	void SetupRound(WM_Card card, Actor from = null)
	{
		Amount     = 1;
		capacity   = 1;
		cardId     = card.weaponClass;
		wmLandSound = card.casingSound;
		if (from && from.player) wmSoundOwner = from.PlayerNumber() + 1;
		// WHICH GUNS IT FITS AND HOW IT IS HELD, from its gun's card -- asked only by a
		// load point (WM_Rig.LoadWhy), which a card with no load verb never has.
		magFamily  = card.FamilyOfMags();
		wmSubject  = card.RoundSubject();
		worldScale = card.roundScale > 0 ? card.roundScale : 0.17;
		WearMesh(card.roundModelPath, card.roundModelFile, card.roundSkinPath, card.roundSkinFile);
		SetAmmoPrefixes(card, "round");
		A_SetScale(worldScale);

		// A glint rather than a colour: a round has no "how full". Small and
		// warm, so a cartridge on a dark floor can still be found.
		A_AttachLight("wm_glint", DynamicLight.PointLight, Color(255, 255, 214, 130),
			int(Cvf("wm_round_glint", 8.0)), 0, DynamicLight.LF_ATTENUATE, (0, 0, 3));
	}

	override void Lying()
	{
		if (still < int(Cvf("wm_round_life", 3150.0))) return;
		// Fades rather than blinking out, so it is never "there, then not".
		A_SetRenderStyle(Alpha, STYLE_Translucent);
		Alpha -= 0.03;
		if (Alpha <= 0) Destroy();
	}

	States
	{
	Spawn:
		WMRD A -1;
		Stop;
	}
}
