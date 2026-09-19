// ============================================================================
// A WEAPON THAT LEAVES THE HAND: WHAT A THROWABLE'S CARD SAYS (THROWABLE_PLAN.md §2).
//
// A throwable is a WM_Gun card whose shot is the weapon itself leaving the hand, at the
// hand's own release velocity (RS_WorldHands' thrower). Four blocks and one key say how.
// Each is additive, and unset on every card before them:
//
//   throw ... end        how it leaves the hand, and what happens after  (WM_Throw)
//   route ... end        targets painted while fire is held, steering it  (WM_Route)
//   fuse ... end         the clock from arming to the blast               (WM_Fuse)
//   mount <id> ... end   where it lives on the body                       (WM_Mount)
//   pouch = whole        the pouch hands a whole one from the reserve     (WM_Card.pouchWhole)
//
// Two verbs work its parts (verb.zs): `pulloff`, a pin pulled along its dof until it comes
// away, and `release`, a lever the grip holds shut that springs off when that hand lets go.
//
// CARD DATA, shared and never changed once the cards are loaded, like WM_Barrel. The parser
// reads and checks it (WM_Parser.ThrowKey, RouteKey, FuseKey, MountKey, ThrowableProblem);
// the play code that acts on it is THROWABLE_PLAN.md §8, steps 3 to 5.
// ============================================================================

// `throw` ... `end`
//
//   on        = trigger | grip       the let-go that throws it. Required.
//   minspeed  = <m/s>                slower than this at release is a drop, or a stow at the mount.
//                                    Unset 1.2, RS_WorldHands' rs_throw_min.
//   flight    = "<actor>"            what flies, found by name where it is spawned. Required.
//   speedband = lo, hi               the release speed clamped to this share of the flight's own
//                                    Speed. Unset: not clamped.
//   spin      = wrist | none         the wrist's spin at release goes with it. Unset wrist.
//   plane     = wrist | none         a disc's face held in the wrist's roll at release. Unset none.
//   spends    = N                    reserve spent a throw, 0 to 100. Unset 1, or 0 for a weapon
//                                    that comes back.
//   after     = empty | next | previous
//                                    what the hand holds once it has gone: nothing, so you reach
//                                    the pouch (unset); the next one at once; or the weapon held
//                                    before it.
//   returns   = yes | no             it flies back to the throwing hand. Unset no.
//   catch     = grip | none          closing that hand on the returning weapon takes it back.
//   catchat   = <units>              the catch radius, above 0, at most 64. Unset 6, the reload
//                                    system's wm_catch_radius.
//   miss      = stow | drop          a returning weapon not caught goes back on its mount (unset),
//                                    or falls.
//   recall    = grip | none          a grip press while it flies, outside the catch radius, turns
//                                    it home early.
class WM_Throw
{
	const ON_UNSTATED = 0;
	const ON_TRIGGER  = 1;
	const ON_GRIP     = 2;

	const AFTER_EMPTY    = 0;
	const AFTER_NEXT     = 1;
	const AFTER_PREVIOUS = 2;

	const MISS_STOW = 0;
	const MISS_DROP = 1;

	int     line;             // the line its block opened on, for a refusal found once the card is whole
	int     on;               // ON_*
	double  minSpeed;
	String  flightClass;
	bool    speedBandStated;
	double  speedBandLo;
	double  speedBandHi;
	bool    spinFromWrist;
	bool    planeFromWrist;
	int     spends;
	bool    spendsStated;
	int     after;            // AFTER_*
	bool    returns;
	bool    catchByGrip;
	double  catchAt;
	bool    catchAtStated;
	int     miss;             // MISS_*
	bool    missStated;
	bool    recallByGrip;

	void Init()
	{
		line            = 0;
		on              = ON_UNSTATED;
		minSpeed        = 1.2;
		flightClass     = "";
		speedBandStated = false;
		speedBandLo     = 0.0;
		speedBandHi     = 0.0;
		spinFromWrist   = true;
		planeFromWrist  = false;
		spends          = 1;
		spendsStated    = false;
		after           = AFTER_EMPTY;
		returns         = false;
		catchByGrip     = false;
		catchAt         = 6.0;
		catchAtStated   = false;
		miss            = MISS_STOW;
		missStated      = false;
		recallByGrip    = false;
	}

	static String OnWord(int onKind)
	{
		if (onKind == ON_TRIGGER) return "trigger";
		if (onKind == ON_GRIP)    return "grip";
		return "unstated";
	}

	static String AfterWord(int afterKind)
	{
		if (afterKind == AFTER_NEXT)     return "next";
		if (afterKind == AFTER_PREVIOUS) return "previous";
		return "empty";
	}

	// ONE LINE, for the bind log.
	String Describe()
	{
		String s = String.Format("thrown on letting go of the %s at %.2f m/s or more, flying %s", OnWord(on), minSpeed, flightClass);
		if (speedBandStated) s = s .. String.Format(" (speed clamped to %.2f-%.2f x its own)", speedBandLo, speedBandHi);
		s = s .. (spinFromWrist ? ", the wrist's spin" : ", no spin");
		if (planeFromWrist) s = s .. ", held flat in the wrist's roll";
		s = s .. String.Format(", spends %d, then the hand holds %s", spends,
			(after == AFTER_NEXT) ? "the next one" : ((after == AFTER_PREVIOUS) ? "the weapon from before" : "nothing -- reach the pouch"));
		if (returns)
		{
			s = s .. ", comes back";
			s = s .. (catchByGrip ? String.Format(", caught by closing the hand within %.1f", catchAt) : ", not caught");
			s = s .. ((miss == MISS_DROP) ? ", missed it falls" : ", missed it stows on its mount");
			if (recallByGrip) s = s .. ", recalled by a grip press while it flies";
		}
		return s;
	}
}

// `route` ... `end`
//
//   paint = fire          painted while fire is held. Required; the only way it is painted.
//   range = <units>       how far from the hand a target may be, 64 to 8192. Unset 1200,
//                         RS_ShieldSaw's rs_ss_lock_range.
//   cone  = <degrees>     how far off the hand's aim, above 0, at most 90. Unset 14.
//   max   = N             the most targets, 1 to 16. Unset 5, RS_ShieldSaw's rs_ss_locks.
//   every = N             tics between scans, 1 to 35. Unset 3.
//   mark  = "<actor>"     the mark on a target, a look only, found by name. Unset: no mark.
class WM_Route
{
	// THE MOST A ROUTE HOLDS: what one `wm_throw` carries (THROWABLE_PLAN.md §4.1).
	const MOST_TARGETS = 16;

	int     line;
	bool    paintByFire;
	double  range;
	double  cone;
	int     mostTargets;
	int     everyTics;
	String  markClass;

	void Init()
	{
		line        = 0;
		paintByFire = false;
		range       = 1200.0;
		cone        = 14.0;
		mostTargets = 5;
		everyTics   = 3;
		markClass   = "";
	}

	String Describe()
	{
		return String.Format("a route of up to %d targets, painted while fire is held: within %.0f units and %.1f degrees of the hand's aim, scanned every %d tics%s",
			mostTargets, range, cone, everyTics, (markClass != "") ? (", marked with " .. markClass) : ", unmarked");
	}
}

// `fuse` ... `end`
//
//   tics    = N                           from start to the blast, 1 to 1050 (30 seconds). Required.
//   starts  = pulloff | release | throw   what starts it. Required.
//   blast   = "<actor>"                   what goes off, found by name; its damage is its own. Required.
//   cookoff = player | none               run out in the hand, the blast is at the player (unset), or
//                                         nothing happens.
//   dud     = "<actor>"                   an unarmed throw lands as this pickup, found by name.
//                                         Unset: it just lands.
class WM_Fuse
{
	const STARTS_UNSTATED = 0;
	const STARTS_PULLOFF  = 1;
	const STARTS_RELEASE  = 2;
	const STARTS_THROW    = 3;

	int     line;
	int     tics;
	int     starts;           // STARTS_*
	String  blastClass;
	bool    cookOffAtPlayer;
	String  dudClass;

	void Init()
	{
		line            = 0;
		tics            = 0;
		starts          = STARTS_UNSTATED;
		blastClass      = "";
		cookOffAtPlayer = true;
		dudClass        = "";
	}

	static String StartsWord(int startsKind)
	{
		if (startsKind == STARTS_PULLOFF) return "pulloff";
		if (startsKind == STARTS_RELEASE) return "release";
		if (startsKind == STARTS_THROW)   return "throw";
		return "unstated";
	}

	String Describe()
	{
		return String.Format("a fuse of %d tics from its %s, then %s%s%s", tics, StartsWord(starts), blastClass,
			cookOffAtPlayer ? "; run out in the hand it goes off at the player" : "; run out in the hand nothing happens",
			(dudClass != "") ? ("; unarmed it lands as " .. dudClass) : "");
	}
}

// `mount <id>` ... `end`
//
//   at    = back_left | back_right | forearm_off   where on the body. Required. The two backs are
//                                                  reached over that shoulder; the forearm rides the
//                                                  off hand's arm (RS_ShieldSaw's two mounts).
//   holds = weapon                                 what lives there: the weapon itself. Required.
//
// Drawn from by reaching there and gripping; a stow puts it back.
class WM_Mount
{
	const AT_UNSTATED    = 0;
	const AT_BACK_LEFT   = 1;
	const AT_BACK_RIGHT  = 2;
	const AT_FOREARM_OFF = 3;

	String  id;
	int     line;
	int     at;               // AT_*
	bool    holdsWeapon;

	void Init(String mountId)
	{
		id          = mountId;
		line        = 0;
		at          = AT_UNSTATED;
		holdsWeapon = false;
	}

	static int AtFromWord(String word)
	{
		if (word == "back_left")   return AT_BACK_LEFT;
		if (word == "back_right")  return AT_BACK_RIGHT;
		if (word == "forearm_off") return AT_FOREARM_OFF;
		return AT_UNSTATED;
	}

	static String AtWord(int atKind)
	{
		if (atKind == AT_BACK_LEFT)   return "back_left";
		if (atKind == AT_BACK_RIGHT)  return "back_right";
		if (atKind == AT_FOREARM_OFF) return "forearm_off";
		return "unstated";
	}

	String Describe()
	{
		return String.Format("mount %s at %s, holding the weapon itself", id, AtWord(at));
	}
}
