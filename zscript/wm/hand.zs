// ============================================================================
// WHAT EACH HAND IS DOING, AND WHOSE HANDS THEY ARE.
//
// ------------------------------------------------------------ ONE STATE PER HAND
//
// A hand working the other gun is doing exactly one thing: nothing (FREE),
// holding one of that gun's parts (ONPART), carrying one of our magazines
// (CARRY), pushing a magazine into the well (GUIDE), holding a magazine
// something else put in it (FOREIGN), or bracing the gun (BRACE).
//
// These used to be five parallel arrays on WM_System, kept apart only by the
// order WorkHand happened to test them in. Every setter here clears first, so
// two of them at once cannot be written down -- not merely not reached. Every
// verb added later would otherwise have multiplied the combinations.
//
// A MAGAZINE CAN GO OUT FROM UNDER A HAND. The engine nulls a pointer to an
// actor that has been destroyed, and the old arrays were plain pointers, so a
// carry whose magazine vanished simply stopped being a carry. The accessors
// below keep exactly that: Carried() and ForeignMag() read null, and HasHand()
// reads false, for a carry or a foreign hold whose magazine is gone.
//
// ---------------------------------------------------------- ONE CONTAINER PER PLAYER
//
// Everything the system keeps about one player's two hands lives in a
// WM_PlayerHands: the two states, the two guns, and every per-hand scratch
// value. WM_System keeps one per player slot. Today only the console player's
// is ever worked, exactly as before; running the system for every player is a
// loop over these, not a rewrite.
// ============================================================================

class WM_HandState play
{
	const FREE    = 0;
	const ONPART  = 1;   // holding a part of the gun this hand works
	const CARRY   = 2;   // one of OUR magazines, in this hand
	const GUIDE   = 3;   // a magazine being pushed into the well
	const FOREIGN = 4;   // a magazine something else (RS_WorldHands) holds in this hand
	const BRACE   = 5;   // an open hand at the support point

	int         mode;
	int         part;        // ONPART: index into the worked gun's card parts
	WM_LooseMag mag;         // CARRY, GUIDE, FOREIGN
	bool        ours;        // GUIDE: it was our carry before the guide began
	bool        preview;     // CARRY: a tuning preview (wm_heldmag_preview), not a real carry
	bool        leftPouch;   // CARRY, and a GUIDE that was ours: has left the pouch since drawn

	void Clear()
	{
		mode      = FREE;
		part      = -1;
		mag       = null;
		ours      = false;
		preview   = false;
		leftPouch = false;
	}

	// Not OnPart(): that is the same identifier as ONPART to this compiler.
	void Holding(int i)           { Clear(); mode = ONPART;  part = i; }
	void Carrying(WM_LooseMag m)  { Clear(); mode = CARRY;   mag = m; }
	void Foreigner(WM_LooseMag m) { Clear(); mode = FOREIGN; mag = m; }
	void Bracing()                { Clear(); mode = BRACE; }

	// A CARRY GOING INTO THE WELL KEEPS WHETHER IT HAS LEFT THE POUCH. A guide
	// let go of short of the catch goes back to being that same carry, and
	// whether opening the hand inside the pouch puts it back depends on it.
	void Guiding(WM_LooseMag m, bool wasOurs)
	{
		bool lp = leftPouch;
		Clear();
		mode = GUIDE;
		mag  = m;
		ours = wasOurs;
		if (wasOurs) leftPouch = lp;
	}

	// OURS, LET GO OF SHORT OF THE CATCH: carried again, as it was before.
	void ReturnToCarry()
	{
		if (mode != GUIDE) return;
		let m = mag;
		bool lp = leftPouch;
		Carrying(m);
		leftPouch = lp;
	}

	// A GUIDE ENDS WITHOUT GOING BACK TO A CARRY. A magazine RS_WorldHands put
	// in the hand is still in that hand -- being at the well never took it out
	// -- so the hand is FOREIGN again until WorkHand next looks; anything else
	// leaves it free.
	void EndGuide()
	{
		if (mode != GUIDE) return;
		let m = mag;
		if (!ours && m) Foreigner(m);
		else Clear();
	}

	// ---- reading it ---------------------------------------------------------

	// NOT FREE: the test for putting this hand's own gun away. A carry or a
	// foreign hold whose magazine has gone counts as free, as it always did.
	bool HasHand()
	{
		if (mode == ONPART || mode == GUIDE || mode == BRACE) return true;
		if (Held()) return true;
		return false;
	}
	bool IsFree() { return !HasHand(); }

	WM_LooseMag Held()
	{
		if (mode == CARRY || mode == GUIDE || mode == FOREIGN) return mag;
		return null;
	}

	// The part held, or -1.
	int HeldPart()
	{
		if (mode == ONPART) return part;
		return -1;
	}

	WM_LooseMag Carried()
	{
		if (mode == CARRY) return mag;
		return null;
	}

	WM_LooseMag Guided()
	{
		if (mode == GUIDE) return mag;
		return null;
	}

	// A MAGAZINE SOMETHING ELSE HOLDS IN THIS HAND -- loose in it, or being
	// pushed into the well, which does not take it out of that hand. Whoever
	// holds it poses the hand.
	WM_LooseMag ForeignMag()
	{
		if (mode == FOREIGN || (mode == GUIDE && !ours)) return mag;
		return null;
	}

	String ModeName()
	{
		switch (mode)
		{
			case FREE:    return "FREE";
			case ONPART:  return "ONPART";
			case CARRY:   return "CARRY";
			case GUIDE:   return "GUIDE";
			case FOREIGN: return "FOREIGN";
			case BRACE:   return "BRACE";
		}
		return String.Format("UNKNOWN(%d)", mode);
	}
}

// ONE PLAYER'S HANDS. Everything WM_System keeps per hand or per player, so a
// later netplay step runs the same code over each player's container.
class WM_PlayerHands play
{
	int          playerNum;      // the player slot these belong to

	WM_HandState hstate[2];      // what each hand is doing
	WM_Rig       rigs[2];        // the gun each hand holds; hand h works rigs[1-h]

	// Per hand, incidental -- not modes.
	WM_LooseMag  lastForeign[2]; // the foreign magazine last seen in this hand, for the pouch
	bool         gripArm[2];     // grip was held last tic: a press is a fresh squeeze
	bool         pinned[2];      // the drawn hand is seated on a part by us
	Actor        handActors[2];  // RS_WorldHands' drawn hand, found by name
	bool         bonesAsked[2];
	int          lastReach[2];   // what ReachBuzz last buzzed for, -1 nothing
	int          placingSite[2]; // pouch this hand is dragging in placement mode, -1 none
	double       palmFacing[2];  // last palm-to-gun reading, 1 square, 0 sideways
	bool         lastGripHud[2]; // grip state at the last HUD log snapshot
	Vector3      trail[8];       // four samples per hand, the fallback for throws

	// Per player.
	uint         lastButtons;    // for edge-detecting the drop-mag buttons
	int          equipWindow;    // tics left in which a carded gun goes in over a fist
	bool         placeMode;      // RS_VRBody's placement mode moves this player's pouches
	int          lastShotTic;    // this player's last shot, matched to puffs in ImpactFX
	int          lastShotHand;

	void Init(int pn)
	{
		playerNum = pn;
		placingSite[0] = -1;
		placingSite[1] = -1;
		Ensure();
	}

	void Ensure()
	{
		for (int h = 0; h < 2; h++)
		{
			if (!hstate[h]) { hstate[h] = new("WM_HandState"); hstate[h].Clear(); }
			if (!rigs[h])   { rigs[h] = new("WM_Rig"); rigs[h].Init(h); }
		}
	}
}
