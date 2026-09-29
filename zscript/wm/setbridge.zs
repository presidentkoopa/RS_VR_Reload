// ============================================================================
// THE SET BRIDGE -- a weapon set IS its parent mod's guns when that mod is loaded, and its own set
// when it is not.
//
// The owner, 2026-09-19: "id like the ww2 guns to serve as THE bwolf guns when bwolf is loaded, and
// just a ww2 weapon set which coincidentially behaves the same way when it isnt loaded. same thing
// for Breach, really."
//
// ONE HOOK, TWO TABLES, CHOSEN BY WHAT IS LOADED.
//
//   parent mod PRESENT -- ITS weapon pickups become ours. Its maps, its placements and its balance
//                         drive the set, and we are not fighting it for the same spawn.
//   parent mod ABSENT  -- DOOM'S pickups become ours instead, so the set slots into Doom, Doom 2,
//                         TNT or Plutonia with no map made for it.
//
// CheckReplacement, NOT `replaces`. `replaces` is decided when the class is compiled and cannot be
// asked a question; this runs per spawn, in script, and can look at what else is in the load order.
// It also fires for EVERY spawn rather than only map placement -- a zombieman dropping a clip is a
// spawn -- so map pickups and monster drops both come through here and no separate drop replacer is
// needed.
//
// DETECTION IS BY STRING AND BY RUNTIME LOOKUP. Object.FindClass(name, "Actor") answers null when the
// mod is absent, so there is no compile-time reference to a pk3 that may not be there -- which is
// fatal AND global in ZScript and has broken this project three times in other places. Same discipline
// as the grip arbiter and the throw service: ask, and carry on if nothing answers.
//
// A SET FILLS IN THREE THINGS and inherits everything else:
//   Marker()     one class name only the parent mod has
//   Configure()  the swaps, reading `parentLoaded`
//   MAPINFO      AddEventHandlers = "<its bridge>"
// ============================================================================

class WM_SetBridge : EventHandler
{
	// True when the parent mod is in the load order. Read it in Configure().
	protected bool parentLoaded;

	private Array<String> mFrom, mTo;
	private bool mReady;

	// ONE CLASS NAME THE PARENT MOD HAS AND NOBODY ELSE DOES. Empty means the set has no parent and
	// always uses its Doom table.
	virtual String Marker() { return ""; }

	// THE PLAYER CLASS THIS SET IS. The owner, 2026-09-20: "i can still load all of the sets it
	// won't matter, it matters what fucking class i pick" -- and "when i play vanilla doom and pick
	// up a shotgun / slot3 weapon, i get a slot3 weapon from whatever weaponset i am using."
	//
	// WITHOUT THIS EVERY LOADED SET ANSWERS AND THE FIRST ONE WINS. CheckReplacement fires for every
	// bridge in the load order and the first match sets e.IsFinal, which locks the rest out -- so
	// with ten sets loaded, Doom's Pistol became whichever set's bridge happened to register first.
	// LOAD ORDER DECIDED YOUR ARSENAL. Picking Blood on the class screen and getting Robocop's guns
	// out of every pickup is not a bug you would file as a race; it just looks broken.
	//
	// Empty means "always answer", which is what a set with no player class of its own wants.
	virtual String SetClass() { return ""; }

	// Push the swaps here. Called once, after parentLoaded is known.
	virtual void Configure() {}

	// replacee -> replacement, by name. Both are plain strings: a set names its parent mod's classes
	// without ever referencing them, which is the whole point.
	protected void Swap(String replacee, String replacement)
	{
		mFrom.Push(replacee);
		mTo.Push(replacement);
	}

	// RESOLVED ONCE, LAZILY. Not in OnRegister: another package's classes are all present by the time
	// anything spawns, and doing it here means the answer cannot depend on handler order.
	private void EnsureReady()
	{
		if (mReady) return;
		mReady = true;
		String mk = Marker();
		parentLoaded = (mk != "") && (Object.FindClass(mk, "Actor") != null);
		Configure();
	}

	// IS THIS SET THE ONE BEING PLAYED?
	//
	// OFF THE FIRST PLAYER IN THE GAME, NOT consoleplayer, AND THAT IS NOT A DETAIL. Replacement is
	// a PLAYSIM decision -- the actor that spawns is one actor in one world -- so every machine has
	// to reach the same answer or the game desyncs. consoleplayer is a different number on every
	// machine, so reading it here would replace differently per client: the classic desync, and
	// invisible until someone plays co-op. Player numbers are the same on every machine, so the
	// lowest one in the game is an answer they all agree on. In single player that is you.
	private bool MineIsChosen() const
	{
		String mine = SetClass();
		if (mine == "") return true;
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i]) continue;
			let c = players[i].cls;
			// No class yet (asked before the player is built) -- answer nothing rather than guess.
			return c && (String.Format("%s", c.GetClassName()) ~== mine);
		}
		return false;
	}

	override void CheckReplacement(ReplaceEvent e)
	{
		EnsureReady();
		// A replacement another handler has already made FINAL is not ours to take.
		if (e.IsFinal || !e.Replacee) return;
		// NOT THE SET BEING PLAYED: say nothing, and leave the spawn for the set that is. Checked
		// BEFORE the name loop so a set that is not chosen never sets IsFinal and never locks out
		// the one that is.
		if (!MineIsChosen()) return;

		// EXACT CLASS NAMES ONLY. A mod's own subclass of a pickup is that mod's business, and
		// replacing a subclass we were never told about is how one set quietly eats another's guns.
		String n = e.Replacee.GetClassName();
		for (int i = 0; i < mFrom.Size(); i++)
		{
			if (mFrom[i] ~== n)
			{
				e.Replacement = mTo[i];

				// FINAL, AND IT HAS TO BE. Without this the engine carries on down the replacement
				// chain and asks what OUR ANSWER is replaced by (info.cpp:621-625, 644) -- and a
				// parent mod that replaces the very class we hand back sends the spawn straight
				// back to it. Brutal Wolfenstein replaces Clip, ClipBox, Shell and ShellBox with
				// random spawners that roll its own ammo, so its clip becoming our Clip becomes its
				// spawner becoming its clip again, round and round until RandomSpawner's recursion
				// cap cuts it off at an arbitrary depth. Every ammo pickup in the game, silently.
				//
				// Final says the question is answered. It costs us nothing -- we already refuse to
				// touch a replacement somebody else made final, so this is the same courtesy back --
				// and the parent's own spawners still work, because a spawner rolls first and we
				// only ever see the leaf it rolled.
				e.IsFinal = true;
				return;
			}
		}
	}
}
