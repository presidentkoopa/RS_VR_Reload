// ============================================================================
// A WEAPON SHEET: WHAT A GUN SHOOTS (WMSHEET lumps; RS_VR_Reload/THE_CARD_PLAN.md).
//
// A gun is two pieces of data. Its MODEL CARD (WMCARD, parser.zs) says how the physical gun works:
// parts, stores, verbs, grabs, meshes, handling sounds. Its WEAPON SHEET says what it shoots. A sheet
// is found by its weapon class's name, and every key is optional: a key a sheet does not state keeps
// the weapon class's own Default (WM_Gun.*), or the card's own value.
//
//   gun "<weapon class>"
//     # THE SHOT -- WM_Gun's properties, lower case, each in its property's own shape
//     shotpellets = N              firetics = N                  chambersperpull = N
//     shotspread = yaw, pitch      fullauto = yes | no           firstshotsaccurate = N
//     shotdamage = lo, hi          roundspershot = N             releasetics = N
//     shotclass = "<actor>"        shotrail = yes | no           railcolors = spiral, core   (0xRRGGBB ok)
//     trailprofile = "<profile>"   chargetics = N                chargesound = "<sound>"
//     shotsaw = yes | no           sawsounds = "<full>", "<hit>" sawpuff = "<actor>"
//     spinuptics = N               spindowntics = N
//     roundprofile, flashprofile, altflashprofile, ejectaprofile = "<RS_Ballistics profile>"
//     recoilprofile, altrecoilprofile = "<RS_Ballistics recoil profile>"   (RECOIL_PLAN.md; stored, read by nothing yet)
//     # FROM THE CARD
//     capacity = N                 the gun's rounds -- the card's `capacity`, never a store's
//     firesfrom = chamber | magazine | reserve | none
//     firesound = "<sound>"
//     # WHICH MODEL CARD. Unset: the card named for this gun's own class.
//     model = <model card id>      the class that card was measured for (WM_Rifle). This gun gets ITS OWN COPY of it.
//     # THE GUN'S CLASS, for RS_VR_Weapons' class writer at build time. Never read here: skipped to its `end`.
//     class
//       slot, selectionorder, ammo, hand, name, pickupmessage, upsound, readysound, pickupsound, maxamount
//     end
//     # A SECOND BARREL'S SHOT. Its geometry (input, trigger, from, muzzle, barrel, needs, casing) stays on the card.
//     barrel <id>
//       shotclass = "<actor>"   ammo = "<Ammo class>"   firesound = "<sound>"   firetics = N
//     end
//   end
//
// A sheet with a key it does not know, or a value out of range, is refused whole, with its line, and the
// gun keeps its class's and card's values. So is a second sheet for the same gun. 0 is "unset" for every
// number whose property treats it so (one pellet, 19 tics a shot, ...), so a sheet can copy a class exactly.
//
// WHERE IT LANDS
// - The card keys (capacity, firesfrom, firesound, a barrel's shot) go onto the card once every lump is read,
//   BEFORE WM_Parser.Finish, so Finish checks the card as the sheet leaves it (WM_System.LoadCards).
// - The shot keys go onto every WM_Gun: at WorldLoaded, every gun in the level (a map's own, a start item,
//   one restored from a save), and in WM_Gun.PostBeginPlay, a gun made after that. Each time, the gun's shot
//   fields are first set back to its class's Default and the sheet is laid over them, so a key taken out of
//   a sheet does not linger in a saved game.
// - Never on a rebind: WM_Rig.Bind runs only for the console player (NETPLAY_SPEC problem 2), and a sheet
//   applied there would differ between machines the moment it differs from the class.
//
// NETPLAY: the lumps load on every machine, and both landings run in the playsim alike on every machine --
// no RNG, no consoleplayer, no cvar. WM_Gun reads its own fields exactly as before.
//
// THE PRINTOUT (KEYCONF `wm_card <class> | all | check`, WM_System.LocalUiEvent): a gun's card summary and
// every sheet key with its value and where it came from. `check` lists every key a sheet states that differs
// from the class's Default or the card's own value -- empty while the sheets only copy today's numbers.
// Prints on the sending player's machine only, and changes nothing.
// ============================================================================

class WM_SheetBarrel
{
	String id;
	int    line;
	String shotClassName;   bool shotClassStated;
	String ammoClassName;   bool ammoStated;
	String fireSound;       bool fireSoundStated;
	int    fireTicCount;    bool fireTicsStated;

	// WHAT THE CARD'S BARREL SAID before this sheet was laid over it (WM_SheetReader.ApplyToCards), for `check`.
	bool   landed;
	String cardShotClass;
	String cardAmmo;
	String cardFireSound;
	int    cardFireTics;
}

class WM_Sheet
{
	String weaponClass;
	String sourceName;
	int    line;

	// ---- THE SHOT (WM_Gun), each with whether the sheet states it --------------------------------------
	int    shotPelletCount;                     bool shotPelletsStated;
	double shotSpreadYaw, shotSpreadPitch;      bool shotSpreadStated;
	int    shotDamageLo, shotDamageHi;          bool shotDamageStated;
	int    fireTicCount;                        bool fireTicsStated;
	int    chambersPerPullCount;                bool chambersStated;
	bool   fullAutoFire;                        bool fullAutoStated;
	int    firstShotsDeadOn;                    bool firstShotsStated;
	int    roundsPerShotCount;                  bool roundsPerShotStated;
	String shotClassName;                       bool shotClassStated;
	bool   railShotOn;                          bool shotRailStated;
	int    railSpiralRGB, railCoreRGB;          bool railColorsStated;
	String trailProfileName;                    bool trailProfileStated;
	int    chargeTicCount;                      bool chargeTicsStated;
	String chargeSoundName;                     bool chargeSoundStated;
	bool   sawShotOn;                           bool shotSawStated;
	String sawFullSoundName, sawHitSoundName;   bool sawSoundsStated;
	String sawPuffName;                         bool sawPuffStated;
	int    releaseTicCount;                     bool releaseTicsStated;
	int    spinUpTicCount;                      bool spinUpTicsStated;
	int    spinDownTicCount;                    bool spinDownTicsStated;
	String roundProfileName;                    bool roundProfileStated;
	String flashProfileName;                    bool flashProfileStated;
	String altFlashProfileName;                 bool altFlashProfileStated;
	String ejectaProfileName;                   bool ejectaProfileStated;
	String recoilProfileName;                   bool recoilProfileStated;
	String altRecoilProfileName;                bool altRecoilProfileStated;

	// ---- FROM THE CARD ---------------------------------------------------------------------------------
	int    capacity;       bool capacityStated;
	int    firesFrom;      bool firesFromStated;    // WM_Card.FIRES_*
	String fireSound;      bool fireSoundStated;
	Array<WM_SheetBarrel> barrels;

	// ---- WHICH MODEL CARD (WM_SheetReader.BorrowModels) ------------------------------------------------------
	String modelId;        bool modelStated;

	// WHAT THE CARD SAID before this sheet was laid over it (WM_SheetReader.ApplyToCards), for `check`.
	bool   landedOnCard;
	int    cardCapacity;
	int    cardFiresFrom;
	String cardFireSound;

	WM_SheetBarrel FindBarrel(String barrelId)
	{
		for (int i = 0; i < barrels.Size(); i++)
			if (barrels[i].id ~== barrelId) return barrels[i];
		return null;
	}
}

class WM_SheetReader
{
	// ---- READING ---------------------------------------------------------------------------------------

	static void ParseAll(String text, String sourceName, WM_CardSet into)
	{
		Array<String> lines;
		text.Split(lines, "\n");

		WM_Sheet       sheet   = null;
		WM_SheetBarrel barrel  = null;
		bool           refused = false;
		bool           inClass = false;   // inside a `class` … `end` block, which this reader skips

		for (int ln = 0; ln < lines.Size(); ln++)
		{
			String raw = lines[ln];
			int hash = raw.IndexOf("#");
			if (hash >= 0) raw = raw.Left(hash);
			raw.StripLeftRight();
			if (raw.Length() == 0) continue;

			Array<String> words;
			raw.Split(words, " ", TOK_SKIPEMPTY);
			String head   = words.Size() > 0 ? words[0].MakeLower() : "";
			String second = words.Size() > 1 ? words[1] : "";
			bool   isHeaderShape = (words.Size() >= 2 && second.Left(1) != "=");

			// `gun "<class>"` opens a sheet. An open one before it was never closed: refused.
			if (head == "gun" && isHeaderShape)
			{
				if (sheet && !refused) Refuse(sourceName, ln + 1, "gun " .. sheet.weaponClass, "its block was never closed with `end`");
				sheet   = null;
				barrel  = null;
				refused = false;
				inClass = false;
				String gunWhy = "";
				String gunClass = Unquote(second);
				if (words.Size() != 2) gunWhy = "one weapon class per line: `gun \"<weapon class>\"` alone, then its keys, then `end`";
				else if (into.SheetFor(gunClass) != null) gunWhy = "a sheet for " .. gunClass .. " was already read -- one sheet a gun";
				if (gunWhy != "")
				{
					Refuse(sourceName, ln + 1, raw, gunWhy);
					refused = true;      // skipping to the next gun
					continue;
				}
				sheet = new("WM_Sheet");
				sheet.weaponClass = gunClass;
				sheet.sourceName  = sourceName;
				sheet.line        = ln + 1;
				continue;
			}

			if (refused) continue;
			if (!sheet)
			{
				Refuse(sourceName, ln + 1, raw, "nothing here belongs to a `gun` line");
				continue;
			}

			// A `class` … `end` block: the gun's class, for RS_VR_Weapons' class writer at build time. Skipped whole.
			if (inClass)
			{
				if (raw.MakeLower() == "end") inClass = false;
				continue;
			}
			if (head == "class" && words.Size() == 1)
			{
				if (barrel)
				{
					Refuse(sourceName, ln + 1, raw, "a class block goes in the gun, not inside a barrel block");
					refused = true;
					sheet   = null;
					barrel  = null;
					continue;
				}
				inClass = true;
				continue;
			}

			if (raw.MakeLower() == "end")
			{
				if (barrel)
				{
					sheet.barrels.Push(barrel);
					barrel = null;
				}
				else
				{
					into.sheets.Push(sheet);
					sheet = null;
				}
				continue;
			}

			// `barrel <id>` opens a second barrel's shot, inside a sheet.
			if (head == "barrel" && isHeaderShape)
			{
				String barrelWhy = "";
				if (barrel) barrelWhy = "a barrel block is already open -- close it with `end` first";
				else if (words.Size() != 2) barrelWhy = "`barrel <id>` alone on its line";
				else if (sheet.FindBarrel(Unquote(second)) != null) barrelWhy = "this sheet already has a barrel by that id";
				if (barrelWhy != "")
				{
					Refuse(sourceName, ln + 1, raw, barrelWhy);
					refused = true;
					sheet   = null;
					barrel  = null;
					continue;
				}
				barrel = new("WM_SheetBarrel");
				barrel.id   = Unquote(second);
				barrel.line = ln + 1;
				continue;
			}

			int eq = raw.IndexOf("=");
			String keyWhy = "";
			if (eq <= 0) keyWhy = "a key line is `key = value`";
			else
			{
				String key = raw.Left(eq);
				key.StripLeftRight();
				key = key.MakeLower();
				String val = raw.Mid(eq + 1);
				val.StripLeftRight();
				keyWhy = barrel ? BarrelKey(barrel, key, val) : SheetKey(sheet, key, val);
			}
			if (keyWhy != "")
			{
				Refuse(sourceName, ln + 1, raw, keyWhy);
				refused = true;
				sheet   = null;
				barrel  = null;
			}
		}
		if (sheet && !refused) Refuse(sourceName, lines.Size(), "gun " .. sheet.weaponClass, "its block was never closed with `end`");
	}

	// Returns WHY a sheet key is refused, or "" when it is taken.
	private static String SheetKey(WM_Sheet s, String key, String val)
	{
		String word = Unquote(val);
		String lw = word.MakeLower();
		String a, b;

		if (key == "shotpellets")
		{
			if (!IsWhole(lw) || lw.ToInt(10) > WM_Gun.MAX_SHOT_PELLETS) return String.Format("shotpellets is a whole number, 0 (one pellet) to %d", WM_Gun.MAX_SHOT_PELLETS);
			s.shotPelletCount = lw.ToInt(10);  s.shotPelletsStated = true;
		}
		else if (key == "shotspread")
		{
			if (!SplitTwo(val, a, b) || !IsNumber(a) || !IsNumber(b)) return "shotspread is yaw, pitch -- two numbers of degrees";
			double yaw   = a.ToDouble();
			double pitch = b.ToDouble();
			if (yaw < 0.0 || yaw > 45.0 || pitch < 0.0 || pitch > 45.0) return "shotspread is yaw, pitch -- each 0 to 45 degrees";
			s.shotSpreadYaw = yaw;  s.shotSpreadPitch = pitch;  s.shotSpreadStated = true;
		}
		else if (key == "shotdamage")
		{
			if (!SplitTwo(val, a, b) || !IsWhole(a) || !IsWhole(b)) return "shotdamage is lo, hi -- two whole numbers";
			int lo = a.ToInt(10);
			int hi = b.ToInt(10);
			if (hi < lo) return "shotdamage is lo, hi -- hi cannot be below lo";
			s.shotDamageLo = lo;  s.shotDamageHi = hi;  s.shotDamageStated = true;
		}
		else if (key == "firetics")
		{
			if (!IsWhole(lw) || lw.ToInt(10) > 350) return "firetics is a whole number of tics, 0 (unset: 19) to 350";
			s.fireTicCount = lw.ToInt(10);  s.fireTicsStated = true;
		}
		else if (key == "chambersperpull")
		{
			if (!IsWhole(lw) || lw.ToInt(10) > WM_Gun.MAX_CHAMBERS_PER_PULL) return String.Format("chambersperpull is a whole number, 0 (one) to %d", WM_Gun.MAX_CHAMBERS_PER_PULL);
			s.chambersPerPullCount = lw.ToInt(10);  s.chambersStated = true;
		}
		else if (key == "fullauto")
		{
			int yn = ReadYesNo(lw);
			if (yn < 0) return "fullauto is yes or no";
			s.fullAutoFire = (yn == 1);  s.fullAutoStated = true;
		}
		else if (key == "firstshotsaccurate")
		{
			if (!IsWhole(lw) || lw.ToInt(10) > 1000) return "firstshotsaccurate is a whole number of shots, 0 to 1000";
			s.firstShotsDeadOn = lw.ToInt(10);  s.firstShotsStated = true;
		}
		else if (key == "roundspershot")
		{
			if (!IsWhole(lw) || lw.ToInt(10) > WM_Gun.MAX_ROUNDS_PER_SHOT) return String.Format("roundspershot is a whole number, 0 (one) to %d", WM_Gun.MAX_ROUNDS_PER_SHOT);
			s.roundsPerShotCount = lw.ToInt(10);  s.roundsPerShotStated = true;
		}
		else if (key == "shotclass")      { s.shotClassName       = word;  s.shotClassStated       = true; }
		else if (key == "shotrail")
		{
			int yn = ReadYesNo(lw);
			if (yn < 0) return "shotrail is yes or no";
			s.railShotOn = (yn == 1);  s.shotRailStated = true;
		}
		else if (key == "railcolors")
		{
			if (!SplitTwo(val, a, b) || !IsColorWord(a) || !IsColorWord(b)) return "railcolors is spiral, core -- two colours as whole numbers or 0xRRGGBB";
			int spiral = ColorValue(a);
			int core   = ColorValue(b);
			if (spiral < 0 || spiral > 0xFFFFFF || core < 0 || core > 0xFFFFFF) return "railcolors is spiral, core -- each 0 to 0xFFFFFF";
			s.railSpiralRGB = spiral;  s.railCoreRGB = core;  s.railColorsStated = true;
		}
		else if (key == "trailprofile")   { s.trailProfileName    = word;  s.trailProfileStated    = true; }
		else if (key == "chargetics")
		{
			if (!IsWhole(lw) || lw.ToInt(10) > 350) return "chargetics is a whole number of tics, 0 (no charge) to 350";
			s.chargeTicCount = lw.ToInt(10);  s.chargeTicsStated = true;
		}
		else if (key == "chargesound")    { s.chargeSoundName     = word;  s.chargeSoundStated     = true; }
		else if (key == "shotsaw")
		{
			int yn = ReadYesNo(lw);
			if (yn < 0) return "shotsaw is yes or no";
			s.sawShotOn = (yn == 1);  s.shotSawStated = true;
		}
		else if (key == "sawsounds")
		{
			if (!SplitTwo(val, a, b)) return "sawsounds is \"<full>\", \"<hit>\" -- two sound names";
			s.sawFullSoundName = Unquote(a);  s.sawHitSoundName = Unquote(b);  s.sawSoundsStated = true;
		}
		else if (key == "sawpuff")        { s.sawPuffName         = word;  s.sawPuffStated         = true; }
		else if (key == "releasetics")
		{
			if (!IsWhole(lw) || lw.ToInt(10) > 350) return "releasetics is a whole number of tics, 0 to 350";
			s.releaseTicCount = lw.ToInt(10);  s.releaseTicsStated = true;
		}
		else if (key == "spinuptics")
		{
			if (!IsWhole(lw) || lw.ToInt(10) > 350) return "spinuptics is a whole number of tics, 0 (fires on the pull) to 350";
			s.spinUpTicCount = lw.ToInt(10);  s.spinUpTicsStated = true;
		}
		else if (key == "spindowntics")
		{
			if (!IsWhole(lw) || lw.ToInt(10) > 350) return "spindowntics is a whole number of tics, 0 (twice spinuptics) to 350";
			s.spinDownTicCount = lw.ToInt(10);  s.spinDownTicsStated = true;
		}
		else if (key == "roundprofile")    { s.roundProfileName    = word;  s.roundProfileStated    = true; }
		else if (key == "flashprofile")    { s.flashProfileName    = word;  s.flashProfileStated    = true; }
		else if (key == "altflashprofile") { s.altFlashProfileName = word;  s.altFlashProfileStated = true; }
		else if (key == "ejectaprofile")   { s.ejectaProfileName   = word;  s.ejectaProfileStated   = true; }
		else if (key == "recoilprofile")    { s.recoilProfileName    = word;  s.recoilProfileStated    = true; }
		else if (key == "altrecoilprofile") { s.altRecoilProfileName = word;  s.altRecoilProfileStated = true; }
		else if (key == "capacity")
		{
			if (!IsWhole(lw) || lw.ToInt(10) < 1 || lw.ToInt(10) > 10000) return "capacity is the gun's rounds, a whole number 1 to 10000";
			s.capacity = lw.ToInt(10);  s.capacityStated = true;
		}
		else if (key == "firesfrom")
		{
			int fires = FiresFromWord(lw);
			if (fires < 0) return "firesfrom is chamber, magazine, reserve or none";
			s.firesFrom = fires;  s.firesFromStated = true;
		}
		else if (key == "firesound")       { s.fireSound = word;  s.fireSoundStated = true; }
		else if (key == "model")
		{
			if (word == "" || word.IndexOf(" ") >= 0 || word.IndexOf("\"") >= 0)
				return "model in a sheet is one model card's id -- the class it was measured for, like WM_Rifle. A mesh path belongs on the card";
			s.modelId = word;  s.modelStated = true;
		}
		else if (key == "pellets" || key == "spread" || key == "damage")
			return "the shot lives on WM_Gun -- shotpellets, shotspread, shotdamage";
		else if (IsModelCardKey(key))
			return key .. " stays on the model card (WMCARD) -- a sheet says what the gun shoots, not how it is built";
		else return "unknown sheet key -- see sheet.zs for the list";
		return "";
	}

	// Returns WHY a barrel key is refused, or "" when it is taken.
	private static String BarrelKey(WM_SheetBarrel b, String key, String val)
	{
		String word = Unquote(val);
		String lw = word.MakeLower();
		if      (key == "shotclass") { b.shotClassName = word;  b.shotClassStated = true; }
		else if (key == "ammo")      { b.ammoClassName = word;  b.ammoStated      = true; }
		else if (key == "firesound") { b.fireSound     = word;  b.fireSoundStated = true; }
		else if (key == "firetics")
		{
			if (!IsWhole(lw) || lw.ToInt(10) < 1 || lw.ToInt(10) > 350) return "firetics is a whole number of tics, 1 to 350";
			b.fireTicCount = lw.ToInt(10);  b.fireTicsStated = true;
		}
		else if (key == "input" || key == "trigger" || key == "from" || key == "muzzle" || key == "barrel" || key == "needs" || key == "casing")
			return key .. " is the barrel's geometry and stays on the model card (WMCARD)";
		else return "unknown key in a sheet's barrel block -- shotclass, ammo, firesound or firetics";
		return "";
	}

	// The card keys a sheet does not take, named so a refusal can say where they belong.
	private static bool IsModelCardKey(String key)
	{
		static const String cardKeys[] = {
			"prop", "skin", "type", "handprofile", "hands", "mechanism", "pouch", "casing", "magfamily", "hand",
			"muzzle", "barrel", "ejectport", "ejectdir", "magmodel", "magskin", "magskinempty", "magscale", "magcenter",
			"roundmodel", "roundskin", "roundscale", "linkmodel", "linkskin", "linkscale", "exhaustport", "exhaustdir",
			"drysound", "magoutsound", "maginsound", "slidebacksound", "slidefwdsound", "rackapexsound", "rackresetsound",
			"magdropsound", "casingsound", "cycleoutsound", "cyclehomesound", "loadsound", "ejectsound", "opensound",
			"closesound", "spinupsound", "spinsound", "spindownsound", "pullsound", "startsound", "idlesound", "stopsound"
		};
		for (int i = 0; i < cardKeys.Size(); i++)
			if (cardKeys[i] == key) return true;
		return false;
	}

	// ---- BORROWING A MODEL CARD (before ApplyToCards and WM_Parser.Finish) -------------------------------------
	//
	// A gun whose sheet says `model = <id>` gets ITS OWN COPY of that card: read afresh from the card's own WMCARD
	// lump and renamed to the gun's class. The same parts, stores, verbs, meshes and handling sounds, with no live
	// part state shared with the model's own gun (WM_Part's value, present and spin live on the card -- NETPLAY_SPEC
	// problem 7), so both can be in hand at once. Its hand is the gun's own (+WEAPON.OFFHANDWEAPON), never the
	// model's. It runs before ApplyToCards, so the sheet's card keys land on the copy, and before Finish, which checks
	// the copy like any card. A refusal in that lump is printed a second time as the lump is read again.
	static void BorrowModels(WM_CardSet cardSet)
	{
		for (int i = 0; i < cardSet.sheets.Size(); i++)
		{
			let s = cardSet.sheets[i];
			if (!s.modelStated || s.modelId ~== s.weaponClass) continue;
			if (FindCard(cardSet, s.weaponClass))
			{
				Console.Printf("\c[Red]WM ERROR\c- %s line %d -- the sheet for %s names model %s, and %s has a card of its own. It keeps its own card; remove that card or the model line.",
					s.sourceName, s.line, s.weaponClass, s.modelId, s.weaponClass);
				continue;
			}
			let model = FindCard(cardSet, s.modelId);
			if (!model)
			{
				Console.Printf("\c[Red]WM ERROR\c- %s line %d -- the sheet for %s names model %s, and no card by that id was read. The gun has no card.",
					s.sourceName, s.line, s.weaponClass, s.modelId);
				continue;
			}
			// A MODEL THAT IS ITSELF A COPY is read from its own model's lump, under that model's id.
			String lumpId = (model.modelId != "") ? model.modelId : model.weaponClass;
			// A FRESH, WHOLE COPY (WM_Parser.FreshCard): read again from its lump, and built from its base when it has one.
			let copy = WM_Parser.FreshCard(cardSet, lumpId);
			if (!copy)
			{
				Console.Printf("\c[Red]WM ERROR\c- the sheet for %s: model %s could not be read again from its WMCARD lump. The gun has no card.",
					s.weaponClass, lumpId);
				continue;
			}
			copy.weaponClass = s.weaponClass;
			copy.modelId     = lumpId;
			copy.sourceLump  = model.sourceLump;
			Class<Weapon> wc = (Class<Weapon>)(Object.FindClass(s.weaponClass, "Weapon"));
			if (wc)
			{
				let def = GetDefaultByType(wc);
				if (def) copy.hand = def.bOffhandWeapon ? 1 : 0;
			}
			cardSet.cards.Push(copy);
		}
	}

	// ---- LANDING ON THE CARDS (before WM_Parser.Finish) ----------------------------------------------------

	static void ApplyToCards(WM_CardSet cardSet)
	{
		for (int i = 0; i < cardSet.sheets.Size(); i++)
		{
			let s = cardSet.sheets[i];
			WM_Card c = null;
			for (int k = 0; k < cardSet.cards.Size(); k++)
			{
				if (cardSet.cards[k].weaponClass ~== s.weaponClass)
				{
					c = cardSet.cards[k];
					break;
				}
			}
			if (!c)
			{
				bool cardKeys = s.capacityStated || s.firesFromStated || s.fireSoundStated || s.barrels.Size() > 0;
				if (cardKeys)
					Console.Printf("\c[Red]WM ERROR\c- %s line %d -- the sheet for %s: no WMCARD card by that weapon class, so its capacity, firesfrom, firesound and barrels go nowhere. Its shot keys still reach the gun.",
						s.sourceName, s.line, s.weaponClass);
				continue;
			}
			s.landedOnCard  = true;
			s.cardCapacity  = c.capacity;
			s.cardFiresFrom = c.firesFrom;
			s.cardFireSound = c.fireSound;
			if (s.capacityStated)  c.capacity  = s.capacity;
			if (s.firesFromStated)
			{
				c.firesFrom = s.firesFrom;
				if (c.firesFromLine <= 0) c.firesFromLine = s.line;
			}
			if (s.fireSoundStated) c.fireSound = s.fireSound;

			for (int j = 0; j < s.barrels.Size(); j++)
			{
				let sb = s.barrels[j];
				WM_Barrel cb = null;
				for (int k = 0; k < c.barrels.Size(); k++)
				{
					if (c.barrels[k].id ~== sb.id)
					{
						cb = c.barrels[k];
						break;
					}
				}
				if (!cb)
				{
					Console.Printf("\c[Red]WM ERROR\c- %s line %d -- the sheet for %s names barrel %s, and its card has no barrel by that id. Skipped.",
						s.sourceName, sb.line, s.weaponClass, sb.id);
					continue;
				}
				sb.landed        = true;
				sb.cardShotClass = cb.shotClassName;
				sb.cardAmmo      = cb.ammoClassName;
				sb.cardFireSound = cb.fireSound;
				sb.cardFireTics  = cb.fireTicCount;
				if (sb.shotClassStated) cb.shotClassName = sb.shotClassName;
				if (sb.ammoStated)      cb.ammoClassName = sb.ammoClassName;
				if (sb.fireSoundStated) cb.fireSound     = sb.fireSound;
				if (sb.fireTicsStated)  cb.fireTicCount  = sb.fireTicCount;
			}
		}
	}

	// ---- LANDING ON A GUN ---------------------------------------------------------------------------------------
	//
	// WM_Gun.TakeSheet (weapon.zs), called by WM_System.ApplySheet at WorldLoaded and from WM_Gun.PostBeginPlay. It
	// lives on the gun because a plain data class like this one may not write an actor's fields.

	// ---- THE PRINTOUT (`wm_card`) ------------------------------------------------------------------------------

	static void Print(WM_CardSet cardSet, String what)
	{
		String arg = what;
		arg.StripLeftRight();
		String lower = arg.MakeLower();
		if (!cardSet)
		{
			Console.Printf("\c[Gold]WM CARD:\c- no cards are loaded yet.");
			return;
		}
		if (arg == "" || arg == "%1")
		{
			Console.Printf("\c[Gold]WM CARD:\c- wm_card <weapon class> | all | check");
			return;
		}
		if (lower == "check")
		{
			Check(cardSet);
			return;
		}
		if (lower == "all")
		{
			for (int i = 0; i < cardSet.cards.Size(); i++) PrintGun(cardSet, cardSet.cards[i].weaponClass);
			for (int i = 0; i < cardSet.sheets.Size(); i++)
				if (!cardSet.sheets[i].landedOnCard) PrintGun(cardSet, cardSet.sheets[i].weaponClass);
			Console.Printf("\c[Gold]WM CARD:\c- %d card(s), %d sheet(s).", cardSet.cards.Size(), cardSet.sheets.Size());
			return;
		}
		PrintGun(cardSet, arg);
	}

	private static void PrintGun(WM_CardSet cardSet, String weaponClass)
	{
		WM_Card c = null;
		for (int k = 0; k < cardSet.cards.Size(); k++)
			if (cardSet.cards[k].weaponClass ~== weaponClass) { c = cardSet.cards[k]; break; }
		let s = cardSet.SheetFor(weaponClass);
		Class<WM_Gun> gc = (Class<WM_Gun>)(Object.FindClass(weaponClass, "WM_Gun"));
		if (!c && !s && !gc)
		{
			Console.Printf("\c[Gold]WM CARD:\c- %s -- no card, no sheet and no WM_Gun class by that name.", weaponClass);
			return;
		}

		Console.Printf("\c[Gold]WM CARD %s\c- -- model card %s; sheet %s; class %s",
			weaponClass, c ? (((c.modelId != "") ? c.modelId .. " (this gun's own copy)" : c.weaponClass .. " (" .. c.sourceName .. ")") .. ((c.baseId != "") ? ", starting from " .. c.baseId : "")) : "none",
			s ? String.Format("%s line %d", s.sourceName, s.line) : "none", gc ? "WM_Gun" : "NOT a WM_Gun class");
		bool has = (s != null);
		if (c)
		{
			Console.Printf("  card: %s hand, %d parts, drawn as %s; verbs %s; type %s",
				(c.hand == 0) ? "main" : "off", c.parts.Size(), c.propClass, c.VerbsSummary(), c.gunType);
			Row("capacity",  String.Format("%d", c.capacity),           has && s.capacityStated,  "card");
			Row("firesfrom", FiresFromName(c.firesFrom),                has && s.firesFromStated, "card");
			Row("firesound", Quoted(c.fireSound),                       has && s.fireSoundStated, "card");
			for (int j = 0; j < c.barrels.Size(); j++)
			{
				let cb = c.barrels[j];
				let sb = has ? s.FindBarrel(cb.id) : null;
				bool sbHas = (sb != null && sb.landed);
				Console.Printf("  barrel %s:", cb.id);
				Row("  shotclass", Quoted(cb.shotClassName),             sbHas && sb.shotClassStated, "card");
				Row("  ammo",      Quoted(cb.ammoClassName),             sbHas && sb.ammoStated,      "card");
				Row("  firesound", Quoted(cb.fireSound),                 sbHas && sb.fireSoundStated, "card");
				Row("  firetics",  String.Format("%d", cb.fireTicCount), sbHas && sb.fireTicsStated,  "card");
			}
		}
		if (!gc) return;
		let def = GetDefaultByType(gc);
		if (!def) return;
		Row("shotpellets",        String.Format("%d", has && s.shotPelletsStated ? s.shotPelletCount : def.shotPelletCount),  has && s.shotPelletsStated, "class");
		Row("shotspread",         has && s.shotSpreadStated ? String.Format("%g, %g", s.shotSpreadYaw, s.shotSpreadPitch) : String.Format("%g, %g", def.shotSpreadYaw, def.shotSpreadPitch), has && s.shotSpreadStated, "class");
		Row("shotdamage",         has && s.shotDamageStated ? String.Format("%d, %d", s.shotDamageLo, s.shotDamageHi) : String.Format("%d, %d", def.shotDamageLo, def.shotDamageHi), has && s.shotDamageStated, "class");
		Row("firetics",           String.Format("%d", has && s.fireTicsStated ? s.fireTicCount : def.fireTicCount),          has && s.fireTicsStated, "class");
		Row("chambersperpull",    String.Format("%d", has && s.chambersStated ? s.chambersPerPullCount : def.chambersPerPullCount), has && s.chambersStated, "class");
		Row("fullauto",           YesNo(has && s.fullAutoStated ? s.fullAutoFire : def.fullAutoFire),                        has && s.fullAutoStated, "class");
		Row("firstshotsaccurate", String.Format("%d", has && s.firstShotsStated ? s.firstShotsDeadOn : def.firstShotsDeadOn),  has && s.firstShotsStated, "class");
		Row("roundspershot",      String.Format("%d", has && s.roundsPerShotStated ? s.roundsPerShotCount : def.roundsPerShotCount), has && s.roundsPerShotStated, "class");
		Row("shotclass",          Quoted(has && s.shotClassStated ? s.shotClassName : def.shotClassName),                     has && s.shotClassStated, "class");
		Row("shotrail",           YesNo(has && s.shotRailStated ? s.railShotOn : def.railShotOn),                            has && s.shotRailStated, "class");
		Row("railcolors",         has && s.railColorsStated ? String.Format("0x%06X, 0x%06X", s.railSpiralRGB, s.railCoreRGB) : String.Format("0x%06X, 0x%06X", def.railSpiralRGB, def.railCoreRGB), has && s.railColorsStated, "class");
		Row("trailprofile",       Quoted(has && s.trailProfileStated ? s.trailProfileName : def.trailProfileName),           has && s.trailProfileStated, "class");
		Row("chargetics",         String.Format("%d", has && s.chargeTicsStated ? s.chargeTicCount : def.chargeTicCount),    has && s.chargeTicsStated, "class");
		Row("chargesound",        Quoted(has && s.chargeSoundStated ? s.chargeSoundName : def.chargeSoundName),              has && s.chargeSoundStated, "class");
		Row("shotsaw",            YesNo(has && s.shotSawStated ? s.sawShotOn : def.sawShotOn),                               has && s.shotSawStated, "class");
		Row("sawsounds",          has && s.sawSoundsStated ? Quoted(s.sawFullSoundName) .. ", " .. Quoted(s.sawHitSoundName) : Quoted(def.sawFullSoundName) .. ", " .. Quoted(def.sawHitSoundName), has && s.sawSoundsStated, "class");
		Row("sawpuff",            Quoted(has && s.sawPuffStated ? s.sawPuffName : def.sawPuffName),                          has && s.sawPuffStated, "class");
		Row("releasetics",        String.Format("%d", has && s.releaseTicsStated ? s.releaseTicCount : def.releaseTicCount), has && s.releaseTicsStated, "class");
		Row("spinuptics",         String.Format("%d", has && s.spinUpTicsStated ? s.spinUpTicCount : def.spinUpTicCount),    has && s.spinUpTicsStated, "class");
		Row("spindowntics",       String.Format("%d", has && s.spinDownTicsStated ? s.spinDownTicCount : def.spinDownTicCount), has && s.spinDownTicsStated, "class");
		Row("roundprofile",       Quoted(has && s.roundProfileStated ? s.roundProfileName : def.roundProfileName),           has && s.roundProfileStated, "class");
		Row("flashprofile",       Quoted(has && s.flashProfileStated ? s.flashProfileName : def.flashProfileName),           has && s.flashProfileStated, "class");
		Row("altflashprofile",    Quoted(has && s.altFlashProfileStated ? s.altFlashProfileName : def.altFlashProfileName),  has && s.altFlashProfileStated, "class");
		Row("ejectaprofile",      Quoted(has && s.ejectaProfileStated ? s.ejectaProfileName : def.ejectaProfileName),        has && s.ejectaProfileStated, "class");
		Row("recoilprofile",      Quoted(has && s.recoilProfileStated ? s.recoilProfileName : def.recoilProfileName),        has && s.recoilProfileStated, "class");
		Row("altrecoilprofile",   Quoted(has && s.altRecoilProfileStated ? s.altRecoilProfileName : def.altRecoilProfileName), has && s.altRecoilProfileStated, "class");
	}

	private static void Row(String key, String value, bool fromSheet, String otherwise)
	{
		Console.Printf("    %s = %s  -- %s", key, value, fromSheet ? "sheet" : otherwise);
	}

	// EVERY KEY A SHEET STATES THAT DIFFERS from the class's Default or the card's own value.
	private static void Check(WM_CardSet cardSet)
	{
		int diffs = 0;
		for (int i = 0; i < cardSet.sheets.Size(); i++)
		{
			let s = cardSet.sheets[i];
			String who = String.Format("%s (%s line %d)", s.weaponClass, s.sourceName, s.line);
			Class<WM_Gun> gc = (Class<WM_Gun>)(Object.FindClass(s.weaponClass, "WM_Gun"));
			if (!gc)
			{
				Console.Printf("  %s: no WM_Gun class by that name", who);
				diffs++;
			}
			else
			{
				let def = GetDefaultByType(gc);
				if (s.shotPelletsStated && s.shotPelletCount != def.shotPelletCount)            diffs += Diff(who, "shotpellets", String.Format("%d", def.shotPelletCount), String.Format("%d", s.shotPelletCount));
				if (s.shotSpreadStated && (abs(s.shotSpreadYaw - def.shotSpreadYaw) > 1e-6 || abs(s.shotSpreadPitch - def.shotSpreadPitch) > 1e-6))
					diffs += Diff(who, "shotspread", String.Format("%g, %g", def.shotSpreadYaw, def.shotSpreadPitch), String.Format("%g, %g", s.shotSpreadYaw, s.shotSpreadPitch));
				if (s.shotDamageStated && (s.shotDamageLo != def.shotDamageLo || s.shotDamageHi != def.shotDamageHi))
					diffs += Diff(who, "shotdamage", String.Format("%d, %d", def.shotDamageLo, def.shotDamageHi), String.Format("%d, %d", s.shotDamageLo, s.shotDamageHi));
				if (s.fireTicsStated && s.fireTicCount != def.fireTicCount)                     diffs += Diff(who, "firetics", String.Format("%d", def.fireTicCount), String.Format("%d", s.fireTicCount));
				if (s.chambersStated && s.chambersPerPullCount != def.chambersPerPullCount)     diffs += Diff(who, "chambersperpull", String.Format("%d", def.chambersPerPullCount), String.Format("%d", s.chambersPerPullCount));
				if (s.fullAutoStated && s.fullAutoFire != def.fullAutoFire)                     diffs += Diff(who, "fullauto", YesNo(def.fullAutoFire), YesNo(s.fullAutoFire));
				if (s.firstShotsStated && s.firstShotsDeadOn != def.firstShotsDeadOn)           diffs += Diff(who, "firstshotsaccurate", String.Format("%d", def.firstShotsDeadOn), String.Format("%d", s.firstShotsDeadOn));
				if (s.roundsPerShotStated && s.roundsPerShotCount != def.roundsPerShotCount)    diffs += Diff(who, "roundspershot", String.Format("%d", def.roundsPerShotCount), String.Format("%d", s.roundsPerShotCount));
				if (s.shotClassStated && s.shotClassName != def.shotClassName)                  diffs += Diff(who, "shotclass", Quoted(def.shotClassName), Quoted(s.shotClassName));
				if (s.shotRailStated && s.railShotOn != def.railShotOn)                         diffs += Diff(who, "shotrail", YesNo(def.railShotOn), YesNo(s.railShotOn));
				if (s.railColorsStated && (s.railSpiralRGB != def.railSpiralRGB || s.railCoreRGB != def.railCoreRGB))
					diffs += Diff(who, "railcolors", String.Format("0x%06X, 0x%06X", def.railSpiralRGB, def.railCoreRGB), String.Format("0x%06X, 0x%06X", s.railSpiralRGB, s.railCoreRGB));
				if (s.trailProfileStated && s.trailProfileName != def.trailProfileName)         diffs += Diff(who, "trailprofile", Quoted(def.trailProfileName), Quoted(s.trailProfileName));
				if (s.chargeTicsStated && s.chargeTicCount != def.chargeTicCount)               diffs += Diff(who, "chargetics", String.Format("%d", def.chargeTicCount), String.Format("%d", s.chargeTicCount));
				if (s.chargeSoundStated && s.chargeSoundName != def.chargeSoundName)            diffs += Diff(who, "chargesound", Quoted(def.chargeSoundName), Quoted(s.chargeSoundName));
				if (s.shotSawStated && s.sawShotOn != def.sawShotOn)                            diffs += Diff(who, "shotsaw", YesNo(def.sawShotOn), YesNo(s.sawShotOn));
				if (s.sawSoundsStated && (s.sawFullSoundName != def.sawFullSoundName || s.sawHitSoundName != def.sawHitSoundName))
					diffs += Diff(who, "sawsounds", Quoted(def.sawFullSoundName) .. ", " .. Quoted(def.sawHitSoundName), Quoted(s.sawFullSoundName) .. ", " .. Quoted(s.sawHitSoundName));
				if (s.sawPuffStated && s.sawPuffName != def.sawPuffName)                        diffs += Diff(who, "sawpuff", Quoted(def.sawPuffName), Quoted(s.sawPuffName));
				if (s.releaseTicsStated && s.releaseTicCount != def.releaseTicCount)            diffs += Diff(who, "releasetics", String.Format("%d", def.releaseTicCount), String.Format("%d", s.releaseTicCount));
				if (s.spinUpTicsStated && s.spinUpTicCount != def.spinUpTicCount)               diffs += Diff(who, "spinuptics", String.Format("%d", def.spinUpTicCount), String.Format("%d", s.spinUpTicCount));
				if (s.spinDownTicsStated && s.spinDownTicCount != def.spinDownTicCount)         diffs += Diff(who, "spindowntics", String.Format("%d", def.spinDownTicCount), String.Format("%d", s.spinDownTicCount));
				if (s.roundProfileStated && s.roundProfileName != def.roundProfileName)         diffs += Diff(who, "roundprofile", Quoted(def.roundProfileName), Quoted(s.roundProfileName));
				if (s.flashProfileStated && s.flashProfileName != def.flashProfileName)         diffs += Diff(who, "flashprofile", Quoted(def.flashProfileName), Quoted(s.flashProfileName));
				if (s.altFlashProfileStated && s.altFlashProfileName != def.altFlashProfileName) diffs += Diff(who, "altflashprofile", Quoted(def.altFlashProfileName), Quoted(s.altFlashProfileName));
				if (s.ejectaProfileStated && s.ejectaProfileName != def.ejectaProfileName)      diffs += Diff(who, "ejectaprofile", Quoted(def.ejectaProfileName), Quoted(s.ejectaProfileName));
				if (s.recoilProfileStated && s.recoilProfileName != def.recoilProfileName)      diffs += Diff(who, "recoilprofile", Quoted(def.recoilProfileName), Quoted(s.recoilProfileName));
				if (s.altRecoilProfileStated && s.altRecoilProfileName != def.altRecoilProfileName) diffs += Diff(who, "altrecoilprofile", Quoted(def.altRecoilProfileName), Quoted(s.altRecoilProfileName));
			}
			if (s.landedOnCard)
			{
				if (s.capacityStated && s.capacity != s.cardCapacity)    diffs += Diff(who, "capacity", String.Format("%d", s.cardCapacity), String.Format("%d", s.capacity));
				if (s.firesFromStated && s.firesFrom != s.cardFiresFrom) diffs += Diff(who, "firesfrom", FiresFromName(s.cardFiresFrom), FiresFromName(s.firesFrom));
				if (s.fireSoundStated && s.fireSound != s.cardFireSound) diffs += Diff(who, "firesound", Quoted(s.cardFireSound), Quoted(s.fireSound));
				for (int j = 0; j < s.barrels.Size(); j++)
				{
					let sb = s.barrels[j];
					if (!sb.landed) continue;
					String bwho = who .. " barrel " .. sb.id;
					if (sb.shotClassStated && sb.shotClassName != sb.cardShotClass) diffs += Diff(bwho, "shotclass", Quoted(sb.cardShotClass), Quoted(sb.shotClassName));
					if (sb.ammoStated && sb.ammoClassName != sb.cardAmmo)           diffs += Diff(bwho, "ammo", Quoted(sb.cardAmmo), Quoted(sb.ammoClassName));
					if (sb.fireSoundStated && sb.fireSound != sb.cardFireSound)     diffs += Diff(bwho, "firesound", Quoted(sb.cardFireSound), Quoted(sb.fireSound));
					if (sb.fireTicsStated && sb.fireTicCount != sb.cardFireTics)    diffs += Diff(bwho, "firetics", String.Format("%d", sb.cardFireTics), String.Format("%d", sb.fireTicCount));
				}
			}
		}
		Console.Printf("\c[Gold]WM CARD CHECK:\c- %d sheet(s), %d difference(s) from the classes and cards%s",
			cardSet.sheets.Size(), diffs, (diffs == 0) ? " -- every sheet matches." : ".");
	}

	private static int Diff(String who, String key, String was, String now)
	{
		Console.Printf("  %s: %s  class/card %s, sheet %s", who, key, was, now);
		return 1;
	}

	// ---- SMALL HELPERS (the parser's own are private to WM_Parser) ------------------------------------------

	private static WM_Card FindCard(WM_CardSet cardSet, String cardId)
	{
		for (int k = 0; k < cardSet.cards.Size(); k++)
			if (cardSet.cards[k].weaponClass ~== cardId) return cardSet.cards[k];
		return null;
	}

	private static void Refuse(String src, int line, String what, String why)
	{
		Console.Printf("\c[Red]WM ERROR\c- refused %s line %d -- \"%s\": %s. That sheet is skipped; its gun keeps its class's and card's values.",
			src, line, what, why);
		// THE COMPILE CHECK (zscript/wm/cardvalidator.zs): while the engine runs the data validators, the same refusal
		// fails the check. False in play.
		if (DataValidation.Running())
			DataValidation.Refuse(String.Format("%s line %d", src, line), String.Format("sheet '%s': %s", what, why));
	}

	private static String Unquote(String s)
	{
		s.StripLeftRight();
		if (s.Length() >= 2 && s.Left(1) == "\"" && s.Mid(s.Length() - 1) == "\"")
			return s.Mid(1, s.Length() - 2);
		return s;
	}

	private static String Quoted(String s) { return "\"" .. s .. "\""; }

	private static String YesNo(bool b) { return b ? "yes" : "no"; }

	private static bool SplitTwo(String v, out String a, out String b)
	{
		Array<String> n;
		v.Split(n, ",", TOK_SKIPEMPTY);
		if (n.Size() != 2) return false;
		a = n[0];
		a.StripLeftRight();
		b = n[1];
		b.StripLeftRight();
		return true;
	}

	// 1 yes, 0 no, -1 neither.
	private static int ReadYesNo(String v)
	{
		if (v == "yes" || v == "true"  || v == "1") return 1;
		if (v == "no"  || v == "false" || v == "0") return 0;
		return -1;
	}

	private static bool IsNumber(String v)
	{
		int n = v.Length();
		if (n == 0) return false;
		int digits = 0;
		int dots = 0;
		for (int i = 0; i < n; i++)
		{
			int c = v.ByteAt(i);
			if (c >= 48 && c <= 57) digits++;                           // 0-9
			else if (c == 46) { dots++; if (dots > 1) return false; }   // .
			else if ((c == 45 || c == 43) && i == 0) continue;          // - or + leading
			else return false;
		}
		return digits > 0;
	}

	private static bool IsWhole(String v)
	{
		int n = v.Length();
		if (n == 0) return false;
		for (int i = 0; i < n; i++)
		{
			int c = v.ByteAt(i);
			if (c < 48 || c > 57) return false;
		}
		return true;
	}

	// A colour: decimal digits, or 0x and hex digits.
	private static bool IsColorWord(String v)
	{
		int n = v.Length();
		if (n == 0) return false;
		bool hex = (n > 2 && (v.Left(2) == "0x" || v.Left(2) == "0X"));
		for (int i = hex ? 2 : 0; i < n; i++)
		{
			int c = v.ByteAt(i);
			bool dec = (c >= 48 && c <= 57);
			bool hexDigit = (c >= 65 && c <= 70) || (c >= 97 && c <= 102);
			if (!dec && !(hex && hexDigit)) return false;
		}
		return true;
	}

	// Decimal is read as decimal (a leading 0 is not octal); 0x as hex.
	private static int ColorValue(String v)
	{
		if (v.Length() > 2 && (v.Left(2) == "0x" || v.Left(2) == "0X"))
		{
			String digits = v.Mid(2);
			return digits.ToInt(16);
		}
		return v.ToInt(10);
	}

	private static int FiresFromWord(String lw)
	{
		if (lw == "chamber")  return WM_Card.FIRES_CHAMBER;
		if (lw == "magazine") return WM_Card.FIRES_MAGAZINE;
		if (lw == "reserve")  return WM_Card.FIRES_RESERVE;
		if (lw == "none")     return WM_Card.FIRES_NOTHING;
		return -1;
	}

	private static String FiresFromName(int fires)
	{
		if (fires == WM_Card.FIRES_MAGAZINE) return "magazine";
		if (fires == WM_Card.FIRES_RESERVE)  return "reserve";
		if (fires == WM_Card.FIRES_NOTHING)  return "none";
		return "chamber";
	}
}
