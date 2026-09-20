// ============================================================================
// WHAT THE GUN IN A HAND WEIGHS (RS_WeaponWeightService).
//
// Found with ServiceIterator.Find("RS_WeaponWeightService"), so no package compiles against
// any other. That indirection is not tidiness: RS_Grenade's hard reference to a class in
// another pk3 "broke the whole game three separate times across three folder layouts" -- a
// ZScript class reference to an archive that is absent, or that loads later, is fatal AND
// global and takes down every mod after it.
//
//   GetDouble("weapon.weight.lbs",  "", hand, 0, pawn)   the held gun EMPTY, in pounds
//   GetInt   ("weapon.weight.has",  "", hand, 0, pawn)   1 it has a weight, 0 it does not,
//                                                        -1 nothing is held in that hand
//   GetInt   ("weapon.weight.rounds","", hand, 0, pawn)  live rounds in the gun right now
//
// Pass a WM_Gun as objectArg instead of a pawn to ask about a specific weapon; pass a pawn
// with hand 0 (main) or 1 (off) to ask what that hand is holding.
//
// ---------------------------------------------------------------- ABSENT IS NOT ZERO
//
// THE `has` COMPANION IS THE WHOLE POINT AND IT IS NOT DECORATION. 70 of 145 guns have no
// published weight -- plasma, the BFG, the Unmaker, most of HacX -- because the weapons lane
// refused to invent seventy numbers to make a column look full, which was the right call.
//
// A service that answers 0.0 for "no data" is the same defect as a recoil impulse reading
// zero for a gun nobody measured: every consumer then treats an ENERGY WEAPON AS WEIGHTLESS
// and makes it snap level while the ballistic guns droop. Ask `has` first. A caller that
// only reads the double gets 0.0 and must treat it as "do not apply weight", never as light.
//
// ------------------------------------------------------------------ WHY NOT CURRENT WEIGHT
//
// The build lane asked for base + rounds x per-round as well, and a PPSh IS 10.30 empty and
// 12.00 with its drum -- a seventh of the gun, and a gun that lightens as you empty it falls
// out of that for free.
//
// This publishes the two halves it OWNS -- the empty weight and the live round count -- and
// not the product, because the third number is `roundmass` and that lives in RS_Ballistics
// (RSBDEFS `roundmass = 324  # grains, 7000 = 1 lb`). Reading it from here would mean naming
// an RS_Ballistics class from this package, which is the coupling above. Whoever owns
// roundmass can expose it the same way and multiply on their own side, with both halves
// already asked for by string.
//
// READS ONLY. It reads WM_Gun.BaseWeightLbs (the sheet's `baseweight`) and the gun's own
// WM_Ammo, and writes, spawns and rolls nothing.
// ============================================================================

class RS_WeaponWeightService : Service
{
	override double GetDouble(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		return RS_WeaponWeightService.AnswerDouble(request, intArg, objectArg);
	}

	override int GetInt(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		return RS_WeaponWeightService.AnswerInt(request, intArg, objectArg);
	}

	// UI CALLERS MUST PASS THE WEAPON. A HUD cannot be told what a hand is holding from
	// here -- that is live playsim state and reading it from ui scope is how a HUD ends up
	// disagreeing with the game on one machine and not another.
	override int GetIntUI(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		return RS_WeaponWeightService.About(request, WM_Gun(objectArg));
	}

	// THE GUN BEING ASKED ABOUT: a weapon handed in directly, or whatever the named hand of
	// the handed-in pawn is holding. hand 0 is main, 1 is off; anything else is neither.
	//
	// PLAY SCOPE, NOT CLEARSCOPE, AND THE COMPILER IS RIGHT TO INSIST. What a hand is holding
	// lives on WM_PlayerHands, which is play -- a clearscope reader of live hand state would
	// be reading the playsim from anywhere, which is the door netplay desync walks through.
	// So the per-hand question is answered in play only; a UI caller passes the weapon itself.
	play static WM_Gun GunOf(int hand, Object objectArg)
	{
		let g = WM_Gun(objectArg);
		if (g) return g;
		let pmo = PlayerPawn(objectArg);
		if (!pmo || !pmo.player) return null;
		if (hand < 0 || hand > 1) return null;
		let sys = WM_System(EventHandler.Find("WM_System"));
		if (!sys) return null;
		let ph = sys.ForPlayer(pmo.PlayerNumber());
		if (!ph || !ph.rigs[hand]) return null;
		return WM_Gun(ph.rigs[hand].gunItem);
	}

	play static double AnswerDouble(String request, int hand, Object objectArg)
	{
		if (!(request ~== "weapon.weight.lbs")) return 0;
		let g = RS_WeaponWeightService.GunOf(hand, objectArg);
		// 0 FROM HERE MEANS "DO NOT APPLY WEIGHT", never "this gun is light". Ask `has`.
		return g ? g.BaseWeightLbs() : 0;
	}

	play static int AnswerInt(String request, int hand, Object objectArg)
	{
		let g = RS_WeaponWeightService.GunOf(hand, objectArg);
		return RS_WeaponWeightService.About(request, g);
	}

	// The same answers for a weapon already in hand -- safe from any scope, because nothing
	// here reads live hand state.
	clearscope static int About(String request, WM_Gun g)
	{
		if (request ~== "weapon.weight.has")
		{
			if (!g) return -1;                       // nothing held: not the same as no data
			return (g.BaseWeightLbs() > 0) ? 1 : 0;  // 0: a real gun whose weight nobody measured
		}
		if (request ~== "weapon.weight.rounds")
		{
			if (!g) return -1;
			// The same count the ammo service calls READY TO FIRE, asked the same way, so the
			// two can never disagree about what is in the gun.
			return RS_WeaponAmmoService.Answer("rounds", g);
		}
		// IDENTITY. ServiceIterator matches a case-insensitive SUBSTRING of the class name, so
		// finding something proves nothing on its own.
		if (request ~== "weapon.weight.hello") return 1;
		return -1;
	}
}
