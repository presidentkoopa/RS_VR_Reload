// VR WEAPON SOUND SELECTION'S PICKS (the weapons lane's companion pk3, the owner's order 2026-09-13).
//
// The companion lets the owner give each gun's each sound slot any sound, with a preview, and declares one
// string cvar per pick: wm_snd_<gun>_<slot>. <gun> is the weapon class lower-cased without its leading "wm_"
// (WM_PumpM37 -> pumpm37). <slot> is the card's sound key without "sound" (fire, dry, magout, ...), plus
// altfire (a barrel's firesound), charge (WM_Gun.ChargeSound) and sawfull / sawhit (WM_Gun.SawSounds).
//
// A pick replaces the card's sound wherever that slot plays. An empty pick, or no such cvar because the
// companion is not loaded, is exactly the card's sound. Resolved on every play and never cached, so a pick
// is heard the next time the slot sounds (a loop: the next time it starts). The picks get baked into the
// cards later; this is the authoring path.
//
// NETPLAY: the pick is read through the GUN OWNER's player (CVar.GetCVar with that PlayerInfo), never the
// console player, so a `user` pick is the same on every machine. It only names a sound -- no state changes,
// and no playsim random draw: a $random sound chooses with the engine's client-side FCRandom
// (pr_randsound, src/sound/s_doomsound.cpp).
//
// Not `For`: ZScript names ignore case, so For is the `for` keyword.
//
// A plain class, so the rig, a weapon and a loose object can all call it.
class WM_SoundPick
{
	// "WM_PumpM37" -> "pumpm37"
	static String GunKey(String weaponClass)
	{
		String key = weaponClass.MakeLower();
		if (key.Left(3) == "wm_") key = key.Mid(3);
		return key;
	}

	static String Pick(PlayerInfo p, String weaponClass, String slot, String fallback)
	{
		if (weaponClass == "" || slot == "") return fallback;
		String cvarName = "wm_snd_" .. GunKey(weaponClass) .. "_" .. slot;
		let c = CVar.GetCVar(cvarName, p);
		if (!c) return fallback;
		String pick = c.GetString();
		return (pick != "") ? pick : fallback;
	}

	// From an actor that may be a player (a gun's Owner), or none.
	static String ForActor(Actor who, String weaponClass, String slot, String fallback)
	{
		if (who && who.player) return Pick(who.player, weaponClass, slot, fallback);
		return Pick(null, weaponClass, slot, fallback);
	}

	// From a player number (a loose object's owner); out of range or not in the game, no player.
	static String ForPlayer(int pn, String weaponClass, String slot, String fallback)
	{
		if (pn >= 0 && pn < MAXPLAYERS && playeringame[pn]) return Pick(players[pn], weaponClass, slot, fallback);
		return Pick(null, weaponClass, slot, fallback);
	}
}
