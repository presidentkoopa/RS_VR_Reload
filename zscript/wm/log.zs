// ============================================================================
// THE DIAGNOSTIC LAYER.
//
// WHY THIS EXISTS, IN ONE SENTENCE: this package cannot be tested the way
// everything else is tested.
//
// A headless run of this engine dies at Vulkan init -- there is no window and
// no OpenXR runtime, so the game never reaches a map. That means no automated
// test can ever observe a grab, a drive, a dropped magazine or a pose. The only
// machine that can run this build is the one with the headset on it, and the
// only thing that comes back out of it is TEXT.
//
// So the text has to be worth reading. Every line below exists because some
// question about this system was, at one point, unanswerable from the outside:
//
//   "the gun does not animate"     -- which part, driven by what, to what value
//   "I cannot grab anything"       -- where the grab point is, how far the hand
//                                     is from it, and which of those two failed
//   "the model does not appear"    -- whether the lump resolved, the surfaces
//                                     resolved, and what the mesh actually
//                                     contains versus what the card asked for
//   "it fires full auto"           -- the ammo triple, and every transition
//
// ------------------------------------------------------------------- LEVELS
//
//   0  off
//   1  ERROR   something is broken and the feature will not work
//   2  WARN  + something is suspicious but survivable
//   3  INFO  + state CHANGES: grabs, drops, seats, shots, mode switches
//   4  TRACE + per-tic values. Floods the console. For one specific hunt.
//
// Levels rather than one bool because INFO has to be usable while PLAYING --
// a line per event, readable in the corner of a headset -- and TRACE cannot.
//
// ------------------------------------------ WHY THE CONSTANTS ARE PREFIXED
//
// LV_ERR, not ERR. ZSCRIPT IS CASE-INSENSITIVE: a constant `ERR` and a method
// `Err()` are the same identifier and the compiler refuses the file outright
// with "attempt to redefine". Costs one prefix and saves the next person the
// twenty minutes it cost to find.
// ============================================================================

class WM_Log
{
	const LV_OFF   = 0;
	const LV_ERR   = 1;
	const LV_WARN  = 2;
	const LV_INFO  = 3;
	const LV_TRACE = 4;

	static int Level()
	{
		let c = CVar.GetCVar("wm_log", players[consoleplayer]);
		return c ? c.GetInt() : LV_INFO;
	}

	private static String Tag(int lvl)
	{
		if (lvl <= LV_ERR)  return "\c[Red]WM ERROR\c-";
		if (lvl == LV_WARN) return "\c[Gold]WM warn\c-";
		if (lvl == LV_INFO) return "\c[Cyan]WM\c-";
		return "\c[DarkGray]WM ..\c-";
	}

	static void Say(int lvl, String msg)
	{
		if (Level() < lvl) return;
		Console.Printf("%s %s", Tag(lvl), msg);
	}

	static void Err(String m)   { Say(LV_ERR,   m); }
	static void Warn(String m)  { Say(LV_WARN,  m); }
	static void Info(String m)  { Say(LV_INFO,  m); }
	static void Trace(String m) { Say(LV_TRACE, m); }

	// ---- SAID ONCE --------------------------------------------------------
	//
	// A complaint inside a tic function runs 35 times a second, and 35 copies
	// of "surface not found" is not more informative than one -- it is less,
	// because it pushes the line that mattered off the top of the console.
	//
	// ZSCRIPT HAS NO STATIC MUTABLE STATE, which is why the spoken list is not
	// a static array here (the compiler says "static not allowed" and means
	// it). It lives on the handler instance, and this is the way in.
	play static void Once(int lvl, String key, String msg)
	{
		if (Level() < lvl) return;
		let h = WM_System(EventHandler.Find("WM_System"));
		if (!h) { Say(lvl, msg); return; }   // no handler yet: better loud than lost
		if (h.AlreadySaid(key)) return;
		Say(lvl, msg);
	}

	// Every N tics. For values that genuinely change and are genuinely worth
	// watching -- a drive value, a hand distance -- without 35 lines a second.
	// The caller passes the tic. A static function has no `level` of its own --
	// the global is play-scope state reached through an instance, and reaching
	// for it here is what the compiler means by "left side of maptime is not a
	// struct or class". Every call site already has level.maptime to hand.
	static void Every(int lvl, int tics, int now, String msg)
	{
		if (Level() < lvl) return;
		if (tics < 1) tics = 1;
		if ((now % tics) != 0) return;
		Say(lvl, msg);
	}

	// A heading, so a dump is findable in a wall of scrolling console.
	static void Rule(String title)
	{
		if (Level() < LV_INFO) return;
		Console.Printf("\c[Cyan]---- WM %s ----------------------------------------\c-", title);
	}

	static String Vec(Vector3 v)
	{
		return String.Format("(%.2f, %.2f, %.2f)", v.x, v.y, v.z);
	}

	static String YesNo(bool b) { return b ? "yes" : "no"; }
}
