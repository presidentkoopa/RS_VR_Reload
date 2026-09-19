// ============================================================================
// HAND PROFILES -- WHERE YOUR HAND SITS ON A GUN, PER KIND OF GUN.
//
// WHY THIS EXISTS. The hand seats used to be per HAND and nothing else:
// wm_main_slide, wm_main_mag, wm_main_forend, wm_main_foregrip and the off hand's
// five, shared by every gun that put a hand on a part of that shape. A pistol's
// slide, a rifle's charging handle, an SMG's bolt and the stopgap revolvers'
// hammer all read wm_main_slide -- so the owner tuned the revolver and the pistol's
// hand moved with it. A hand on a pistol and a hand on a revolver are not the same
// wrist, and one set of numbers cannot serve both.
//
// SO EVERY SEAT SET IS PER PROFILE:  wm_hs_<profile>_<main|off>_<seat>
//
//   profile  a gun TYPE -- pistol, shotgun, breakaction, revolver, rifle, smg,
//            chaingun, plasma, launcher, bfg, railgun, flamethrower, chainsaw,
//            default -- or a card's own `handprofile`
//   main|off the GUN's hand, as the old sets were: _main_ is a hand on the gun in
//            your main hand (which is your off hand)
//   seat     WM_Rig.HandSeatKind: slide, mag, support, forend, foregrip
//
// WHICH SET A HAND READS, per seat -- the first that is declared:
//   1. the card's `handprofile = <name>`, when a weapon package declares that set
//   2. the card's TYPE: its `type = <name>`; unstated, its archetype's `type`, or
//      "pistol" for a card on pistol grammar (WM_Parser.FinishCard). A gun with no
//      type is "default" -- which wm_hs_uncalibrated may point at a type instead
//   3. wm_hs_default
// "Declared" is the set's _ofs_x cvar existing. A fallback is logged once.
//
// NOSAVE, NOT USER. A `user` cvar is USERINFO: every value goes over the wire to
// every other player at a netgame's start and again on every change, and these are
// 980 of them. `nosave` (CVAR_CONFIG_ONLY) keeps them in this machine's ini and out
// of userinfo and savegames. The renderer's GetPlacementCVar and CVar.GetCVar find
// them exactly as they find a user cvar, so the sliders still move the hand live.
//
// THE RENDERER READS EVERY ONE OF THESE by name (a hand's PlacementPrefix), so the
// sliders move the hand while the menu is open. Named at run time, so declared to
// the lint here. The old per-hand sets are declared in CVARINFO so the ini's saved
// values still load, and read by nothing -- DEPRECATED, listed as LINT-CVARS below.
//
// LINT-PREFIXES: wm_hs_default_main_slide wm_hs_default_main_mag wm_hs_default_main_support wm_hs_default_main_forend wm_hs_default_main_foregrip wm_hs_default_off_slide wm_hs_default_off_mag wm_hs_default_off_support wm_hs_default_off_forend wm_hs_default_off_foregrip
// LINT-PREFIXES: wm_hs_boltrifle_main_slide wm_hs_boltrifle_main_mag wm_hs_boltrifle_main_support wm_hs_boltrifle_main_forend wm_hs_boltrifle_main_foregrip wm_hs_boltrifle_off_slide wm_hs_boltrifle_off_mag wm_hs_boltrifle_off_support wm_hs_boltrifle_off_forend wm_hs_boltrifle_off_foregrip
// LINT-PREFIXES: wm_hs_mg_main_slide wm_hs_mg_main_mag wm_hs_mg_main_support wm_hs_mg_main_forend wm_hs_mg_main_foregrip wm_hs_mg_off_slide wm_hs_mg_off_mag wm_hs_mg_off_support wm_hs_mg_off_forend wm_hs_mg_off_foregrip
// LINT-PREFIXES: wm_hs_pump_main_slide wm_hs_pump_main_mag wm_hs_pump_main_support wm_hs_pump_main_forend wm_hs_pump_main_foregrip wm_hs_pump_off_slide wm_hs_pump_off_mag wm_hs_pump_off_support wm_hs_pump_off_forend wm_hs_pump_off_foregrip
// LINT-PREFIXES: wm_hs_flamer_main_slide wm_hs_flamer_main_mag wm_hs_flamer_main_support wm_hs_flamer_main_forend wm_hs_flamer_main_foregrip wm_hs_flamer_off_slide wm_hs_flamer_off_mag wm_hs_flamer_off_support wm_hs_flamer_off_forend wm_hs_flamer_off_foregrip
// LINT-PREFIXES: wm_hs_pistol_main_slide wm_hs_pistol_main_mag wm_hs_pistol_main_support wm_hs_pistol_main_forend wm_hs_pistol_main_foregrip wm_hs_pistol_off_slide wm_hs_pistol_off_mag wm_hs_pistol_off_support wm_hs_pistol_off_forend wm_hs_pistol_off_foregrip
// LINT-PREFIXES: wm_hs_shotgun_main_slide wm_hs_shotgun_main_mag wm_hs_shotgun_main_support wm_hs_shotgun_main_forend wm_hs_shotgun_main_foregrip wm_hs_shotgun_off_slide wm_hs_shotgun_off_mag wm_hs_shotgun_off_support wm_hs_shotgun_off_forend wm_hs_shotgun_off_foregrip
// LINT-PREFIXES: wm_hs_breakaction_main_slide wm_hs_breakaction_main_mag wm_hs_breakaction_main_support wm_hs_breakaction_main_forend wm_hs_breakaction_main_foregrip wm_hs_breakaction_off_slide wm_hs_breakaction_off_mag wm_hs_breakaction_off_support wm_hs_breakaction_off_forend wm_hs_breakaction_off_foregrip
// LINT-PREFIXES: wm_hs_revolver_main_slide wm_hs_revolver_main_mag wm_hs_revolver_main_support wm_hs_revolver_main_forend wm_hs_revolver_main_foregrip wm_hs_revolver_off_slide wm_hs_revolver_off_mag wm_hs_revolver_off_support wm_hs_revolver_off_forend wm_hs_revolver_off_foregrip
// LINT-PREFIXES: wm_hs_rifle_main_slide wm_hs_rifle_main_mag wm_hs_rifle_main_support wm_hs_rifle_main_forend wm_hs_rifle_main_foregrip wm_hs_rifle_off_slide wm_hs_rifle_off_mag wm_hs_rifle_off_support wm_hs_rifle_off_forend wm_hs_rifle_off_foregrip
// LINT-PREFIXES: wm_hs_smg_main_slide wm_hs_smg_main_mag wm_hs_smg_main_support wm_hs_smg_main_forend wm_hs_smg_main_foregrip wm_hs_smg_off_slide wm_hs_smg_off_mag wm_hs_smg_off_support wm_hs_smg_off_forend wm_hs_smg_off_foregrip
// LINT-PREFIXES: wm_hs_chaingun_main_slide wm_hs_chaingun_main_mag wm_hs_chaingun_main_support wm_hs_chaingun_main_forend wm_hs_chaingun_main_foregrip wm_hs_chaingun_off_slide wm_hs_chaingun_off_mag wm_hs_chaingun_off_support wm_hs_chaingun_off_forend wm_hs_chaingun_off_foregrip
// LINT-PREFIXES: wm_hs_plasma_main_slide wm_hs_plasma_main_mag wm_hs_plasma_main_support wm_hs_plasma_main_forend wm_hs_plasma_main_foregrip wm_hs_plasma_off_slide wm_hs_plasma_off_mag wm_hs_plasma_off_support wm_hs_plasma_off_forend wm_hs_plasma_off_foregrip
// LINT-PREFIXES: wm_hs_launcher_main_slide wm_hs_launcher_main_mag wm_hs_launcher_main_support wm_hs_launcher_main_forend wm_hs_launcher_main_foregrip wm_hs_launcher_off_slide wm_hs_launcher_off_mag wm_hs_launcher_off_support wm_hs_launcher_off_forend wm_hs_launcher_off_foregrip
// LINT-PREFIXES: wm_hs_bfg_main_slide wm_hs_bfg_main_mag wm_hs_bfg_main_support wm_hs_bfg_main_forend wm_hs_bfg_main_foregrip wm_hs_bfg_off_slide wm_hs_bfg_off_mag wm_hs_bfg_off_support wm_hs_bfg_off_forend wm_hs_bfg_off_foregrip
// LINT-PREFIXES: wm_hs_railgun_main_slide wm_hs_railgun_main_mag wm_hs_railgun_main_support wm_hs_railgun_main_forend wm_hs_railgun_main_foregrip wm_hs_railgun_off_slide wm_hs_railgun_off_mag wm_hs_railgun_off_support wm_hs_railgun_off_forend wm_hs_railgun_off_foregrip
// LINT-PREFIXES: wm_hs_flamethrower_main_slide wm_hs_flamethrower_main_mag wm_hs_flamethrower_main_support wm_hs_flamethrower_main_forend wm_hs_flamethrower_main_foregrip wm_hs_flamethrower_off_slide wm_hs_flamethrower_off_mag wm_hs_flamethrower_off_support wm_hs_flamethrower_off_forend wm_hs_flamethrower_off_foregrip
// LINT-PREFIXES: wm_hs_chainsaw_main_slide wm_hs_chainsaw_main_mag wm_hs_chainsaw_main_support wm_hs_chainsaw_main_forend wm_hs_chainsaw_main_foregrip wm_hs_chainsaw_off_slide wm_hs_chainsaw_off_mag wm_hs_chainsaw_off_support wm_hs_chainsaw_off_forend wm_hs_chainsaw_off_foregrip
//
// THE AMMO SETS (FEEL_PLAN row 3, AmmoPrefix below): wm_ha_<profile>_<slot>, named at run time.
// LINT-PREFIXES: wm_ha_default_main_mag wm_ha_default_off_mag wm_ha_default_main_round wm_ha_default_off_round wm_ha_default_floor_mag wm_ha_default_floor_round
// LINT-PREFIXES: wm_ha_pistol_main_mag wm_ha_pistol_off_mag wm_ha_pistol_main_round wm_ha_pistol_off_round wm_ha_pistol_floor_mag wm_ha_pistol_floor_round
// LINT-PREFIXES: wm_ha_shotgun_main_mag wm_ha_shotgun_off_mag wm_ha_shotgun_main_round wm_ha_shotgun_off_round wm_ha_shotgun_floor_mag wm_ha_shotgun_floor_round
// LINT-PREFIXES: wm_ha_breakaction_main_mag wm_ha_breakaction_off_mag wm_ha_breakaction_main_round wm_ha_breakaction_off_round wm_ha_breakaction_floor_mag wm_ha_breakaction_floor_round
// LINT-PREFIXES: wm_ha_revolver_main_mag wm_ha_revolver_off_mag wm_ha_revolver_main_round wm_ha_revolver_off_round wm_ha_revolver_floor_mag wm_ha_revolver_floor_round
// LINT-PREFIXES: wm_ha_rifle_main_mag wm_ha_rifle_off_mag wm_ha_rifle_main_round wm_ha_rifle_off_round wm_ha_rifle_floor_mag wm_ha_rifle_floor_round
// LINT-PREFIXES: wm_ha_smg_main_mag wm_ha_smg_off_mag wm_ha_smg_main_round wm_ha_smg_off_round wm_ha_smg_floor_mag wm_ha_smg_floor_round
// LINT-PREFIXES: wm_ha_chaingun_main_mag wm_ha_chaingun_off_mag wm_ha_chaingun_main_round wm_ha_chaingun_off_round wm_ha_chaingun_floor_mag wm_ha_chaingun_floor_round
// LINT-PREFIXES: wm_ha_plasma_main_mag wm_ha_plasma_off_mag wm_ha_plasma_main_round wm_ha_plasma_off_round wm_ha_plasma_floor_mag wm_ha_plasma_floor_round
// LINT-PREFIXES: wm_ha_launcher_main_mag wm_ha_launcher_off_mag wm_ha_launcher_main_round wm_ha_launcher_off_round wm_ha_launcher_floor_mag wm_ha_launcher_floor_round
// LINT-PREFIXES: wm_ha_bfg_main_mag wm_ha_bfg_off_mag wm_ha_bfg_main_round wm_ha_bfg_off_round wm_ha_bfg_floor_mag wm_ha_bfg_floor_round
// LINT-PREFIXES: wm_ha_railgun_main_mag wm_ha_railgun_off_mag wm_ha_railgun_main_round wm_ha_railgun_off_round wm_ha_railgun_floor_mag wm_ha_railgun_floor_round
// LINT-PREFIXES: wm_ha_flamethrower_main_mag wm_ha_flamethrower_off_mag wm_ha_flamethrower_main_round wm_ha_flamethrower_off_round wm_ha_flamethrower_floor_mag wm_ha_flamethrower_floor_round
// LINT-PREFIXES: wm_ha_chainsaw_main_mag wm_ha_chainsaw_off_mag wm_ha_chainsaw_main_round wm_ha_chainsaw_off_round wm_ha_chainsaw_floor_mag wm_ha_chainsaw_floor_round
// DEPRECATED 2026-09-13, the old shared magazine and round sets: declared so saved values load, read by nothing.
// LINT-CVARS: wm_heldmag_main_ofs_x wm_heldmag_main_ofs_y wm_heldmag_main_ofs_z wm_heldmag_main_yaw wm_heldmag_main_pitch wm_heldmag_main_roll wm_heldmag_main_scale
// LINT-CVARS: wm_heldmag_off_ofs_x wm_heldmag_off_ofs_y wm_heldmag_off_ofs_z wm_heldmag_off_yaw wm_heldmag_off_pitch wm_heldmag_off_roll wm_heldmag_off_scale
// LINT-CVARS: wm_heldround_main_ofs_x wm_heldround_main_ofs_y wm_heldround_main_ofs_z wm_heldround_main_yaw wm_heldround_main_pitch wm_heldround_main_roll wm_heldround_main_scale
// LINT-CVARS: wm_heldround_off_ofs_x wm_heldround_off_ofs_y wm_heldround_off_ofs_z wm_heldround_off_yaw wm_heldround_off_pitch wm_heldround_off_roll wm_heldround_off_scale
// LINT-CVARS: wm_dropmag_ofs_x wm_dropmag_ofs_y wm_dropmag_ofs_z wm_dropmag_yaw wm_dropmag_pitch wm_dropmag_roll wm_dropmag_scale
// LINT-CVARS: wm_dropround_ofs_x wm_dropround_ofs_y wm_dropround_ofs_z wm_dropround_yaw wm_dropround_pitch wm_dropround_roll wm_dropround_scale
//
// DEPRECATED 2026-09-13: the old per-hand seat sets. Declared in CVARINFO only so the
// values doomxr.ini saved under them load without complaint. Nothing reads them.
// LINT-CVARS: wm_main_slide_ofs_x wm_main_slide_ofs_y wm_main_slide_ofs_z wm_main_slide_yaw wm_main_slide_pitch wm_main_slide_roll wm_main_slide_scale
// LINT-CVARS: wm_main_mag_ofs_x wm_main_mag_ofs_y wm_main_mag_ofs_z wm_main_mag_yaw wm_main_mag_pitch wm_main_mag_roll wm_main_mag_scale
// LINT-CVARS: wm_main_support_ofs_x wm_main_support_ofs_y wm_main_support_ofs_z wm_main_support_yaw wm_main_support_pitch wm_main_support_roll wm_main_support_scale
// LINT-CVARS: wm_main_forend_ofs_x wm_main_forend_ofs_y wm_main_forend_ofs_z wm_main_forend_yaw wm_main_forend_pitch wm_main_forend_roll wm_main_forend_scale
// LINT-CVARS: wm_main_foregrip_ofs_x wm_main_foregrip_ofs_y wm_main_foregrip_ofs_z wm_main_foregrip_yaw wm_main_foregrip_pitch wm_main_foregrip_roll wm_main_foregrip_scale
// LINT-CVARS: wm_off_slide_ofs_x wm_off_slide_ofs_y wm_off_slide_ofs_z wm_off_slide_yaw wm_off_slide_pitch wm_off_slide_roll wm_off_slide_scale
// LINT-CVARS: wm_off_mag_ofs_x wm_off_mag_ofs_y wm_off_mag_ofs_z wm_off_mag_yaw wm_off_mag_pitch wm_off_mag_roll wm_off_mag_scale
// LINT-CVARS: wm_off_support_ofs_x wm_off_support_ofs_y wm_off_support_ofs_z wm_off_support_yaw wm_off_support_pitch wm_off_support_roll wm_off_support_scale
// LINT-CVARS: wm_off_forend_ofs_x wm_off_forend_ofs_y wm_off_forend_ofs_z wm_off_forend_yaw wm_off_forend_pitch wm_off_forend_roll wm_off_forend_scale
// LINT-CVARS: wm_off_foregrip_ofs_x wm_off_foregrip_ofs_y wm_off_foregrip_ofs_z wm_off_foregrip_yaw wm_off_foregrip_pitch wm_off_foregrip_roll wm_off_foregrip_scale
// ============================================================================

class WM_HandProfile
{
	// THE PROFILES THIS PACKAGE DECLARES SETS AND A PAGE FOR, in the order
	// wm_hs_uncalibrated counts them (MENUDEF OptionValue WMHandProfiles). 0 is the
	// uncalibrated set itself.
	const PROFILE_COUNT = 14;

	static String TypeAt(int i)
	{
		switch (i)
		{
		case 0:  return "default";
		case 1:  return "pistol";
		case 2:  return "shotgun";
		case 3:  return "breakaction";
		case 4:  return "revolver";
		case 5:  return "rifle";
		case 6:  return "smg";
		case 7:  return "chaingun";
		case 8:  return "plasma";
		case 9:  return "launcher";
		case 10: return "bfg";
		case 11: return "railgun";
		case 12: return "flamethrower";
		case 13: return "chainsaw";
		}
		return "";
	}

	// A TYPE OR A PROFILE BECOMES PART OF A CVAR NAME -- wm_hs_<it>_main_slide_ofs_x --
	// so it is one lower-case word: a letter, then letters, digits and underscores.
	// "" when it is one; otherwise why not, for the card's refusal.
	static String WordProblem(String w)
	{
		// Length() is unsigned; an int copy keeps every comparison below signed.
		int wordLen = int(w.Length());
		if (wordLen == 0) return "is empty -- it names the hand seats, wm_hs_<word>_*";
		if (wordLen > 24) return "is longer than 24 characters -- it becomes part of every hand seat cvar's name";
		for (int i = 0; i < wordLen; i++)
		{
			int ch = w.ByteAt(i);
			bool isLetter = (ch >= 0x61 && ch <= 0x7A);
			bool isLater  = (ch >= 0x30 && ch <= 0x39) || ch == 0x5F;
			if (!isLetter && !(i > 0 && isLater))
				return String.Format("'%s' is not one lower-case word -- a letter, then letters, digits and _, because it becomes part of a cvar name (wm_hs_<word>_*)", w);
		}
		return "";
	}

	static String SetName(String profileName, int gunHand, String seat)
	{
		return String.Format("wm_hs_%s_%s_%s", profileName, (gunHand == 0) ? "main" : "off", seat);
	}

	static bool SetDeclared(String prefix)
	{
		return CVar.GetCVar(prefix .. "_ofs_x", players[consoleplayer]) != null;
	}

	// The card's type as its hands read it: stated, derived, or "default".
	static String TypeOf(WM_Card card)
	{
		if (!card || card.gunType == "") return "default";
		return card.gunType;
	}

	// WHAT A GUN WITH NO TYPE READS: wm_hs_uncalibrated's type, or its own set. The
	// owner's words: a gun that never says what it is can still be given a profile.
	static String UncalibratedReads()
	{
		let c = CVar.GetCVar("wm_hs_uncalibrated", players[consoleplayer]);
		int i = c ? c.GetInt() : 0;
		if (i <= 0 || i >= PROFILE_COUNT) return "default";
		return TypeAt(i);
	}

	// THE SET A HAND ON THIS GUN'S <seat> READS. Returns the prefix, the profile it
	// belongs to, and what it fell back past ("" when nothing was missing).
	static String, String, String SeatPrefix(WM_Card card, int gunHand, String seat)
	{
		String missed = "";
		if (card && card.handProfile != "")
		{
			String ownSet = SetName(card.handProfile, gunHand, seat);
			if (SetDeclared(ownSet)) return ownSet, card.handProfile, "";
			missed = String.Format("handprofile %s has no %s_* declared", card.handProfile, ownSet);
		}

		String gunKind = TypeOf(card);
		if (gunKind == "default") gunKind = UncalibratedReads();
		String typeSet = SetName(gunKind, gunHand, seat);
		if (SetDeclared(typeSet)) return typeSet, gunKind, missed;

		String noTypeSet = String.Format("type %s has no %s_* declared", gunKind, typeSet);
		missed = (missed == "") ? noTypeSet : (missed .. "; " .. noTypeSet);
		return SetName("default", gunHand, seat), "default", missed;
	}

	// FOR THE BIND LOG: which profile the card asks for, and why.
	static String Describe(WM_Card card)
	{
		if (!card) return "no card";
		String whence = (card.gunTypeFrom == "") ? "" : (" (" .. card.gunTypeFrom .. ")");
		String gunKind = TypeOf(card);
		if (card.handProfile != "")
			return String.Format("handprofile %s, over type %s%s", card.handProfile, gunKind, whence);
		if (gunKind == "default")
		{
			String reads = UncalibratedReads();
			if (reads != "default")
				return String.Format("no type%s -- uncalibrated, reading %s by wm_hs_uncalibrated", whence, reads);
			return String.Format("no type%s -- uncalibrated", whence);
		}
		return String.Format("type %s%s", gunKind, whence);
	}

	// A PROFILE'S PAGE. MENUDEF names them WM_HS_<Profile>; a Name is case-blind, so
	// "revolver" finds WM_HS_Revolver. A weapon package that declares its own
	// handprofile may declare a page by the same rule.
	static Name PageFor(String profileName)
	{
		return Name("WM_HS_" .. profileName);
	}

	// ---- THE AMMO SETS (FEEL_PLAN row 3) ---------------------------------------------------------
	//
	// A MAGAZINE OR A ROUND of a gun -- in either hand, or on the floor -- is drawn by a placement set
	// of its own gun's kind: wm_ha_<profile>_<slot>, slot main_mag, off_mag, main_round, off_round
	// (main and off: the hand HOLDING it), floor_mag or floor_round. The chain is the seats': the
	// card's handprofile when a weapon package declares that set, then its type (the uncalibrated
	// choice for a gun with none), then default. Resolved when the magazine or round is made
	// (WM_LooseMag.SetAmmoPrefixes), so a slider on a kind's page moves only that kind's.
	static String AmmoSetName(String profileName, String slot)
	{
		return String.Format("wm_ha_%s_%s", profileName, slot);
	}

	// THE SET A MAGAZINE OR ROUND OF THIS CARD'S GUN READS in a slot, and the profile it belongs to.
	static String, String AmmoPrefix(WM_Card card, String slot)
	{
		if (card && card.handProfile != "")
		{
			String ownSet = AmmoSetName(card.handProfile, slot);
			if (SetDeclared(ownSet)) return ownSet, card.handProfile;
		}
		String gunKind = TypeOf(card);
		if (gunKind == "default") gunKind = UncalibratedReads();
		String typeSet = AmmoSetName(gunKind, slot);
		if (SetDeclared(typeSet)) return typeSet, gunKind;
		return AmmoSetName("default", slot), "default";
	}

	// A PROFILE'S MAGAZINE-AND-ROUND PAGE, WM_HA_<Profile>, by the same case-blind rule as PageFor.
	static Name AmmoPageFor(String profileName)
	{
		return Name("WM_HA_" .. profileName);
	}
}

// ============================================================================
// THE GUN IN EACH HAND, ON THE HAND-SEAT PAGES.
//
// MENUDEF:  WMHandProfile "Main-hand gun", 0, "pistol"
//           (label, which hand's gun, the profile this page tunes -- "" on the hub)
//
// A menu cannot read a card: the game writes wm_hs_now_main / wm_hs_now_off every
// tic -- "<weapon class>|<profile its action seat reads>|<its type>" -- and this row
// reads it back, the way the grab page reads wm_gp_name_*. On a type page it says
// whether these sliders move that gun's hand; when they do not, selecting it opens
// the page that does. On the hub it always opens the gun's page.
// ============================================================================

class OptionMenuItemWMHandProfile : OptionMenuItem
{
	int    mGunHand;
	String mPage;
	String mBase;

	OptionMenuItemWMHandProfile Init(String label, int gunHand, String page)
	{
		Super.Init(label, "", true);
		mBase    = label;
		mGunHand = gunHand;
		mPage    = page.MakeLower();
		return self;
	}

	private String, String, String Now()
	{
		String s = WM_MenuCVar.GetS((mGunHand == 0) ? "wm_hs_now_main" : "wm_hs_now_off");
		Array<String> f;
		s.Split(f, "|");
		if (f.Size() < 3) return "", "", "";
		return f[0], f[1], f[2];
	}

	// Somewhere to go: a gun in that hand, reading a profile other than this page's.
	private bool CanJump()
	{
		String gunName, readsProfile, gunKind;
		[gunName, readsProfile, gunKind] = Now();
		if (gunName == "" || readsProfile == mPage) return false;
		return MenuDescriptor.GetDescriptor(PageFor(readsProfile)) != null;
	}

	// THE PAGE A PROFILE OPENS, and what that page's sliders move: a hand here; a gun's magazines
	// and rounds on the ammo pages (OptionMenuItemWMAmmoProfile below).
	virtual Name PageFor(String profileName) { return WM_HandProfile.PageFor(profileName); }
	virtual String MovesText() { return "THESE SLIDERS MOVE ITS HAND"; }

	override bool Selectable() { return CanJump(); }

	override bool Activate()
	{
		if (!CanJump()) return false;
		String gunName, readsProfile, gunKind;
		[gunName, readsProfile, gunKind] = Now();
		Menu.MenuSound("menu/advance");
		Menu.SetMenu(PageFor(readsProfile));
		return true;
	}

	override int Draw(OptionMenuDescriptor desc, int y, int indent, bool selected)
	{
		String gunName, readsProfile, gunKind;
		[gunName, readsProfile, gunKind] = Now();
		int ink = OptionMenuSettings.mFontColor;
		if (gunName == "")
			mLabel = mBase .. ": no carded gun in that hand";
		else
		{
			String said = (readsProfile == gunKind) ? readsProfile : String.Format("%s (type %s)", readsProfile, gunKind);
			if (mPage == "")
			{
				mLabel = String.Format("%s: %s -- %s", mBase, gunName, said);
				ink = OptionMenuSettings.mFontColorMore;
			}
			else if (readsProfile == mPage)
			{
				mLabel = String.Format("%s: %s -- %s", mBase, gunName, MovesText());
				ink = OptionMenuSettings.mFontColorValue;
			}
			else
			{
				mLabel = String.Format("%s: %s is %s -- not this page, select to go there", mBase, gunName, said);
				ink = OptionMenuSettings.mFontColorMore;
			}
		}
		int x = drawLabel(indent, y, selected ? OptionMenuSettings.mFontColorSelection : ink);
		return x - 16 * CleanXfac_1;
	}
}

// ============================================================================
// THE GUN IN EACH HAND, ON THE MAGAZINE-AND-ROUND PAGES (FEEL_PLAN row 3).
//
// MENUDEF:  WMAmmoProfile "Main-hand gun", 0, "pistol"
//
// The hand-seat row, opening WM_HA_<profile> instead. The profile it names is the one that gun's
// hand seats read (wm_hs_now_*): the same chain the ammo sets take, so they agree unless a card's
// own handprofile declares seats and no ammo sets -- then its magazines read its type's page, and
// the bind log's AmmoPrefix says so.
// ============================================================================

class OptionMenuItemWMAmmoProfile : OptionMenuItemWMHandProfile
{
	override Name PageFor(String profileName) { return WM_HandProfile.AmmoPageFor(profileName); }
	override String MovesText() { return "THESE SLIDERS MOVE ITS MAGAZINES AND ROUNDS"; }
}
